import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'ChallengerRoadMapView.dart';

class ChallengerRoadTeaserView extends StatefulWidget {
  const ChallengerRoadTeaserView({
    super.key,
    this.embedded = false,
    this.onCloseTap,
    this.onMainHeaderVisibilityChanged,
  });

  final bool embedded;
  final VoidCallback? onCloseTap;
  final ValueChanged<bool>? onMainHeaderVisibilityChanged;

  @override
  State<ChallengerRoadTeaserView> createState() => _ChallengerRoadTeaserViewState();
}

class _ChallengerRoadTeaserViewState extends State<ChallengerRoadTeaserView> {
  static const String _walkthroughSeenKey = 'challenger_road_preview_walkthrough_seen';
  bool _showWalkthrough = true;
  final PageController _walkthroughController = PageController();
  int _walkthroughPage = 0;

  final List<({String title, String body, IconData icon})> _walkthroughSlides = const [
    (
      title: 'How Challenger Road Works',
      body: 'Tap a challenge to open it. Then press Start to try the challenge.',
      icon: Icons.route_rounded,
    ),
    (
      title: 'Level 1 Is Free',
      body: 'You can try Level 1 challenges for free.',
      icon: Icons.sports_hockey,
    ),
    (
      title: 'Level 2 Requires Pro',
      body: 'When you finish Level 1, you can upgrade to unlock more levels.',
      icon: Icons.lock_open_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadWalkthroughPreference();
  }

  @override
  void dispose() {
    _walkthroughController.dispose();
    super.dispose();
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

  Future<void> _nextWalkthroughPage() async {
    if (_walkthroughPage >= _walkthroughSlides.length - 1) {
      await _dismissWalkthrough();
      return;
    }
    await _walkthroughController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _promptGoPro() async {
    await presentPaywallIfNeeded(context);
  }

  Widget _buildWalkthroughCard(BuildContext context) {
    final isLast = _walkthroughPage == _walkthroughSlides.length - 1;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 270,
                  child: PageView.builder(
                    controller: _walkthroughController,
                    itemCount: _walkthroughSlides.length,
                    onPageChanged: (index) => setState(() => _walkthroughPage = index),
                    itemBuilder: (context, index) {
                      final slide = _walkthroughSlides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(slide.icon, size: 44, color: Theme.of(context).primaryColor),
                            const SizedBox(height: 14),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 22,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NovecentoSans',
                                fontSize: 16,
                                height: 1.35,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_walkthroughSlides.length, (i) {
                    final selected = i == _walkthroughPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: selected ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: _dismissWalkthrough,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        textStyle: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 17,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _nextWalkthroughPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontFamily: 'NovecentoSans',
                          fontSize: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      child: Text(isLast ? 'Get Started' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBanner(BuildContext context) {
    final bottomTabInset = widget.embedded ? kBottomNavigationBarHeight + 10 : 0.0;

    return Positioned(
      left: 14,
      right: 14,
      bottom: 16 + bottomTabInset,
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
      final body = Center(
        child: Text(
          'Sign in to try the Challenger Road preview.',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );

      if (widget.embedded) {
        return body;
      }

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
        body: body,
      );
    }

    final bottomTabInset = widget.embedded ? kBottomNavigationBarHeight + 10 : 0.0;

    final body = Stack(
      fit: StackFit.expand,
      children: [
        ChallengerRoadMapView(
          userId: userId,
          isPreviewMode: true,
          previewMaxLevel: 1,
          onPreviewLevelUnlockAttempted: _promptGoPro,
          mapBottomInset: 120 + bottomTabInset,
          onCloseTap: widget.onCloseTap,
          onMainHeaderVisibilityChanged: widget.onMainHeaderVisibilityChanged,
        ),
        if (_showWalkthrough) _buildWalkthroughCard(context),
        _buildBottomBanner(context),
      ],
    );

    if (widget.embedded) {
      return body;
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
      body: body,
    );
  }
}
