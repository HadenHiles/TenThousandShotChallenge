import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';

/// Bell icon button that shows an unread-count badge driven by a Firestore stream.
///
/// Place this in any AppBar's [actions] list. Tapping navigates to [AppRoutePaths.notifications].
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.color});

  /// Icon colour — defaults to the app bar's onPrimary colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').where('read', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        final iconColor = color ?? Theme.of(context).colorScheme.onPrimary;

        return Container(
          margin: const EdgeInsets.only(top: 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: Icon(
                  unreadCount > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                  color: iconColor,
                  size: 26,
                ),
                onPressed: () => context.push(AppRoutePaths.notifications),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
