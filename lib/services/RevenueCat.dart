import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'RevenueCatConfig.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// The Pro feature a paywall should lead with. Each maps to its own RevenueCat
/// offering (same products, different paywall design); `general` is the
/// original offering that older app versions keep using.
enum PaywallFocus {
  teamBadges('pro_team_badges'),
  challengerRoad('pro_challenger_road'),
  multiTeam('pro_multi_team'),
  general(RevenueCatConfig.proOfferingIdentifier);

  const PaywallFocus(this.offeringId);
  final String offeringId;
}

Future<void> presentPaywallIfNeeded(BuildContext context, {PaywallFocus focus = PaywallFocus.general}) async {
  if (!RevenueCatConfig.configured) {
    log('RevenueCat not configured - cannot show paywall');
    Fluttertoast.showToast(
      msg: "Subscription service not initialized. Please restart the app.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );
    return;
  }

  if (!context.mounted) return;

  try {
    // Prefer the feature-specific offering, falling back to the original one.
    Offering? proOffering;
    try {
      final offerings = await Purchases.getOfferings();
      proOffering = offerings.all[focus.offeringId] ?? offerings.all[RevenueCatConfig.proOfferingIdentifier];
    } catch (e) {
      log('Could not fetch offering "${focus.offeringId}", will use default: $e');
    }

    // Only shows the paywall if the user does not already have the pro entitlement.
    await RevenueCatUI.presentPaywallIfNeeded(
      RevenueCatConfig.proEntitlementIdentifier,
      offering: proOffering,
      displayCloseButton: true,
    );
  } catch (e) {
    log('Exception showing RevenueCat paywall: $e');
    Fluttertoast.showToast(
      msg: "Error loading subscription options: $e",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );
    return;
  }

  // Refresh entitlements after the paywall closes
  if (RevenueCatConfig.configured && context.mounted) {
    Purchases.invalidateCustomerInfoCache();
    final notifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
    notifier?.attach();
    await notifier?.refresh();
  }
}

// Pull subscription level from RevenueCat customer info loaded in main.dart and passed as a provider
Future<String> subscriptionLevel(BuildContext context) async {
  // If widget already unmounted, avoid Provider lookup which crashes
  if (!context.mounted) return "free";
  CustomerInfoNotifier? ciNotifier;
  try {
    ciNotifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
  } catch (_) {
    // Provider not found or context deactivated
    return "free";
  }
  if (ciNotifier == null) return "free";
  if (ciNotifier.info == null) {
    try {
      await ciNotifier.refresh();
    } catch (_) {}
  }
  return ciNotifier.isPro ? "pro" : "free";
}

/// Convenience synchronous accessor (best-effort) for cases where async/await
/// or context safety is tricky (e.g., during dispose). Returns cached value only.
String currentSubscriptionLevelOrCached(BuildContext context) {
  if (!context.mounted) return "free";
  try {
    final ciNotifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
    if (ciNotifier == null) return "free";
    return ciNotifier.isPro ? "pro" : "free";
  } catch (_) {
    return "free";
  }
}
