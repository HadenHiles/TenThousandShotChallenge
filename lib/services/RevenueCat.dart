import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' show RevenueCatUI;
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';

Future<void> presentPaywallIfNeeded(BuildContext context) async {
  final paywallResult = await RevenueCatUI.presentPaywallIfNeeded("pro");
  log('Paywall result: $paywallResult');
  // After closing paywall, force refresh entitlements so UI updates immediately
  try {
    Purchases.invalidateCustomerInfoCache();
    final notifier = Provider.of<CustomerInfoNotifier>(context, listen: false);
    notifier.attach();
    await notifier.refresh();
  } catch (_) {}
}

// Pull subscription level from RevenueCat customer info loaded in main.dart and passed as a provider
Future<String> subscriptionLevel(BuildContext context) async {
  final ciNotifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
  if (ciNotifier == null) return "free";
  // If we don't have info yet, try to fetch once (non-blocking for long)
  if (ciNotifier.info == null) {
    try {
      await ciNotifier.refresh();
    } catch (_) {}
  }
  return ciNotifier.isPro ? "pro" : "free";
}
