import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/models/firestore/AppNotification.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';

/// Full-page notification centre showing the current user's friend activity.
///
/// Opened when the user taps the bell icon or taps a friend-session system notification.
/// All unread notifications are marked read when this screen is first rendered.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    _markAllRead();
  }

  Future<void> _markAllRead() async {
    if (_markedRead) return;
    _markedRead = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final unread = await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').where('read', isEqualTo: false).get();

    if (unread.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        iconTheme: Theme.of(context).iconTheme,
        centerTitle: true,
        title: Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 22,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').orderBy('created_at', descending: true).limit(50).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState(context);
                }

                final notifications = docs.map((d) => AppNotification.fromSnapshot(d)).toList();

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    indent: 72,
                  ),
                  itemBuilder: (context, i) => _NotificationTile(
                    notification: notifications[i],
                    timeLabel: _timeAgo(notifications[i].createdAt),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontFamily: 'NovecentoSans',
                fontSize: 22,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "When your friends log sessions you'll see their activity here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.timeLabel,
  });

  final AppNotification notification;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutePaths.playerPathFor(notification.fromUid)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar circle with hockey icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_hockey_rounded,
                size: 22,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: notification.fromName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: ' logged ${notification.shots} shots',
                        ),
                      ],
                    ),
                  ),
                  if (notification.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.read)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
