import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // For BuildContext & MediaQuery (three-button nav heuristic)
import 'dart:io' show Platform; // For platform check
import 'package:device_info_plus/device_info_plus.dart'; // For Android version

final NumberFormat numberFormat = NumberFormat('###,###,###');

// ── WebM → MP4 URL resolution for iOS ────────────────────────────────────────
//
// The Cloud Function (transcodeWebmToMp4) transcodes every uploaded .webm file
// to H.264 MP4 and stores it at the same Storage path with a .mp4 extension,
// made publicly readable so no auth token is needed.
//
// On iOS, fvp's VT decoder only hardware-accelerates VP9 on macOS 11+; on iOS
// it falls back to CPU software decoding (heat + choppiness).  Switching to
// H.264 MP4 lets iOS use its native VideoToolbox hardware decoder.
//
// Firebase Storage download URL format:
//   https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded_path}?alt=media&token={t}
// Public GCS URL for the transcoded MP4 (no token required):
//   https://storage.googleapis.com/{bucket}/{decoded_path with .mp4}

/// On iOS, converts a Firebase Storage WebM download URL to the public MP4 URL
/// that the [transcodeWebmToMp4] Cloud Function produces.  On all other
/// platforms the original [url] is returned unchanged.
String resolveVideoUrl(String url) {
  if (!Platform.isIOS) return url;
  if (!url.contains('.webm')) return url;

  try {
    // Parse: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded_path}?…
    final uri = Uri.parse(url);
    if (!uri.host.contains('firebasestorage.googleapis.com') && !uri.host.contains('storage.googleapis.com')) return url;

    // Path looks like /v0/b/{bucket}/o/{encoded_file_path}
    final parts = uri.path.split('/o/');
    if (parts.length != 2) return url;

    final bucket = parts[0].replaceFirst('/v0/b/', '');
    final filePath = Uri.decodeComponent(parts[1]).replaceAll('.webm', '.mp4');

    // Re-encode each path segment individually (preserve slashes)
    final encodedPath = filePath.split('/').map(Uri.encodeComponent).join('/');
    return 'https://storage.googleapis.com/$bucket/$encodedPath';
  } catch (_) {
    return url; // Fallback: use original URL as-is
  }
}

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

/// Parses a hex color string (e.g. '#CC3333' or 'CC3333') into a [Color].
/// Falls back to [fallback] (default: app red #CC3333) if null or invalid.
Color colorFromHex(String? hex, {Color fallback = const Color(0xffCC3333)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final clean = hex.replaceFirst('#', '');
  if (clean.length == 6) {
    final value = int.tryParse('ff$clean', radix: 16);
    return value != null ? Color(value) : fallback;
  }
  return fallback;
}

/// Returns the hex string for a [Color] (e.g. '#CC3333').
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}
