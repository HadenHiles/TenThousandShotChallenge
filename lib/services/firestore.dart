import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/models/firestore/Invite.dart';
import 'package:tenthousandshotchallenge/models/firestore/Iteration.dart';
import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';
import 'package:tenthousandshotchallenge/models/firestore/Team.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/firebaseMessageService.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

Future<bool?> saveShootingSession(List<Shots> shots) async {
  // Get the total number of shots for the session
  int total = 0;
  int wrist = 0;
  int snap = 0;
  int slap = 0;
  int backhand = 0;
  for (var s in shots) {
    total += s.count!;

    switch (s.type) {
      case "wrist":
        wrist += s.count!;
        break;
      case "snap":
        snap += s.count!;
        break;
      case "slap":
        slap += s.count!;
        break;
      case "backhand":
        backhand += s.count!;
        break;
      default:
    }
  }

  ShootingSession shootingSession = ShootingSession(total, wrist, snap, slap, backhand, DateTime.now(), sessionService.currentDuration);
  shootingSession.shots = shots;

  Iteration iteration = Iteration(DateTime.now(), DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100), null, const Duration(), 0, 0, 0, 0, 0, false);

  return await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) async {
    if (snapshot.docs.isNotEmpty) {
      iteration = Iteration.fromSnapshot(snapshot.docs[0]);

      saveSessionData(shootingSession, snapshot.docs[0].reference, shots).then((value) => true).onError((error, stackTrace) => false);
    } else {
      await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').add(iteration.toMap()).then((i) async {
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

    for (var shot in shots) {
      var sRef = s.collection('shots').doc();
      batch.set(sRef, shot.toMap());
    }

    await ref.get().then((i) {
      Iteration iteration = Iteration.fromSnapshot(i);
      iteration = Iteration(
        iteration.startDate,
        iteration.targetDate,
        iteration.endDate,
        (iteration.totalDuration! + shootingSession.duration!),
        (iteration.total! + shootingSession.total!),
        (iteration.totalWrist! + shootingSession.totalWrist!),
        (iteration.totalSnap! + shootingSession.totalSnap!),
        (iteration.totalSlap! + shootingSession.totalSlap!),
        (iteration.totalBackhand! + shootingSession.totalBackhand!),
        iteration.complete,
      );
      batch.update(ref, iteration.toMap());
    });

    return await batch.commit().then((_) => true).onError((error, stackTrace) => false);
  });
}

Future<bool> deleteSession(ShootingSession shootingSession) async {
  return await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').doc(shootingSession.reference!.parent.parent!.id).get().then((iDoc) async {
    Iteration iteration = Iteration.fromSnapshot(iDoc);
    if (!iteration.complete!) {
      // Get a new write batch
      var batch = FirebaseFirestore.instance.batch();

      Iteration decrementedIteration = Iteration(
        iteration.startDate,
        iteration.targetDate,
        iteration.endDate,
        (iteration.totalDuration! - shootingSession.duration!),
        (iteration.total! - shootingSession.total!),
        (iteration.totalWrist! - shootingSession.totalWrist!),
        (iteration.totalSnap! - shootingSession.totalSnap!),
        (iteration.totalSlap! - shootingSession.totalSlap!),
        (iteration.totalBackhand! - shootingSession.totalBackhand!),
        iteration.complete,
      );

      batch.update(iDoc.reference, decrementedIteration.toMap());

      batch.delete(iDoc.reference.collection('sessions').doc(shootingSession.reference!.id));

      return await batch.commit().then((_) => true).onError((error, stackTrace) => false);
    } else {
      return false;
    }
  });
}

