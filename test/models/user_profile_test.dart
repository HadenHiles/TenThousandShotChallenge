import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';

void main() {
  test('missing user document produces an empty profile', () async {
    final firestore = FakeFirebaseFirestore();
    final snapshot = await firestore.collection('users').doc('missing-user').get();

    final profile = UserProfile.fromSnapshot(snapshot);

    expect(profile.reference, snapshot.reference);
    expect(profile.displayName, isNull);
    expect(profile.teamIds, isEmpty);
    expect(profile.public, isFalse);
  });
}
