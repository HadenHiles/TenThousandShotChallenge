import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeAllTimeHistory.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeProgressEntry.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengeSession.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadAttempt.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadChallenge.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadLevel.dart';
import 'package:tenthousandshotchallenge/models/firestore/ChallengerRoadUserSummary.dart';

/// Returned by [ChallengerRoadService.incrementChallengerRoadShots] so callers
/// can trigger the 10K celebration without a second Firestore read.
class ChallengerRoadMilestoneResult {
  final bool didHitMilestone;

  /// The new value of `challengerRoadShotCount` after the update (already
  /// reset to the remainder if a milestone was crossed).
  final int newCount;

  /// Total number of times the 10K milestone has been hit this attempt
  /// (cumulative, never resets).
  final int resetCount;

  const ChallengerRoadMilestoneResult({
    required this.didHitMilestone,
    required this.newCount,
    required this.resetCount,
  });
}

/// Visual and motivational rarity tier for a Challenger Road badge.
///
/// Tiers drive the badge colour in the UI:
/// - [common]    → grey     (#90A4AE)
/// - [uncommon]  → green    (#66BB6A)
/// - [rare]      → blue     (#42A5F5)
/// - [epic]      → purple   (#AB47BC)
/// - [legendary] → gold     (#FFD700)
/// - [hidden]    → slate    (#78909C)  displayed as "SECRET"; not shown in
///                the locked-badge gallery until earned
enum ChallengerRoadBadgeTier { common, uncommon, rare, epic, legendary, hidden }

/// Groups Challenger Road badges by the behaviour that unlocks them.
///
/// Categories are used to:
///   1. Assign icon characters in [_BadgeChip], [ChallengerRoadBadgeAwardScreen],
///      and the map-view badge sheet.
///   2. Group badges in future catalogue screens.
///
/// | Category                 | Icon                         |
/// |--------------------------|------------------------------|
/// | firstSteps               | Icons.route_rounded          |
/// | withinRunEfficiency      | Icons.bolt_rounded           |
/// | crossAttemptImprovement  | Icons.trending_up_rounded    |
/// | grindAndResilience       | Icons.shield_rounded         |
/// | levelAdvancement         | Icons.stairs_rounded         |
/// | crShotMilestones         | Icons.workspace_premium_rounded |
/// | crSessionAccuracy        | Icons.gps_fixed_rounded      |
/// | hotStreaks                | Icons.local_fire_department_rounded |
/// | challengeMastery         | Icons.emoji_events_rounded   |
/// | multiAttemptCareer       | Icons.repeat_rounded         |
/// | eliteEndgame             | Icons.military_tech_rounded  |
/// | chirpy                   | Icons.sports_hockey_rounded  |
enum ChallengerRoadBadgeCategory {
  firstSteps,
  withinRunEfficiency,
  crossAttemptImprovement,
  grindAndResilience,
  levelAdvancement,
  crShotMilestones,
  crSessionAccuracy,
  hotStreaks,
  challengeMastery,
  multiAttemptCareer,
  eliteEndgame,
  chirpy,
}

/// Immutable definition of a single Challenger Road badge.
///
/// Instances live exclusively in [ChallengerRoadService.badgeCatalog] — they
/// are `const` and never stored in Firestore.  Only the [id] is persisted
/// (as a string) in the user's `badges` array inside the
/// `users/{uid}/challenger_road/summary` document.
///
/// **Adding a new badge**
/// 1. Add a `ChallengerRoadBadgeDefinition` entry to [ChallengerRoadService.badgeCatalog].
/// 2. Add the award logic to `_checkAndAwardBadges`, `_checkContextualSessionBadges`,
///    `advanceLevel`, or `incrementChallengerRoadShots` as appropriate.
/// 3. Add the [id] to the `VALID_BADGE_IDS` set in
///    `scripts/prune_legacy_badges.js`.
///
/// **Removing a badge**
/// Remove the entry from [badgeCatalog].  `_checkAndAwardBadges` automatically
/// strips any ID not present in the catalog from a user's `badges` list the
/// next time it runs for that user.
class ChallengerRoadBadgeDefinition {
  /// Stable, snake_case identifier persisted in Firestore. Never rename.
  final String id;

  /// Short display name shown in the badge award screen and profile grid.
  final String name;

  /// One-sentence description shown under the badge name (gen-Z hockey voice).
  final String description;

  /// Behavioural grouping used for icon selection and future catalogue screens.
  final ChallengerRoadBadgeCategory category;

  /// Rarity tier that drives badge colour.
  final ChallengerRoadBadgeTier tier;

  /// Admin-managed display name override stored in Firestore
  /// (`challenger_road_badges/{id}.display_name`). When non-null, the UI should
  /// prefer this over [name]. Never affects award logic.
  final String? displayName;

  /// Admin-managed description override stored in Firestore
  /// (`challenger_road_badges/{id}.display_description`). When non-null, the UI
  /// should prefer this over [description]. Never affects award logic.
  final String? displayDescription;

  /// The name shown to players. Returns [displayName] if the admin has set one,
  /// otherwise falls back to the code-defined [name].
  String get effectiveName => displayName ?? name;

  /// The description shown to players. Returns [displayDescription] if the admin
  /// has set one, otherwise falls back to the code-defined [description].
  String get effectiveDescription => displayDescription ?? description;

  const ChallengerRoadBadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
    this.displayName,
    this.displayDescription,
  });

  ChallengerRoadBadgeDefinition copyWith({
    String? displayName,
    String? displayDescription,
  }) {
    return ChallengerRoadBadgeDefinition(
      id: id,
      name: name,
      description: description,
      category: category,
      tier: tier,
      displayName: displayName ?? this.displayName,
      displayDescription: displayDescription ?? this.displayDescription,
    );
  }
}

class ChallengerRoadService {
  final FirebaseFirestore _firestore;

  ChallengerRoadService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Internal path helpers
  // ---------------------------------------------------------------------------

  /// Root of the Challenger Road levels collection.
  /// Firestore path: challenger_road_levels/{levelId}
  CollectionReference get _levelsRef => _firestore.collection('challenger_road_levels');

  /// Admin-managed badge display overrides.
  /// Firestore path: challenger_road_badges/{badgeId}
  /// Fields: display_name (string?), display_description (string?)
  CollectionReference get _badgeOverridesRef => _firestore.collection('challenger_road_badges');

  /// Challenge docs owned by a specific level.
  CollectionReference _challengesRef(String levelDocId) => _levelsRef.doc(levelDocId).collection('challenges');

  /// Per-user Challenger Road summary document.
  /// Firestore path: users/{uid}/challenger_road/summary
  DocumentReference _userSummaryRef(String userId) => _firestore.collection('users').doc(userId).collection('challenger_road').doc('summary');

  /// Attempts sub-collection for a user.
  CollectionReference _attemptsRef(String userId) => _firestore.collection('users').doc(userId).collection('challenger_road_attempts');

  /// Challenge sessions sub-collection for a given attempt.
  CollectionReference _sessionsRef(String userId, String attemptId) => _attemptsRef(userId).doc(attemptId).collection('challenge_sessions');

  /// Per-challenge progress sub-collection within one attempt.
  CollectionReference _progressRef(String userId, String attemptId) => _attemptsRef(userId).doc(attemptId).collection('challenge_progress');

  /// Cross-attempt per-challenge history sub-collection.
  CollectionReference _allTimeHistoryRef(String userId) => _firestore.collection('users').doc(userId).collection('challenger_road_challenge_history');

  Future<QueryDocumentSnapshot?> _findActiveLevelSnapshot(int level) async {
    final snap = await _levelsRef.where('active', isEqualTo: true).get();
    for (final doc in snap.docs) {
      final levelValue = ((doc.data() as Map<String, dynamic>?)?['level'] as num?)?.toInt();
      if (levelValue == level) return doc;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Badge catalog — static, hockey-voice, CR-only
  // ---------------------------------------------------------------------------

  /// The full badge catalog. Every badge here is earned exclusively through
  /// Challenger Road challenge sessions, level completions, attempt data, and
  /// CR shot counters. Nothing bleeds into weekly achievements or normal
  /// shooting sessions.
  static const List<ChallengerRoadBadgeDefinition> badgeCatalog = [
    // ── FIRST STEPS ──────────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_fresh_laces',
      name: 'Fresh Laces',
      description: 'Started the Challenger Road.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_drop_the_biscuit',
      name: 'Drop the Biscuit',
      description: 'Completed your first challenge session.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_clean_read',
      name: 'Clean Read',
      description: 'Passed your first challenge.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_level_clear',
      name: 'Level Clear',
      description: 'Level 1 done.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_made_the_show',
      name: 'Made the Show',
      description: 'Level 3 cleared. Not a tryout anymore.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),

    // ── WITHIN-RUN EFFICIENCY ─────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_no_warmup_needed',
      name: 'No Warmup Needed',
      description: 'Cleared a full level without a single failed session.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_sharp',
      name: 'Sharp',
      description: '4 passes in a row, zero failures between them.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_breakaway',
      name: 'Breakaway',
      description: 'Cleared every challenge in a level in a single day.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_freight_train',
      name: 'Freight Train',
      description: 'Two levels in a row with zero failed sessions.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_clean_sweep',
      name: 'Clean Sweep',
      description: 'Every challenge in a level passed on the first try.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── CROSS-ATTEMPT IMPROVEMENT ─────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_scouting_report',
      name: 'Scouting Report',
      description: 'First-try pass on a challenge that took multiple tries last run.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_rematch',
      name: 'The Rematch',
      description: 'Passed a challenge you couldn\'t finish in your previous attempt.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_dialed_in',
      name: 'Dialed In',
      description: 'New personal best accuracy on your hardest challenge.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_comeback_season',
      name: 'Comeback Season',
      description: 'Reached a higher level than your previous best attempt.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_redemption_arc',
      name: 'Redemption Arc',
      description: 'First-try pass on a challenge you failed 5+ times in a previous run.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_comeback_kid',
      name: 'The Comeback Kid',
      description: 'Set a new personal best level in 3 separate attempts.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.hidden,
    ),

    // ── GRIND & RESILIENCE ────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_battle_tested',
      name: 'Battle Tested',
      description: 'Failed the same challenge 5 times in a row, then passed it.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_game_7',
      name: 'Game 7',
      description: 'Passed the challenge you\'ve failed more than any other.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_ghosts_in_the_machine',
      name: 'Ghosts in the Machine',
      description: 'Passed a challenge after 10+ all-time failures on it.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_third_period_heart',
      name: 'Third Period Heart',
      description: 'Cleared a level despite 10+ failed sessions inside it.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_old_grudge',
      name: 'Old Grudge',
      description: 'Failed this challenge in two straight attempts — then finally passed it.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.rare,
    ),

    // ── LEVEL ADVANCEMENT ─────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_ice_time_earned',
      name: 'Ice Time Earned',
      description: 'Level 5 cleared.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_team_captain',
      name: 'Team Captain',
      description: 'Level 10 cleared.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_climb',
      name: 'The Climb',
      description: 'New personal best level reached.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_playoff_mode',
      name: 'Playoff Mode',
      description: 'Reached the highest level on the Challenger Road.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_general',
      name: 'The General',
      description: 'Every challenge, every level — all of them.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── CR SHOT MILESTONES ────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_first_bucket',
      name: 'First Bucket',
      description: '100 Challenger Road shots.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_building_a_barn',
      name: 'Building a Barn',
      description: '1,000 Challenger Road shots.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_ten_minute_major',
      name: 'Ten-Minute Major',
      description: '5,000 Challenger Road shots.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_buzzer_beater',
      name: 'Buzzer Beater',
      description: '10,000 Challenger Road shots.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_three_periods',
      name: 'Three Periods',
      description: '30,000 Challenger Road shots in one attempt.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_well_never_runs_dry',
      name: 'The Well Never Runs Dry',
      description: '25,000 cumulative Challenger Road shots all-time.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── CR SESSION ACCURACY ───────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_lights_out',
      name: 'Lights Out',
      description: 'New personal best accuracy in a session.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_bar_down',
      name: 'Bar Down',
      description: '90%+ accuracy in a single session.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_top_cheese',
      name: 'Top Cheese',
      description: '95%+ accuracy in a single session.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_pure',
      name: 'Pure',
      description: '100% accuracy in a session. Nothing missed.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_sniper',
      name: 'The Sniper',
      description: '85%+ average accuracy across a full completed level.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_all_net',
      name: 'All Net',
      description: '5 perfect 100% accuracy sessions.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── HOT STREAKS ───────────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_sauce',
      name: 'Sauce',
      description: '5 passes in a row, no failures in between.',
      category: ChallengerRoadBadgeCategory.hotStreaks,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_unstoppable',
      name: 'Unstoppable',
      description: '10 passes in a row, no failures in between.',
      category: ChallengerRoadBadgeCategory.hotStreaks,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_full_send',
      name: 'Full Send',
      description: 'Best accuracy AND highest shot volume in the same session.',
      category: ChallengerRoadBadgeCategory.hotStreaks,
      tier: ChallengerRoadBadgeTier.epic,
    ),

