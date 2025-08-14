import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'RevenueCatConfig.dart';

/// A simple ChangeNotifier that keeps the latest RevenueCat CustomerInfo
/// and exposes convenience getters. Call attach() after Purchases.configure
/// and call refresh() whenever you want to force a fetch from the SDK.
class CustomerInfoNotifier extends ChangeNotifier {
  CustomerInfo? _info;
  bool _attached = false;

  CustomerInfo? get info => _info;
  bool get isPro => _info?.entitlements.active.isNotEmpty ?? false;
  // RevenueCat v9 returns latestExpirationDate as an ISO8601 String?
  String? get latestExpirationDateString => _info?.latestExpirationDate;
  DateTime? get latestExpirationDateTime {
    final s = _info?.latestExpirationDate;
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Attach a listener to RevenueCat updates (idempotent).
  void attach() {
    if (_attached) return;
    if (!RevenueCatConfig.configured) return; // Defer until configured
    Purchases.addCustomerInfoUpdateListener((CustomerInfo customerInfo) {
      _info = customerInfo;
      notifyListeners();
    });
    _attached = true;
  }

  /// Fetch current CustomerInfo from the SDK and notify listeners.
  Future<void> refresh() async {
    if (!RevenueCatConfig.configured) return;
    try {
      final ci = await Purchases.getCustomerInfo();
      _info = ci;
      notifyListeners();
    } catch (_) {
      // Swallow errors; callers can inspect state if needed
    }
  }
}
