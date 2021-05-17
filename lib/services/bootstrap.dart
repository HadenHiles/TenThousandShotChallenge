import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';

final user = FirebaseAuth.instance.currentUser;

Future<void> bootstrap() async {
  await bootstrapIterations();
}

Future<void> bootstrapIterations() async {
  await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').get().then((iSnap) async {
    if (iSnap.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').doc().set(Iteration(DateTime.now(), null, 0, 0, 0, 0, 0, false).toMap()).then((_) {});
    }
  });
}
