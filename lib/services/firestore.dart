import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Invite.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';

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

  ShootingSession shootingSession = ShootingSession(total, wrist, snap, slap, backhand, DateTime.now(), sessionService.currentDuration);
  shootingSession.shots = shots;

  Iteration iteration = Iteration(DateTime.now(), null, Duration(), 0, 0, 0, 0, 0, false);

  return await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) async {
    if (snapshot.docs.isNotEmpty) {
      iteration = Iteration.fromSnapshot(snapshot.docs[0]);

      // Check if they reached 10,000
      if (iteration.total + total >= 10000) {
        saveSessionData(shootingSession, snapshot.docs[0].reference, shots).then((value) => true).onError((error, stackTrace) => false);
      } else {
        saveSessionData(shootingSession, snapshot.docs[0].reference, shots).then((value) => true).onError((error, stackTrace) => false);
      }
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
      Iteration iteration = Iteration.fromSnapshot(i);
      iteration = Iteration(
        iteration.startDate,
        iteration.endDate,
        (iteration.totalDuration + shootingSession.duration),
        (iteration.total + shootingSession.total),
        (iteration.totalWrist + shootingSession.totalWrist),
        (iteration.totalSnap + shootingSession.totalSnap),
        (iteration.totalSlap + shootingSession.totalSlap),
        (iteration.totalBackhand + shootingSession.totalBackhand),
        iteration.complete,
      );
      batch.update(ref, iteration.toMap());
    });

    return await batch.commit().then((_) => true).onError((error, stackTrace) => false);
  });
}

Future<bool> deleteSession(ShootingSession shootingSession) async {
  return await shootingSession.reference.parent.parent.get().then((iDoc) async {
    Iteration iteration = Iteration.fromSnapshot(iDoc);
    if (!iteration.complete) {
      Iteration decrementedIteration = Iteration(
        iteration.startDate,
        iteration.endDate,
        (iteration.totalDuration - shootingSession.duration),
        (iteration.total - shootingSession.total),
        (iteration.totalWrist - shootingSession.totalWrist),
        (iteration.totalSnap - shootingSession.totalSnap),
        (iteration.totalSlap - shootingSession.totalSlap),
        (iteration.totalBackhand - shootingSession.totalBackhand),
        iteration.complete,
      );
      return await iDoc.reference.update(decrementedIteration.toMap()).then((_) async {
        return await iDoc.reference
            .collection('sessions')
            .doc(shootingSession.reference.id)
            .delete()
            .then(
              (success) => true,
            )
            .onError(
              (error, stackTrace) => null,
            );
      });
    } else {
      return false;
    }
  });
}

Future<bool> startNewIteration() async {
  return await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) async {
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs[0].reference.update({'complete': true, 'end_date': DateTime.now()}).then((_) {
        FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser.uid).collection('iterations').doc().set(Iteration(DateTime.now(), null, Duration(), 0, 0, 0, 0, 0, false).toMap()).then((value) => true);
      });
    }
  }).onError((error, stackTrace) {
    print(error);
  });
}

Future<bool> sendInvite(String fromUid, String toUid) async {
  Invite invite = Invite(fromUid, DateTime.now());
  return await FirebaseFirestore.instance.collection('invites').doc(toUid).collection('invites').doc(fromUid).set(invite.toMap()).then((_) => true).onError((error, stackTrace) => null);
}

Future<bool> acceptInvite(Invite invite) async {
  // Get the teammate who the invite is from
  return await FirebaseFirestore.instance.collection('users').doc(invite.fromUid).get().then((u) async {
    UserProfile teammate = UserProfile.fromSnapshot(u);
    // Save the teammate to the current user's teammates
    return await FirebaseFirestore.instance.collection('teammates').doc(auth.currentUser.uid).collection('teammates').doc(teammate.reference.id).set(teammate.toMap()).then((_) async {
      // Get the current user
      return await FirebaseFirestore.instance.collection('users').doc(auth.currentUser.uid).get().then((u) async {
        UserProfile user = UserProfile.fromSnapshot(u);
        // Save the current user as a teammate of the invitee teammate
        return await FirebaseFirestore.instance.collection('teammates').doc(teammate.reference.id).collection('teammates').doc(auth.currentUser.uid).set(user.toMap()).then((_) async {
          // Delete the invite
          return await FirebaseFirestore.instance.collection('invites').doc(auth.currentUser.uid).collection('invites').doc(invite.fromUid).delete().then((value) => true).onError((error, stackTrace) => null);
        });
      });
    });
  });
}

Future<bool> deleteInvite(String fromUid, String toUid) async {
  if (toUid == auth.currentUser.uid) {
    return await FirebaseFirestore.instance.collection('invites').doc(toUid).collection('invites').doc(fromUid).delete().then((value) => true).onError((error, stackTrace) => null);
  }

  return false;
}
