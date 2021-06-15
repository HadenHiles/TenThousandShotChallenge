import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart';

class HttpProvider {
  Future<Response> getData(String url, Map<String, String> headers) async {
    var file = await DefaultCacheManager().getSingleFile(url, headers: headers);
    if (file != null && await file.exists()) {
      var res = await file.readAsString();
      return Response(res, 200);
    }
    return Response(null, 404);
  }
}
