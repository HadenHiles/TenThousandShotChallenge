import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';

class ShootingSessionItem extends ShootingSession {
  bool? deletable;

  ShootingSessionItem({
    total,
    totalWrist,
    totalSnap,
    totalSlap,
    totalBackhand,
    date,
    duration,
    wristTargetsHit,
    snapTargetsHit,
    slapTargetsHit,
    backhandTargetsHit,
    shots,
    reference,
    this.deletable,
  }) : super(
          total,
          totalWrist,
          totalSnap,
          totalSlap,
          totalBackhand,
          date,
          duration,
          wristTargetsHit: wristTargetsHit,
          snapTargetsHit: snapTargetsHit,
          slapTargetsHit: slapTargetsHit,
          backhandTargetsHit: backhandTargetsHit,
          shots: shots,
          reference: reference,
        );
}
