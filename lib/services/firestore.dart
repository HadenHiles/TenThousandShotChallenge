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

Future<bool> saveShootingSession(List<Shots> shots, FirebaseAuth auth, FirebaseFirestore firestore) async {
  // Get the total number of shots and targets hit for the session
  int total = 0;
  int wrist = 0;
  int snap = 0;
  int slap = 0;
  int backhand = 0;
  int wristTargetsHit = 0;
  int snapTargetsHit = 0;
  int slapTargetsHit = 0;
  int backhandTargetsHit = 0;

  for (Shots s in shots) {
    total += s.count ?? 0;
    switch (s.type) {
      case "wrist":
        wrist += s.count ?? 0;
        wristTargetsHit += s.targetsHit ?? 0;
        break;
      case "snap":
        snap += s.count ?? 0;
        snapTargetsHit += s.targetsHit ?? 0;
        break;
      case "slap":
        slap += s.count ?? 0;
        slapTargetsHit += s.targetsHit ?? 0;
        break;
      case "backhand":
        backhand += s.count ?? 0;
        backhandTargetsHit += s.targetsHit ?? 0;
        break;
      default:
    }
  }

  // Update: Add targetsHit fields to the ShootingSession object
  ShootingSession shootingSession = ShootingSession(
    total,
    wrist,
    snap,
    slap,
    backhand,
    DateTime.now(),
    sessionService.currentDuration,
    wristTargetsHit: wristTargetsHit,
    snapTargetsHit: snapTargetsHit,
    slapTargetsHit: slapTargetsHit,
    backhandTargetsHit: backhandTargetsHit,
  );
  shootingSession.shots = shots;

  Iteration iteration = Iteration(
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
    DateTime.now(),
  );

  try {
    final snapshot = await firestore.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').where('complete', isEqualTo: false).get();
    bool result = false;
    DocumentReference? iterationRef;
    if (snapshot.docs.isNotEmpty) {
      iteration = Iteration.fromSnapshot(snapshot.docs[0]);
      iterationRef = snapshot.docs[0].reference;
      result = await saveSessionData(shootingSession, iterationRef, shots, firestore);
    } else {
      final i = await firestore.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').add(iteration.toMap());
      iterationRef = i;
      result = await saveSessionData(shootingSession, iterationRef, shots, firestore);
    }

    return result;
  } catch (e) {
    print(e);
    return false;
  }
}

DateTime getWeekStart() {
  final now = DateTime.now();
  // Monday = 1, Sunday = 7
  final int currentWeekday = now.weekday;
  // Calculate how many days to subtract to get to Monday
  final int daysToSubtract = currentWeekday - DateTime.monday;
  final weekStart = DateTime(now.year, now.month, now.day - daysToSubtract);
  return DateTime(weekStart.year, weekStart.month, weekStart.day, 0, 0, 0, 0, 0);
}

Future<bool> saveSessionData(ShootingSession shootingSession, DocumentReference ref, List<Shots> shots, FirebaseFirestore firestore) async {
  // Ensure the shots are set on the session object
  shootingSession.shots = shots;

  // Save the session with the embedded shots array
  return await ref.collection('sessions').add(shootingSession.toMap()).then((s) async {
    // Get a new write batch
    var batch = firestore.batch();

    // Still save each shot as a subcollection for backward compatibility
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
        iteration.udpatedAt,
      );
      batch.update(ref, iteration.toMap());
    });

    return await batch.commit().then((_) => true).onError((error, stackTrace) => false);
  });
}

Future<bool> deleteSession(ShootingSession shootingSession, FirebaseAuth auth, FirebaseFirestore firestore) async {
  return await firestore.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').doc(shootingSession.reference!.parent.parent!.id).get().then((iDoc) async {
    Iteration iteration = Iteration.fromSnapshot(iDoc);
    if (!iteration.complete!) {
      // Get a new write batch
      var batch = firestore.batch();

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
        iteration.udpatedAt,
      );

      batch.update(iDoc.reference, decrementedIteration.toMap());

      batch.delete(iDoc.reference.collection('sessions').doc(shootingSession.reference!.id));

      return await batch.commit().then((_) => true).onError((error, stackTrace) => false);
    } else {
      return false;
    }
  });
}

