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
            expandedHeight: 170,
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
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: Text(
                'Achievements'.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 18,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              background: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                builder: (context, snap) {
                  final profile = snap.hasData ? UserProfile.fromSnapshot(snap.data!) : null;
                  return Container(
                    color: theme.colorScheme.primaryContainer,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(top: 48, bottom: 36),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: UserAvatar(user: profile, backgroundColor: Colors.transparent),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          playerName,
                          style: TextStyle(
                            fontFamily: 'NovecentoSans',
                            fontSize: 20,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