    // ── CHALLENGE MASTERY ─────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_never_missed',
      name: 'Never Missed',
      description: '5+ challenges you\'ve never once failed.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_untouchable',
      name: 'Untouchable',
      description: 'First-try pass on the same challenge in 5+ separate runs.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_earned_a_salary',
      name: 'Earned a Salary',
      description: '25 all-time passes on a single challenge.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.epic,
    ),

    // ── MULTI-ATTEMPT / CAREER ────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_veteran_presence',
      name: 'Veteran Presence',
      description: 'Started a second Challenger Road attempt.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_lifer',
      name: 'Lifer',
      description: '5 Challenger Road attempts. It\'s just your thing now.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_career_year',
      name: 'Career Year',
      description: 'Hit 10,000 shots AND a new personal best level in the same attempt.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_road_dog',
      name: 'Road Dog',
      description: '250 total sessions on the Challenger Road.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_all_time_great',
      name: 'All-Time Great',
      description: '100 total challenge passes across all attempts.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── ELITE / ENDGAME ───────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_hall_of_famer',
      name: 'Hall of Famer',
      description: 'Completed the full Challenger Road in a single attempt.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_machine',
      name: 'The Machine',
      description: '80%+ average accuracy across 3 complete attempts.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_hockey_god',
      name: 'Hockey God',
      description: 'Completed the full road with zero failed sessions.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.hidden,
    ),

    // ── CHIRPY / PERSONALITY ──────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_bender',
      name: 'Bender',
      description: 'Started a new attempt at a lower level than your previous best.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_pigeon',
      name: 'Pigeon',
      description: 'First-try pass at 95%+ accuracy on a hard challenge.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_ferda',
      name: 'Ferda',
      description: 'Hit 10,000 shots and kept going.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_sauce_boss',
      name: 'Sauce Boss',
      description: 'New personal best accuracy on a harder Challenger Road challenge.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_skip_the_tryout',
      name: 'Skip the Tryout',
      description: 'Started a new attempt at a higher level using unlocks from a previous run.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_all_stars',
      name: 'All Stars',
      description: 'Completed the full road from Level 1 — even though you had levels unlocked to skip.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
  ];

  /// Returns the full badge catalog with code-defined values only.
  /// Use [getBadgeCatalogForUser] to include admin-managed display overrides.
  Future<List<ChallengerRoadBadgeDefinition>> getBadgeCatalog() async => badgeCatalog;

  /// Returns the badge catalog with any admin-managed display overrides applied.
  ///
  /// Reads `challenger_road_badges/{id}` documents from Firestore. If a doc
  /// exists for a badge it may supply `display_name` and/or
  /// `display_description` fields; those override the code-defined copy in the
  /// UI via [ChallengerRoadBadgeDefinition.effectiveName] and
  /// [ChallengerRoadBadgeDefinition.effectiveDescription].
  ///
  /// Award logic is never affected — it always uses [badgeCatalog] directly.
  Future<List<ChallengerRoadBadgeDefinition>> getBadgeCatalogForUser(String userId) async {
    final overridesSnap = await _badgeOverridesRef.get();
    if (overridesSnap.docs.isEmpty) return badgeCatalog;

    final overridesByid = <String, Map<String, dynamic>>{
      for (final doc in overridesSnap.docs) doc.id: doc.data() as Map<String, dynamic>,
    };

    return badgeCatalog.map((badge) {
      final overrides = overridesByid[badge.id];
      if (overrides == null) return badge;
      final displayName = overrides['display_name'] as String?;
      final displayDescription = overrides['display_description'] as String?;
      if (displayName == null && displayDescription == null) return badge;
      return badge.copyWith(
        displayName: displayName,
        displayDescription: displayDescription,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 1. Global challenge data
  // ---------------------------------------------------------------------------

  /// Returns all [ChallengerRoadChallenge] objects that have an active level
  /// document at [level], ordered by that level's [sequence] field.
  Future<List<ChallengerRoadChallenge>> getChallengesForLevel(int level) async {
    final levelSnap = await _findActiveLevelSnapshot(level);
    if (levelSnap == null) return [];

    // level_name is authoritative on the parent level document — override
    // whatever the challenge sub-docs carry so a single field update is enough.
    final parentData = levelSnap.data() as Map<String, dynamic>?;
    final parentLevelName = (parentData?['level_name'] as String?)?.trim();

    final challengesSnap = await _challengesRef(levelSnap.id).orderBy('sequence').get();
    return challengesSnap.docs.map(ChallengerRoadChallenge.fromSnapshot).where((c) => c.active).map((c) {
      if (parentLevelName != null && parentLevelName.isNotEmpty && parentLevelName != c.levelName) {
        return c.copyWith(levelName: parentLevelName);
      }
      return c;
    }).toList();
  }

  /// Returns the [ChallengerRoadLevel] document for a specific challenge at a
  /// specific level, or null if the challenge does not participate at that level.
  Future<ChallengerRoadLevel?> getLevelDoc(String challengeId, int level) async {
    final challenges = await getChallengesForLevel(level);
    for (final challenge in challenges) {
      if (challenge.id == challengeId) {
        return challenge.toLevelDoc();
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. Distinct active level numbers (for map rendering)
  // ---------------------------------------------------------------------------

  /// Returns a sorted list of all distinct active level numbers across all challenges.
  /// Used to build the full snake map without loading every challenge.
  Future<List<int>> getAllActiveLevels() async {
    final snap = await _levelsRef.where('active', isEqualTo: true).get();

    final levels = snap.docs.map((d) => (d.data() as Map<String, dynamic>?)?['level'] as num?).whereType<num>().map((n) => n.toInt()).toSet().toList()..sort();

    return levels;
  }

  // ---------------------------------------------------------------------------
  // 3. User attempt management
  // ---------------------------------------------------------------------------

  /// Returns the current active [ChallengerRoadAttempt] for a user, or null
  /// if the user has never started Challenger Road.
  Future<ChallengerRoadAttempt?> getActiveAttempt(String userId) async {
    final snap = await _attemptsRef(userId).where('status', isEqualTo: 'active').limit(1).get();
    if (snap.docs.isEmpty) return null;
    return ChallengerRoadAttempt.fromSnapshot(snap.docs.first);
  }

  /// Creates a brand-new [ChallengerRoadAttempt] for a user starting at
  /// [startingLevel]. Also updates the user summary's `currentAttemptId` and
  /// `totalAttempts`, then runs badge checks.
  Future<ChallengerRoadAttempt> createAttempt(
    String userId,
    int startingLevel, {
    int inheritedUnlockedLevel = 0,
  }) async {
    final summary = await getUserSummary(userId);
    final attemptNumber = summary.totalAttempts + 1;

    final attempt = ChallengerRoadAttempt(
      attemptNumber: attemptNumber,
      startingLevel: startingLevel,
      currentLevel: startingLevel,
      challengerRoadShotCount: 0,
      totalShotsThisAttempt: 0,
      resetCount: 0,
      highestLevelReachedThisAttempt: startingLevel,
      inheritedUnlockedLevel: inheritedUnlockedLevel,
      status: 'active',
      startDate: DateTime.now(),
    );

    final docRef = await _attemptsRef(userId).add(attempt.toMap());
    attempt.id = docRef.id;

    await updateUserSummary(userId, {
      'current_attempt_id': docRef.id,
      'total_attempts': attemptNumber,
    });

    final updatedSummary = summary.copyWith(
      currentAttemptId: docRef.id,
      totalAttempts: attemptNumber,
    );
    await _checkAndAwardBadges(userId: userId, summary: updatedSummary);

    // cr_skip_the_tryout: player chose to start above Level 1 using inherited unlocks.
    if (inheritedUnlockedLevel > 0 && startingLevel > 1) {
      final freshSummary = await getUserSummary(userId);
      final earned = List<String>.from(freshSummary.badges);
      if (!earned.contains('cr_skip_the_tryout')) {
        earned.add('cr_skip_the_tryout');
        await updateUserSummary(userId, {'badges': earned});
      }
    }

    return attempt;
  }

  /// Applies a partial update to an attempt document. Callers should use the
  /// snake_case field names that match the Firestore document schema.
  Future<void> updateAttempt(String userId, String attemptId, Map<String, dynamic> data) async {
    await _attemptsRef(userId).doc(attemptId).update(data);
  }

  // ---------------------------------------------------------------------------
  // 4. Challenge session management
  // ---------------------------------------------------------------------------

  /// Saves a completed [ChallengeSession] and atomically updates both the
  /// per-attempt [ChallengeProgressEntry] and the cross-attempt
  /// [ChallengeAllTimeHistory] for the same challenge.
  ///
  /// All three writes succeed or none do (WriteBatch).
  /// Returns the list of [ChallengerRoadBadgeDefinition] that were newly earned
  /// by this session (empty list if none).
  Future<List<ChallengerRoadBadgeDefinition>> saveChallengeSession(String userId, String attemptId, ChallengeSession session) async {
    final batch = _firestore.batch();

    // 1. New challenge_sessions document.
    final sessionRef = _sessionsRef(userId, attemptId).doc();
    batch.set(sessionRef, session.toMap());

    // 2. Upsert challenge_progress for this attempt.
    await _buildChallengeProgressUpdate(userId, attemptId, session, batch: batch);

    // 3. Upsert cross-attempt challenge history.
    await _buildAllTimeHistoryUpdate(userId, session, batch: batch);

    await batch.commit();

    // Compute badge stats once — shared by both stat-based and contextual checks
    // to avoid loading all Firestore session data twice per save.
    // getUserSummary is kicked off in parallel with the stats load.
    final badgeStatsFuture = _loadRoadBadgeStats(userId);
    final summaryFuture = getUserSummary(userId);
    final badgeStats = await badgeStatsFuture;
    final summary = await summaryFuture;

    final newStatsBadges = await _checkAndAwardBadges(
      userId: userId,
      summary: summary,
      precomputedStats: badgeStats,
    );

    // Re-read summary so contextual check sees stats badges already persisted.
    final summaryAfterStats = await getUserSummary(userId);
    final newContextualBadges = await _checkContextualSessionBadges(
      userId: userId,
      attemptId: attemptId,
      session: session,
      summary: summaryAfterStats,
      precomputedStats: badgeStats,
    );

    final allNewIds = {...newStatsBadges, ...newContextualBadges};
    final catalog = badgeCatalog;
    return catalog.where((def) => allNewIds.contains(def.id)).toList();
  }

  /// Awards session-level contextual badges that need the current [session]
  /// object in scope — things like new personal-best accuracy, consecutive
  /// pass streaks checked live, and special per-challenge conditions.
  /// Returns the IDs of any badges newly awarded by this call.
  Future<List<String>> _checkContextualSessionBadges({
    required String userId,
    required String attemptId,
    required ChallengeSession session,
    required ChallengerRoadUserSummary summary,
    _RoadBadgeStats? precomputedStats,
  }) async {
    final earned = List<String>.from(summary.badges);
    final newIds = <String>[];

    void maybeAward(String id) {
      if (!earned.contains(id)) {
        earned.add(id);
        newIds.add(id);
      }
    }

    final sessionAcc = session.totalShots > 0 ? session.shotsMade / session.totalShots : 0.0;

    // cr_greasy_but_goes_in was removed from the catalog (too niche).

    // cr_lights_out: new personal best accuracy — compare against all previous CR sessions.
    // Read all prior sessions for this challenge across all attempts to find the prior best.
    double priorBestAcc = 0.0;
    final allAttemptSnap = await _attemptsRef(userId).get();
    for (final attemptDoc in allAttemptSnap.docs) {
      if (attemptDoc.id == attemptId) continue; // exclude current attempt
      final priorSnap = await _sessionsRef(userId, attemptDoc.id).where('challenge_id', isEqualTo: session.challengeId).get();
      for (final ps in priorSnap.docs) {
        final s = ChallengeSession.fromSnapshot(ps);
        final acc = s.totalShots > 0 ? s.shotsMade / s.totalShots : 0.0;
        if (acc > priorBestAcc) priorBestAcc = acc;
      }
    }
    // Also check prior sessions in the current attempt for this challenge.
    final currentAttemptPrior = await _sessionsRef(userId, attemptId).where('challenge_id', isEqualTo: session.challengeId).get();
    for (final ps in currentAttemptPrior.docs) {
      final s = ChallengeSession.fromSnapshot(ps);
      if (s.id == session.id) continue;
      final acc = s.totalShots > 0 ? s.shotsMade / s.totalShots : 0.0;
      if (acc > priorBestAcc) priorBestAcc = acc;
    }
    if (sessionAcc > priorBestAcc && priorBestAcc > 0.0) {
      maybeAward('cr_lights_out');
      // cr_better_than_before was removed from the catalog; no longer awarded here.
    }

    // cr_didnt_quit was removed from the catalog (too simple / overlapping).

    // cr_short_handed: removed. cr_battle_tested: passed after 5+ consecutive failures.
    if (session.passed) {
      final allInAttempt = await _sessionsRef(userId, attemptId).where('challenge_id', isEqualTo: session.challengeId).orderBy('date').get();
      final sessionList = allInAttempt.docs.map(ChallengeSession.fromSnapshot).toList();

      // cr_battle_tested: passed after exactly 5 consecutive failures.
      if (sessionList.length >= 6) {
        final priorFive = sessionList.sublist(sessionList.length - 6, sessionList.length - 1);
        if (priorFive.every((s) => !s.passed)) maybeAward('cr_battle_tested');
      }
    }

    // cr_game_7: passed the all-time most-failed challenge.
    if (session.passed) {
      final stats = precomputedStats ?? await _loadRoadBadgeStats(userId);
      if (stats.mostFailedChallengeId == session.challengeId && stats.mostFailedChallengeCount >= 3) {
        maybeAward('cr_game_7');
      }

      // cr_ghosts_in_the_machine: 10+ all-time failures on this challenge, now passed.
      final failCount = stats.allTimeSessionsByChallenge[session.challengeId] ?? 0;
      final passCount = stats.allTimePassesByChallenge[session.challengeId] ?? 0;
      final priorFailed = failCount - passCount - 1; // subtract this pass
      if (priorFailed >= 10) maybeAward('cr_ghosts_in_the_machine');

      // cr_old_grudge + cr_redemption_arc: fetch all prior-attempt progress in
      // parallel to avoid N sequential Firestore round-trips.
      final priorAttemptDocs = (await _attemptsRef(userId).orderBy('attempt_number').get()).docs.takeWhile((doc) => doc.id != attemptId).toList();
      final priorProgresses = await Future.wait(
        priorAttemptDocs.map((doc) => getChallengeProgress(userId, doc.id, session.challengeId)),
      );

      // cr_old_grudge: failed this challenge in the previous two attempts, now passed.
      final attemptsWithoutPass = priorProgresses.whereType<ChallengeProgressEntry>().where((p) => p.totalPassed == 0 && p.totalAttempts > 0).length;
      if (attemptsWithoutPass >= 2) maybeAward('cr_old_grudge');

      // cr_redemption_arc: passed first-try this attempt; had 5+ failures in a prior attempt.
      final progressSnap = await _progressRef(userId, attemptId).doc(session.challengeId).get();
      if (progressSnap.exists) {
        final progress = ChallengeProgressEntry.fromSnapshot(progressSnap);
        // totalAttempts == 1 means this is the first (and only) session in this attempt.
        if (progress.totalAttempts == 1) {
          for (final pp in priorProgresses) {
            if (pp != null && (pp.totalAttempts - pp.totalPassed) >= 5) {
              maybeAward('cr_redemption_arc');
              break;
            }
          }
        }
      }

      // cr_snipe_artist was removed from the catalog; no contextual check needed.
    }

    // cr_pigeon: first-try 95%+ on a hard challenge.
    // (difficulty stored on the challenge; use level as proxy: level >= 5 = hard.)
    if (session.passed && sessionAcc >= 0.95 && session.level >= 5) {
      final progressNow = await getChallengeProgress(userId, attemptId, session.challengeId);
      if (progressNow != null && progressNow.totalAttempts == 1) {
        maybeAward('cr_pigeon');
      }
    }

    // cr_sauce_boss: personal best accuracy on any challenge at a hard level.
    if (session.level >= 5) {
      if (sessionAcc > priorBestAcc) maybeAward('cr_sauce_boss');
    }

    // cr_full_send: top-10 volume AND best accuracy simultaneously — simplified:
    // award if this session is the single best accuracy session and also has
    // >= 80% of the personal max totalShots seen in any session.
    // (Full cross-session top-10 rank requires reading all sessions — too expensive
    // here. We use a reasonable approximation.)
    if (sessionAcc >= 0.85) {
      // Check if totalShots is within 80% of the max across recent sessions.
      final recentSnap = await _sessionsRef(userId, attemptId).orderBy('date', descending: true).limit(20).get();
      final maxShots = recentSnap.docs.map(ChallengeSession.fromSnapshot).map((s) => s.totalShots).fold(0, (a, b) => a > b ? a : b);
      if (maxShots > 0 && session.totalShots >= maxShots * 0.80) {
        maybeAward('cr_full_send');
      }
    }

    if (newIds.isNotEmpty) await updateUserSummary(userId, {'badges': earned});
    return newIds;
  }

  /// Returns all [ChallengeSession] documents for a given attempt, ordered by
  /// date descending.
  Future<List<ChallengeSession>> getSessionsForAttempt(String userId, String attemptId) async {
    final snap = await _sessionsRef(userId, attemptId).orderBy('date', descending: true).get();
    return snap.docs.map(ChallengeSession.fromSnapshot).toList();
  }

  /// Returns all [ChallengeSession] tries for a specific [challengeId] at a
  /// specific [level] within one attempt, ordered by date descending.
  Future<List<ChallengeSession>> getTriesForChallenge(
    String userId,
    String attemptId,
    String challengeId,
    int level,
  ) async {
    final snap = await _sessionsRef(userId, attemptId).where('challenge_id', isEqualTo: challengeId).where('level', isEqualTo: level).orderBy('date', descending: true).get();
    return snap.docs.map(ChallengeSession.fromSnapshot).toList();
  }

  /// Returns true if a passing session exists for [challengeId] at [level]
  /// within a given attempt.
  ///
  /// Prefer [getChallengeProgress] for repeated/bulk checks — this method
  /// queries challenge_sessions directly and is best for one-off verification.
  Future<bool> isChallengePassedAtLevel(String userId, String attemptId, String challengeId, int level) async {
    // Fast path: read challenge_progress document (O(1) doc read).
    final progress = await getChallengeProgress(userId, attemptId, challengeId);
    if (progress != null) return progress.bestLevel >= level;

    // Fallback: query sessions directly (no progress doc yet = never passed).
    return false;
  }

  // ---------------------------------------------------------------------------
  // 4b. Per-challenge history management
  // ---------------------------------------------------------------------------

  /// Returns the [ChallengeProgressEntry] for a specific challenge within one
  /// attempt, or null if the challenge has never been attempted.
  Future<ChallengeProgressEntry?> getChallengeProgress(String userId, String attemptId, String challengeId) async {
    final snap = await _progressRef(userId, attemptId).doc(challengeId).get();
    if (!snap.exists) return null;
    return ChallengeProgressEntry.fromSnapshot(snap);
  }

  /// Returns the [ChallengeAllTimeHistory] for a specific challenge across all
  /// of a user's attempts, or null if the challenge has never been attempted.
  Future<ChallengeAllTimeHistory?> getChallengeAllTimeHistory(String userId, String challengeId) async {
    final snap = await _allTimeHistoryRef(userId).doc(challengeId).get();
    if (!snap.exists) return null;
    return ChallengeAllTimeHistory.fromSnapshot(snap);
  }

  // ---------------------------------------------------------------------------
  // 5. Level advancement
  // ---------------------------------------------------------------------------

  /// Returns true when every active challenge that participates at [level] has
  /// a passing session in the given attempt.
  Future<bool> isLevelComplete(String userId, String attemptId, int level) async {
    final challenges = await getChallengesForLevel(level);
    if (challenges.isEmpty) return false;

    for (final challenge in challenges) {
      final challengeId = challenge.id;
      if (challengeId == null) continue;

      final passed = await isChallengePassedAtLevel(userId, attemptId, challengeId, level);
      if (!passed) return false;
    }

    return true;
  }

  /// Replays any missed level unlocks for the active attempt by checking
  /// contiguous level completion from the persisted current level onward.
  ///
  /// This is forward-only: it advances stale attempts that should already have
  /// unlocked additional levels, but it does not downgrade stored progress.
  Future<ChallengerRoadAttempt?> syncActiveAttemptProgress(String userId) async {
    final activeAttempt = await getActiveAttempt(userId);
    if (activeAttempt == null) return null;

    var attempt = activeAttempt;

    while (await isLevelComplete(userId, attempt.id!, attempt.currentLevel)) {
      attempt = await advanceLevel(userId, attempt.id!);
    }

    return attempt;
  }

  /// Advances the user's current level by 1, updating [ChallengerRoadAttempt]
  /// and [ChallengerRoadUserSummary] as needed. Call this after confirming
  /// [isLevelComplete] returns true.
  ///
  /// Returns the updated [ChallengerRoadAttempt].
  Future<ChallengerRoadAttempt> advanceLevel(String userId, String attemptId) async {
    final attemptSnap = await _attemptsRef(userId).doc(attemptId).get();
    final attempt = ChallengerRoadAttempt.fromSnapshot(attemptSnap);

    final completedLevel = attempt.currentLevel;
    final newLevel = completedLevel + 1;
    final newHighest = max(attempt.highestLevelReachedThisAttempt, completedLevel);

    await updateAttempt(userId, attemptId, {
      'current_level': newLevel,
      'highest_level_reached_this_attempt': newHighest,
    });

    // Update all-time best level on user summary if we set a new record.
    // Capture pre-advancement best level for comeback badge check.
    final summary = await getUserSummary(userId);
    final prevBestLevel = summary.allTimeBestLevel;
    final bestAttemptUpdate = _buildBestAttemptSummaryUpdate(
      summary: summary,
      completedLevel: completedLevel,
      totalShotsThisAttempt: attempt.totalShotsThisAttempt,
    );
    if (bestAttemptUpdate.isNotEmpty) {
      await updateUserSummary(userId, bestAttemptUpdate);
    }

    final updatedSummary = await getUserSummary(userId);
    await _checkAndAwardBadges(userId: userId, summary: updatedSummary);

    // Extra badges that require attempt-level and level-completion context.
    final extraBadges = <String>[];

    // cr_the_climb: new all-time best level reached.
    if (completedLevel > prevBestLevel) {
      extraBadges.add('cr_the_climb');
    }

    // cr_third_period_heart: cleared this level despite 10+ failed sessions within it.
    final levelSessions = await _sessionsRef(userId, attemptId).where('level', isEqualTo: completedLevel).get();
    final failedInLevel = levelSessions.docs.map(ChallengeSession.fromSnapshot).where((s) => !s.passed).length;
    if (failedInLevel >= 10) extraBadges.add('cr_third_period_heart');

    // cr_no_warmup_needed: cleared this level with zero failed sessions.
    if (failedInLevel == 0) extraBadges.add('cr_no_warmup_needed');

    // cr_breakaway: all challenges in this level cleared in one calendar day.
    final allLevelSessions = levelSessions.docs.map(ChallengeSession.fromSnapshot).where((s) => s.passed).toList();
    if (allLevelSessions.isNotEmpty) {
      final dates = allLevelSessions.map((s) => s.date).toList()..sort();
      final firstDate = dates.first;
      final lastDate = dates.last;
      final sameDay = firstDate.year == lastDate.year && firstDate.month == lastDate.month && firstDate.day == lastDate.day;
      if (sameDay) extraBadges.add('cr_breakaway');
    }

    // cr_clean_sweep: every challenge in this level passed on first attempt.
    if (await _isLevelPerfect(userId, attemptId, completedLevel)) {
      extraBadges.add('cr_clean_sweep');
    }

    // cr_freight_train: previous level was also completed with zero failures.
    if (failedInLevel == 0 && completedLevel > 1) {
      final prevLevelSessions = await _sessionsRef(userId, attemptId).where('level', isEqualTo: completedLevel - 1).get();
      final prevFailed = prevLevelSessions.docs.map(ChallengeSession.fromSnapshot).where((s) => !s.passed).length;
      if (prevFailed == 0) extraBadges.add('cr_freight_train');
    }

    // cr_the_sniper: 85%+ average accuracy across all sessions in this level.
    if (levelSessions.docs.isNotEmpty) {
      final allInLevel = levelSessions.docs.map(ChallengeSession.fromSnapshot).toList();
      if (allInLevel.any((s) => s.totalShots > 0)) {
        final avgAcc = allInLevel.where((s) => s.totalShots > 0).map((s) => s.shotsMade / s.totalShots).fold(0.0, (a, b) => a + b) / allInLevel.where((s) => s.totalShots > 0).length;
        if (avgAcc >= 0.85) extraBadges.add('cr_the_sniper');
      }
    }

    // Check if the full road is now complete (all levels cleared in this attempt).
    final activeLevels = await getAllActiveLevels();
    final allLevelsComplete = activeLevels.isNotEmpty &&
        await Future.wait(
          activeLevels.map((l) => isLevelComplete(userId, attemptId, l)),
        ).then((results) => results.every((r) => r));

    if (allLevelsComplete) {
      // cr_hall_of_famer: first time completing the full road.
      extraBadges.add('cr_hall_of_famer');

      // cr_hockey_god: full road with zero failed sessions across all levels.
      final allSessionsSnap = await _sessionsRef(userId, attemptId).get();
      final anyFailure = allSessionsSnap.docs.map(ChallengeSession.fromSnapshot).any((s) => !s.passed);
      if (!anyFailure) extraBadges.add('cr_hockey_god');

      // cr_the_machine: 80%+ average across 3 complete attempts.
      // We check all completed attempts' average accuracies.
      final completedAttemptsSnap = await _attemptsRef(userId).where('status', isEqualTo: 'completed').get();
      if (completedAttemptsSnap.docs.length >= 3) {
        final accs = <double>[];
        for (final aDoc in completedAttemptsSnap.docs) {
          final aSessions = await _sessionsRef(userId, aDoc.id).get();
          final validSessions = aSessions.docs.map(ChallengeSession.fromSnapshot).where((s) => s.totalShots > 0).toList();
          if (validSessions.isEmpty) continue;
          final avg = validSessions.map((s) => s.shotsMade / s.totalShots).fold(0.0, (a, b) => a + b) / validSessions.length;
          accs.add(avg);
        }
        if (accs.length >= 3 && accs.every((a) => a >= 0.80)) {
          extraBadges.add('cr_the_machine');
        }
      }

      // cr_all_stars: completed the full road from Level 1 even though the
      // player had levels unlocked that they could have skipped.
      if (attempt.inheritedUnlockedLevel > 0 && attempt.startingLevel == 1) {
        extraBadges.add('cr_all_stars');
      }
    }

    if (extraBadges.isNotEmpty) {
      final freshSummary = await getUserSummary(userId);
      final earned = List<String>.from(freshSummary.badges);
      bool changed = false;
      for (final badgeId in extraBadges) {
        if (!earned.contains(badgeId)) {
          earned.add(badgeId);
          changed = true;
        }
      }
      if (changed) await updateUserSummary(userId, {'badges': earned});
    }

    return attempt.copyWith(
      currentLevel: newLevel,
      highestLevelReachedThisAttempt: newHighest,
    );
  }

  // ---------------------------------------------------------------------------
  // 6. 10K milestone handling
  // ---------------------------------------------------------------------------

  /// Adds [count] shots to both `challengerRoadShotCount` and
  /// `totalShotsThisAttempt`. If the rolling counter reaches or exceeds 10,000,
  /// it wraps around (resets to the remainder) and `resetCount` is incremented.
  ///
  /// Also updates [ChallengerRoadUserSummary.allTimeTotalChallengerRoadShots].
  Future<ChallengerRoadMilestoneResult> incrementChallengerRoadShots(String userId, String attemptId, int count) async {
    final attemptSnap = await _attemptsRef(userId).doc(attemptId).get();
    final attempt = ChallengerRoadAttempt.fromSnapshot(attemptSnap);

    final newRolling = attempt.challengerRoadShotCount + count;
    final newTotal = attempt.totalShotsThisAttempt + count;
    final didHit = newRolling >= 10000;
    final finalRolling = didHit ? newRolling - 10000 : newRolling;
    final newResetCount = attempt.resetCount + (didHit ? 1 : 0);

    await updateAttempt(userId, attemptId, {
      'challenger_road_shot_count': finalRolling,
      'total_shots_this_attempt': newTotal,
      'reset_count': newResetCount,
    });

    // Keep the all-time total in sync on the summary doc.
    final summary = await getUserSummary(userId);
    final newAllTimeTotal = summary.allTimeTotalChallengerRoadShots + count;
    await updateUserSummary(userId, {
      'all_time_total_challenger_road_shots': newAllTimeTotal,
    });

    if (didHit) {
      final updatedSummary = await getUserSummary(userId);
      await _checkAndAwardBadges(userId: userId, summary: updatedSummary);

      // Contextual milestone badges for reset counts.
      final freshSummary = await getUserSummary(userId);
      final earned = List<String>.from(freshSummary.badges);
      bool changed = false;
      void maybeAward(String id) {
        if (!earned.contains(id)) {
          earned.add(id);
          changed = true;
        }
      }

      // cr_and_again removed from catalog. cr_three_periods: 3 resets = 30,000 total.
      if (newResetCount >= 3) maybeAward('cr_three_periods');
      // cr_ferda: kept going after a 10k reset (will have more sessions after reset).
      maybeAward('cr_ferda');
      // cr_career_year: 10k milestone hit AND this attempt set a new all-time best level.
      if (attempt.highestLevelReachedThisAttempt > freshSummary.allTimeBestLevel) {
        maybeAward('cr_career_year');
      }
      if (changed) await updateUserSummary(userId, {'badges': earned});
    }

    return ChallengerRoadMilestoneResult(
      didHitMilestone: didHit,
      newCount: finalRolling,
      resetCount: newResetCount,
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Attempt restart
  // ---------------------------------------------------------------------------

  /// Restarts Challenger Road for a user.
  ///
  /// **Mid-attempt restart** (`resetCount == 0`, i.e. user has never hit the
  /// 10 000-shot milestone in the current attempt): the attempt is marked
  /// `cancelled` and a fresh attempt doc is created reusing the **same**
  /// `attemptNumber` — `totalAttempts` in the user summary is NOT incremented.
  ///
  /// **Post-completion restart** (`resetCount >= 1`): the attempt is marked
  /// `completed` and a genuinely new attempt is created with an incremented
  /// `attemptNumber` / `totalAttempts` (original behaviour).
  ///
  /// [chosenStartingLevel] lets the player pick where to begin on the new
  /// attempt (1 for the full grind, or their highest inherited-unlock level).
  Future<ChallengerRoadAttempt> restartChallengerRoad(
    String userId, {
    int? chosenStartingLevel,
  }) async {
    final active = await getActiveAttempt(userId);

    int inheritedUnlockedLevel = 0;
    if (active != null) {
      inheritedUnlockedLevel = max(0, active.highestLevelReachedThisAttempt - 1);

      final hasCompletedRoad = active.resetCount >= 1;
      await updateAttempt(userId, active.id!, {
        'status': hasCompletedRoad ? 'completed' : 'cancelled',
        'end_date': Timestamp.fromDate(DateTime.now()),
      });

      if (!hasCompletedRoad) {
        // Do-over: reuse the same attempt number, no inherited unlocks apply.
        final startingLevel = max(1, active.highestLevelReachedThisAttempt - 1);
        final attempt = ChallengerRoadAttempt(
          attemptNumber: active.attemptNumber,
          startingLevel: startingLevel,
          currentLevel: startingLevel,
          challengerRoadShotCount: 0,
          totalShotsThisAttempt: 0,
          resetCount: 0,
          highestLevelReachedThisAttempt: startingLevel,
          inheritedUnlockedLevel: 0,
          status: 'active',
          startDate: DateTime.now(),
        );
        final docRef = await _attemptsRef(userId).add(attempt.toMap());
        attempt.id = docRef.id;
        // Only update the pointer — do NOT touch total_attempts.
        await updateUserSummary(userId, {'current_attempt_id': docRef.id});
        return attempt;
      }
    }

    // Genuine new attempt (post-completion) — increment totalAttempts.
    final safeStartingLevel = inheritedUnlockedLevel > 0 && chosenStartingLevel != null ? chosenStartingLevel.clamp(1, inheritedUnlockedLevel + 1) : max(1, (active?.highestLevelReachedThisAttempt ?? 2) - 1);
    return createAttempt(userId, safeStartingLevel, inheritedUnlockedLevel: inheritedUnlockedLevel);
  }

  /// Called when the user taps "RUN IT BACK" after completing the full road.
  ///
  /// Marks the current attempt as `completed` and creates a genuine new attempt.
  /// [chosenStartingLevel] lets the player pick Level 1 (completionist path) or
  /// jump to the highest level they've unlocked via [inheritedUnlockedLevel].
  Future<ChallengerRoadAttempt> runItBack(String userId, {int chosenStartingLevel = 1}) async {
    final active = await getActiveAttempt(userId);
    int inheritedUnlockedLevel = 0;
    if (active != null) {
      inheritedUnlockedLevel = max(0, active.highestLevelReachedThisAttempt - 1);
      await updateAttempt(userId, active.id!, {
        'status': 'completed',
        'end_date': Timestamp.fromDate(DateTime.now()),
      });
    }
    // Clamp the chosen level to what is actually unlocked.
    final safeStartingLevel = inheritedUnlockedLevel > 0 ? chosenStartingLevel.clamp(1, inheritedUnlockedLevel + 1) : 1;
    return createAttempt(userId, safeStartingLevel, inheritedUnlockedLevel: inheritedUnlockedLevel);
  }

  // ---------------------------------------------------------------------------
  // 8. User summary
  // ---------------------------------------------------------------------------

  /// Returns the [ChallengerRoadUserSummary] for a user, creating an empty one
  /// if it does not yet exist.
  Future<ChallengerRoadUserSummary> getUserSummary(String userId) async {
    final snap = await _userSummaryRef(userId).get();
    if (!snap.exists) return ChallengerRoadUserSummary.empty();
    return ChallengerRoadUserSummary.fromSnapshot(snap);
  }

  /// Live stream of the user summary — use in profile widgets.
  Stream<ChallengerRoadUserSummary> watchUserSummary(String userId) {
    return _userSummaryRef(userId).snapshots().map((snap) {
      if (!snap.exists) return ChallengerRoadUserSummary.empty();
      return ChallengerRoadUserSummary.fromSnapshot(snap);
    });
  }

  /// Silently awards any badges the user has earned but doesn't yet have,
  /// based purely on their persisted stats (full session history scan).
  ///
  /// Safe to call at any time — fully idempotent. Already-earned badges are
  /// never re-awarded. This is useful after deploying new badge definitions: any
  /// user who already meets the criteria will receive the badge the next time
  /// this runs (e.g. when opening the Challenger Road map).
  ///
  /// Returns the IDs of badges newly added by this call (empty if nothing changed).
  Future<List<String>> awardMissingBadges(String userId) async {
    final summary = await getUserSummary(userId);
    return _checkAndAwardBadges(userId: userId, summary: summary);
  }

  /// Applies a partial update to the user summary document. If the document
  /// does not exist it will be created (merge: true behaviour via [SetOptions]).
  Future<void> updateUserSummary(String userId, Map<String, dynamic> data) async {
    await _userSummaryRef(userId).set(data, SetOptions(merge: true));
  }

  Map<String, dynamic> _buildBestAttemptSummaryUpdate({
    required ChallengerRoadUserSummary summary,
    required int completedLevel,
    required int totalShotsThisAttempt,
  }) {
    if (!_isBetterBestAttempt(
      summary: summary,
      completedLevel: completedLevel,
      totalShotsThisAttempt: totalShotsThisAttempt,
    )) {
      return const <String, dynamic>{};
    }

    return {
      'all_time_best_level': completedLevel,
      'all_time_best_level_shots': totalShotsThisAttempt,
    };
  }

  bool _isBetterBestAttempt({
    required ChallengerRoadUserSummary summary,
    required int completedLevel,
    required int totalShotsThisAttempt,
  }) {
    if (completedLevel <= 0) return false;
    if (completedLevel > summary.allTimeBestLevel) return true;
    if (completedLevel < summary.allTimeBestLevel) return false;

    final bestShots = summary.allTimeBestLevelShots;
    if (bestShots == null) return true;
    return totalShotsThisAttempt < bestShots;
  }

  // ---------------------------------------------------------------------------
  // Internal: batch helpers
  // ---------------------------------------------------------------------------

  /// Reads the existing [ChallengeProgressEntry] for [session.challengeId] (if
  /// any) and enqueues an upsert into [batch].
  Future<void> _buildChallengeProgressUpdate(
    String userId,
    String attemptId,
    ChallengeSession session, {
    required WriteBatch batch,
  }) async {
    final ref = _progressRef(userId, attemptId).doc(session.challengeId);
    final snap = await ref.get();

    final historyEntry = ChallengeLevelHistoryEntry(
      level: session.level,
      passed: session.passed,
      shotsMade: session.shotsMade,
      shotsRequired: session.shotsRequired,
      date: session.date,
    );

    if (!snap.exists) {
      final entry = ChallengeProgressEntry(
        challengeId: session.challengeId,
        bestLevel: session.passed ? session.level : 0,
        totalAttempts: 1,
        totalPassed: session.passed ? 1 : 0,
        firstPassedAt: session.passed ? session.date : null,
        lastAttemptAt: session.date,
        levelHistory: [historyEntry],
      );
      batch.set(ref, entry.toMap());
    } else {
      final existing = ChallengeProgressEntry.fromSnapshot(snap);
      final newBest = session.passed ? max(existing.bestLevel, session.level) : existing.bestLevel;
      final data = <String, dynamic>{
        'bestLevel': newBest,
        'totalAttempts': existing.totalAttempts + 1,
        'totalPassed': existing.totalPassed + (session.passed ? 1 : 0),
        'lastAttemptAt': Timestamp.fromDate(session.date),
        'levelHistory': [
          ...existing.levelHistory.map((e) => e.toMap()),
          historyEntry.toMap(),
        ],
      };
      if (session.passed && existing.firstPassedAt == null) {
        data['firstPassedAt'] = Timestamp.fromDate(session.date);
      }
      batch.update(ref, data);
    }
  }

  /// Reads the existing [ChallengeAllTimeHistory] for [session.challengeId]
  /// and enqueues an upsert into [batch].
  Future<void> _buildAllTimeHistoryUpdate(
    String userId,
    ChallengeSession session, {
    required WriteBatch batch,
  }) async {
    final ref = _allTimeHistoryRef(userId).doc(session.challengeId);
    final snap = await ref.get();

    if (!snap.exists) {
      final history = ChallengeAllTimeHistory(
        challengeId: session.challengeId,
        allTimeBestLevel: session.passed ? session.level : 0,
        allTimeTotalAttempts: 1,
        allTimeTotalPassed: session.passed ? 1 : 0,
        firstPassedAt: session.passed ? session.date : null,
        lastPassedAt: session.passed ? session.date : null,
      );
      batch.set(ref, history.toMap());
    } else {
      final existing = ChallengeAllTimeHistory.fromSnapshot(snap);
      final newBest = session.passed ? max(existing.allTimeBestLevel, session.level) : existing.allTimeBestLevel;
      final data = <String, dynamic>{
        'allTimeBestLevel': newBest,
        'allTimeTotalAttempts': existing.allTimeTotalAttempts + 1,
        'allTimeTotalPassed': existing.allTimeTotalPassed + (session.passed ? 1 : 0),
      };
      if (session.passed) {
        if (existing.firstPassedAt == null) {
          data['firstPassedAt'] = Timestamp.fromDate(session.date);
        }
        data['lastPassedAt'] = Timestamp.fromDate(session.date);
      }
      batch.update(ref, data);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal: badge helpers
  // ---------------------------------------------------------------------------

  /// Aggregates all Challenger Road data for [userId] into a single
  /// [_RoadBadgeStats] snapshot used by [_checkAndAwardBadges].
  ///
  /// Reading order (minimises Firestore round-trips):
  /// 1. Active level + challenge config from `challenger_road_levels`.
  /// 2. All attempt documents (ordered by `attempt_number`).
  /// 3. All session documents for each attempt (ordered by `date`).
  /// 4. All-time history documents (one per challenge, O(1) reads).
  ///
  /// This is the most expensive read path in the service.  It is called once
  /// per `_checkAndAwardBadges` invocation, which itself runs after every
  /// session save, level advance, and 10 000-shot milestone.
  Future<_RoadBadgeStats> _loadRoadBadgeStats(String userId) async {
    // ── 1. Active challenge config from Firestore ────────────────────────────
    final levelSnaps = await _levelsRef.where('active', isEqualTo: true).get();
    final activeChallengeIdsByLevel = <int, Set<String>>{};

    for (final levelDoc in levelSnaps.docs) {
      final level = ((levelDoc.data() as Map<String, dynamic>?)?['level'] as num?)?.toInt();
      if (level == null) continue;
      final challengeSnaps = await _challengesRef(levelDoc.id).where('active', isEqualTo: true).get();
      for (final cs in challengeSnaps.docs) {
        final c = ChallengerRoadChallenge.fromSnapshot(cs);
        if (c.id != null) {
          activeChallengeIdsByLevel.putIfAbsent(level, () => <String>{}).add(c.id!);
        }
      }
    }
    final highestActiveLevel = activeChallengeIdsByLevel.keys.isEmpty ? 0 : (activeChallengeIdsByLevel.keys.toList()..sort()).last;

    // ── 2. All attempts, ordered by attemptNumber ────────────────────────────
    final attemptsSnap = await _attemptsRef(userId).orderBy('attempt_number').get();
    final allAttempts = attemptsSnap.docs.map(ChallengerRoadAttempt.fromSnapshot).toList();

    // ── 3. Per-attempt aggregates ────────────────────────────────────────────
    // For each attempt, collect:
    //   • all sessions
    //   • which levels were fully cleared
    //   • per-challenge: was this the first session? was it passed?
    //   • pass streak
    //   • accuracy metrics

    int totalCrSessions = 0;
    int totalFailedSessions = 0;
    int totalPassedSessions = 0;
    double bestSingleSessionAccuracy = 0.0;
    int perfectSessions = 0;
    int longestPassStreak = 0;

    final levelsEverCleared = <int>{};
    Set<int> levelsCleared_latestAttempt = {};
    int latestAttemptNumber = 0;
    int latestAttemptStartingLevel = 1;
    int previousAttemptHighestLevel = 0;
    bool latestAttemptWasPerfect = false;
    final attemptNumbersWithNewBestLevel = <int>[];

    // Per-challenge cross-attempt data (populated from allTimeHistory docs).
    final allTimePassesByChallenge = <String, int>{};
    final allTimeSessionsByChallenge = <String, int>{};
    // bestAccuracyByChallenge: highest (shotsMade/totalShots) across all sessions.
    final bestAccuracyByChallenge = <String, double>{};

    // firstAttemptPassesByChallenge[challengeId] = list of attemptNumbers where
    // that challenge was passed on the very first session of that challenge in
    // that attempt (no prior session for that challenge in the same attempt).
    final firstAttemptPassesByChallenge = <String, List<int>>{};

    // For cross-attempt improvement badges we need per-challenge, per-attempt data.
    // sessionsByChallengByAttempt[challengeId][attemptNumber] = ordered list of sessions.
    final sessionsByChallengeByAttempt = <String, Map<int, List<ChallengeSession>>>{};

    int allTimeBestSeen = 0;
    int currentPassStreak = 0;

    // Fetch all per-attempt session docs in parallel to avoid N sequential round-trips.
    final allSessionSnaps = await Future.wait(
      allAttempts.map((a) => _sessionsRef(userId, a.id!).orderBy('date').get()),
    );

    for (int attemptIdx = 0; attemptIdx < allAttempts.length; attemptIdx++) {
      final attempt = allAttempts[attemptIdx];
      final attemptId = attempt.id!;
      final attemptNumber = attempt.attemptNumber;

      if (attemptNumber > latestAttemptNumber) {
        latestAttemptNumber = attemptNumber;
        latestAttemptStartingLevel = attempt.startingLevel;
      }

      // All sessions for this attempt, oldest first (pre-fetched in parallel above).
      final sessions = allSessionSnaps[attemptIdx].docs.map(ChallengeSession.fromSnapshot).toList();

      // Track first-session-per-challenge within this attempt.
      final seenChallengesThisAttempt = <String>{};
      bool attemptHadAnyFailure = false;

      for (final s in sessions) {
        totalCrSessions++;

        final acc = s.totalShots > 0 ? s.shotsMade / s.totalShots : 0.0;

        if (s.passed) {
          totalPassedSessions++;
          currentPassStreak++;
          if (currentPassStreak > longestPassStreak) longestPassStreak = currentPassStreak;
        } else {
          totalFailedSessions++;
          attemptHadAnyFailure = true;
          currentPassStreak = 0;
        }

        if (acc > bestSingleSessionAccuracy) bestSingleSessionAccuracy = acc;
        if (s.totalShots > 0 && s.shotsMade == s.totalShots) perfectSessions++;

        // Per-challenge accuracy tracking.
        final prev = bestAccuracyByChallenge[s.challengeId] ?? 0.0;
        if (acc > prev) bestAccuracyByChallenge[s.challengeId] = acc;

        // Bucket by challenge+attempt for cross-attempt analysis.
        sessionsByChallengeByAttempt.putIfAbsent(s.challengeId, () => {}).putIfAbsent(attemptNumber, () => []).add(s);

        // First-attempt pass tracking.
        if (!seenChallengesThisAttempt.contains(s.challengeId)) {
          seenChallengesThisAttempt.add(s.challengeId);
          if (s.passed) {
            firstAttemptPassesByChallenge.putIfAbsent(s.challengeId, () => []).add(attemptNumber);
          }
        }
      }

      // Determine which levels were fully cleared this attempt.
      final clearedThisAttempt = <int>{};
      for (final entry in activeChallengeIdsByLevel.entries) {
        final level = entry.key;
        final required = entry.value;
        // A level is cleared if every active challenge has at least one passed
        // session at that level in this attempt.
        final passedAtLevel = <String>{};
        for (final s in sessions) {
          if (s.passed && s.level == level) passedAtLevel.add(s.challengeId);
        }
        if (required.every((id) => passedAtLevel.contains(id))) {
          clearedThisAttempt.add(level);
        }
      }
      levelsEverCleared.addAll(clearedThisAttempt);

      // Track best-level progression for "The Comeback Kid" badge.
      if (attempt.highestLevelReachedThisAttempt > allTimeBestSeen) {
        allTimeBestSeen = attempt.highestLevelReachedThisAttempt;
        attemptNumbersWithNewBestLevel.add(attemptNumber);
      }

      // Record previous attempt details before overwriting.
      if (attemptNumber < latestAttemptNumber || allAttempts.last.id == attemptId) {
        // We'll set previousAttemptHighestLevel after the loop using attempt order.
      }

      if (attemptNumber == latestAttemptNumber) {
        levelsCleared_latestAttempt = clearedThisAttempt;
        latestAttemptWasPerfect = !attemptHadAnyFailure && sessions.isNotEmpty;
      }
    }

    // Determine previous attempt highest level (second-to-last attempt).
    if (allAttempts.length >= 2) {
      previousAttemptHighestLevel = allAttempts[allAttempts.length - 2].highestLevelReachedThisAttempt;
    }

    // ── 4. All-time history docs (O(1) per challenge) ──────────────────────
    final historySnap = await _allTimeHistoryRef(userId).get();
    for (final doc in historySnap.docs) {
      final h = ChallengeAllTimeHistory.fromSnapshot(doc);
      allTimePassesByChallenge[h.challengeId] = h.allTimeTotalPassed;
      allTimeSessionsByChallenge[h.challengeId] = h.allTimeTotalAttempts;
    }

    // ── 5. Derived cross-attempt metrics ──────────────────────────────────
    int challengesWithPerfectRecord = 0;
    String? mostFailedChallengeId;
    int mostFailedChallengeCount = 0;
    int challengesWithSalary = 0;
    int untouchableChallenges = 0;

    // Per-challenge: all-time failed session count.
    final failedSessionsByChallenge = <String, int>{};
    for (final entry in sessionsByChallengeByAttempt.entries) {
      final challengeId = entry.key;
      int failed = 0;
      for (final sessions in entry.value.values) {
        failed += sessions.where((s) => !s.passed).length;
      }
      failedSessionsByChallenge[challengeId] = failed;

      if (failed == 0) challengesWithPerfectRecord++;
      if (failed > mostFailedChallengeCount) {
        mostFailedChallengeCount = failed;
        mostFailedChallengeId = challengeId;
      }

      final passes = allTimePassesByChallenge[challengeId] ?? 0;
      if (passes >= 25) challengesWithSalary++;

      final firstPassAttempts = firstAttemptPassesByChallenge[challengeId] ?? [];
      if (firstPassAttempts.length >= 5) untouchableChallenges++;
    }

    // Scouting Report: challenges passed first-try in attempt N but that
    // required > 1 try in attempt N-1.
    int scoutingReportCount = 0;
    int rematches = 0;
    bool dialedInAchieved = false;

    for (final entry in sessionsByChallengeByAttempt.entries) {
      final byAttempt = entry.value;
      final attemptNums = byAttempt.keys.toList()..sort();

      for (int i = 0; i < attemptNums.length; i++) {
        final aN = attemptNums[i];
        final sessions = byAttempt[aN]!;
        final passedThisAttempt = sessions.any((s) => s.passed);

        if (i > 0) {
          final prevSessions = byAttempt[attemptNums[i - 1]]!;
          final prevPassed = prevSessions.any((s) => s.passed);
          final prevSessionCount = prevSessions.length;
          final firstThisAttempt = sessions.first.passed;

          // Scouting Report: first try here, needed multiple last time.
          if (firstThisAttempt && prevSessionCount > 1) scoutingReportCount++;

          // The Rematch: not passed in prev attempt, passed in this one.
          if (!prevPassed && passedThisAttempt) rematches++;
        }
      }
    }

    // Dialed In: current personal best accuracy on the most-failed challenge
    // was achieved in the most recent attempt.
    if (mostFailedChallengeId != null && latestAttemptNumber > 0) {
      final bestAcc = bestAccuracyByChallenge[mostFailedChallengeId] ?? 0.0;
      final latestAttempt = allAttempts.last;
      final latestSess = await _sessionsRef(userId, latestAttempt.id!).where('challenge_id', isEqualTo: mostFailedChallengeId).get();
      final latestAccMax = latestSess.docs.map(ChallengeSession.fromSnapshot).map((s) => s.totalShots > 0 ? s.shotsMade / s.totalShots : 0.0).fold(0.0, (a, b) => a > b ? a : b);
      dialedInAchieved = latestAccMax >= bestAcc && bestAcc > 0.0;
    }

    return _RoadBadgeStats(
      activeChallengeIdsByLevel: activeChallengeIdsByLevel,
      highestActiveLevel: highestActiveLevel,
      totalCrSessions: totalCrSessions,
      totalFailedSessions: totalFailedSessions,
      totalPassedSessions: totalPassedSessions,
      bestSingleSessionAccuracy: bestSingleSessionAccuracy,
      perfectSessions: perfectSessions,
      longestPassStreak: longestPassStreak,
      levelsEverCleared: levelsEverCleared,
      levelsCleared_latestAttempt: levelsCleared_latestAttempt,
      latestAttemptNumber: latestAttemptNumber,
      latestAttemptStartingLevel: latestAttemptStartingLevel,
      previousAttemptHighestLevel: previousAttemptHighestLevel,
      latestAttemptWasPerfect: latestAttemptWasPerfect,
      attemptNumbersWithNewBestLevel: attemptNumbersWithNewBestLevel,
      firstAttemptPassesByChallenge: firstAttemptPassesByChallenge,
      allTimePassesByChallenge: allTimePassesByChallenge,
      allTimeSessionsByChallenge: allTimeSessionsByChallenge,
      bestAccuracyByChallenge: bestAccuracyByChallenge,
      challengesWithPerfectRecord: challengesWithPerfectRecord,
      mostFailedChallengeId: mostFailedChallengeId,
      mostFailedChallengeCount: mostFailedChallengeCount,
      challengesWithSalary: challengesWithSalary,
      untouchableChallenges: untouchableChallenges,
      scoutingReportCount: scoutingReportCount,
      rematches: rematches,
      dialedInAchieved: dialedInAchieved,
    );
  }

  /// Returns true if every active challenge at [level] was completed on the
  /// first try within [attemptId] — i.e., there is exactly one
  /// [ChallengeLevelHistoryEntry] at this level in each progress entry.
  Future<bool> _isLevelPerfect(String userId, String attemptId, int level) async {
    try {
      final challenges = await getChallengesForLevel(level);
      if (challenges.isEmpty) return false;

      for (final challenge in challenges) {
        final challengeId = challenge.id;
        if (challengeId == null) continue;

        final progressSnap = await _progressRef(userId, attemptId).doc(challengeId).get();
        if (!progressSnap.exists) return false;
        final entry = ChallengeProgressEntry.fromSnapshot(progressSnap);
        final attemptsAtLevel = entry.levelHistory.where((h) => h.level == level).length;
        if (attemptsAtLevel != 1) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks all **stat-based** badge conditions and persists any newly earned
  /// badges to the user's summary document.
  ///
  /// Idempotent — will not re-award a badge already in the `badges` list.
  /// Also prunes any badge IDs that no longer exist in [badgeCatalog],
  /// ensuring removed badges are silently cleaned up without extra tooling.
  ///
  /// **Award paths** — badges are awarded from one of four call sites:
  ///
  /// | Call site                         | Badges awarded there |
  /// |-----------------------------------|----------------------|
  /// | `_checkAndAwardBadges` (here)     | All stat-derivable badges: shot milestones, level clears, session counts, streak lengths, cross-attempt improvement counters, etc. |
  /// | `_checkContextualSessionBadges`   | Badges that need the live `ChallengeSession` object: `cr_lights_out`, `cr_battle_tested`, `cr_game_7`, `cr_ghosts_in_the_machine`, `cr_old_grudge`, `cr_redemption_arc`, `cr_pigeon`, `cr_sauce_boss`, `cr_full_send`. |
  /// | `advanceLevel`                    | Level-completion badges: `cr_the_climb`, `cr_third_period_heart`, `cr_no_warmup_needed`, `cr_breakaway`, `cr_clean_sweep`, `cr_freight_train`, `cr_the_sniper`, `cr_hall_of_famer`, `cr_hockey_god`, `cr_the_machine`, `cr_all_stars`. |
  /// | `incrementChallengerRoadShots`    | 10k-milestone badges: `cr_three_periods`, `cr_ferda`, `cr_career_year`. |
  /// | `createAttempt`                   | Per-attempt badges: `cr_skip_the_tryout`. |
  ///
  /// Returns the IDs of badges newly awarded by this call.
  Future<List<String>> _checkAndAwardBadges({
    required String userId,
    required ChallengerRoadUserSummary summary,
    _RoadBadgeStats? precomputedStats,
  }) async {
    // Prune any badge IDs no longer present in the current catalog — removes
    // legacy badges earned before a catalog reduction without any extra tooling.
    final catalogIds = badgeCatalog.map((b) => b.id).toSet();
    final earned = summary.badges.where((id) => catalogIds.contains(id)).toList();
    final hadLegacyBadges = earned.length != summary.badges.length;

    final newIds = <String>[];
    final stats = precomputedStats ?? await _loadRoadBadgeStats(userId);

    void maybeAward(String badgeId) {
      if (!earned.contains(badgeId)) {
        earned.add(badgeId);
        newIds.add(badgeId);
      }
    }

    final t = summary.totalAttempts;
    final shots = summary.allTimeTotalChallengerRoadShots;

    // ── FIRST STEPS ──────────────────────────────────────────────────────────
    if (t >= 1) maybeAward('cr_fresh_laces');
    if (stats.totalCrSessions >= 1) maybeAward('cr_drop_the_biscuit');
    if (stats.totalPassedSessions >= 1) maybeAward('cr_clean_read');
    if (stats.levelsEverCleared.contains(1)) maybeAward('cr_level_clear');
    // cr_called_up (Level 2) and cr_the_tape_is_on removed from catalog.
    if (stats.levelsEverCleared.contains(3)) maybeAward('cr_made_the_show');

    // ── WITHIN-RUN EFFICIENCY ─────────────────────────────────────────────────
    // cr_no_warmup_needed: any level completed with 0 failed sessions — computed
    // contextually in advanceLevel; mark here if already earned via stats proxy.
    // (The flag is set by advanceLevel; _checkAndAwardBadges won't re-compute it.)

    // cr_sharp: 4 consecutive passes (longestPassStreak).
    if (stats.longestPassStreak >= 4) maybeAward('cr_sharp');

    // cr_greasy_but_goes_in: passed at exact shotsToPass — awarded contextually
    // in saveChallengeSession; check stats can't easily re-derive it, so we
    // rely on the contextual path. Skip here.

    // cr_breakaway: awarded contextually in advanceLevel.

    // cr_freight_train: two consecutive levels with 0 failures — awarded contextually.

    // cr_clean_sweep: first-attempt pass on every challenge in a level — awarded contextually.

    // cr_barnburner_run: level cleared with 0 failures and 80%+ avg accuracy — contextually.

    // ── CROSS-ATTEMPT IMPROVEMENT ─────────────────────────────────────────────
    if (stats.scoutingReportCount >= 1) maybeAward('cr_scouting_report');
    if (stats.rematches >= 1) maybeAward('cr_the_rematch');
    // cr_better_than_before, cr_dug_deep, cr_second_nature, cr_chip_on_your_shoulder removed.
    if (stats.dialedInAchieved) maybeAward('cr_dialed_in');

    // cr_comeback_season: latest attempt's highest level > previous attempt's highest.
    if (stats.latestAttemptNumber >= 2 && summary.allTimeBestLevel > stats.previousAttemptHighestLevel) {
      maybeAward('cr_comeback_season');
    }

    // cr_redemption_arc: awarded contextually in saveChallengeSession.

    // cr_the_comeback_kid: new best level achieved in 3+ separate attempts.
    if (stats.attemptNumbersWithNewBestLevel.length >= 3) {
      maybeAward('cr_the_comeback_kid');
    }

    // ── GRIND & RESILIENCE ────────────────────────────────────────────────────
    // cr_battle_tested, cr_game_7, cr_ghosts_in_the_machine, cr_old_grudge —
    // all awarded contextually in saveChallengeSession.
    // cr_third_period_heart — awarded contextually in advanceLevel.
    // cr_short_handed, cr_didnt_quit, cr_takes_a_licking — removed from catalog.

    // ── LEVEL ADVANCEMENT ─────────────────────────────────────────────────────
    if (stats.levelsEverCleared.contains(5)) maybeAward('cr_ice_time_earned');
    if (stats.levelsEverCleared.contains(10)) maybeAward('cr_team_captain');
    // cr_paying_your_dues, cr_franchise_player, cr_reclaiming_the_ice — removed.

    // cr_the_climb: awarded contextually in advanceLevel when new all-time best hit.

    // cr_playoff_mode: reached the max available level.
    if (stats.highestActiveLevel > 0 && summary.allTimeBestLevel >= stats.highestActiveLevel) {
      maybeAward('cr_playoff_mode');
    }

    // cr_the_general: all challenges at max level cleared.
    if (stats.highestActiveLevel > 0) {
      final activeAtMax = stats.activeChallengeIdsByLevel[stats.highestActiveLevel] ?? {};
      if (activeAtMax.isNotEmpty && stats.levelsEverCleared.contains(stats.highestActiveLevel)) {
        maybeAward('cr_the_general');
      }
    }

    // ── CR SHOT MILESTONES ────────────────────────────────────────────────────
    if (shots >= 100) maybeAward('cr_first_bucket');
    if (shots >= 1000) maybeAward('cr_building_a_barn');
    // cr_filling_the_net removed (2,500 — too granular).
    if (shots >= 5000) maybeAward('cr_ten_minute_major');
    if (shots >= 10000) maybeAward('cr_buzzer_beater');
    // cr_and_again removed; cr_three_periods awarded contextually via incrementChallengerRoadShots.
    if (shots >= 25000) maybeAward('cr_well_never_runs_dry');
    // cr_tape_burner removed (50,000 — extremely hard to achieve).

    // ── CR SESSION ACCURACY ───────────────────────────────────────────────────
    // cr_lights_out: awarded contextually in saveChallengeSession (new PB).
    if (stats.bestSingleSessionAccuracy >= 0.90) maybeAward('cr_bar_down');
    if (stats.bestSingleSessionAccuracy >= 0.95) maybeAward('cr_top_cheese');
    if (stats.perfectSessions >= 1) maybeAward('cr_pure');
    // cr_snipe_artist, cr_dead_aim, cr_millimetre, cr_pinpoint — removed.
    // cr_the_sniper — awarded contextually in advanceLevel.
    if (stats.perfectSessions >= 5) maybeAward('cr_all_net');

    // ── HOT STREAKS ───────────────────────────────────────────────────────────
    // cr_on_a_heater removed (3 passes — too close to cr_sauce at 5 passes).
    if (stats.longestPassStreak >= 5) maybeAward('cr_sauce');
    if (stats.longestPassStreak >= 10) maybeAward('cr_unstoppable');
    // cr_full_send — awarded contextually in saveChallengeSession.

    // ── CHALLENGE MASTERY ─────────────────────────────────────────────────────
    if (stats.challengesWithPerfectRecord >= 5) maybeAward('cr_never_missed');
    // cr_consistent removed (overlaps with cr_untouchable).
    if (stats.untouchableChallenges >= 1) maybeAward('cr_untouchable');
    if (stats.challengesWithSalary >= 1) maybeAward('cr_earned_a_salary');
    // cr_the_regular removed (overlaps with cr_earned_a_salary).

    // ── MULTI-ATTEMPT / CAREER ────────────────────────────────────────────────
    if (t >= 2) maybeAward('cr_veteran_presence');
    // cr_double_shift, cr_this_is_what_i_do removed (too granular).
    if (t >= 5) maybeAward('cr_lifer');
    // cr_career_year: awarded contextually when 10k milestone and new best happen in same attempt.
    // cr_the_long_road removed (overlaps with cr_road_dog).
    if (stats.totalCrSessions >= 250) maybeAward('cr_road_dog');
    if (stats.totalPassedSessions >= 100) maybeAward('cr_all_time_great');

    // ── ELITE / ENDGAME ───────────────────────────────────────────────────────
    // cr_hall_of_famer — awarded contextually in advanceLevel.
    // cr_hockey_god — awarded contextually in advanceLevel.
    // cr_the_machine — awarded contextually after attempt completes.
    // cr_the_road_ends_here, cr_sniper_mentality — removed from catalog.
    // cr_all_stars — awarded contextually in advanceLevel (full road from level 1 with unlocks).

    // ── CHIRPY ────────────────────────────────────────────────────────────────
    if (stats.latestAttemptNumber >= 2 && stats.latestAttemptStartingLevel < stats.previousAttemptHighestLevel) {
      maybeAward('cr_bender');
    }

    // cr_pigeon: first-try 95%+ on a hard challenge — contextually.
    // cr_ferda, cr_sauce_boss — contextually.
    // cr_old_habits, cr_just_visiting — removed from catalog.
    // cr_skip_the_tryout: awarded in createAttempt when startingLevel > 1 with inherited unlocks.

    // Persist earned badges if changed (new awards OR legacy badges pruned).
    if (newIds.isNotEmpty || hadLegacyBadges) {
      await updateUserSummary(userId, {'badges': earned});
    }
    return newIds;
  }
}

class _RoadBadgeStats {
  // ── Active challenge map (from Firestore config) ──────────────────────────
  /// All active challenge IDs grouped by level number.
  final Map<int, Set<String>> activeChallengeIdsByLevel;

  /// Highest level number that has at least one active challenge.
  final int highestActiveLevel;

  // ── Session counts ─────────────────────────────────────────────────────────
  /// Total CR challenge sessions across all attempts.
  final int totalCrSessions;

  /// Total failed CR challenge sessions across all attempts.
  final int totalFailedSessions;

  /// Total passed CR challenge sessions across all attempts.
  final int totalPassedSessions;

  // ── Accuracy tracking ──────────────────────────────────────────────────────
  /// Best accuracy ratio (shotsMade/totalShots) seen in any single CR session.
  final double bestSingleSessionAccuracy;

  /// Number of CR sessions with 100% accuracy.
  final int perfectSessions;

  // ── Pass-streak tracking ───────────────────────────────────────────────────
  /// Longest consecutive-pass streak (no failures between) across all attempts.
  final int longestPassStreak;

  // ── Level completion (cross-attempt) ──────────────────────────────────────
  /// Set of level numbers fully cleared (all challenges passed) in ANY attempt.
  final Set<int> levelsEverCleared;

  /// Levels fully cleared in the most recent completed/active attempt.
  final Set<int> levelsCleared_latestAttempt;

  /// The attempt number of the most recent attempt (1-based). 0 if no attempts.
  final int latestAttemptNumber;

  /// The starting level of the most recent attempt.
  final int latestAttemptStartingLevel;

  /// Highest level reached in the attempt before the most recent one (0 if only one attempt).
  final int previousAttemptHighestLevel;

  /// Whether the most recent completed attempt included zero failed sessions total.
  final bool latestAttemptWasPerfect;

  /// Attempt numbers in which a new allTimeBestLevel was achieved (in order).
  final List<int> attemptNumbersWithNewBestLevel;

  // ── Challenge-level history (cross-attempt) ────────────────────────────────
  /// For each challengeId: the attempt numbers in which challenge was passed
  /// on the very first session of that attempt at that challenge.
  /// Key = challengeId.
  final Map<String, List<int>> firstAttemptPassesByChallenge;

  /// For each challengeId: total all-time passed sessions.
  final Map<String, int> allTimePassesByChallenge;

  /// For each challengeId: total all-time sessions (passed + failed).
  final Map<String, int> allTimeSessionsByChallenge;

  /// Best accuracy (shotsMade/totalShots) ever recorded for each challengeId.
  final Map<String, double> bestAccuracyByChallenge;

  /// Number of challenges that have zero all-time failed sessions.
  final int challengesWithPerfectRecord;

  /// ID of the challenge with the most all-time failed sessions (null if none failed).
  final String? mostFailedChallengeId;

  /// Highest all-time failed-session count on any single challenge.
  final int mostFailedChallengeCount;

  /// Number of challenges where allTimeTotalPassed >= 25.
  final int challengesWithSalary;

  /// Number of challenges where first-attempt pass happened in >= 5 separate attempts.
  final int untouchableChallenges;

  // ── Cross-attempt improvement ──────────────────────────────────────────────
  /// Number of challenges that were passed on first attempt in a newer run but
  /// required multiple attempts in the immediately preceding run.
  final int scoutingReportCount;

  /// Number of challenges that were not passed in a previous attempt but were
  /// passed (in any session) in a later attempt.
  final int rematches;

  /// True when: the all-time best accuracy on the most-failed challenge was set
  /// in the most recent attempt.
  final bool dialedInAchieved;

  const _RoadBadgeStats({
    required this.activeChallengeIdsByLevel,
    required this.highestActiveLevel,
    required this.totalCrSessions,
    required this.totalFailedSessions,
    required this.totalPassedSessions,
    required this.bestSingleSessionAccuracy,
    required this.perfectSessions,
    required this.longestPassStreak,
    required this.levelsEverCleared,
    required this.levelsCleared_latestAttempt,
    required this.latestAttemptNumber,
    required this.latestAttemptStartingLevel,
    required this.previousAttemptHighestLevel,
    required this.latestAttemptWasPerfect,
    required this.attemptNumbersWithNewBestLevel,
    required this.firstAttemptPassesByChallenge,
    required this.allTimePassesByChallenge,
    required this.allTimeSessionsByChallenge,
    required this.bestAccuracyByChallenge,
    required this.challengesWithPerfectRecord,
    required this.mostFailedChallengeId,
    required this.mostFailedChallengeCount,
    required this.challengesWithSalary,
    required this.untouchableChallenges,
    required this.scoutingReportCount,
    required this.rematches,
    required this.dialedInAchieved,
  });
}