Future<bool> recalculateIterationTotals(FirebaseAuth auth, FirebaseFirestore firestore) async {
  return await firestore.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').get().then((iSnap) async {
    if (iSnap.docs.isNotEmpty) {
      // Get a new write batch
      var batch = firestore.batch();

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
                    ShootingSession updatedSession = ShootingSession(
                      sessionTotal,
                      sessionTotalWrist,
                      sessionTotalSnap,
                      sessionTotalSlap,
                      sessionTotalBackhand,
                      s.date,
                      s.duration,
                    );
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
              Iteration updatedIteration = Iteration(
                i.startDate,
                i.targetDate,
                i.endDate,
                i.totalDuration,
                iTotal,
                totalWrist,
                totalSnap,
                totalSlap,
                totalBackhand,
                i.complete,
                i.udpatedAt,
              );
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

Future<bool?> startNewIteration(FirebaseAuth auth, FirebaseFirestore firestore) async {
  return await firestore.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').where('complete', isEqualTo: false).get().then((snapshot) async {
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs[0].reference.update({'complete': true, 'end_date': DateTime.now()}).then((_) {
        firestore
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
              DateTime.now(),
            ).toMap())
            .then((value) => true);
      });
    }
  }).onError((error, stackTrace) {
    print(error);
  });
}

