import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart'; // For BuildContext & MediaQuery (three-button nav heuristic)
import 'dart:io' show Platform; // For platform check
import 'package:device_info_plus/device_info_plus.dart'; // For Android version

final NumberFormat numberFormat = NumberFormat('###,###,###');

String printDuration(Duration duration, bool showSeconds) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  String durationString = "";
  if (duration.inHours != 0) {
    durationString += "${twoDigits(duration.inHours)}h ";
  }

  if (duration.inMinutes != 0) {
    durationString += "${twoDigitMinutes}m ";
  }

  if (showSeconds == true) {
    if (duration.inSeconds != 0) {
      durationString += "${twoDigitSeconds}s";
    }
  }

  return durationString;
}

String printDate(DateTime date) {
  return DateFormat("EEEE MMMM d hh:mm a").format(date);
}

String printTime(DateTime date) {
  return DateFormat("hh:mm a").format(date);
}

String printWeekday(DateTime date) {
  switch (date.weekday) {
    case DateTime.sunday:
      return "Sunday";
    case DateTime.monday:
      return "Monday";
    case DateTime.tuesday:
      return "Tuesday";
    case DateTime.wednesday:
      return "Wednesday";
    case DateTime.thursday:
      return "Thursday";
    case DateTime.friday:
      return "Friday";
    case DateTime.saturday:
      return "Saturday";
    default:
      return "";
  }
}

// ---------------- Device Navigation Heuristic ----------------
// Returns true when the device is (likely) using classic 3‑button Android
// system navigation (Back / Home / Recents) instead of full gesture nav.
// Simple heuristic: bottom inset > threshold (many 3-button bars reserve >30).
const double threeButtonNavBottomThreshold = 30.0;

/// Returns the Android SDK int (e.g., 34 for Android 14 / 35 for Android 15) or null if not Android / fails.
int? _cachedAndroidSdkInt; // Null until initialized (or non-Android)
bool _androidSdkInitStarted = false;
bool? _cachedThreeButtonNav; // Null until computed
double? _rawSystemBottomPaddingDp; // For debug/inspection if needed

Future<void> initAndroidSdkVersionCache() async {
  if (_androidSdkInitStarted) return; // Prevent duplicate concurrent init
  _androidSdkInitStarted = true;
  if (!Platform.isAndroid) {
    _cachedAndroidSdkInt = null;
    return;
  }
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    _cachedAndroidSdkInt = info.version.sdkInt;
  } catch (_) {
    _cachedAndroidSdkInt = null; // Fallback; treated as unknown
  }
}

/// Initialize environment data used for navigation heuristics (SDK + system paddings).
Future<void> initNavigationEnvironment() async {
  await initAndroidSdkVersionCache();
  _computeThreeButtonNavIfNeeded();
}

void _computeThreeButtonNavIfNeeded() {
  if (_cachedThreeButtonNav != null) return;
  if (!Platform.isAndroid) {
    _cachedThreeButtonNav = false;
    return;
  }
  try {
    // Use the platform view's padding (in physical pixels) independent of widget tree modifications.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final devicePixelRatio = view.devicePixelRatio;
    final bottomPhysical = view.padding.bottom; // physical pixels
    final bottomDp = bottomPhysical / (devicePixelRatio == 0 ? 1 : devicePixelRatio);
    _rawSystemBottomPaddingDp = bottomDp;
    final sdk = _cachedAndroidSdkInt;
    if (sdk == null) {
      _cachedThreeButtonNav = false;
      return;
    }
    _cachedThreeButtonNav = (bottomDp > threeButtonNavBottomThreshold) && sdk >= 35;
  } catch (_) {
    _cachedThreeButtonNav = false;
  }
}

/// Heuristic to determine whether the user is on Android with 3-button navigation
/// AND running Android 15 (API 35) or later. Uses cached SDK (initialized early).
bool isThreeButtonAndroidNavigation(BuildContext context) {
  if (_cachedThreeButtonNav == null) {
    // Attempt late compute using platform view if not yet done.
    _computeThreeButtonNavIfNeeded();
    if (_cachedThreeButtonNav == null) {
      // Fallback to context-based heuristic while cache not set.
      if (!Platform.isAndroid) return false;
      final bottom = MediaQuery.of(context).viewPadding.bottom;
      final sdk = _cachedAndroidSdkInt;
      return sdk != null && sdk >= 35 && bottom > threeButtonNavBottomThreshold;
    }
  }
  return _cachedThreeButtonNav!;
}

// Optional exposure for debugging / metrics.
double? debugRawSystemBottomPaddingDp() => _rawSystemBottomPaddingDp;