Future<bool> recalculateIterationTotals() async {
  return await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').get().then((iSnap) async {
    if (iSnap.docs.isNotEmpty) {
      // Get a new write batch
      var batch = FirebaseFirestore.instance.batch();

      await Future.forEach(iSnap.docs, (iDoc) async {
        int iTotal = 0;
        int totalWrist = 0;
        int totalSnap = 0;
        int totalSlap = 0;
        int totalBackhand = 0;
        Iteration i = Iteration.fromSnapshot(iDoc as DocumentSnapshot);

        await i.reference!.collection('sessions').get().then((sSnap) async {
          if (sSnap.docs.isNotEmpty) {
            int sTotal = 0;
            int tWrist = 0;
            int tSnap = 0;
            int tSlap = 0;
            int tBackhand = 0;

            await Future.forEach(sSnap.docs, (DocumentSnapshot sDoc) async {
              ShootingSession s = ShootingSession.fromSnapshot(sDoc);

              await sDoc.reference.collection('shots').get().then((shotsSnapshot) async {
                if (shotsSnapshot.docs.isNotEmpty) {
                  int sessionTotal = 0;
                  int sessionTotalWrist = 0;
                  int sessionTotalSnap = 0;
                  int sessionTotalSlap = 0;
                  int sessionTotalBackhand = 0;

                  await Future.forEach(shotsSnapshot.docs, (shotsDoc) {
                    Shots shots = Shots.fromSnapshot(shotsDoc as DocumentSnapshot);
                    // Get the total number of shots for the session
                    sTotal += shots.count!;
                    sessionTotal += shots.count!;

                    switch (shots.type) {
                      case "wrist":
                        tWrist += shots.count!;
                        sessionTotalWrist += shots.count!;
                        break;
                      case "snap":
                        tSnap += shots.count!;
                        sessionTotalSnap += shots.count!;
                        break;
                      case "slap":
                        tSlap += shots.count!;
                        sessionTotalSlap += shots.count!;
                        break;
                      case "backhand":
                        tBackhand += shots.count!;
                        sessionTotalBackhand += shots.count!;
                        break;
                      default:
                    }
                  }).then((_) {
                    // Update the session shot totals
                    ShootingSession updatedSession = ShootingSession(sessionTotal, sessionTotalWrist, sessionTotalSnap, sessionTotalSlap, sessionTotalBackhand, s.date, s.duration);
                    batch.update(s.reference!, updatedSession.toMap());
                  });
                }
              });
            }).then((_) {
              iTotal += sTotal;
              totalWrist += tWrist;
              totalSnap += tSnap;
              totalSlap += tSlap;
              totalBackhand += tBackhand;

              // Update the iteration total
              Iteration updatedIteration = Iteration(i.startDate, i.targetDate, i.endDate, i.totalDuration, iTotal, totalWrist, totalSnap, totalSlap, totalBackhand, i.complete);
              batch.update(i.reference!, updatedIteration.toMap());
            });
          }
        });
      }).then((_) async {
        // Commit the changes
        return await batch.commit().then((_) => true).onError((error, stackTrace) => false);
      });
    }

    return false;
  });
}

Future<bool?> startNewIteration() async {
  return await FirebaseFirestore.instance.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) async {
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs[0].reference.update({'complete': true, 'end_date': DateTime.now()}).then((_) {
        FirebaseFirestore.instance
            .collection('iterations')
            .doc(auth.currentUser!.uid)
            .collection('iterations')
            .doc()
            .set(Iteration(
              DateTime.now(),
              DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 100),
              null,
              const Duration(),
              0,
              0,
              0,
              0,
              0,
              false,
            ).toMap())
            .then((value) => true);
      });
    }
  }).onError((error, stackTrace) {
    print(error);
  });
}

