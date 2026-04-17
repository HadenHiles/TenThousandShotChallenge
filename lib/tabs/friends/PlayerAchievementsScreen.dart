import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/widgets/UserAchievementsReadOnly.dart';
import 'package:tenthousandshotchallenge/widgets/UserAvatar.dart';
import 'package:tenthousandshotchallenge/widgets/UserStatsChipsRow.dart';

/// Full-screen achievements view for another player's profile.
class PlayerAchievementsScreen extends StatelessWidget {
  final String userId;
  final String playerName;

  const PlayerAchievementsScreen({
    super.key,
    required this.userId,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            collapsedHeight: 65,
            expandedHeight: 85,
            backgroundColor: theme.colorScheme.primary,
            floating: true,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.only(top: 10),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.colorScheme.onPrimary, size: 28),
                onPressed: () => context.pop(),
              ),
            ),
            actions: const [],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                builder: (context, snap) {
                  final profile = snap.hasData ? UserProfile.fromSnapshot(snap.data!) : null;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: UserAvatar(user: profile, backgroundColor: Colors.transparent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          playerName,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 15,
                            color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                centerTitle: true,
                title: Text(
                  'Achievements'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 20,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                background: Container(color: theme.colorScheme.primaryContainer),
              ),
            ),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserStatsChipsRow(
                userId: userId,
                showShootingChips: false,
                padding: const EdgeInsets.only(bottom: 16),
              ),
              UserAchievementsReadOnly(userId: userId),
            ],
          ),
        ),
      ),
    );
  }
}
