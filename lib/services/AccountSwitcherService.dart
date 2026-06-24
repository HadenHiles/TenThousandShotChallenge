import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/main.dart' show initRevenueCat;
import 'package:tenthousandshotchallenge/services/authentication/auth.dart';
import 'package:tenthousandshotchallenge/services/bootstrap.dart';

// ── Saved account model ────────────────────────────────────────────────────

class SavedAccount {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// Authentication provider used to sign in: 'google', 'apple', or 'email'.
  final String authProvider;

  const SavedAccount({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    required this.authProvider,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'authProvider': authProvider,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        uid: json['uid'] as String,
        displayName: _sanitizeDisplayName(json['displayName'] as String?),
        email: json['email'] as String?,
        photoUrl: json['photoUrl'] as String?,
        authProvider: (json['authProvider'] as String?) ?? 'email',
      );

  factory SavedAccount.fromFirebaseUser(User user, String provider) => SavedAccount(
        uid: user.uid,
        displayName: _sanitizeDisplayName(user.displayName),
        email: user.email,
        photoUrl: user.photoURL,
        authProvider: provider,
      );

  /// Returns null for names that are blank, literally "null", or "null null"
  /// (which Apple Sign-In can produce when the user's name is unavailable).
  static String? _sanitizeDisplayName(String? name) {
    if (name == null) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'null' || lower == 'null null') return null;
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is SavedAccount && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

// ── Switch result ──────────────────────────────────────────────────────────

class SwitchAccountResult {
  final bool success;
  final bool userCancelled;

  /// True when an email account has no cached password and the caller should
  /// prompt the user to re-enter it, then retry [AccountSwitcherService.switchToAccount]
  /// with [emailPassword] supplied.
  final bool needsPassword;
  final String? errorMessage;

  const SwitchAccountResult._({
    required this.success,
    required this.userCancelled,
    required this.needsPassword,
    this.errorMessage,
  });

  factory SwitchAccountResult.success() => const SwitchAccountResult._(success: true, userCancelled: false, needsPassword: false);

  factory SwitchAccountResult.cancelled() => const SwitchAccountResult._(success: false, userCancelled: true, needsPassword: false);

  factory SwitchAccountResult.needsPassword() => const SwitchAccountResult._(success: false, userCancelled: false, needsPassword: true);

  factory SwitchAccountResult.error(String message) => SwitchAccountResult._(success: false, userCancelled: false, needsPassword: false, errorMessage: message);
}

// ── Service ────────────────────────────────────────────────────────────────

class AccountSwitcherService {
  static const _prefsKey = 'saved_accounts';

  // ── Account list management ────────────────────────────────────────────

  /// Loads saved accounts from SharedPreferences. The currently signed-in
  /// Firebase user is always included, even if they haven't been saved before.
  static Future<List<SavedAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];

    final accounts = raw
        .map((s) {
          try {
            return SavedAccount.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedAccount>()
        .toList();

    // Always ensure the currently-active user appears in the list.
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && !accounts.any((a) => a.uid == current.uid)) {
      accounts.insert(0, SavedAccount.fromFirebaseUser(current, _inferProvider(current)));
    }

    return accounts;
  }

  /// Persists or updates a user account in the saved accounts list.
  /// Call this after any successful sign-in so the account is remembered.
  static Future<void> saveAccount(User user, String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final accounts = raw
        .map((s) {
          try {
            return SavedAccount.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedAccount>()
        .toList();

    final updated = SavedAccount.fromFirebaseUser(user, provider);
    final idx = accounts.indexWhere((a) => a.uid == user.uid);
    if (idx == -1) {
      accounts.add(updated);
    } else {
      accounts[idx] = updated; // Refresh display name / photo URL
    }

    await prefs.setStringList(
      _prefsKey,
      accounts.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  /// Removes an account from the saved list (e.g. when the user removes it
  /// from the switcher).
  static Future<void> removeAccount(String uid) async {
    // Delete any securely-cached email credentials for this account.
    await deleteEmailCredentials(uid);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final accounts = raw
        .map((s) {
          try {
            return SavedAccount.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedAccount>()
        .where((a) => a.uid != uid)
        .toList();

    await prefs.setStringList(
      _prefsKey,
      accounts.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  // ── Account switching ──────────────────────────────────────────────────

  /// Switches the active Firebase session to [account].
  ///
  /// • **Google / Apple** accounts: re-authenticates via the platform provider.
  ///   On modern devices the credential manager handles this silently (no
  ///   visible UI) when the account's session is still valid.
  ///
  /// • **Email** accounts: tries locally-cached credentials first so the switch
  ///   is completely silent.  Returns [SwitchAccountResult.needsPassword] if no
  ///   cached credentials exist yet (first time) or if they have gone stale
  ///   (password changed).  Call again with [emailPassword] to sign in and
  ///   re-cache the new credentials.
  ///
  /// FCM tokens are updated automatically.
  static Future<SwitchAccountResult> switchToAccount(
    SavedAccount account, {
    String? emailPassword,
  }) async {
    final authInstance = FirebaseAuth.instance;
    final firestoreInstance = FirebaseFirestore.instance;
    final oldUid = authInstance.currentUser?.uid;
    String? usedManualPassword;

    try {
      // 1. Clear FCM from the outgoing account so it won't receive
      //    notifications while this device is on a different account.
      if (oldUid != null) {
        await _clearFcmToken(oldUid);
      }

      // 2. Re-authenticate with the appropriate provider.
      //    Firebase Auth switches currentUser atomically, so the router never
      //    sees a null user and won't redirect to /login mid-switch.
      switch (account.authProvider) {
        case 'google':
          await signInWithGoogle();
          break;
        case 'apple':
          // the_apple_sign_in only works on iOS / macOS.
          // On Android, Apple-provider accounts in the saved list cannot be
          // re-authenticated; return a clear error instead of crashing.
          if (!Platform.isIOS && !Platform.isMacOS) {
            if (oldUid != null) await _updateFcmToken(oldUid);
            return SwitchAccountResult.error('Apple Sign-In is only available on Apple devices.');
          }
          await signInWithApple();
          break;
        case 'email':
          // Try cached credentials first for a completely prompt-free switch.
          final cached = await _getEmailCredentials(account.uid);
          if (cached != null) {
            try {
              await authInstance.signInWithEmailAndPassword(
                email: cached['email']!,
                password: cached['password']!,
              );
            } on FirebaseAuthException {
              // Credentials are stale (password changed) – ask the user.
              if (oldUid != null) await _updateFcmToken(oldUid);
              return SwitchAccountResult.needsPassword();
            }
          } else if (emailPassword != null && emailPassword.isNotEmpty) {
            await authInstance.signInWithEmailAndPassword(
              email: account.email ?? '',
              password: emailPassword,
            );
            usedManualPassword = emailPassword;
          } else {
            if (oldUid != null) await _updateFcmToken(oldUid);
            return SwitchAccountResult.needsPassword();
          }
          break;
        default:
          if (oldUid != null) await _updateFcmToken(oldUid);
          return SwitchAccountResult.error('Unknown authentication provider');
      }

      final newUser = authInstance.currentUser;
      if (newUser == null) {
        return SwitchAccountResult.error('Sign-in failed. Please try again.');
      }

      // 3. Assign FCM token to the newly-active account.
      await _updateFcmToken(newUser.uid);

      // 4. Persist refreshed account info (display name / photo may have changed).
      await saveAccount(newUser, _inferProvider(newUser));

      // 5. Cache password for future seamless email switches.
      if (usedManualPassword != null) {
        await cacheEmailCredentials(
          newUser.email ?? account.email ?? '',
          usedManualPassword,
          newUser.uid,
        );
      }

      // 6. Bootstrap Firestore data for the new user.
      await bootstrap(authInstance, firestoreInstance);

      // 7. Update RevenueCat to the new user context.
      try {
        await initRevenueCat(newUser.uid);
      } catch (_) {}

      return SwitchAccountResult.success();
    } on PlatformException catch (e) {
      // Restore FCM on the original account if the switch was aborted.
      if (oldUid != null) await _updateFcmToken(oldUid);
      final cancelCodes = {'ERROR_ABORTED_BY_USER', 'CANCELED', 'sign_in_canceled', 'canceled'};
      if (cancelCodes.contains(e.code)) {
        return SwitchAccountResult.cancelled();
      }
      return SwitchAccountResult.error(e.message ?? 'Authentication failed');
    } catch (e) {
      if (oldUid != null) await _updateFcmToken(oldUid);
      return SwitchAccountResult.error('An error occurred. Please try again.');
    }
  }

  /// Prepares to add a new account:
  /// 1. Saves the current user to the saved list.
  /// 2. Removes the FCM token from their Firestore doc.
  /// 3. Signs out so the router navigates to /login automatically.
  ///
  /// After the user logs in with the new account, [saveAccount] should be
  /// called from the login flow to register the new account.
  static Future<void> prepareAddAccount() async {
    final authInstance = FirebaseAuth.instance;
    final current = authInstance.currentUser;
    if (current != null) {
      await saveAccount(current, _inferProvider(current));
      await _clearFcmToken(current.uid);
    }
    await authInstance.signOut();
  }

  // ── Email credential cache (flutter_secure_storage) ────────────────────

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _credentialKeyPrefix = 'account_credentials_';

  /// Stores [email] + [password] in the device Keychain / Keystore so that
  /// subsequent account switches can happen without prompting the user.
  static Future<void> cacheEmailCredentials(
    String email,
    String password,
    String uid,
  ) async {
    try {
      await _storage.write(
        key: '$_credentialKeyPrefix$uid',
        value: jsonEncode({'email': email, 'password': password}),
      );
    } catch (_) {
      // Best-effort – some devices may not support secure storage.
    }
  }

  /// Retrieves cached email credentials for [uid], or null if none exist.
  static Future<Map<String, String>?> _getEmailCredentials(String uid) async {
    try {
      final raw = await _storage.read(key: '$_credentialKeyPrefix$uid');
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'email': data['email'] as String,
        'password': data['password'] as String,
      };
    } catch (_) {
      return null;
    }
  }

  /// Removes cached email credentials for [uid] (e.g. when an account is
  /// removed from the switcher or when the user explicitly logs out).
  static Future<void> deleteEmailCredentials(String uid) async {
    try {
      await _storage.delete(key: '$_credentialKeyPrefix$uid');
    } catch (_) {}
  }

  // ── FCM helpers ────────────────────────────────────────────────────────

  /// Removes the FCM token from a user's Firestore document so that user no
  /// longer receives push notifications on this device.
  static Future<void> _clearFcmToken(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcm_token': FieldValue.delete()});
    } catch (_) {
      // Best-effort; don't break the switch flow if Firestore is unavailable.
    }
  }

  /// Sets the device's current FCM token on a user's Firestore document so
  /// that user receives push notifications on this device.
  static Future<void> _updateFcmToken(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcm_token': token});
      }
    } catch (_) {
      // Best-effort.
    }
  }

  // ── Provider inference ─────────────────────────────────────────────────

  static String _inferProvider(User user) {
    for (final info in user.providerData) {
      if (info.providerId.contains('google')) return 'google';
      if (info.providerId.contains('apple')) return 'apple';
    }
    return 'email';
  }
}
