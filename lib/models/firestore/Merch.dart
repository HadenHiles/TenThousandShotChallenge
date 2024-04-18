import 'package:cloud_firestore/cloud_firestore.dart';

class Merch {
  final String? title;
  final String? url;
  final String? image;
  DocumentReference? reference;

  Merch(this.title, this.url, this.image);

  Merch.fromMap(Map<String, dynamic> map, {this.reference})
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

  Merch.fromSnapshot(DocumentSnapshot snapshot) : this.fromMap(snapshot.data() as Map<String, dynamic>, reference: snapshot.reference);
}
