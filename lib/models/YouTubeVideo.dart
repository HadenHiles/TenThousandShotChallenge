import 'package:cloud_firestore/cloud_firestore.dart';

class YouTubeVideo {
  final String id;
  final String title;
  final String thumbnail;
  String buttonUrl;
  String buttonText;
  String content;
  DocumentReference reference;

  YouTubeVideo(this.id, this.title, this.thumbnail);

  YouTubeVideo.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['id'] != null),
        assert(map['title'] != null),
        id = map['id'],
        title = map['title'],
        thumbnail = map['thumbnail'],
        buttonUrl = map['button_url'],
        buttonText = map['button_text'],
        content = map['content'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
      'button_url': buttonUrl,
      'button_text': buttonText,
      'content': content,
    };
  }

  YouTubeVideo.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
