import 'dart:convert';

import 'package:global_configuration/global_configuration.dart';
import 'package:tenthousandshotchallenge/models/YouTubeVideo.dart';
import 'package:http/http.dart' as http;

Future<String> getChannelThumbnail(String id) async {
  final String apiKey = GlobalConfiguration().getValue("web_key");
  Uri uri = Uri.parse("https://www.googleapis.com/youtube/v3/channels?part=snippet&id=$id&fields=items%2Fsnippet%2Fthumbnails&key=$apiKey");

  return await http.get(uri).then((response) {
    final Map<String, dynamic> data = json.decode(response.body);

    return data["items"][0]["snippet"]["thumbnails"]["medium"]["url"];
  }).catchError((err) {
    print(err);
    return null;
  });
}

Future<List<YouTubeVideo>> getVideos(String channelId) async {
  final String apiKey = GlobalConfiguration().getValue("web_key");
  Uri uri = Uri.parse("https://www.googleapis.com/youtube/v3/search?key=$apiKey&channelId=$channelId&part=snippet,id&order=date&maxResults=20");

  return await http.get(uri).then((response) {
    final Map<String, dynamic> data = json.decode(response.body);

    final List items = data["items"];
    List<YouTubeVideo> videos = [];

    items.forEach((dynamic i) {
      videos.add(YouTubeVideo(
        i["id"]["videoId"],
        i["snippet"]["title"],
        i["snippet"]["thumbnails"]["medium"]["url"],
      ));
    });

    return videos;
  }).catchError((err) {
    print(err);
    return null;
  });
}