Future<bool?> inviteTeammate(String fromUid, String toUid) async {
  Invite invite = Invite(fromUid, DateTime.now());
  return await FirebaseFirestore.instance.collection('teammates').doc(fromUid).collection('teammates').doc(toUid).get().then((t) async {
    if (!t.exists) {
      return await FirebaseFirestore.instance.collection('invites').doc(toUid).collection('invites').doc(fromUid).get().then((i) async {
        if (!i.exists) {
          return await FirebaseFirestore.instance.collection('invites').doc(toUid).collection('invites').doc(fromUid).set(invite.toMap()).then((_) async {
            return await FirebaseFirestore.instance.collection('users').doc(toUid).get().then((t) async {
              String? friendFCMToken = UserProfile.fromSnapshot(t).fcmToken;

              if (friendFCMToken!.isNotEmpty) {
                // Get the current user profile
                return await FirebaseFirestore.instance.collection('users').doc(toUid).get().then((u) async {
                  UserProfile user = UserProfile.fromSnapshot(u);
                  // Send the teammate a push notification! WOW
                  return sendPushMessage(friendFCMToken, "Someone has challenged you!", "${user.displayName} has sent you an friend invitation.").then((value) => true);
                }).onError((error, stackTrace) => false);
              }

              return true;
            }).onError((error, stackTrace) => false);
          });
        } else {
          return true;
        }
      });
    } else {
      return true;
    }
  });
}

Future<bool> acceptInvite(Invite invite) async {
  // Get the teammate who the invite is from
  return await FirebaseFirestore.instance.collection('users').doc(invite.fromUid).get().then((u) async {
    UserProfile friend = UserProfile.fromSnapshot(u);
    // Save the teammate to the current user's teammates
    return await FirebaseFirestore.instance.collection('teammates').doc(auth.currentUser!.uid).collection('teammates').doc(friend.reference!.id).set(friend.toMap()).then((_) async {
      // Get the current user
      return await FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.uid).get().then((u) async {
        UserProfile user = UserProfile.fromSnapshot(u);
        // Save the current user as a teammate of the invitee teammate
        return await FirebaseFirestore.instance.collection('teammates').doc(friend.reference!.id).collection('teammates').doc(auth.currentUser!.uid).set(user.toMap()).then((_) async {
          // Delete the invite
          return await FirebaseFirestore.instance.collection('invites').doc(auth.currentUser!.uid).collection('invites').doc(invite.fromUid).delete().then((value) => true).onError((error, stackTrace) => false);
        });
      });
    });
  });
}

Future<bool> deleteInvite(String fromUid, String toUid) async {
  if (toUid == auth.currentUser!.uid) {
    return await FirebaseFirestore.instance.collection('invites').doc(toUid).collection('invites').doc(fromUid).delete().then((value) => true).onError((error, stackTrace) => false);
  }

  return false;
}

Future<bool> addFriendBarcode(String friendUid) async {
  // Get the teammate
  return await FirebaseFirestore.instance.collection('users').doc(friendUid).get().then((u) async {
    UserProfile friend = UserProfile.fromSnapshot(u);
    // Save the teammate to the current user's teammates
    return await FirebaseFirestore.instance.collection('teammates').doc(auth.currentUser!.uid).collection('teammates').doc(friend.reference!.id).set(friend.toMap()).then((_) async {
      // Get the current user
      return await FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.uid).get().then((u) async {
        UserProfile user = UserProfile.fromSnapshot(u);
        // Save the current user as a teammate of the invitee teammate
        return await FirebaseFirestore.instance.collection('teammates').doc(friend.reference!.id).collection('teammates').doc(auth.currentUser!.uid).set(user.toMap()).then((value) => true).onError((error, stackTrace) => false);
      });
    });
  });
}

Future<bool> deleteFriend(String uid) async {
  return await FirebaseFirestore.instance.collection('teammates').doc(auth.currentUser!.uid).collection('teammates').doc(uid).delete().then((_) async {
    return await FirebaseFirestore.instance.collection('teammates').doc(uid).collection('teammates').doc(auth.currentUser!.uid).delete().then((value) => true).onError((error, stackTrace) => false);
  });
}

Future<bool> joinTeam(String teamId) async {
  // Get the teammate
  return await FirebaseFirestore.instance.collection('teams').doc(teamId).get().then((u) async {
    Team team = Team.fromSnapshot(u);
    // Set the current user's team
    return await FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.uid).get().then((u) async {
      UserProfile user = UserProfile.fromSnapshot(u);
      user.teamId = team.id;
      // Save the updated user doc with the new team id
      return await u.reference.set(user.toMap()).then((value) => true).onError((error, stackTrace) => false);
    });
  });
}
