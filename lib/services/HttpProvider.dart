import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart';

class HttpProvider {
  Future<Response> getData(String url, Map<String, String> headers) async {
    String key = "youtubeCacheKey";
    var file = await CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 1),
        maxNrOfCacheObjects: 20,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    ).getSingleFile(url, headers: headers);
    if (file != null && await file.exists()) {
      var res = await file.readAsString();
      return Response(res, 200);
    }
    return Response(null, 404);
  }
}
