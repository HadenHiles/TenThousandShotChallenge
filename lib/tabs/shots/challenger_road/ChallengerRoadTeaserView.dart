import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'ChallengerRoadMapView.dart';

class ChallengerRoadTeaserView extends StatefulWidget {
  const ChallengerRoadTeaserView({super.key});

  @override
  State<ChallengerRoadTeaserView> createState() => _ChallengerRoadTeaserViewState();
}

class _ChallengerRoadTeaserViewState extends State<ChallengerRoadTeaserView> {
  static const String _walkthroughSeenKey = 'challenger_road_preview_walkthrough_seen';
  bool _showWalkthrough = true;

  @override
  void initState() {
    super.initState();
    _loadWalkthroughPreference();
  }

  Future<void> _loadWalkthroughPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_walkthroughSeenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _showWalkthrough = !seen;
    });
  }

  Future<void> _dismissWalkthrough() async {
    setState(() => _showWalkthrough = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkthroughSeenKey, true);
  }

  Future<void> _promptGoPro() async {
    await presentPaywallIfNeeded(context);
  }

  ChallengerRoadAttempt _previewHeaderAttempt() {
    return ChallengerRoadAttempt(
      id: 'preview-attempt',
      attemptNumber: 1,
      startingLevel: 1,
      currentLevel: 1,
      challengerRoadShotCount: 920,
      totalShotsThisAttempt: 920,
      resetCount: 0,
      highestLevelReachedThisAttempt: 1,
      status: 'active',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
    );
  }

  Widget _buildWalkthroughCard(BuildContext context) {
    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick Walkthrough',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _dismissWalkthrough,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '1) Tap any Level 1 challenge to open details and start.',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '2) Complete Level 1 challenges to learn the flow and track attempts.',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '3) Unlock Level 2+ with Pro when you are ready to continue.',
                style: TextStyle(
                  fontFamily: 'NovecentoSans',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBanner(BuildContext context) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Card(
          color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.95),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Free mode: play all Level 1 challenges. Pro unlocks Level 2 and beyond.',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _promptGoPro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'GO PRO',
                    style: TextStyle(
                      fontFamily: 'NovecentoSans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<FirebaseAuth>(context, listen: false).currentUser?.uid;

    if (userId == null || userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Text(
            'Challenger Road Preview',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 22,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Sign in to try the Challenger Road preview.',
            style: TextStyle(
              fontFamily: 'NovecentoSans',
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: BackButton(color: Theme.of(context).colorScheme.onPrimary),
        title: Text(
          'Challenger Road Preview',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 22,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ChallengerRoadMapView(
            userId: userId,
            isPreviewMode: true,
            previewMaxLevel: 1,
            previewHeaderAttempt: _previewHeaderAttempt(),
            onPreviewLevelUnlockAttempted: _promptGoPro,
          ),
          if (_showWalkthrough) _buildWalkthroughCard(context),
          _buildBottomBanner(context),
        ],
      ),
    );
  }
}
