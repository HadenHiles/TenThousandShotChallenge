import 'package:cloud_firestore/cloud_firestore.dart';

class LearnToPlayItem {
  final String title;
  final String url;
  final String image;
  DocumentReference reference;

  LearnToPlayItem(this.title, this.url, this.image);

  LearnToPlayItem.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['title'] != null),
        assert(map['url'] != null),
        assert(map['image'] != null),
        title = map['title'],
        url = map['url'],
        image = map['image'];

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'image': image,
    };
  }

  LearnToPlayItem.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
