import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart';

class HttpProvider {
  Future<Response> getData(String url, Map<String, String> headers) async {
    var file = await YouTubeCacheManager.instance.getSingleFile(url, headers: headers);
    if (file != null && await file.exists()) {
      var res = await file.readAsString();
      return Response(res, 200);
    }
    return Response(null, 404);
  }
}

class YouTubeCacheManager {
  static const String key = "youtubeCacheKey";
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(seconds: 3),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
