import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/widgets/UserStatsChipsRow.dart';
import 'package:tenthousandshotchallenge/widgets/WeeklyAchievementsWidget.dart';

/// Full-screen achievements view, extracted from the Profile accordion.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<FirebaseAuth>(context, listen: false).currentUser;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            collapsedHeight: 65,
            expandedHeight: 85,
            backgroundColor: Theme.of(context).colorScheme.primary,
            floating: true,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.only(top: 10),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                onPressed: () => context.pop(),
              ),
            ),
            actions: const [],
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                centerTitle: true,
                title: Text(
                  'Achievements'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                background: Container(color: Theme.of(context).colorScheme.primaryContainer),
              ),
            ),
          ),
        ],
        body: user == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserStatsChipsRow(
                      userId: user.uid,
                      showShootingChips: false,
                      padding: const EdgeInsets.only(bottom: 16),
                    ),
                    const WeeklyAchievementsWidget(showResetCountdown: true),
                  ],
                ),
              ),
      ),
    );
  }
}
