import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

Future<bool> saveShootingSession(List<Shots> shots) async {
  // Get the total number of shots for the session
  int total = 0;
  int wrist = 0;
  int snap = 0;
  int slap = 0;
  int backhand = 0;
  shots.forEach((s) {
    total += s.count;

    switch (s.type) {
      case "wrist":
        wrist += s.count;
        break;
      case "snap":
        snap += s.count;
        break;
      case "slap":
        slap += s.count;
        break;
      case "backhand":
        backhand += s.count;
        break;
      default:
    }
  });

  ShootingSession shootingSession = ShootingSession(total, wrist, snap, slap, backhand, DateTime.now());
  shootingSession.shots = shots;

  Iteration iteration = Iteration(DateTime.now(), null, 0, false);

  return await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) async {
    if (snapshot.docs.isNotEmpty) {
      iteration = Iteration.fromMap(snapshot.docs[0].data());
      saveSessionData(shootingSession, snapshot.docs[0].reference, shots).then((value) => true).onError((error, stackTrace) => false);
    } else {
      await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser.uid).collection('iterations').add(iteration.toMap()).then((i) async {
        saveSessionData(shootingSession, i, shots).then((value) => true).onError((error, stackTrace) => false);
      }).onError((error, stackTrace) {
        print(error);
      });
    }
  }).onError((error, stackTrace) {
    print(error);
  });
}

Future<bool> saveSessionData(ShootingSession shootingSession, DocumentReference ref, List<Shots> shots) async {
  return await ref.collection('sessions').add(shootingSession.toMap()).then((s) async {
    // Get a new write batch
    var batch = FirebaseFirestore.instance.batch();

    shots.forEach((shot) {
      var sRef = s.collection('shots').doc();
      batch.set(sRef, shot.toMap());
    });

    await ref.get().then((i) {
      Iteration iteration = Iteration.fromMap(i.data());
      iteration = Iteration(iteration.startDate, iteration.endDate, (iteration.total + shootingSession.total), iteration.complete);
      batch.update(ref, iteration.toMap());
    });

    return await batch.commit().then((_) => true).onError((error, stackTrace) => false);
  });
}

Future<List<Iteration>> getIterations(String userId) async {
  userId = userId.isNotEmpty ? userId : auth.currentUser.uid;

  List<Iteration> iterations = [];
  return await FirebaseFirestore.instance.collection('iterations').doc(userId).collection('iterations').orderBy('start_date', descending: true).get().then((snapshots) {
    snapshots.docs.forEach((doc) {
      iterations.add(Iteration.fromMap(doc.data()));
    });

    return iterations;
  }).onError((error, stackTrace) => iterations);
}

Future<String> getActiveIterationId(String userId) async {
  userId = userId.isNotEmpty ? userId : auth.currentUser.uid;

  return await FirebaseFirestore.instance.collection('iterations').doc(userId).collection('iterations').where('complete', isEqualTo: false).get().then((snapshots) {
    return snapshots.docs[0].id;
  }).onError((error, stackTrace) => null);
}

Future<List<ShootingSession>> getShootingSessions(String userId, String iterationId) async {
  userId = userId.isNotEmpty ? userId : auth.currentUser.uid;

  List<ShootingSession> shootingSessions = [];
  return await FirebaseFirestore.instance.collection('iterations').doc(userId).collection('iterations').doc(iterationId).collection('sessions').orderBy('date', descending: true).get().then((snapshots) {
    snapshots.docs.forEach((doc) {
      shootingSessions.add(ShootingSession.fromMap(doc.data()));
    });

    return shootingSessions;
  }).onError((error, stackTrace) => shootingSessions);
}