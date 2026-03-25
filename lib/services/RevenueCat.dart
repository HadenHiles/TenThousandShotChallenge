import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'RevenueCatConfig.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Custom paywall implementation since RevenueCat UI requires FlutterFragmentActivity
/// which doesn't exist in modern Flutter
Future<void> presentPaywallIfNeeded(BuildContext context) async {
  // Check if user already has pro
  final ciNotifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
  if (ciNotifier?.isPro == true) {
    log('User already has pro subscription');
    return;
  }

  // Show custom paywall
  await _showCustomPaywall(context);
}

Future<void> _showCustomPaywall(BuildContext context) async {
  // Check if RevenueCat SDK is configured first
  if (!RevenueCatConfig.configured) {
    log('RevenueCat not configured - cannot show paywall');
    Fluttertoast.showToast(
      msg: "Subscription service not initialized. Please restart the app.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );
    return;
  }

  try {
    log('Fetching offerings for custom paywall');
    final offerings = await Purchases.getOfferings();

    if (offerings.current == null || offerings.current!.availablePackages.isEmpty) {
      log('No current offering available');
      Fluttertoast.showToast(
        msg: "No subscription options available. Check RevenueCat dashboard configuration.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
      return;
    }

    if (!context.mounted) return;

    // Show custom paywall dialog
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => _PaywallDialog(
        offering: offerings.current!,
        onPurchaseComplete: () async {
          // Refresh entitlements after purchase
          if (RevenueCatConfig.configured) {
            Purchases.invalidateCustomerInfoCache();
            final notifier = Provider.of<CustomerInfoNotifier>(context, listen: false);
            notifier.attach();
            await notifier.refresh();
          }
        },
      ),
    );
  } catch (e) {
    log('Exception showing custom paywall: $e');
    Fluttertoast.showToast(
      msg: "Error loading subscription options: $e",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );
  }
}

class _PaywallDialog extends StatefulWidget {
  final Offering offering;
  final VoidCallback onPurchaseComplete;

  const _PaywallDialog({
    required this.offering,
    required this.onPurchaseComplete,
  });

  @override
  State<_PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends State<_PaywallDialog> {
  bool _isProcessing = false;

  Future<void> _purchasePackage(Package package) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      log('Attempting to purchase package: ${package.identifier}');
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;
      log('Purchase result: ${customerInfo.entitlements.active.isNotEmpty ? "Success" : "No active entitlements"}');

      if (customerInfo.entitlements.active.isNotEmpty) {
        widget.onPurchaseComplete();
        if (mounted) {
          Navigator.of(context).pop();
          Fluttertoast.showToast(
            msg: "Welcome to Pro! 🎉",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
          );
        }
      }
    } on PlatformException catch (e) {
      log('Purchase error: ${e.code} - ${e.message}');
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        Fluttertoast.showToast(
          msg: "Purchase failed: ${e.message}",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upgrade to Pro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock premium features:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('✓ Shot accuracy tracking'),
            const Text('✓ Mini-challenges'),
            const Text('✓ Advanced statistics'),
            const Text('✓ And more!'),
            const SizedBox(height: 20),
            const Text(
              'Choose your plan:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...widget.offering.availablePackages.map((package) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _purchasePackage(package),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '${package.storeProduct.title} - ${package.storeProduct.priceString}',
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
      ],
    );
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
