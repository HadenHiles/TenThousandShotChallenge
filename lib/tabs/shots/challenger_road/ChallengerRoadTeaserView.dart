import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/services/ChallengerRoadService.dart';
import 'package:tenthousandshotchallenge/services/RevenueCat.dart';
import 'package:tenthousandshotchallenge/services/RevenueCatProvider.dart';
import 'ChallengeMapNode.dart';
import 'LevelBannerWidget.dart';

// ── Layout constants (mirrors ChallengerRoadMapView) ─────────────────────────
const double _nodeSpacing = 108.0;
const double _nodeDiameter = 62.0;
const double _bannerHeight = 44.0;
const double _levelTopPad = 16.0;
const double _levelBottomPad = 20.0;
const List<double> _xFractions = [0.18, 0.50, 0.82];

int _colForIndex(int i) {
  final mod = i % 4;
  return mod == 3 ? 1 : mod;
}

List<Offset> _computeNodeCentres(int count, double stackWidth) {
  return List.generate(count, (i) {
    final x = stackWidth * _xFractions[_colForIndex(i)];
    final y = _levelTopPad + _bannerHeight + 16.0 + (_nodeDiameter / 2) + i * _nodeSpacing;
    return Offset(x, y);
  });
}

double _levelSectionHeight(int nodeCount) => _levelTopPad + _bannerHeight + 16.0 + nodeCount.clamp(1, 99) * _nodeSpacing + _levelBottomPad;

// ── Data ─────────────────────────────────────────────────────────────────────

class _TeaserData {
  final List<int> levels;
  final Map<int, List<ChallengerRoadChallenge>> challengesByLevel;

  const _TeaserData({required this.levels, required this.challengesByLevel});
}

// ── Main widget ───────────────────────────────────────────────────────────────

/// Full-screen blurred Challenger Road map shown to free users as a teaser.
///
/// Node taps are swallowed. A centred paywall card prompts the user to go pro.
class ChallengerRoadTeaserView extends StatefulWidget {
  const ChallengerRoadTeaserView({super.key});

  @override
  State<ChallengerRoadTeaserView> createState() => _ChallengerRoadTeaserViewState();
}

class _ChallengerRoadTeaserViewState extends State<ChallengerRoadTeaserView> {
  Future<_TeaserData>? _dataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dataFuture == null) {
      final firestore = Provider.of<FirebaseFirestore>(context, listen: false);
      _dataFuture = _loadData(firestore);
    }
  }

  Future<_TeaserData> _loadData(FirebaseFirestore firestore) async {
    final service = ChallengerRoadService(firestore: firestore);
    // Fetch first 3 levels for visual authenticity.
    final allLevels = await service.getAllActiveLevels();
    final levels = allLevels.take(3).toList();

    final challengesByLevel = <int, List<ChallengerRoadChallenge>>{};
    for (final lvl in levels) {
      challengesByLevel[lvl] = await service.getChallengesForLevel(lvl);
    }

    return _TeaserData(levels: levels, challengesByLevel: challengesByLevel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: BackButton(color: Theme.of(context).colorScheme.onPrimary),
        title: Text(
          'Challenger Road',
          style: TextStyle(
            fontFamily: 'NovecentoSans',
            fontSize: 22,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
      body: FutureBuilder<_TeaserData>(
        future: _dataFuture,
        builder: (context, snap) {
          Widget mapContent;
          if (snap.hasData && snap.data!.levels.isNotEmpty) {
            mapContent = _buildBlurredMap(snap.data!);
          } else {
            mapContent = _buildPlaceholderMap();
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Blurred, non-interactive map behind
              mapContent,
              // Paywall overlay
              _buildPaywallOverlay(context),
            ],
          );
        },
      ),
    );
  }

  // ── Blurred map ────────────────────────────────────────────────────────────

  Widget _buildBlurredMap(_TeaserData data) {
    // Build the same visual map structure as ChallengerRoadMapView, but only
    // the first few levels and completely non-interactive.
    return IgnorePointer(
      child: Opacity(
        opacity: 0.55,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackWidth = constraints.maxWidth;

              // Build level sections bottom-to-top (Level 1 at bottom).
              // Compute heights for each level so we can stack them.
              double cumulativeHeight = 0;
              final levelHeights = <int, double>{};
              for (final lvl in data.levels) {
                final challenges = data.challengesByLevel[lvl] ?? [];
                levelHeights[lvl] = _levelSectionHeight(challenges.length);
                cumulativeHeight += levelHeights[lvl]!;
              }

              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  height: cumulativeHeight + 60,
                  child: Stack(
                    children: _buildLevelWidgets(data, stackWidth, cumulativeHeight),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLevelWidgets(_TeaserData data, double stackWidth, double totalHeight) {
    final widgets = <Widget>[];
    // Level 1 is at the bottom: render in reverse order.
    final reversed = data.levels.toList(); // already ascending
    double offsetFromTop = 0;

    for (final lvl in reversed) {
      final challenges = data.challengesByLevel[lvl] ?? [];
      final sectionHeight = _levelSectionHeight(challenges.length);
      final centres = _computeNodeCentres(challenges.length, stackWidth);

      widgets.add(
        Positioned(
          top: offsetFromTop,
          left: 0,
          right: 0,
          height: sectionHeight,
          child: Stack(
            children: [
              // Level banner
              Positioned(
                top: _levelTopPad,
                left: 8,
                right: 8,
                height: _bannerHeight,
                child: LevelBannerWidget(
                  level: lvl,
                  isCurrentLevel: false,
                  isLocked: true,
                ),
              ),
              // Nodes (all locked visually for teaser)
              for (int i = 0; i < challenges.length; i++)
                Positioned(
                  left: centres[i].dx - _nodeDiameter / 2,
                  top: centres[i].dy - _nodeDiameter / 2,
                  width: _nodeDiameter,
                  height: _nodeDiameter,
                  child: ChallengeMapNode(
                    challengeName: challenges[i].name,
                    state: ChallengeNodeState.locked,
                    onTap: null,
                  ),
                ),
            ],
          ),
        ),
      );

      offsetFromTop += sectionHeight;
    }

    return widgets;
  }

  Widget _buildPlaceholderMap() {
    // Shown while loading — a simple gradient placeholder
    return IgnorePointer(
      child: Opacity(
        opacity: 0.25,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Paywall overlay card ───────────────────────────────────────────────────

  Widget _buildPaywallOverlay(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Card(
          color: Theme.of(context).cardTheme.color,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.route_rounded,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'CHALLENGER ROAD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 26,
                    color: Theme.of(context).colorScheme.onPrimary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'is a Pro feature',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Progress through structured shooting challenges, earn badges, and track your personal best level — all on the road to 10,000 shots.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NovecentoSans',
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await presentPaywallIfNeeded(context);
                      if (!context.mounted) return;
                      final notifier = Provider.of<CustomerInfoNotifier?>(context, listen: false);
                      if (notifier?.isPro == true) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'GO PRO',
                      style: TextStyle(
                        fontFamily: 'NovecentoSans',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
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
}
