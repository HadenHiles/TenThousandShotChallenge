import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/models/firestore/AppNotification.dart';
import 'package:tenthousandshotchallenge/navigation/AppRoutePaths.dart';
import 'package:tenthousandshotchallenge/services/LocalNotificationService.dart';

/// Full-page notification centre showing the current user's friend activity.
///
/// Opened when the user taps the bell icon or taps a friend-session system notification.
/// Individual notifications can be marked read/unread via long-press.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Future<void> _markAllRead(String uid) async {
    final unread = await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _clearAll(BuildContext context, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This will permanently delete all your notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final all = await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').get();
    if (all.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in all.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutePaths.app);
            }
          },
        ),
        actions: [
          if (uid != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onPrimary),
              onSelected: (value) {
                if (value == 'mark_all_read') _markAllRead(uid);
                if (value == 'clear_all') _clearAll(context, uid);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'mark_all_read', child: Text('Mark all as read')),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
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
                if (docs.isEmpty) return _buildEmptyState(context);

                final notifications = docs.map((d) => AppNotification.fromSnapshot(d)).toList();

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    indent: 72,
                  ),
                  itemBuilder: (context, i) {
                    final notif = notifications[i];
                    return Dismissible(
                      key: ValueKey(notif.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => notif.reference?.delete(),
                      child: _NotificationTile(
                        notification: notif,
                        timeLabel: _timeAgo(notif.createdAt),
                      ),
                    );
                  },
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
              "When your friends log sessions or pass Challenger Road challenges you'll see their activity here.",
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

  void _toggleRead() {
    notification.reference?.update({'read': !notification.read});
  }

  void _markRead() {
    if (!notification.read) notification.reference?.update({'read': true});
  }

  void _showLongPressMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(notification.read ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined),
              title: Text(notification.read ? 'Mark as unread' : 'Mark as read'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleRead();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;

    // --- Routing on tap ---
    void handleTap() {
      _markRead();
      // Dismiss any lingering system notifications for this message.
      LocalNotificationService.cancelForegroundMessages();
      if (n.isInviteReceived || n.isInviteAccepted) {
        context.push(AppRoutePaths.playerPathFor(n.fromUid));
      } else if (n.isBadgeEarned) {
        final badgeId = n.badgeId;
        if (badgeId != null && badgeId.isNotEmpty) {
          context.push(AppRoutePaths.profileChallengerRoadFor(badgeId));
        } else {
          context.push(AppRoutePaths.profileChallengerRoad);
        }
      } else if (n.isLevelCompleted) {
        context.push(AppRoutePaths.challengerRoad);
      } else if (n.isWeeklyAvailable || n.isAchievementCompleted) {
        context.push(AppRoutePaths.profileAchievements);
      } else {
        // friend_session / friend_challenge - go to player profile
        context.push(AppRoutePaths.playerPathFor(n.fromUid));
      }
    }

    // --- Visual config per type ---
    final Color avatarBg;
    final Color avatarFg;
    final IconData avatarIcon;
    final String headline;
    final String? subtitleLine;

    if (n.isChallenge) {
      avatarBg = Colors.amber.withValues(alpha: 0.18);
      avatarFg = Colors.amber[700]!;
      avatarIcon = Icons.emoji_events_rounded;
      headline = '${n.fromName} passed a Challenger Road challenge';
      subtitleLine = 'Level ${n.level ?? '?'} - ${n.challengeName ?? 'Challenger Road'}';
    } else if (n.isInviteReceived) {
      avatarBg = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15);
      avatarFg = Theme.of(context).colorScheme.secondary;
      avatarIcon = Icons.person_add_rounded;
      headline = '${n.fromName} sent you a teammate invite';
      subtitleLine = null;
    } else if (n.isInviteAccepted) {
      avatarBg = Colors.green.withValues(alpha: 0.15);
      avatarFg = Colors.green[700]!;
      avatarIcon = Icons.handshake_rounded;
      headline = '${n.fromName} accepted your invite';
      subtitleLine = "You're now teammates!";
    } else if (n.isWeeklyAvailable) {
      avatarBg = Colors.purple.withValues(alpha: 0.15);
      avatarFg = Colors.purple[600]!;
      avatarIcon = Icons.calendar_today_rounded;
      headline = 'New weekly challenges available';
      subtitleLine = null;
    } else if (n.isAchievementCompleted) {
      avatarBg = Colors.green.withValues(alpha: 0.15);
      avatarFg = Colors.green[700]!;
      avatarIcon = Icons.check_circle_rounded;
      headline = 'Challenge complete!';
      subtitleLine = n.achievementTitle;
    } else if (n.isBadgeEarned) {
      avatarBg = Colors.amber.withValues(alpha: 0.18);
      avatarFg = Colors.amber[800]!;
      avatarIcon = Icons.military_tech_rounded;
      headline = 'New badge earned!';
      subtitleLine = n.badgeName;
    } else if (n.isLevelCompleted) {
      avatarBg = Theme.of(context).primaryColor.withValues(alpha: 0.15);
      avatarFg = Theme.of(context).primaryColor;
      avatarIcon = Icons.stairs_rounded;
      headline = 'Level ${n.level ?? '?'} complete!';
      subtitleLine = 'Challenger Road';
    } else {
      // friend_session (default)
      avatarBg = Theme.of(context).primaryColor.withValues(alpha: 0.15);
      avatarFg = Theme.of(context).primaryColor;
      avatarIcon = Icons.sports_hockey_rounded;
      headline = '${n.fromName} logged ${n.shots} shots';
      subtitleLine = null;
    }

    // Score detail for challenges
    final String? scoreDetail = n.isChallenge && n.shotsMade != null && n.shotsToPass != null ? '${n.shotsMade}/${n.shotsToPass} shots on target' : null;

    return InkWell(
      onTap: handleTap,
      onLongPress: () => _showLongPressMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
              child: Icon(avatarIcon, size: 22, color: avatarFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  if (subtitleLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleLine,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: avatarFg.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (scoreDetail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      scoreDetail,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: avatarFg.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (n.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.message,
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
            if (!n.read)
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
