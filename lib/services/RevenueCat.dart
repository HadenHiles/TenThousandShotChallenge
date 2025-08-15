import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'RevenueCatConfig.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' show RevenueCatUI;
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';

Future<void> presentPaywallIfNeeded(BuildContext context) async {
  final paywallResult = await RevenueCatUI.presentPaywallIfNeeded("pro");
  log('Paywall result: $paywallResult');
  // After closing paywall, force refresh entitlements so UI updates immediately
  try {
    if (!context.mounted) return; // Defensive: caller might have been disposed
    if (RevenueCatConfig.configured) {
      Purchases.invalidateCustomerInfoCache();
      final notifier = Provider.of<CustomerInfoNotifier>(context, listen: false);
      notifier.attach();
      await notifier.refresh();
    }
  } catch (_) {}
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
