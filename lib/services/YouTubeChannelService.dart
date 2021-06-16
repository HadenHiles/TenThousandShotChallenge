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
    "https://www.googleapis.com/youtube/v3/search?key=$apiKey&channelId=$channelId&part=snippet,id&order=date&maxResults=20",
    {'cache-control': 'private, max-age=86400'},
  ).then((response) {
    final Map<String, dynamic> data = json.decode(response.body);

    List<YouTubeVideo> videos = [];

    if (data != null) {
      final List items = data["items"];

      if (items != null && items.length > 0) {
        items.forEach((dynamic i) {
          videos.add(YouTubeVideo(
            i["id"]["videoId"],
            i["snippet"]["title"],
            i["snippet"]["thumbnails"]["medium"]["url"],
          ));
        });
      }
    }

    return videos;
  }).catchError((err) {
    print(err);
    return null;
  });
}
