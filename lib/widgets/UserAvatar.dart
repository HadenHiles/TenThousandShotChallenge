import 'package:flutter/material.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.user, this.radius, this.backgroundColor});

  final UserProfile? user;
  final double? radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Defensive: if user is null, show a default placeholder avatar
    if (user == null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.antiAlias,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: const AssetImage("assets/images/avatar.png"),
          backgroundColor: backgroundColor,
          child: const SizedBox(),
        ),
      );
    }

    final String? photoUrl = user!.photoUrl;

    if (photoUrl != null && photoUrl.contains('http')) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.antiAlias,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(photoUrl),
          backgroundColor: backgroundColor,
        ),
      );
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.antiAlias,
        child: Transform.scale(
          scale: photoUrl.contains('characters') ? 1.03 : 0.98,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor,
            child: Image(
              image: AssetImage(photoUrl),
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
