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

enum ChallengerRoadBadgeTier { common, uncommon, rare, epic, legendary, hidden }

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

class ChallengerRoadBadgeDefinition {
  final String id;
  final String name;
  final String description;
  final ChallengerRoadBadgeCategory category;
  final ChallengerRoadBadgeTier tier;

  const ChallengerRoadBadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
  });
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
      description: 'Geared up and stepped onto the Road. The real work starts here.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_drop_the_biscuit',
      name: 'Drop the Biscuit',
      description: 'First rep on the Road in the books. Now let\'s see what you\'ve got.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_clean_read',
      name: 'Clean Read',
      description: 'Passed your first challenge. You belong on this Road.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_level_clear',
      name: 'Level Clear',
      description: 'Level 1 done. You\'re past the tryout.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_called_up',
      name: 'Called Up',
      description: 'Level 2. You earned the promotion.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_made_the_show',
      name: 'Made the Show',
      description: 'Level 3. Not a warmup anymore.',
      category: ChallengerRoadBadgeCategory.firstSteps,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_tape_is_on',
      name: 'The Tape Is On',
      description: 'Started your second attempt. The Road doesn\'t care what happened last time.',
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
      description: 'Four straight challenge passes with zero failures between them.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_greasy_but_goes_in',
      name: 'Greasy But Goes In',
      description: 'Passed a challenge at exactly the minimum shots-to-pass threshold.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_breakaway',
      name: 'Breakaway',
      description: 'Cleared every challenge in a level in a single calendar day.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_freight_train',
      name: 'Freight Train',
      description: 'Two consecutive levels cleared without a single failed session in either.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_clean_sweep',
      name: 'Clean Sweep',
      description: 'First-attempt pass on every challenge in a full level. Nothing got through.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_barnburner_run',
      name: 'Barnburner Run',
      description: 'Flew through a full level — zero failures and 80%+ average accuracy.',
      category: ChallengerRoadBadgeCategory.withinRunEfficiency,
      tier: ChallengerRoadBadgeTier.epic,
    ),

    // ── CROSS-ATTEMPT IMPROVEMENT ─────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_scouting_report',
      name: 'Scouting Report',
      description: 'Passed a challenge first try in a new attempt that took multiple tries last run.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_rematch',
      name: 'The Rematch',
      description: 'Passed a challenge in a new attempt that you failed to pass in your previous attempt.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_better_than_before',
      name: 'Better Than Before',
      description: 'Hit a new personal best accuracy on a specific challenge. Growth.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_dug_deep',
      name: 'Dug Deep',
      description: 'Cleared a level in a new attempt that you failed to finish in a prior attempt.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_second_nature',
      name: 'Second Nature',
      description: 'Five challenges in a single level — all first-try — that you previously failed at least once.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_dialed_in',
      name: 'Dialed In',
      description: 'Personal best accuracy on your own most-failed challenge. You cracked it.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_chip_on_your_shoulder',
      name: 'Chip on Your Shoulder',
      description: 'Started at a lower level than last time. Climbed higher than ever. Say less.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_comeback_season',
      name: 'Comeback Season',
      description: 'Beat your best level from the previous attempt. The restart wasn\'t a setback.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_redemption_arc',
      name: 'Redemption Arc',
      description: 'First-attempt pass in a new run on a challenge you failed 5+ times previously.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_comeback_kid',
      name: 'The Comeback Kid',
      description: 'Three separate attempts, three separate personal best levels. Keeps getting better.',
      category: ChallengerRoadBadgeCategory.crossAttemptImprovement,
      tier: ChallengerRoadBadgeTier.hidden,
    ),

    // ── GRIND & RESILIENCE ────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_short_handed',
      name: 'Short-Handed',
      description: 'Down after 3+ consecutive failures on the same challenge — came back with the pass.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_battle_tested',
      name: 'Battle Tested',
      description: 'Five straight failures on the same challenge in one attempt, then you broke through.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_game_7',
      name: 'Game 7',
      description: 'The challenge you\'ve failed the most all-time — you finally got it.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_ghosts_in_the_machine',
      name: 'Ghosts in the Machine',
      description: '10+ all-time failures on the same challenge. Stared it down anyway and passed.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_third_period_heart',
      name: 'Third Period Heart',
      description: 'Deep in a level, absorbed 10+ failed sessions across its challenges, still found a way out.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_old_grudge',
      name: 'Old Grudge',
      description: 'Failed this challenge in two separate attempts without passing it. Closed it out in a third.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_didnt_quit',
      name: 'Didn\'t Quit',
      description: 'Failed a challenge and passed it in your very next session.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_takes_a_licking',
      name: 'Takes a Licking',
      description: '50 total failed CR sessions across your whole history. Still competing.',
      category: ChallengerRoadBadgeCategory.grindAndResilience,
      tier: ChallengerRoadBadgeTier.rare,
    ),

    // ── LEVEL ADVANCEMENT ─────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_paying_your_dues',
      name: 'Paying Your Dues',
      description: 'Level 3 complete. Running real shifts now.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_ice_time_earned',
      name: 'Ice Time Earned',
      description: 'Level 5. Every level past here is bonus territory for most players.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_franchise_player',
      name: 'Franchise Player',
      description: 'Level 7 down. You carry this Road.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_team_captain',
      name: 'Team Captain',
      description: 'Level 10. No one earns the C without this kind of work.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_climb',
      name: 'The Climb',
      description: 'Reached a new personal best level. Your ceiling just moved.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_reclaiming_the_ice',
      name: 'Reclaiming the Ice',
      description: 'Cleared a level in a new attempt that you\'d already beaten before. Muscle memory.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_playoff_mode',
      name: 'Playoff Mode',
      description: 'Reached the highest available level on the Road. The cup run starts now.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_general',
      name: 'The General',
      description: 'Every challenge, every level. Commander status.',
      category: ChallengerRoadBadgeCategory.levelAdvancement,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── CR SHOT MILESTONES ────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_first_bucket',
      name: 'First Bucket',
      description: '100 Challenger Road shots. The counter is moving.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_building_a_barn',
      name: 'Building a Barn',
      description: '1,000 shots on the Road. Foundation is poured.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_filling_the_net',
      name: 'Filling the Net',
      description: '2,500 shots deep into the Road. You\'ve put in serious work.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_ten_minute_major',
      name: 'Ten-Minute Major',
      description: '5,000 Challenger Road shots. A major-penalty\'s worth of effort.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_buzzer_beater',
      name: 'Buzzer Beater',
      description: '10,000 Challenger Road shots. You heard the horn and it was earned.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_and_again',
      name: 'And Again',
      description: 'Hit the 10k Challenger Road milestone twice in a single attempt. Counter reset. You didn\'t.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_three_periods',
      name: 'Three Periods',
      description: 'Three 10k resets in one attempt. The clock just keeps running.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_well_never_runs_dry',
      name: 'The Well Never Runs Dry',
      description: '25,000 cumulative Challenger Road shots. Across everything. That\'s a career.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_tape_burner',
      name: 'Tape Burner',
      description: '50,000 Challenger Road shots. Nobody else is working like this.',
      category: ChallengerRoadBadgeCategory.crShotMilestones,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── CR SESSION ACCURACY ───────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_lights_out',
      name: 'Lights Out',
      description: 'New personal best accuracy in a CR session. Everything found the mark.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_bar_down',
      name: 'Bar Down',
      description: '90%+ accuracy in a single CR challenge session. Top of the cage.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_top_cheese',
      name: 'Top Cheese',
      description: '95%+ accuracy in a single CR session. You\'re not missing anything right now.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_pure',
      name: 'Pure',
      description: '100% accuracy in a CR session. Every shot, every mark.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_snipe_artist',
      name: 'Snipe Artist',
      description: 'Three consecutive CR sessions above 85% accuracy. Dialled right in.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_dead_aim',
      name: 'Dead Aim',
      description: '80%+ average accuracy across every session in a completed level.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_sniper',
      name: 'The Sniper',
      description: '85%+ average accuracy across a fully completed level. That\'s a different shooter.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_millimetre',
      name: 'Millimetre',
      description: '10 CR sessions at 90%+ accuracy across your entire history.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_all_net',
      name: 'All Net',
      description: 'Five perfect 100% accuracy sessions on the Road.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_pinpoint',
      name: 'Pinpoint',
      description: '85%+ average CR session accuracy across an entire attempt, start to finish.',
      category: ChallengerRoadBadgeCategory.crSessionAccuracy,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── HOT STREAKS ───────────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_on_a_heater',
      name: 'On a Heater',
      description: 'Three consecutive passed CR sessions with zero failures between them.',
      category: ChallengerRoadBadgeCategory.hotStreaks,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_sauce',
      name: 'Sauce',
      description: 'Five passed CR sessions in a row. No failures. You\'re cooking right now.',
      category: ChallengerRoadBadgeCategory.hotStreaks,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_unstoppable',
      name: 'Unstoppable',
      description: 'Ten straight CR sessions passed. That kind of run is impossible to ignore.',
      category: ChallengerRoadBadgeCategory.hotStreaks,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_full_send',
      name: 'Full Send',
      description: 'Your highest-volume CR session AND best accuracy in the same session. Total output.',
      category: ChallengerRoadBadgeCategory.hotStreaks,
      tier: ChallengerRoadBadgeTier.epic,
    ),

    // ── CHALLENGE MASTERY ─────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_never_missed',
      name: 'Never Missed',
      description: 'Five or more challenges on this Road you have never once failed. Clean record.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_consistent',
      name: 'Consistent',
      description: 'The same challenge, passed first attempt in three or more separate attempts.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_untouchable',
      name: 'Untouchable',
      description: 'One challenge, first-attempt pass, five or more separate attempts. You own it.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_earned_a_salary',
      name: 'Earned a Salary',
      description: '25 all-time passed sessions on a single challenge. You own that drill.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_regular',
      name: 'The Regular',
      description: '15+ all-time sessions attempted on a single challenge across all runs.',
      category: ChallengerRoadBadgeCategory.challengeMastery,
      tier: ChallengerRoadBadgeTier.rare,
    ),

    // ── MULTI-ATTEMPT / CAREER ────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_veteran_presence',
      name: 'Veteran Presence',
      description: 'Second attempt. More dangerous for knowing what\'s coming.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_double_shift',
      name: 'Double Shift',
      description: 'Third attempt. The Road keeps calling.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_this_is_what_i_do',
      name: 'This Is What I Do',
      description: 'Fourth attempt. Not novelty — this is just your thing.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_lifer',
      name: 'Lifer',
      description: 'Five attempts on this Road. The Road is in your DNA.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_career_year',
      name: 'Career Year',
      description: 'Hit 10k CR shots AND reached a new personal best level in the same attempt.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_long_road',
      name: 'The Long Road',
      description: '100 total CR challenge sessions across your whole history.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.rare,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_road_dog',
      name: 'Road Dog',
      description: '250 total CR sessions. The map is tattooed on your brain.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.epic,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_all_time_great',
      name: 'All-Time Great',
      description: '100 total challenge passes across your Challenger Road career.',
      category: ChallengerRoadBadgeCategory.multiAttemptCareer,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── ELITE / ENDGAME ───────────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_hall_of_famer',
      name: 'Hall of Famer',
      description: 'Full Road completed in a single attempt. Top to bottom. Clean.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_machine',
      name: 'The Machine',
      description: '80%+ average CR session accuracy across three complete attempts. Genuinely inhuman.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_sniper_mentality',
      name: 'Sniper Mentality',
      description: 'Passed every unique CR challenge at 85%+ at least once across your history.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.legendary,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_hockey_god',
      name: 'Hockey God',
      description: 'A full CR attempt with zero failed sessions. A perfect record nobody else has.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.hidden,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_the_road_ends_here',
      name: 'The Road Ends Here',
      description: 'Completed the full Challenger Road in a second or later attempt.',
      category: ChallengerRoadBadgeCategory.eliteEndgame,
      tier: ChallengerRoadBadgeTier.legendary,
    ),

    // ── CHIRPY / PERSONALITY ──────────────────────────────────────────────────
    ChallengerRoadBadgeDefinition(
      id: 'cr_bender',
      name: 'Bender',
      description: 'Started a new attempt at a lower level than your previous best. Humility is underrated.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_pigeon',
      name: 'Pigeon',
      description: 'Passed a hard challenge first try at 95%+. Natural talent or beginner\'s luck?',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_old_habits',
      name: 'Old Habits',
      description: 'Failed the same challenge across two separate attempts without ever passing it.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_just_visiting',
      name: 'Just Visiting',
      description: 'Three attempts on the Road. No level cleared in any of them. Respect for the stubbornness.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.common,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_ferda',
      name: 'Ferda',
      description: 'Hit 10k on the Road and kept right on going. Reset the counter, not the effort.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.uncommon,
    ),
    ChallengerRoadBadgeDefinition(
      id: 'cr_sauce_boss',
      name: 'Sauce Boss',
      description: 'Personal best accuracy session on a hard CR challenge. Pure show-off territory.',
      category: ChallengerRoadBadgeCategory.chirpy,
      tier: ChallengerRoadBadgeTier.rare,
    ),
  ];

  /// Returns the full badge catalog. Identical for every user — the catalog is
  /// static and does not depend on Firestore configuration.
  Future<List<ChallengerRoadBadgeDefinition>> getBadgeCatalog() async => badgeCatalog;

  /// Returns the profile badge catalog for a user. Delegates to [getBadgeCatalog].
  Future<List<ChallengerRoadBadgeDefinition>> getBadgeCatalogForUser(String userId) => getBadgeCatalog();

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
  Future<ChallengerRoadAttempt> createAttempt(String userId, int startingLevel) async {
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
      status: 'active',
      startDate: DateTime.now(),
    );

    final docRef = await _attemptsRef(userId).add(attempt.toMap());
    attempt.id = docRef.id;

    await updateUserSummary(userId, {
      'current_attempt_id': docRef.id,
      'total_attempts': attemptNumber,
    });

    await _checkAndAwardBadges(
      userId: userId,
      summary: summary.copyWith(
        currentAttemptId: docRef.id,
        totalAttempts: attemptNumber,
      ),
    );

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

    // Badge checks (outside the batch — read-then-write pattern).
    final summary = await getUserSummary(userId);
    final newStatsBadges = await _checkAndAwardBadges(userId: userId, summary: summary);

    // Re-read summary so contextual check sees stats badges already persisted.
    final summaryAfterStats = await getUserSummary(userId);
    final newContextualBadges = await _checkContextualSessionBadges(
      userId: userId,
      attemptId: attemptId,
      session: session,
      summary: summaryAfterStats,
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

    // cr_greasy_but_goes_in: passed at exactly shotsToPass.
    if (session.passed && session.shotsMade == session.shotsToPass) {
      maybeAward('cr_greasy_but_goes_in');
    }

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
      maybeAward('cr_better_than_before');
    }

    // cr_didnt_quit: failed challenge passed in immediate next session.
    // Check if the prior session for this challenge in this attempt was a failure.
    final priorInAttempt = await _sessionsRef(userId, attemptId).where('challenge_id', isEqualTo: session.challengeId).orderBy('date', descending: true).limit(2).get();
    if (session.passed && priorInAttempt.docs.length >= 2) {
      final priorSession = ChallengeSession.fromSnapshot(priorInAttempt.docs[1]);
      if (!priorSession.passed) maybeAward('cr_didnt_quit');
    }

    // cr_short_handed: passed after 3+ consecutive failures.
    if (session.passed) {
      final allInAttempt = await _sessionsRef(userId, attemptId).where('challenge_id', isEqualTo: session.challengeId).orderBy('date').get();
      final sessionList = allInAttempt.docs.map(ChallengeSession.fromSnapshot).toList();
      if (sessionList.length >= 4) {
        final priorThree = sessionList.sublist(sessionList.length - 4, sessionList.length - 1);
        if (priorThree.every((s) => !s.passed)) maybeAward('cr_short_handed');
      }

      // cr_battle_tested: passed after exactly 5 consecutive failures.
      if (sessionList.length >= 6) {
        final priorFive = sessionList.sublist(sessionList.length - 6, sessionList.length - 1);
        if (priorFive.every((s) => !s.passed)) maybeAward('cr_battle_tested');
      }
    }

    // cr_game_7: passed the all-time most-failed challenge.
    if (session.passed) {
      final stats = await _loadRoadBadgeStats(userId);
      if (stats.mostFailedChallengeId == session.challengeId && stats.mostFailedChallengeCount >= 3) {
        maybeAward('cr_game_7');
      }

      // cr_ghosts_in_the_machine: 10+ all-time failures on this challenge, now passed.
      final failCount = stats.allTimeSessionsByChallenge[session.challengeId] ?? 0;
      final passCount = stats.allTimePassesByChallenge[session.challengeId] ?? 0;
      final priorFailed = failCount - passCount - 1; // subtract this pass
      if (priorFailed >= 10) maybeAward('cr_ghosts_in_the_machine');

      // cr_old_grudge: failed this challenge in the previous two attempts, now passed.
      int attemptsWithoutPass = 0;
      for (final attemptDoc in (await _attemptsRef(userId).orderBy('attempt_number').get()).docs) {
        if (attemptDoc.id == attemptId) break;
        final progress = await getChallengeProgress(userId, attemptDoc.id, session.challengeId);
        if (progress != null && progress.totalPassed == 0 && progress.totalAttempts > 0) {
          attemptsWithoutPass++;
        }
      }
      if (attemptsWithoutPass >= 2) maybeAward('cr_old_grudge');

      // cr_redemption_arc: passed first-try this attempt; had 5+ failures in a prior attempt.
      final progressSnap = await _progressRef(userId, attemptId).doc(session.challengeId).get();
      if (progressSnap.exists) {
        final progress = ChallengeProgressEntry.fromSnapshot(progressSnap);
        // totalAttempts == 1 means this is the first (and only) session in this attempt.
        if (progress.totalAttempts == 1) {
          for (final attemptDoc in (await _attemptsRef(userId).orderBy('attempt_number').get()).docs) {
            if (attemptDoc.id == attemptId) continue;
            final pp = await getChallengeProgress(userId, attemptDoc.id, session.challengeId);
            if (pp != null && (pp.totalAttempts - pp.totalPassed) >= 5) {
              maybeAward('cr_redemption_arc');
              break;
            }
          }
        }
      }

      // cr_snipe_artist: 3 consecutive sessions at 85%+ (check last 3 in this attempt).
      final last3Snap = await _sessionsRef(userId, attemptId).orderBy('date', descending: true).limit(3).get();
      final last3 = last3Snap.docs.map(ChallengeSession.fromSnapshot).toList();
      if (last3.length == 3 && last3.every((s) => s.totalShots > 0 && s.shotsMade / s.totalShots >= 0.85)) {
        maybeAward('cr_snipe_artist');
      }
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

    // cr_barnburner_run: zero failures AND 80%+ average accuracy.
    if (failedInLevel == 0 && levelSessions.docs.isNotEmpty) {
      final allInLevel = levelSessions.docs.map(ChallengeSession.fromSnapshot).toList();
      final avgAcc = allInLevel.where((s) => s.totalShots > 0).map((s) => s.shotsMade / s.totalShots).fold(0.0, (a, b) => a + b) / allInLevel.length;
      if (avgAcc >= 0.80) extraBadges.add('cr_barnburner_run');
    }

    // cr_freight_train: previous level was also completed with zero failures.
    if (failedInLevel == 0 && completedLevel > 1) {
      final prevLevelSessions = await _sessionsRef(userId, attemptId).where('level', isEqualTo: completedLevel - 1).get();
      final prevFailed = prevLevelSessions.docs.map(ChallengeSession.fromSnapshot).where((s) => !s.passed).length;
      if (prevFailed == 0) extraBadges.add('cr_freight_train');
    }

    // cr_dead_aim: 80%+ average accuracy across all sessions in this level.
    if (levelSessions.docs.isNotEmpty) {
      final allInLevel = levelSessions.docs.map(ChallengeSession.fromSnapshot).toList();
      if (allInLevel.any((s) => s.totalShots > 0)) {
        final avgAcc = allInLevel.where((s) => s.totalShots > 0).map((s) => s.shotsMade / s.totalShots).fold(0.0, (a, b) => a + b) / allInLevel.where((s) => s.totalShots > 0).length;
        if (avgAcc >= 0.80) extraBadges.add('cr_dead_aim');
        if (avgAcc >= 0.85) extraBadges.add('cr_the_sniper');
      }
    }

    // cr_dug_deep: cleared a level that was previously not cleared in any prior attempt.
    final prevAttemptsSnap = await _attemptsRef(userId).where('attempt_number', isLessThan: attempt.attemptNumber).get();
    bool levelWasPreviouslyUncleared = false;
    for (final prevDoc in prevAttemptsSnap.docs) {
      final prevSessions = await _sessionsRef(userId, prevDoc.id).where('level', isEqualTo: completedLevel).where('passed', isEqualTo: true).limit(1).get();
      if (prevSessions.docs.isEmpty) {
        levelWasPreviouslyUncleared = true;
        break;
      }
    }
    if (levelWasPreviouslyUncleared && prevAttemptsSnap.docs.isNotEmpty) {
      extraBadges.add('cr_dug_deep');
    }

    // cr_reclaiming_the_ice: level was cleared in a prior attempt AND this attempt.
    if (!levelWasPreviouslyUncleared && prevAttemptsSnap.docs.isNotEmpty) {
      extraBadges.add('cr_reclaiming_the_ice');
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

      // cr_the_road_ends_here: completing the road in a 2nd+ attempt.
      if (attempt.attemptNumber >= 2) extraBadges.add('cr_the_road_ends_here');

      // cr_hockey_god: full road with zero failed sessions across all levels.
      final allSessionsSnap = await _sessionsRef(userId, attemptId).get();
      final anyFailure = allSessionsSnap.docs.map(ChallengeSession.fromSnapshot).any((s) => !s.passed);
      if (!anyFailure) extraBadges.add('cr_hockey_god');

      // cr_pinpoint: 85%+ average accuracy across the entire attempt.
      final allSessions = allSessionsSnap.docs.map(ChallengeSession.fromSnapshot).where((s) => s.totalShots > 0).toList();
      if (allSessions.isNotEmpty) {
        final attemptAvgAcc = allSessions.map((s) => s.shotsMade / s.totalShots).fold(0.0, (a, b) => a + b) / allSessions.length;
        if (attemptAvgAcc >= 0.85) extraBadges.add('cr_pinpoint');
      }

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

      // cr_sniper_mentality: 85%+ on at least one session per unique challenge.
      final allHistorySnap = await _allTimeHistoryRef(userId).get();
      // Use all-time history docs as a proxy for all challenges ever attempted.
      bool allAt85 = allHistorySnap.docs.isNotEmpty;
      for (final hDoc in allHistorySnap.docs) {
        final bestAcc = await _bestAccuracyForChallenge(userId, hDoc.id);
        if (bestAcc < 0.85) {
          allAt85 = false;
          break;
        }
      }
      if (allAt85 && allHistorySnap.docs.isNotEmpty) {
        extraBadges.add('cr_sniper_mentality');
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

      if (newResetCount >= 2) maybeAward('cr_and_again');
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
  Future<ChallengerRoadAttempt> restartChallengerRoad(String userId) async {
    final active = await getActiveAttempt(userId);

    int startingLevel = 1;
    if (active != null) {
      startingLevel = max(1, active.highestLevelReachedThisAttempt - 1);

      final hasCompletedRoad = active.resetCount >= 1;
      await updateAttempt(userId, active.id!, {
        'status': hasCompletedRoad ? 'completed' : 'cancelled',
        'end_date': Timestamp.fromDate(DateTime.now()),
      });

      if (!hasCompletedRoad) {
        // Reuse the same attempt number — this is a "do-over", not a new attempt.
        final attempt = ChallengerRoadAttempt(
          attemptNumber: active.attemptNumber,
          startingLevel: startingLevel,
          currentLevel: startingLevel,
          challengerRoadShotCount: 0,
          totalShotsThisAttempt: 0,
          resetCount: 0,
          highestLevelReachedThisAttempt: startingLevel,
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
    return createAttempt(userId, startingLevel);
  }

  /// Called when the user taps "RUN IT BACK" after completing the full road.
  ///
  /// Marks the current attempt as `completed` and creates a genuine new attempt
  /// starting from level 1. Unlike [restartChallengerRoad] this path is always
  /// a fresh start — the road was finished, not abandoned.
  Future<ChallengerRoadAttempt> runItBack(String userId) async {
    final active = await getActiveAttempt(userId);
    if (active != null) {
      await updateAttempt(userId, active.id!, {
        'status': 'completed',
        'end_date': Timestamp.fromDate(DateTime.now()),
      });
    }
    // Always start from level 1 — the user beat the whole road.
    return createAttempt(userId, 1);
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
    int sessionsAt90PctPlus = 0;
    int perfectSessions = 0;
    double bestHardChallengeAccuracy = 0.0;
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

    for (final attempt in allAttempts) {
      final attemptId = attempt.id!;
      final attemptNumber = attempt.attemptNumber;

      if (attemptNumber > latestAttemptNumber) {
        latestAttemptNumber = attemptNumber;
        latestAttemptStartingLevel = attempt.startingLevel;
      }

      // All sessions for this attempt, oldest first.
      final sessionsSnap = await _sessionsRef(userId, attemptId).orderBy('date').get();
      final sessions = sessionsSnap.docs.map(ChallengeSession.fromSnapshot).toList();

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
        if (acc >= 0.90) sessionsAt90PctPlus++;
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
    int challengesWithRegularStatus = 0;
    int consistentFirstPassChallenges = 0;
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

      final totalSessions = allTimeSessionsByChallenge[challengeId] ?? 0;
      if (totalSessions >= 15) challengesWithRegularStatus++;

      final firstPassAttempts = firstAttemptPassesByChallenge[challengeId] ?? [];
      if (firstPassAttempts.length >= 3) consistentFirstPassChallenges++;
      if (firstPassAttempts.length >= 5) untouchableChallenges++;
    }

    // Scouting Report: challenges passed first-try in attempt N but that
    // required > 1 try in attempt N-1.
    int scoutingReportCount = 0;
    int rematches = 0;
    int betterThanBeforeCount = 0;
    int dugDeepCount = 0;
    int secondNatureCount = 0;
    bool dialedInAchieved = false;

    for (final entry in sessionsByChallengeByAttempt.entries) {
      final byAttempt = entry.value;
      final attemptNums = byAttempt.keys.toList()..sort();

      double prevBestAcc = 0.0;
      bool everPassedBefore = false;

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

          // Dug Deep: level was not cleared in prev attempt but cleared here.
          // (Approximated at challenge level: not passed prev, passed now.)
          if (!prevPassed && passedThisAttempt && !everPassedBefore) dugDeepCount++;
        }

        // Better Than Before: any session's accuracy exceeds all previous sessions.
        for (final s in sessions) {
          final acc = s.totalShots > 0 ? s.shotsMade / s.totalShots : 0.0;
          if (acc > prevBestAcc && prevBestAcc > 0.0) betterThanBeforeCount++;
          if (acc > prevBestAcc) prevBestAcc = acc;
        }

        if (passedThisAttempt) everPassedBefore = true;
      }

      // Redemption Arc: 5+ failures in a previous attempt, then first-try pass
      // in a later attempt.
      for (int i = 1; i < attemptNums.length; i++) {
        final prevSessions = byAttempt[attemptNums[i - 1]]!;
        final prevFailed = prevSessions.where((s) => !s.passed).length;
        final currSessions = byAttempt[attemptNums[i]]!;
        if (prevFailed >= 5 && currSessions.isNotEmpty && currSessions.first.passed) {
          // Redemption Arc is awarded contextually in _checkAndAwardBadges via
          // a dedicated flag — tracked here:
          // (We reuse scoutingReportCount for now; a dedicated field handles it below.)
        }
      }
    }

    // Second Nature: in the most recent attempt, count challenges where the
    // player had failed at least once in any prior attempt but passed first-try.
    if (latestAttemptNumber > 0 && allAttempts.isNotEmpty) {
      final latestAttempt = allAttempts.last;
      final latestSessions = await _sessionsRef(userId, latestAttempt.id!).orderBy('date').get();
      final latestSessionList = latestSessions.docs.map(ChallengeSession.fromSnapshot).toList();
      final seenInLatest = <String>{};
      for (final s in latestSessionList) {
        if (!seenInLatest.contains(s.challengeId)) {
          seenInLatest.add(s.challengeId);
          if (s.passed) {
            // Check if ever failed in a prior attempt.
            final everFailedPrior = sessionsByChallengeByAttempt[s.challengeId]?.entries.where((e) => e.key < latestAttemptNumber).any((e) => e.value.any((sess) => !sess.passed)) ?? false;
            if (everFailedPrior) secondNatureCount++;
          }
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
      sessionsAt90PctPlus: sessionsAt90PctPlus,
      perfectSessions: perfectSessions,
      bestHardChallengeAccuracy: bestHardChallengeAccuracy,
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
      challengesWithRegularStatus: challengesWithRegularStatus,
      consistentFirstPassChallenges: consistentFirstPassChallenges,
      untouchableChallenges: untouchableChallenges,
      scoutingReportCount: scoutingReportCount,
      rematches: rematches,
      betterThanBeforeCount: betterThanBeforeCount,
      dugDeepCount: dugDeepCount,
      secondNatureCount: secondNatureCount,
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

  /// Returns the highest accuracy ratio (shotsMade/totalShots) ever achieved
  /// across all attempts for a specific [challengeId].
  Future<double> _bestAccuracyForChallenge(String userId, String challengeId) async {
    double best = 0.0;
    final attemptsSnap = await _attemptsRef(userId).get();
    for (final aDoc in attemptsSnap.docs) {
      final snap = await _sessionsRef(userId, aDoc.id).where('challenge_id', isEqualTo: challengeId).get();
      for (final s in snap.docs) {
        final session = ChallengeSession.fromSnapshot(s);
        final acc = session.totalShots > 0 ? session.shotsMade / session.totalShots : 0.0;
        if (acc > best) best = acc;
      }
    }
    return best;
  }

  /// newly earned badges. Idempotent — will not re-award a badge already in
  /// the `badges` list.
  /// Computes badge eligibility from [_RoadBadgeStats] and persists any newly
  /// earned badges.  Returns the IDs of badges newly awarded by this call.
  Future<List<String>> _checkAndAwardBadges({
    required String userId,
    required ChallengerRoadUserSummary summary,
  }) async {
    final earned = List<String>.from(summary.badges);
    final newIds = <String>[];
    final stats = await _loadRoadBadgeStats(userId);

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
    if (stats.levelsEverCleared.contains(2)) maybeAward('cr_called_up');
    if (stats.levelsEverCleared.contains(3)) maybeAward('cr_made_the_show');
    if (t >= 2) maybeAward('cr_the_tape_is_on');

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
    if (stats.betterThanBeforeCount >= 1) maybeAward('cr_better_than_before');
    if (stats.dugDeepCount >= 1) maybeAward('cr_dug_deep');
    if (stats.secondNatureCount >= 5) maybeAward('cr_second_nature');
    if (stats.dialedInAchieved) maybeAward('cr_dialed_in');

    // cr_chip_on_your_shoulder: started lower, reached new all-time best.
    if (stats.latestAttemptNumber >= 2 && stats.latestAttemptStartingLevel < stats.previousAttemptHighestLevel && summary.allTimeBestLevel > stats.previousAttemptHighestLevel) {
      maybeAward('cr_chip_on_your_shoulder');
    }

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
    // cr_short_handed, cr_battle_tested, cr_game_7, cr_ghosts_in_the_machine,
    // cr_didnt_quit, cr_old_grudge — all awarded contextually in saveChallengeSession.
    // cr_third_period_heart — awarded contextually in advanceLevel.

    if (stats.totalFailedSessions >= 50) maybeAward('cr_takes_a_licking');

    // ── LEVEL ADVANCEMENT ─────────────────────────────────────────────────────
    if (stats.levelsEverCleared.contains(3)) maybeAward('cr_paying_your_dues');
    if (stats.levelsEverCleared.contains(5)) maybeAward('cr_ice_time_earned');
    if (stats.levelsEverCleared.contains(7)) maybeAward('cr_franchise_player');
    if (stats.levelsEverCleared.contains(10)) maybeAward('cr_team_captain');

    // cr_the_climb: awarded contextually in advanceLevel when new all-time best hit.

    // cr_reclaiming_the_ice: cleared a level in latest attempt that was also
    // cleared in a prior attempt.
    if (stats.latestAttemptNumber >= 2 && stats.levelsCleared_latestAttempt.any((l) => stats.levelsEverCleared.contains(l))) {
      maybeAward('cr_reclaiming_the_ice');
    }

    // cr_playoff_mode: reached the max available level.
    if (stats.highestActiveLevel > 0 && summary.allTimeBestLevel >= stats.highestActiveLevel) {
      maybeAward('cr_playoff_mode');
    }

    // cr_the_general: all challenges at max level cleared.
    if (stats.highestActiveLevel > 0) {
      final activeAtMax = stats.activeChallengeIdsByLevel[stats.highestActiveLevel] ?? {};
      // Cleared if every one appears in levelsEverCleared data — proxy: all
      // levels up to max were cleared at some point.
      if (activeAtMax.isNotEmpty && stats.levelsEverCleared.contains(stats.highestActiveLevel)) {
        maybeAward('cr_the_general');
      }
    }

    // ── CR SHOT MILESTONES ────────────────────────────────────────────────────
    if (shots >= 100) maybeAward('cr_first_bucket');
    if (shots >= 1000) maybeAward('cr_building_a_barn');
    if (shots >= 2500) maybeAward('cr_filling_the_net');
    if (shots >= 5000) maybeAward('cr_ten_minute_major');
    if (shots >= 10000) maybeAward('cr_buzzer_beater');
    // cr_and_again / cr_three_periods — awarded contextually via incrementChallengerRoadShots.
    if (shots >= 25000) maybeAward('cr_well_never_runs_dry');
    if (shots >= 50000) maybeAward('cr_tape_burner');

    // ── CR SESSION ACCURACY ───────────────────────────────────────────────────
    // cr_lights_out: awarded contextually in saveChallengeSession (new PB).
    if (stats.bestSingleSessionAccuracy >= 0.90) maybeAward('cr_bar_down');
    if (stats.bestSingleSessionAccuracy >= 0.95) maybeAward('cr_top_cheese');
    if (stats.perfectSessions >= 1) maybeAward('cr_pure');
    // cr_snipe_artist: 3 consecutive sessions >= 85% — awarded contextually.
    // cr_dead_aim / cr_the_sniper — awarded contextually in advanceLevel.
    if (stats.sessionsAt90PctPlus >= 10) maybeAward('cr_millimetre');
    if (stats.perfectSessions >= 5) maybeAward('cr_all_net');
    // cr_pinpoint — awarded contextually after a full attempt completes.

    // ── HOT STREAKS ───────────────────────────────────────────────────────────
    if (stats.longestPassStreak >= 3) maybeAward('cr_on_a_heater');
    if (stats.longestPassStreak >= 5) maybeAward('cr_sauce');
    if (stats.longestPassStreak >= 10) maybeAward('cr_unstoppable');
    // cr_full_send — awarded contextually in saveChallengeSession.

    // ── CHALLENGE MASTERY ─────────────────────────────────────────────────────
    if (stats.challengesWithPerfectRecord >= 5) maybeAward('cr_never_missed');
    if (stats.consistentFirstPassChallenges >= 1) maybeAward('cr_consistent');
    if (stats.untouchableChallenges >= 1) maybeAward('cr_untouchable');
    if (stats.challengesWithSalary >= 1) maybeAward('cr_earned_a_salary');
    if (stats.challengesWithRegularStatus >= 1) maybeAward('cr_the_regular');

    // ── MULTI-ATTEMPT / CAREER ────────────────────────────────────────────────
    if (t >= 2) maybeAward('cr_veteran_presence');
    if (t >= 3) maybeAward('cr_double_shift');
    if (t >= 4) maybeAward('cr_this_is_what_i_do');
    if (t >= 5) maybeAward('cr_lifer');
    // cr_career_year: awarded contextually when 10k milestone and new best happen in same attempt.
    if (stats.totalCrSessions >= 100) maybeAward('cr_the_long_road');
    if (stats.totalCrSessions >= 250) maybeAward('cr_road_dog');
    if (stats.totalPassedSessions >= 100) maybeAward('cr_all_time_great');

    // ── ELITE / ENDGAME ───────────────────────────────────────────────────────
    // cr_hall_of_famer, cr_the_road_ends_here — contextually in advanceLevel.
    // cr_hockey_god — contextually in advanceLevel.
    // cr_the_machine, cr_sniper_mentality, cr_pinpoint — contextually after attempt completes.

    // ── CHIRPY ────────────────────────────────────────────────────────────────
    if (stats.latestAttemptNumber >= 2 && stats.latestAttemptStartingLevel < stats.previousAttemptHighestLevel) {
      maybeAward('cr_bender');
    }

    // cr_pigeon: first-try 95%+ on a hard challenge — contextually.

    // cr_old_habits: challenged failed in 2+ attempts, never passed.
    final neverPassedMultiAttempt = stats.allTimePassesByChallenge.entries.where((e) => e.value == 0 && (stats.allTimeSessionsByChallenge[e.key] ?? 0) >= 2).length;
    if (neverPassedMultiAttempt >= 1) maybeAward('cr_old_habits');

    // cr_just_visiting: 3+ attempts, no level cleared in any.
    if (t >= 3 && stats.levelsEverCleared.isEmpty) maybeAward('cr_just_visiting');

    // cr_ferda, cr_sauce_boss — contextually.

    // Persist earned badges if changed.
    if (newIds.isNotEmpty) {
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

  /// Number of CR sessions with accuracy >= 0.90.
  final int sessionsAt90PctPlus;

  /// Number of CR sessions with 100% accuracy.
  final int perfectSessions;

  /// Best accuracy seen on any single hard-difficulty CR challenge session.
  final double bestHardChallengeAccuracy;

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

  /// Number of challenges where allTimeTotalAttempts >= 15.
  final int challengesWithRegularStatus;

  /// Number of challenges where first-attempt pass happened in >= 3 separate attempts.
  final int consistentFirstPassChallenges;

  /// Number of challenges where first-attempt pass happened in >= 5 separate attempts.
  final int untouchableChallenges;

  // ── Cross-attempt improvement ──────────────────────────────────────────────
  /// Number of challenges that were passed on first attempt in a newer run but
  /// required multiple attempts in the immediately preceding run.
  final int scoutingReportCount;

  /// Number of challenges that were not passed in a previous attempt but were
  /// passed (in any session) in a later attempt.
  final int rematches;

  /// Number of challenges where the most-recent session accuracy exceeds the
  /// previous personal best for that challenge.
  final int betterThanBeforeCount;

  /// Number of challenges that:
  ///   - were attempted in a previous attempt and not cleared (level not completed)
  ///   - were passed in a later attempt
  final int dugDeepCount;

  /// Number of challenges in the current level where the player previously
  /// failed at least once (any attempt) but passed first-try this attempt.
  /// Used for the "Second Nature" badge (needs >= 5).
  final int secondNatureCount;

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
    required this.sessionsAt90PctPlus,
    required this.perfectSessions,
    required this.bestHardChallengeAccuracy,
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
    required this.challengesWithRegularStatus,
    required this.consistentFirstPassChallenges,
    required this.untouchableChallenges,
    required this.scoutingReportCount,
    required this.rematches,
    required this.betterThanBeforeCount,
    required this.dugDeepCount,
    required this.secondNatureCount,
    required this.dialedInAchieved,
  });
}
