import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart';

class HttpProvider {
  Future<Response> getData(String? url, Map<String, String>? headers) async {
    final file = await YouTubeCacheManager.instance.getSingleFile(url!, headers: headers);
    if (await file.exists()) {
      final String res = await file.readAsString();
      return Response(res, 200);
    }
    return Response("", 404);
  }
}

class YouTubeCacheManager {
  static const String key = "youtubeCacheKey";
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// Cache manager for Challenger Road video/media files.
///
/// Videos are kept for 30 days and up to 300 objects. Using a dedicated
/// cache key keeps these assets separate from the YouTube cache so their
/// eviction policies do not interfere with each other.
class ChallengerRoadVideoCache {
  static const String key = 'challengerRoadVideoCache';
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
