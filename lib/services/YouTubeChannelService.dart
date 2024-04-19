import 'dart:convert';
import 'package:global_configuration/global_configuration.dart';
import 'package:tenthousandshotchallenge/models/YouTubeVideo.dart';
import 'package:tenthousandshotchallenge/services/HttpProvider.dart';

Future<String> getChannelThumbnail(String id) async {
  final String apiKey = GlobalConfiguration().getValue("web_key");

  return await HttpProvider().getData(
    "https://www.googleapis.com/youtube/v3/channels?part=snippet&id=$id&fields=items%2Fsnippet%2Fthumbnails&key=$apiKey",
    {'cache-control': 'private, max-age=86400'},
  ).then((response) {
    final Map<String, dynamic> data = json.decode(response.body);

    return data["items"][0]["snippet"]["thumbnails"]["medium"]["url"];
  }).catchError((err) {
    print(err);
    return null;
  });
}

Future<List<YouTubeVideo>> getVideos(String channelId) async {
  final String apiKey = GlobalConfiguration().getValue("web_key");

  return await HttpProvider().getData(
    "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=$channelId&key=$apiKey",
    {'cache-control': 'private, max-age=86400', 'Content-Type': 'application/json, charset=utf-8'},
  ).then((response) async {
    final Map<String, dynamic> data = json.decode(response.body);

    List<YouTubeVideo> videos = [];

    final Map<String, dynamic> channel = data["items"][0];

    String playlistId = channel['contentDetails']['relatedPlaylists']['uploads'];

    return await HttpProvider().getData(
      "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$playlistId&maxResults=10&key=$apiKey",
      {'cache-control': 'private, max-age=86400', 'Content-Type': 'application/json, charset=utf-8'},
    ).then((response) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List items = data["items"];

      if (items.length > 0) {
        items.forEach((dynamic i) {
          videos.add(YouTubeVideo(
            i["id"],
            i["snippet"]["title"],
            i["snippet"]["thumbnails"]["medium"]["url"],
          ));
        });
      }

      return videos;
    });
    
    return videos;
  }).catchError((err) {
    print(err);
    return null;
  });
}
