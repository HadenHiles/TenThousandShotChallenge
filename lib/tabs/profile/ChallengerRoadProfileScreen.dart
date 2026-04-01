import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'package:tenthousandshotchallenge/tabs/profile/ChallengerRoadProfileSection.dart';

/// Full-screen Challenger Road profile view,
/// wrapping the existing [ChallengerRoadProfileSection] widget.
class ChallengerRoadProfileScreen extends StatefulWidget {
  const ChallengerRoadProfileScreen({super.key});

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
                child: ChallengerRoadProfileSection(
                  userId: user.uid,
                  isPro: _subscriptionLevel == 'pro',
                  onGoProTap: () async {
                    await presentPaywallIfNeeded(context);
                  },
                ),
              ),
      ),
    );
  }
}
