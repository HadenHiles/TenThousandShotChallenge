import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' show RevenueCatUI;

Future<void> presentPaywallIfNeeded() async {
  final paywallResult = await RevenueCatUI.presentPaywallIfNeeded("pro");
  log('Paywall result: $paywallResult');
}

// Pull subscription level from RevenueCat customer info loaded in main.dart and passed as a provider
Future<String> subscriptionLevel(BuildContext context) async {
  final customerInfo = Provider.of<CustomerInfo?>(context, listen: false);
  bool isPro = customerInfo?.entitlements.active.isNotEmpty ?? false;
  return isPro ? "pro" : "free";
}
