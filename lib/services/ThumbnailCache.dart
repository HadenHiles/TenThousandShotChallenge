import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Two-layer (memory + disk) cache for JPEG thumbnail frames extracted from
/// videos via the `video_thumbnail` package.
///
/// Cache files live in the OS temporary directory under `cr_thumbs/`.  The OS
/// may evict them under storage pressure, but that is acceptable — a cache
/// miss simply falls back to re-extracting the frame from the network.
///
/// The disk key is derived via FNV-1a 32-bit so it is stable across app
/// restarts (unlike Dart's built-in `hashCode`).
///
/// Usage:
/// ```dart
/// // Check before calling VideoThumbnail.thumbnailData:
/// final cached = await ThumbnailDiskCache.instance.getFrame(url, 0);
/// if (cached != null) { /* use cached bytes */ return; }
///
/// // After extracting:
/// ThumbnailDiskCache.instance.putFrame(url, 0, data);
/// ```
class ThumbnailDiskCache {
  ThumbnailDiskCache._();
  static final ThumbnailDiskCache instance = ThumbnailDiskCache._();

  // In-memory layer: avoids the disk round-trip on repeat access within the
  // same app session.
  final Map<String, Uint8List> _mem = {};
  Directory? _dir;

  // ── Directory init ──────────────────────────────────────────────────────

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    final base = await getTemporaryDirectory();
    final d = Directory('${base.path}/cr_thumbs');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return _dir!;
  }

  // ── Key derivation ──────────────────────────────────────────────────────

  /// Stable filesystem-safe key for a video [url] at [timeMs].
  static String _keyFrame(String url, int timeMs) => '${_fnv32(url).toRadixString(16).padLeft(8, '0')}_$timeMs.jpg';

  /// Stable key for the duration-metadata entry of a video [url].
  static String _keyMeta(String url) => '${_fnv32(url).toRadixString(16).padLeft(8, '0')}_meta.txt';

  /// FNV-1a 32-bit — deterministic, fast, no external dependency.
  static int _fnv32(String s) {
    int h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c & 0xFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  // ── Frame API ───────────────────────────────────────────────────────────

  /// Returns the cached JPEG bytes for [url] at [timeMs], or `null` on miss.
  Future<Uint8List?> getFrame(String url, int timeMs) async {
    final k = _keyFrame(url, timeMs);
    final hit = _mem[k];
    if (hit != null) return hit;
    try {
      final dir = await _getDir();
      final f = File('${dir.path}/$k');
      if (await f.exists()) {
        final data = await f.readAsBytes();
        _mem[k] = data;
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Saves [data] for [url] at [timeMs].  The disk write is fire-and-forget.
  void putFrame(String url, int timeMs, Uint8List data) {
    final k = _keyFrame(url, timeMs);
    _mem[k] = data;
    _write(k, data);
  }

  // ── Duration-metadata API ───────────────────────────────────────────────

  /// Returns the cached [stepMs] for [url], or `null` on miss.
  Future<int?> getStepMs(String url) async {
    final k = _keyMeta(url);
    final memEntry = _mem[k];
    if (memEntry != null) {
      return int.tryParse(String.fromCharCodes(memEntry));
    }
    try {
      final dir = await _getDir();
      final f = File('${dir.path}/$k');
      if (await f.exists()) {
        final raw = await f.readAsString();
        final v = int.tryParse(raw.trim());
        if (v != null) _mem[k] = Uint8List.fromList(raw.codeUnits);
        return v;
      }
    } catch (_) {}
    return null;
  }

  /// Saves [stepMs] for [url].  The disk write is fire-and-forget.
  void putStepMs(String url, int stepMs) {
    final raw = stepMs.toString();
    final k = _keyMeta(url);
    _mem[k] = Uint8List.fromList(raw.codeUnits);
    _write(k, Uint8List.fromList(raw.codeUnits));
  }

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _write(String key, Uint8List data) async {
    try {
      final dir = await _getDir();
      await File('${dir.path}/$key').writeAsBytes(data, flush: true);
    } catch (_) {}
  }
}
