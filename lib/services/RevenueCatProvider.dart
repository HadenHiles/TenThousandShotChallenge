import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'RevenueCatConfig.dart';

/// A simple ChangeNotifier that keeps the latest RevenueCat CustomerInfo
/// and exposes convenience getters. Call attach() after Purchases.configure
/// and call refresh() whenever you want to force a fetch from the SDK.
class CustomerInfoNotifier extends ChangeNotifier {
  CustomerInfo? _info;
  bool _attached = false;
  String? _lastSyncedUid;
  bool? _lastSyncedIsPro;

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
      unawaited(_syncProStatusToUserDoc());
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
      await _syncProStatusToUserDoc();
    } catch (_) {
      // Swallow errors; callers can inspect state if needed
    }
  }

  Future<void> _syncProStatusToUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool proNow = isPro;
    if (_lastSyncedUid == user.uid && _lastSyncedIsPro == proNow) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'is_pro': proNow,
        'subscription_level': proNow ? 'pro' : 'free',
      }, SetOptions(merge: true));
      _lastSyncedUid = user.uid;
      _lastSyncedIsPro = proNow;
    } catch (_) {
      // Ignore sync failures; next refresh/listener event will retry.
    }
  }
}
