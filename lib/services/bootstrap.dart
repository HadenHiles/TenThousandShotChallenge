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
      await FirebaseFirestore.instance
          .collection('iterations')
          .doc(user.uid)
          .collection('iterations')
          .doc()
          .set(Iteration(
            DateTime.now(),
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
            null,
            Duration(),
            0,
            0,
            0,
            0,
            0,
            false,
          ).toMap())
          .then((_) {});
    }
  });

  // Ensure current iterations for existing users will have a default target date
  await FirebaseFirestore.instance.collection('iterations').doc(user.uid).collection('iterations').where('complete', isEqualTo: false).get().then((iSnap) async {
    if (iSnap.docs.isNotEmpty) {
      DocumentReference ref = iSnap.docs[0].reference;
      Iteration i = Iteration.fromSnapshot(iSnap.docs[0]);
      if (i.targetDate == null) {
        Iteration updatedIteration = Iteration(
          i.startDate,
          DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
          i.endDate,
          i.totalDuration,
          i.total,
          i.totalWrist,
          i.totalSnap,
          i.totalSlap,
          i.totalBackhand,
          i.complete,
        );

        await ref.update(updatedIteration.toMap());
      }
    }
  });
}
