import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class _PendingError {
  const _PendingError(this.error, this.stackTrace, this.reason, this.fatal);

  final Object error;
  final StackTrace stackTrace;
  final String reason;
  final bool fatal;
}

/// Central entry point for production diagnostics.
///
/// Errors raised before Firebase finishes starting are buffered and uploaded
/// once [initialize] succeeds. Use [trace] and [logEvent] around important new
/// workflows so failures have both timing and breadcrumb context.
abstract final class ObservabilityService {
  static const _maxPendingErrors = 20;
  static final List<_PendingError> _pendingErrors = [];
  static bool _initialized = false;
  static bool _supported = false;

  static bool get _supportsNativeMonitoring => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static void installGlobalErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: details.context?.toDescription() ?? 'Flutter framework error',
        fatal: true,
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      recordError(
        error,
        stackTrace,
        reason: 'Uncaught platform dispatcher error',
        fatal: true,
      );
      return true;
    };
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _supported = _supportsNativeMonitoring;
    _initialized = true;
    if (!_supported) return;

    final collectionEnabled = !kDebugMode;
    try {
      await Future.wait([
        FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(collectionEnabled),
        FirebasePerformance.instance.setPerformanceCollectionEnabled(collectionEnabled),
      ]);
    } catch (error) {
      _supported = false;
      _pendingErrors.clear();
      debugPrint('Unable to initialize Firebase observability: $error');
      return;
    }

    if (!collectionEnabled) {
      _pendingErrors.clear();
      return;
    }

    final pendingErrors = List<_PendingError>.of(_pendingErrors);
    _pendingErrors.clear();
    for (final pending in pendingErrors) {
      await _sendError(pending);
    }
  }

  static void recordError(
    Object error,
    StackTrace stackTrace, {
    required String reason,
    bool fatal = false,
  }) {
    final pending = _PendingError(error, stackTrace, reason, fatal);
    if (!_initialized) {
      if (_pendingErrors.length == _maxPendingErrors) {
        _pendingErrors.removeAt(0);
      }
      _pendingErrors.add(pending);
      return;
    }
    if (!_supported || kDebugMode) return;
    unawaited(_sendError(pending));
  }

  static Future<void> _sendError(_PendingError pending) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        pending.error,
        pending.stackTrace,
        reason: pending.reason,
        fatal: pending.fatal,
        printDetails: false,
      );
    } catch (error) {
      debugPrint('Unable to report error to Crashlytics: $error');
    }
  }

  static Future<void> setUser(String? userId) async {
    try {
      await FirebaseAnalytics.instance.setUserId(id: userId);
      if (_supported) {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? 'signed_out');
      }
    } catch (error, stackTrace) {
      recordError(error, stackTrace, reason: 'Setting observability user context');
    }
  }

  static Future<void> setContext(String key, Object value) async {
    if (!_supported || !_initialized) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (error) {
      debugPrint('Unable to set Crashlytics context: $error');
    }
  }

  static Future<void> breadcrumb(String message) async {
    if (!_supported || !_initialized) return;
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (error) {
      debugPrint('Unable to add Crashlytics breadcrumb: $error');
    }
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
      await breadcrumb('event:$name${parameters == null ? '' : ' $parameters'}');
    } catch (error, stackTrace) {
      recordError(error, stackTrace, reason: 'Logging analytics event $name');
    }
  }

  static Future<T> trace<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String> attributes = const {},
    bool reportErrors = true,
  }) async {
    Trace? trace;
    if (_supported && _initialized && !kDebugMode) {
      try {
        trace = FirebasePerformance.instance.newTrace(name);
        for (final attribute in attributes.entries) {
          trace.putAttribute(attribute.key, attribute.value);
        }
        await trace.start();
      } catch (error) {
        debugPrint('Unable to start performance trace $name: $error');
        trace = null;
      }
    }

    try {
      return await operation();
    } catch (error, stackTrace) {
      if (reportErrors) {
        recordError(error, stackTrace, reason: 'Operation failed: $name');
      }
      rethrow;
    } finally {
      if (trace != null) {
        try {
          await trace.stop();
        } catch (error) {
          debugPrint('Unable to stop performance trace $name: $error');
        }
      }
    }
  }
}

class ObservabilityNavigatorObserver extends NavigatorObserver {
  void _record(Route<dynamic>? route) {
    final routeName = route?.settings.name;
    if (routeName == null || routeName.isEmpty) return;
    unawaited(ObservabilityService.setContext('current_route', routeName));
    unawaited(ObservabilityService.breadcrumb('route:$routeName'));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _record(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _record(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _record(newRoute);
  }
}
