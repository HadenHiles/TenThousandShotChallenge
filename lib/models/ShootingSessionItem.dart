import 'package:tenthousandshotchallenge/models/firestore/ShootingSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/Shots.dart';

class ShootingSessionItem extends ShootingSession {
  bool? deletable;

  ShootingSessionItem({
    int? total,
    int? totalWrist,
    int? totalSnap,
    int? totalSlap,
    int? totalBackhand,
    DateTime? date,
    Duration? duration,
    int? wristTargetsHit,
    int? snapTargetsHit,
    int? slapTargetsHit,
    int? backhandTargetsHit,
    List<Shots>? shots,
    dynamic reference, // Use the correct type if known, e.g., DocumentReference?
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
