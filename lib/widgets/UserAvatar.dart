import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({Key? key, this.user, this.radius, this.backgroundColor}) : super(key: key);

  final UserProfile? user;
  final double? radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (user!.photoUrl != null && user!.photoUrl!.contains('http')) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.antiAlias,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(
            user!.photoUrl!,
          ),
          backgroundColor: backgroundColor,
        ),
      );
    } else if (user!.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.antiAlias,
        child: Transform.scale(
          scale: user!.photoUrl!.contains('characters') ? 1.03 : 0.98,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor,
            child: Image(
              image: AssetImage(user!.photoUrl!),
            ),
          ),
        ),
      );
    } else {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.antiAlias,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: const AssetImage("assets/images/avatar.png"),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }
}
