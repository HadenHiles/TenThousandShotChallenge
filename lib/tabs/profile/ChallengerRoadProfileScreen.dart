import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/UserProfile.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/tabs/profile/ChallengerRoadProfileSection.dart';

/// Full-screen Challenger Road profile view,
/// wrapping the existing [ChallengerRoadProfileSection] widget.
///
/// When [userId] is provided the screen shows that player's CR progress
/// (read-only). When omitted it defaults to the signed-in user's own profile.
class ChallengerRoadProfileScreen extends StatefulWidget {
  const ChallengerRoadProfileScreen({super.key, this.highlightTrophyId, this.userId});

  /// When set, the badge grid scrolls to this badge and briefly highlights it.
  final String? highlightTrophyId;

  /// The user whose Challenger Road progress to display.
  /// Defaults to the currently signed-in user when null.
  final String? userId;

  @override
  State<ChallengerRoadProfileScreen> createState() => _ChallengerRoadProfileScreenState();
}

class _ChallengerRoadProfileScreenState extends State<ChallengerRoadProfileScreen> {
  String _subscriptionLevel = 'free';
  CustomerInfoNotifier? _customerInfoNotifier;

  User? get _user => Provider.of<FirebaseAuth>(context, listen: false).currentUser;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionLevel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _customerInfoNotifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
      _customerInfoNotifier?.addListener(_onEntitlementsChanged);
    });
  }

  void _onEntitlementsChanged() {
    subscriptionLevel(context).then((level) {
      if (mounted) setState(() => _subscriptionLevel = level);
    });
  }

  void _loadSubscriptionLevel() {
    subscriptionLevel(context).then((level) {
      if (mounted) setState(() => _subscriptionLevel = level);
    });
  }

  @override
  void dispose() {
    try {
      _customerInfoNotifier?.removeListener(_onEntitlementsChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
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
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Challenger Road'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
                background: Container(color: Theme.of(context).colorScheme.primaryContainer),
              ),
            ),
          ),
        ],
        body: user == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.userId != null) _PlayerIdentityHeader(userId: widget.userId!),
                    ChallengerRoadProfileSection(
                      userId: widget.userId ?? user.uid,
                      isPro: _subscriptionLevel == 'pro',
                      isEditable: widget.userId == null,
                      showOnlyEarned: widget.userId != null,
                      highlightTrophyId: widget.highlightTrophyId,
                      onGoProTap: () async {
                        await presentPaywallIfNeeded(context);
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Player identity header (shown when viewing another player's CR) ──────────

class _PlayerIdentityHeader extends StatelessWidget {
  const _PlayerIdentityHeader({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        UserProfile? profile;
        if (snap.hasData && snap.data!.exists) {
          profile = UserProfile.fromSnapshot(snap.data!);
        }
        final rawName = (profile?.nickname?.trim().isNotEmpty == true) ? profile!.nickname! : profile?.displayName ?? '';
        final displayName = rawName.isNotEmpty ? rawName : 'Player';
        final photoUrl = profile?.photoUrl;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: photoUrl == null
                    ? Text(
                        displayName[0].toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 28,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                displayName.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Challenger Road Progress',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Divider(indent: 24, endIndent: 24, color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
            ],
          ),
        );
      },
    );
  }
}
