import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';

class UserAvatar extends StatelessWidget {
  UserAvatar({Key key, this.user, this.radius, this.backgroundColor}) : super(key: key);

  final UserProfile user;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (user.photoUrl != null && user.photoUrl.contains('http')) {
      return FittedBox(
        fit: BoxFit.contain,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(
            user.photoUrl,
          ),
          backgroundColor: Colors.transparent,
        ),
      );
    } else if (user.photoUrl != null) {
      return FittedBox(
        fit: BoxFit.contain,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: AssetImage("assets/images/avatars/maple-leafs.png"),
          backgroundColor: Colors.transparent,
        ),
      );
    } else {
      return FittedBox(
        fit: BoxFit.contain,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: AssetImage("assets/images/avatar.png"),
          backgroundColor: Colors.transparent,
        ),
      );
    }
  }
}