Future<bool?> inviteFriend(String fromUid, String toUid, FirebaseFirestore firestore) async {
  Invite invite = Invite(fromUid, DateTime.now());
  return await firestore.collection('teammates').doc(fromUid).collection('teammates').doc(toUid).get().then((t) async {
    if (!t.exists) {
      return await firestore.collection('invites').doc(toUid).collection('invites').doc(fromUid).get().then((i) async {
        if (!i.exists) {
          return await firestore.collection('invites').doc(toUid).collection('invites').doc(fromUid).set(invite.toMap()).then((_) async {
            return await firestore.collection('users').doc(toUid).get().then((t) async {
              String? friendFCMToken = UserProfile.fromSnapshot(t).fcmToken;

              if (friendFCMToken!.isNotEmpty) {
                // Get the current user profile
                return await firestore.collection('users').doc(toUid).get().then((u) async {
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

Future<bool> acceptInvite(Invite invite, FirebaseAuth auth, FirebaseFirestore firestore) async {
  // Get the teammate who the invite is from
  return await firestore.collection('users').doc(invite.fromUid).get().then((u) async {
    UserProfile friend = UserProfile.fromSnapshot(u);
    // Save the teammate to the current user's teammates
    return await firestore.collection('teammates').doc(auth.currentUser!.uid).collection('teammates').doc(invite.fromUid).set(friend.toMap()).then((_) async {
      // Get the current user
      return await firestore.collection('users').doc(auth.currentUser!.uid).get().then((u) async {
        UserProfile user = UserProfile.fromSnapshot(u);
        // Save the current user as a teammate of the invitee teammate
        return await firestore.collection('teammates').doc(invite.fromUid).collection('teammates').doc(auth.currentUser!.uid).set(user.toMap()).then((_) async {
          // Delete the invite
          return await firestore.collection('invites').doc(auth.currentUser!.uid).collection('invites').doc(invite.fromUid).delete().then((value) => true).onError((error, stackTrace) => false);
        });
      });
    });
  });
}

Future<bool> deleteInvite(String fromUid, String toUid, FirebaseAuth auth, FirebaseFirestore firestore) async {
  if (toUid == auth.currentUser!.uid) {
    return await firestore.collection('invites').doc(toUid).collection('invites').doc(fromUid).delete().then((value) => true).onError((error, stackTrace) => false);
  }

  return false;
}

Future<bool> addFriendBarcode(String friendUid, FirebaseAuth auth, FirebaseFirestore firestore) async {
  // Get the teammate
  return await firestore.collection('users').doc(friendUid).get().then((u) async {
    UserProfile friend = UserProfile.fromSnapshot(u);
    // Save the teammate to the current user's teammates
    return await firestore.collection('teammates').doc(auth.currentUser!.uid).collection('teammates').doc(friendUid).set(friend.toMap()).then((_) async {
      // Get the current user
      return await firestore.collection('users').doc(auth.currentUser!.uid).get().then((u) async {
        UserProfile user = UserProfile.fromSnapshot(u);
        // Save the current user as a teammate of the invitee teammate
        return await firestore.collection('teammates').doc(friendUid).collection('teammates').doc(auth.currentUser!.uid).set(user.toMap()).then((value) => true).onError((error, stackTrace) => false);
      });
    });
  });
}

Future<bool> removePlayerFromFriends(String uid, FirebaseAuth auth, FirebaseFirestore firestore) async {
  return await firestore.collection('teammates').doc(auth.currentUser!.uid).collection('teammates').doc(uid).delete().then((_) async {
    return await firestore.collection('teammates').doc(uid).collection('teammates').doc(auth.currentUser!.uid).delete().then((value) => true).onError((error, stackTrace) => false);
  });
}

Future<bool> joinTeam(String teamId, FirebaseAuth auth, FirebaseFirestore firestore) async {
  // Make sure the user's iterations have an updated_at field prior to joining - need this for Caching the team player data
  await firestore.collection('iterations').doc(auth.currentUser!.uid).collection('iterations').get().then((i) async {
    if (i.docs.isNotEmpty) {
      await Future.forEach(i.docs, (DocumentSnapshot iDoc) async {
        Iteration i = Iteration.fromSnapshot(iDoc);

        // Check if there is an updated_at field or not
        if (i.udpatedAt == null) {
          i.reference!.update({'updated_at': DateTime.now()});
        }
      });
    }
  });

  // Get the teammate
  return await firestore.collection('teams').doc(teamId).get().then((t) async {
    Team team = Team.fromSnapshot(t);
    if (!team.players!.contains(auth.currentUser!.uid)) {
      team.players!.add(auth.currentUser!.uid);
    }

    // Add the current user to the team players list
    return await t.reference.update({'players': team.players}).then((value) async {
      // Set the current user's team
      return await firestore.collection('users').doc(auth.currentUser!.uid).get().then((u) async {
        UserProfile user = UserProfile.fromSnapshot(u);
        user.id = auth.currentUser!.uid;
        user.teamId = team.id;
        // Save the updated user doc with the new team id
        return await u.reference.set(user.toMap()).then((value) => true).onError((error, stackTrace) => false);
      });
    }).onError((error, stackTrace) => false);
  });
}

Future<bool> removePlayerFromTeam(String teamId, String uid, FirebaseFirestore firestore) async {
  return await firestore.collection('teams').doc(teamId).get().then((t) async {
    Team team = Team.fromSnapshot(t);
    team.players!.remove(uid);

    // Remove the provided user/player from the team players list
    return await t.reference.update({'players': team.players}).then((value) => true).onError((error, stackTrace) => false);
  });
}

Future<bool> deleteTeam(String teamId, FirebaseAuth auth, FirebaseFirestore firestore) async {
  return await firestore.collection('teams').doc(teamId).delete().then((_) async {
    return await firestore.collection('users').doc(auth.currentUser!.uid).get().then((u) async {
      UserProfile user = UserProfile.fromSnapshot(u);
      user.id = auth.currentUser!.uid;
      user.teamId = null; // remove the user's teamId
      // Save the updated user doc
      return await u.reference.set(user.toMap()).then((_) => true).onError((error, stackTrace) => false);
    });
  }).onError((error, stackTrace) => false);
}
