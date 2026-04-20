# Challenger Road - Implementation Roadmap

> **Purpose of this document:** Living reference for implementing the Challenger Road feature end-to-end. Return here whenever context is running low. Every design decision is captured below so implementation stays consistent regardless of session breaks.

---

## Table of Contents
1. [Confirmed Design Decisions](#1-confirmed-design-decisions)
2. [Firestore Data Architecture](#2-firestore-data-architecture)
3. [Dart Model Classes](#3-dart-model-classes)
4. [Services Layer](#4-services-layer)
5. [Implementation Phases](#5-implementation-phases) _(includes Phase 1b: Seed Test Data)_
6. [UI Component Inventory](#6-ui-component-inventory)
7. [Badges Specification](#7-badges-specification)
8. [Admin / PushTable Notes](#8-admin--pushtable-notes)
9. [Integration Points with Existing Code](#9-integration-points-with-existing-code)
10. [Testing Checklist](#10-testing-checklist)

---

## 1. Confirmed Design Decisions

| # | Decision | Detail |
|---|----------|--------|
| 1 | **Pro-only feature** | Challenger Road is gated by RevenueCat entitlement (`isPro`). Checked via `CustomerInfoNotifier.isPro`. |
| 2 | **Group level advancement** | Player must complete **all** challenges at their current level before the entire group advances to the next level. No per-challenge level tracking. |
| 3 | **Free-roam within a level** | Challenges within the current level can be attempted in any order, like Super Mario's world map. |
| 4 | **Attempt restart level** | When a new attempt begins, player starts at `previousAttempt.highestLevelReached - 1` (minimum Level 1). Ensures long-term scalability. |
| 5 | **Per-level fixed quota** | Each challenge level document has `shotsRequired` (total shots) and `shotsToPass` (minimum on-target to pass). Admin-defined, not user-adjustable. |
| 6 | **Challenger Road shot counter** | A separate 0→10,000 counter per attempt, distinct from the global iteration. Resets to 0 when 10,000 is hit (same attempt continues). |
| 7 | **Shots count toward global iteration** | Challenger Road shots also increment the user's current Iteration total (the normal 10,000 shot challenge). Normal session shots do NOT count toward Challenger Road. |
| 8 | **10,000 milestone reward** | Hitting 10,000 Challenger Road shots triggers: full-screen celebration animation, a badge award, and the counter resets to 0 within the same attempt. |
| 9 | **Map is fully scrollable** | All challenges/levels visible. Future levels dimmed + locked icon. Current level challenges are fully interactive. Completed challenges show completion state. |
| 10 | **Sequence is per-level** | The `sequence` field lives on each challenge's Level sub-document (not the challenge itself). A challenge can exist only at Level 3+ by simply having no Level 1/2 sub-documents. |
| 11 | **Free user experience** | Free users see the existing Start tab unchanged, plus a "Start Challenger Road" button that pushes a teaser/locked view of the map with a paywall prompt. |
| 12 | **Pro user Start tab** | Completely redesigned: snake-map Challenger Road replaces the main content area. Pie chart, progress bar, target date, and shots-over-time graph move to a collapsible "Progress" section in the Profile tab. Normal "Start Shooting" button remains at the bottom. |
| 13 | **Map animations** | Purposeful only: scroll-in reveals, pulsing glow on the current active challenge node, satisfying particle/animation when completing a challenge, level-unlock animation. |
| 14 | **Challenge steps media** | Each step supports `video`, `image`, or `gif` media types with a `mediaUrl`, a `title`, and a `summary`. Levels can optionally override the parent challenge's steps. |

---

## 2. Firestore Data Architecture

### 2a. Global Challenge Data (shared across all users)

```
challenger_road/                          ← top-level collection
  challenges/                             ← sub-collection
    {challengeId}/                        ← document
      name:         string
      description:  string
      active:       bool
      steps:        array<ChallengeStep>  ← default steps; used unless level overrides
        [
          {
            stepNumber: int,
            title:      string,
            mediaType:  'video' | 'image' | 'gif',
            mediaUrl:   string,
            summary:    string
          }
        ]
      createdAt:    Timestamp
      updatedAt:    Timestamp

      levels/                             ← sub-collection
        {levelDocId}/                     ← document
          level:          int             ← 1, 2, 3 … (numeric, determines level grouping)
          levelName:      string          ← "Level 1", "Lvl 1" etc. (display name)
          sequence:       int             ← position on map for THIS level
                                           ← e.g. challenge may be #5 on L1 but #2 on L3
          shotsRequired:  int             ← total shots the player must take
          shotsToPass:    int             ← minimum on-target shots to pass
          active:         bool
          steps:          array<ChallengeStep>?
                                           ← optional; overrides parent challenge steps when present
```

**Key rules:**
- A challenge that should only appear at Level 3+ simply has no Level 1 or Level 2 sub-documents.
- Reordering challenges on any level means changing `sequence` on the level documents - no edits to the challenge document itself.
- Adding new challenges to an existing level is non-breaking; users that have already completed that level will show the new challenge as "completed" only if they happen to attempt it (or it can be marked as bonus/optional - TBD).

---

### 2b. User Challenger Road State

```
users/{userId}/
  challenger_road                         ← document (lightweight summary)
    currentAttemptId:   string | null
    totalAttempts:      int
    allTimeBestLevel:   int               ← highest level completed in any attempt (for badge)
    allTimeTotalChallengerRoadShots: int  ← sum across all attempts + resets (for badge math)

  challenger_road_attempts/               ← sub-collection
    {attemptId}/                          ← document
      attemptNumber:       int
      startingLevel:       int            ← level they started this attempt on
      currentLevel:        int            ← current active level
      challengerRoadShotCount: int        ← 0→10,000 (resets to 0 on milestone)
      totalShotsThisAttempt: int          ← cumulative (does NOT reset); used for badge tracking
      resetCount:          int            ← how many times 10k has been hit this attempt
      highestLevelReachedThisAttempt: int ← tracks for next attempt's startingLevel
      status:              'active' | 'completed'
      startDate:           Timestamp
      endDate:             Timestamp?

      challenge_sessions/                 ← sub-collection
        {sessionId}/                      ← document
          challengeId:    string
          level:          int
          date:           Timestamp
          duration:       int             ← seconds
          shotsRequired:  int             ← copied from level doc at time of session
          shotsToPass:    int             ← copied from level doc at time of session
          shotsMade:      int             ← on-target shots (used to determine pass/fail)
          totalShots:     int             ← all shots taken this session
          passed:         bool
          shots:          array<ShotRecord>
            [
              {
                type:       string,       ← 'wrist' | 'snap' | 'slap' | 'backhand'
                count:      int,
                targetsHit: int,
                date:       Timestamp
              }
            ]

      challenge_progress/                 ← sub-collection (per-challenge summary within attempt)
        {challengeId}/                    ← document (one per unique challenge run this attempt)
          challengeId:    string
          bestLevel:      int             ← highest level passed for this challenge this attempt
          totalAttempts:  int             ← total sessions for this challenge this attempt
          totalPassed:    int             ← number of passes this attempt
          firstPassedAt:  Timestamp?      ← first pass within this attempt (null if never)
          lastAttemptAt:  Timestamp?      ← most recent session for this challenge this attempt
          levelHistory:   array           ← compact append-only log of every session
            [
              {
                level:          int,
                passed:         bool,
                shotsMade:      int,
                shotsRequired:  int,
                date:           Timestamp
              }
            ]
```

**Per-challenge cross-attempt history (stored separately for profile stats & badge math):**

```
users/{userId}/
  challenger_road_challenge_history/      ← sub-collection (one doc per unique challenge)
    {challengeId}/                        ← document
      challengeId:           string
      allTimeBestLevel:      int          ← highest level ever passed for this challenge
      allTimeTotalAttempts:  int          ← total challenge sessions across all attempts
      allTimeTotalPassed:    int          ← total passes across all attempts
      firstPassedAt:         Timestamp?   ← very first time this challenge was ever passed
      lastPassedAt:          Timestamp?   ← most recent pass across any attempt
```

**Key rules:**
- `challengerRoadShotCount` is the display counter (resets at 10k). `totalShotsThisAttempt` never resets and is used for "X × 10,000" badges.
- `passed: true` sessions are what determine level advancement eligibility.
- All shots in `challenge_sessions` also get written to the user's current `iterations/{iterationId}/sessions` via the existing session service (global shot count integration).
- `challenge_progress/{challengeId}` is updated atomically with each `challenge_sessions` write (WriteBatch). Avoids scanning all sessions for per-challenge stats.
- `challenger_road_challenge_history/{challengeId}` is also updated atomically on every session save - aggregates stats for that challenge across all attempts (used for profile display and badge math).

---

### 2c. Derived State (computed client-side, not stored)

- **"Challenge passed at current level"** - query `challenge_sessions` in `currentAttemptId` where `challengeId == X`, `level == currentLevel`, `passed == true`. If any exist, the challenge is complete for this level.
- **"All challenges complete at current level"** - check above for every active challenge that has a level doc for `currentLevel`.
- **"Next attempt starting level"** - `max(1, highestLevelReachedThisAttempt - 1)` from the most recent completed attempt.
- **"Best level for a challenge this attempt"** - read `challenge_progress/{challengeId}.bestLevel` (O(1) doc read; no session scan).
- **"All-time best level for a challenge"** - read `challenger_road_challenge_history/{challengeId}.allTimeBestLevel` (O(1) doc read across all attempts).

---

## 3. Dart Model Classes

Files to create in `lib/models/firestore/`:

### `ChallengeStep.dart`
```dart
// Fields: stepNumber (int), title (String), mediaType (String: 'video'|'image'|'gif'),
//         mediaUrl (String), summary (String)
// Methods: fromMap(), toMap()
```

### `ChallengerRoadChallenge.dart`
```dart
// Fields: id (String?), name, description, active (bool), steps (List<ChallengeStep>),
//         createdAt (DateTime?), updatedAt (DateTime?)
// Note: 'levels' subcollection loaded separately via ChallengerRoadService
// Methods: fromMap(), toMap(), fromSnapshot()
```

### `ChallengerRoadLevel.dart`
```dart
// Fields: id (String?), level (int), levelName (String), sequence (int),
//         shotsRequired (int), shotsToPass (int), active (bool),
//         steps (List<ChallengeStep>?)  // nullable; null = use parent challenge steps
// Methods: fromMap(), toMap(), fromSnapshot()
```

### `ChallengerRoadAttempt.dart`
```dart
// Fields: id (String?), attemptNumber (int), startingLevel (int), currentLevel (int),
//         challengerRoadShotCount (int), totalShotsThisAttempt (int), resetCount (int),
//         highestLevelReachedThisAttempt (int), status (String: 'active'|'completed'),
//         startDate (DateTime), endDate (DateTime?)
// Methods: fromMap(), toMap(), fromSnapshot()
```

### `ChallengeSession.dart`
```dart
// Fields: id (String?), challengeId (String), level (int), date (DateTime),
//         duration (Duration), shotsRequired (int), shotsToPass (int),
//         shotsMade (int), totalShots (int), passed (bool), shots (List<Shots>)
// Note: Shots reuses existing lib/models/firestore/Shots.dart
// Methods: fromMap(), toMap(), fromSnapshot()
```

### `ChallengerRoadUserSummary.dart`
```dart
// Fields: currentAttemptId (String?), totalAttempts (int),
//         allTimeBestLevel (int), allTimeTotalChallengerRoadShots (int)
// Methods: fromMap(), toMap(), fromSnapshot()
```

### `ChallengeProgressEntry.dart`
```dart
// Fields: challengeId (String), bestLevel (int), totalAttempts (int), totalPassed (int),
//         firstPassedAt (DateTime?), lastAttemptAt (DateTime?),
//         levelHistory (List<ChallengeLevelHistoryEntry>)
// ChallengeLevelHistoryEntry: level (int), passed (bool), shotsMade (int),
//                             shotsRequired (int), date (DateTime)
// Firestore path: users/{uid}/challenger_road_attempts/{aid}/challenge_progress/{challengeId}
// Methods: fromMap(), toMap(), fromSnapshot(), copyWith()
```

### `ChallengeAllTimeHistory.dart`
```dart
// Fields: challengeId (String), allTimeBestLevel (int), allTimeTotalAttempts (int),
//         allTimeTotalPassed (int), firstPassedAt (DateTime?), lastPassedAt (DateTime?)
// Firestore path: users/{uid}/challenger_road_challenge_history/{challengeId}
// Methods: fromMap(), toMap(), fromSnapshot(), copyWith()
```

---

## 4. Services Layer

### `ChallengerRoadService.dart`  →  `lib/services/ChallengerRoadService.dart`

Responsibilities:
1. **Fetch all challenges** for a given level (ordered by `sequence`)
   - `Future<List<ChallengerRoadChallenge>> getChallengesForLevel(int level)`
   - `Future<List<ChallengerRoadLevel>> getLevelsForChallenge(String challengeId)`
   - `Future<ChallengerRoadLevel?> getLevelDoc(String challengeId, int level)`
2. **Fetch all distinct level numbers** active in the system (for rendering the full map)
   - `Future<List<int>> getAllActiveLevels()`
3. **User attempt management**
   - `Future<ChallengerRoadAttempt?> getActiveAttempt(String userId)`
   - `Future<ChallengerRoadAttempt> createAttempt(String userId, int startingLevel)`
   - `Future<void> updateAttempt(String userId, String attemptId, Map<String, dynamic> data)`
4. **Challenge session management**
   - `Future<void> saveChallengeSession(String userId, String attemptId, ChallengeSession session)` → uses a `WriteBatch` to atomically write the session, update `challenge_progress`, and update `challenger_road_challenge_history`
   - `Future<List<ChallengeSession>> getSessionsForAttempt(String userId, String attemptId)`
   - `Future<bool> isChallengePassedAtLevel(String userId, String attemptId, String challengeId, int level)`
4b. **Per-challenge history management**
   - `Future<void> updateChallengeProgress(String userId, String attemptId, ChallengeSession session)` → upserts `challenge_progress/{challengeId}` after each session; appends to `levelHistory`, updates `bestLevel`, increments counters
   - `Future<ChallengeProgressEntry?> getChallengeProgress(String userId, String attemptId, String challengeId)`
   - `Future<void> updateChallengeAllTimeHistory(String userId, ChallengeSession session)` → upserts `challenger_road_challenge_history/{challengeId}`; updates `allTimeBestLevel`, increments `allTimeTotalAttempts` and `allTimeTotalPassed`, sets `firstPassedAt`/`lastPassedAt`
   - `Future<ChallengeAllTimeHistory?> getChallengeAllTimeHistory(String userId, String challengeId)`
5. **Level advancement check**
   - `Future<bool> isLevelComplete(String userId, String attemptId, int level)` → true if all active challenges with a doc for `level` have a passed session
   - `Future<void> advanceLevel(String userId, String attemptId)` → increments `currentLevel` and updates `highestLevelReachedThisAttempt` if needed
6. **10K milestone handling**
   - `Future<void> incrementChallengerRoadShots(String userId, String attemptId, int count)` → adds to both `challengerRoadShotCount` and `totalShotsThisAttempt`; if `challengerRoadShotCount >= 10000` resets to `challengerRoadShotCount - 10000` and increments `resetCount`; returns whether milestone was crossed
   - Should return a `bool didHitMilestone` so UI can trigger celebration
7. **Attempt restart**
   - `Future<ChallengerRoadAttempt> restartChallengerRoad(String userId)` → reads last completed attempt's `highestLevelReachedThisAttempt`, computes `max(1, highest - 1)`, creates a new attempt
8. **User summary**
   - `Future<ChallengerRoadUserSummary> getUserSummary(String userId)`
   - `Future<void> updateUserSummary(String userId, Map<String, dynamic> data)`

---

## 5. Implementation Phases

Work through these phases in order. Each phase is self-contained and testable before moving to the next.

---

### Phase 1 - Dart Models & Firestore Rules ✅ COMPLETE

**Files to create:**
- `lib/models/firestore/ChallengeStep.dart`
- `lib/models/firestore/ChallengerRoadChallenge.dart`
- `lib/models/firestore/ChallengerRoadLevel.dart`
- `lib/models/firestore/ChallengerRoadAttempt.dart`
- `lib/models/firestore/ChallengeSession.dart`
- `lib/models/firestore/ChallengerRoadUserSummary.dart`
- `lib/models/firestore/ChallengeProgressEntry.dart` _(Phase 1c)_
- `lib/models/firestore/ChallengeAllTimeHistory.dart` _(Phase 1c)_

**Firestore rules to add** (`firestore.rules`):
```
// Global challenger road challenges - public read, admin write
match /challenger_road/challenges/{challengeId} {
  allow read: if request.auth != null;
  allow write: if false; // admin-only via Firebase Console / PushTable
  match /levels/{levelId} {
    allow read: if request.auth != null;
    allow write: if false;
  }
}

// User challenger road data - owner read/write
match /users/{userId}/challenger_road {
  allow read, write: if request.auth.uid == userId;
}
match /users/{userId}/challenger_road_attempts/{attemptId} {
  allow read, write: if request.auth.uid == userId;
  match /challenge_sessions/{sessionId} {
    allow read, write: if request.auth.uid == userId;
  }
  match /challenge_progress/{challengeId} {
    allow read, write: if request.auth.uid == userId;
  }
}
match /users/{userId}/challenger_road_challenge_history/{challengeId} {
  allow read, write: if request.auth.uid == userId;
}
```

**Firestore indexes to add** (`firestore.indexes.json`):
- Collection: `users/{uid}/challenger_road_attempts/{aid}/challenge_sessions`
  - Fields: `challengeId ASC`, `level ASC`, `passed ASC`
- Collection: `challenger_road/challenges/{cid}/levels`
  - Fields: `level ASC`, `sequence ASC`, `active ASC`
- Collection: `users/{uid}/challenger_road_attempts/{aid}/challenge_progress`
  - Direct doc-ID lookups only; no composite index required.
- Collection: `users/{uid}/challenger_road_challenge_history`
  - Direct doc-ID lookups only; no composite index required.

---

### Phase 1b - Seed Test Data ✅ COMPLETE

> **Goal:** Have realistic Firestore data in place so every phase from Phase 2 onwards can be developed and tested against real map content without waiting for real challenge content from coaches/admins.

**File to create:** `scripts/seed_challenger_road.js`  
**Runtime:** Node.js - uses `firebase-admin` SDK (already available via the existing `functions/` setup).  
**Run once** against your development Firebase project. Safe to re-run - script checks for existing documents and skips them (`{ merge: false }` on new writes, skips if doc already exists).

#### What to seed

**3 levels × 5 challenges = 15 challenge/level combinations.**  
This gives enough data to test:
- Snake map rendering across multiple level banners
- Free-roam within a level
- Level completion → level unlock flow
- A challenge that only appears at Level 2+ (Challenge 5 has no Level 1 doc)
- Level-specific step override (Challenge 2, Level 2 has its own steps)

#### Seed data shape

```
challenger_road/challenges/
  seed_challenge_1   "Wrist Shot Warmup"          - 3 steps, levels 1/2/3
  seed_challenge_2   "Snap Shot Precision"         - 2 steps, levels 1/2/3 (L2 has override steps)
  seed_challenge_3   "Backhand Basics"             - 2 steps, levels 1/2/3
  seed_challenge_4   "Slap Shot Power"             - 2 steps, levels 1/2/3
  seed_challenge_5   "One-Timer Challenge"         - 2 steps, levels 2/3 ONLY (no Level 1 doc)
```

**Level quotas (intentionally easy for dev testing):**

| Challenge | Level 1 seq | L1 req/pass | Level 2 seq | L2 req/pass | Level 3 seq | L3 req/pass |
|-----------|-------------|-------------|-------------|-------------|-------------|-------------|
| Wrist Shot Warmup | 1 | 10 / 6 | 1 | 15 / 10 | 1 | 20 / 14 |
| Snap Shot Precision | 2 | 10 / 6 | 2 | 15 / 10 | 2 | 20 / 14 |
| Backhand Basics | 3 | 10 / 6 | 3 | 15 / 10 | 3 | 20 / 14 |
| Slap Shot Power | 4 | 10 / 6 | 4 | 15 / 10 | 4 | 20 / 14 |
| One-Timer Challenge | - | - | 5 | 15 / 10 | 5 | 20 / 14 |

**Steps use placeholder media** - public domain hockey image URLs (or a single reusable placeholder URL constant at the top of the script). No Firebase Storage upload required for dev.

#### Script outline

```js
// scripts/seed_challenger_road.js
// Usage: node scripts/seed_challenger_road.js
//
// Requires: GOOGLE_APPLICATION_CREDENTIALS env var pointing to a
// Firebase Admin service account JSON key for your dev project.
// OR run `firebase use <dev-project>` and use the emulator.

const admin = require('firebase-admin');

const PLACEHOLDER_IMAGE = 'https://placehold.co/600x400?text=Challenge+Step';

const challenges = [
  {
    id: 'seed_challenge_1',
    name: 'Wrist Shot Warmup',
    description: 'Build muscle memory with controlled wrist shots on net.',
    active: true,
    steps: [
      { stepNumber: 1, title: 'Setup', mediaType: 'image', mediaUrl: PLACEHOLDER_IMAGE,
        summary: 'Place pucks on the dot, 15 feet from the net.' },
      { stepNumber: 2, title: 'Follow Through', mediaType: 'image', mediaUrl: PLACEHOLDER_IMAGE,
        summary: 'Snap your wrists and point the blade at your target.' },
      { stepNumber: 3, title: 'Reset', mediaType: 'image', mediaUrl: PLACEHOLDER_IMAGE,
        summary: 'Retrieve pucks and repeat from the same spot.' },
    ],
    levels: [
      { id: 'level_1', level: 1, levelName: 'Level 1', sequence: 1, shotsRequired: 10, shotsToPass: 6, active: true, steps: null },
      { id: 'level_2', level: 2, levelName: 'Level 2', sequence: 1, shotsRequired: 15, shotsToPass: 10, active: true, steps: null },
      { id: 'level_3', level: 3, levelName: 'Level 3', sequence: 1, shotsRequired: 20, shotsToPass: 14, active: true, steps: null },
    ],
  },
  // ... seed_challenge_2 through seed_challenge_5 following same shape
  // seed_challenge_5 has NO level_1 entry - only level_2 and level_3
];

async function seed() {
  const db = admin.firestore();
  for (const challenge of challenges) {
    const { levels, ...challengeData } = challenge;
    const ref = db.collection('challenger_road').doc('challenges')
                  .collection('challenges').doc(challenge.id);
    // Skip if already exists
    const snap = await ref.get();
    if (snap.exists) { console.log(`Skipping ${challenge.id} - already exists`); continue; }
    await ref.set({ ...challengeData, createdAt: admin.firestore.FieldValue.serverTimestamp(),
                                      updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    for (const level of levels) {
      await ref.collection('levels').doc(level.id).set(level);
    }
    console.log(`Seeded ${challenge.id}`);
  }
}

seed().then(() => { console.log('Done.'); process.exit(0); })
      .catch(e => { console.error(e); process.exit(1); });
```

#### How to run

```bash
# From repo root - uses the same firebase-admin already in functions/
cd functions && npm install   # already done if you've run functions before
cd ..
GOOGLE_APPLICATION_CREDENTIALS=path/to/dev-service-account.json \
  node scripts/seed_challenger_road.js
```

Or against the **Firestore emulator**:
```bash
FIRESTORE_EMULATOR_HOST=localhost:8080 \
  node scripts/seed_challenger_road.js
```

#### Cleanup script

Also add `scripts/unseed_challenger_road.js` - deletes all documents whose IDs start with `seed_`. Run this before promoting seed data to production or when real challenges are ready.

```js
// Deletes seed_challenge_1 ... seed_challenge_N and all their subcollections
// Usage: node scripts/unseed_challenger_road.js
```

#### Verification checklist after seeding
- [ ] Firebase Console shows 5 challenge docs under `challenger_road/challenges`
- [ ] Each challenge has a `levels` subcollection with the correct number of level docs
- [ ] `seed_challenge_5` has **no** `level_1` document
- [ ] `seed_challenge_2 / level_2` has a non-null `steps` array (override steps)
- [ ] App map renders Level 1 with 4 nodes (challenges 1–4), Level 2 with 5 nodes, Level 3 with 5 nodes

---

### Phase 2 - ChallengerRoadService ✅ COMPLETE

**File to create:** `lib/services/ChallengerRoadService.dart`

- Implement all methods listed in Section 4.
- Inject `FirebaseFirestore` and `FirebaseAuth` via constructor (consistent with other services).
- Shot count increment must: (a) update `challengerRoadShotCount` and `totalShotsThisAttempt` on the attempt doc, (b) also call the existing iteration update logic to count toward global season shots.
- Return a `ChallengerRoadMilestoneResult` value object from `incrementChallengerRoadShots` that includes `{ didHitMilestone: bool, newCount: int, resetCount: int }`.

---

### Phase 3 - Profile Tab: Move Progress Section ✅ COMPLETE

**File to modify:** `lib/tabs/Shots.dart` (Start tab) and `lib/tabs/Profile.dart`

**Remove from Start tab (pro users only path):**
- Goal date row (target date + shots/day + shots/week)
- "Progress" label row
- Shot-type breakdown progress bar (wrist/snap/backhand/slap stacked bar)
- Shot count numbers row
- `ShotBreakdownDonut` pie chart
- `ShotsOverTimeLineChart`
- Weekly achievements widget (keep it, but evaluate placement)

**Add to Profile tab:**
- A new `ExpansionTile` (or custom collapsible card) titled **"Progress"** that contains
  all the above widgets verbatim - no logic changes, just relocated.
- This section should be expanded by default on first launch, collapsed on subsequent opens
  (persist state in `SharedPreferences`).
- Free users keep the Start tab exactly as it is today.

---

### Phase 4 - Start Tab Redesign (Pro Users) ✅ COMPLETE

**File to heavily modify:** `lib/tabs/Shots.dart`

**Logic:**
```pseudo
if isPro:
  show ChallengerRoadMapView (full screen scrollable)
  floating at bottom: "Start Shooting" plain session button
else:
  show existing Start tab content (unchanged)
  add "Start Challenger Road" button → Navigator.push(ChallengerRoadTeaserView)
```

**Pro Start Tab layout (top to bottom):**
1. `ChallengerRoadHeader` widget - shows current level badge, CR shot counter (X / 10,000), attempt number
2. `ChallengerRoadMapView` - the snake map (fills remaining screen, scrollable)
3. Pinned bottom bar - "Start Shooting" button (plain session, unchanged behavior)

---

### Phase 5 - Challenger Road Map UI ✅ COMPLETE

**Files to create:**
- `lib/tabs/shots/challenger_road/ChallengerRoadMapView.dart` - root scrollable map
- `lib/tabs/shots/challenger_road/ChallengeMapNode.dart` - individual challenge bubble
- `lib/tabs/shots/challenger_road/LevelBannerWidget.dart` - level header separating level groups
- `lib/tabs/shots/challenger_road/ChallengerRoadHeader.dart` - top stats bar

**Map layout algorithm:**
- Fetch all distinct active levels sorted ascending.
- For each level, fetch challenges ordered by `sequence`.
- Render from bottom of scroll to top (Level 1 at bottom, higher levels above - feels like climbing).
- Snake pattern: alternate challenge nodes left-center-right across three columns per row, connected by a winding path drawn with `CustomPaint`.
- Between level groups, render a `LevelBannerWidget`.

**Node states (visual):**
| State | Visual |
|-------|--------|
| `completed` | Filled primary color, checkmark icon, thumbnail faint overlay |
| `available` | Full color, thumbnail + title, pulsing glow ring (AnimationController) |
| `locked` | Greyed out, lock icon, no tap |
| `current` (first incomplete in level) | Same as available + extra pulse emphasis |

**Animations:**
- **Scroll-in reveal:** Use `AnimatedOpacity` + `AnimatedSlide` triggered when node enters viewport (`ScrollController` listener or `VisibilityDetector` package).
- **Pulsing glow:** `AnimationController` with `Curves.easeInOut` repeating; applies a box shadow / ring that grows and fades.
- **Challenge completion:** On `passed == true` returned from session: `showDialog` with a `Lottie` (or Rive from existing `assets/animations/goal_light.riv`) celebration. Then node animates to `completed` state.
- **Level unlock:** Full-width banner slides in from right with a flash effect when all challenges at a level are complete.
- **Hockey decorations:** Scatter `Image.asset` (hockey stick, puck, gloves) at random points along the path using `Positioned` within a `Stack`. These should subtly rotate/bob using a lightweight `AnimationController`.

---

### Phase 6 - Challenge Detail & Start Challenge Flow ✅ COMPLETE

**Files to create:**
- `lib/tabs/shots/challenger_road/ChallengeDetailSheet.dart` - bottom sheet or pushed screen
- `lib/tabs/shots/challenger_road/ChallengeStepViewer.dart` - PageView of steps with media
- `lib/tabs/shots/challenger_road/StartChallengeScreen.dart` - modified StartShooting for challenges

**Challenge Detail Sheet:**
- Triggered by tapping a `ChallengeMapNode`.
- Shows: challenge name, description, current level badge, `shotsRequired` / `shotsToPass` quota, steps media viewer.
- Steps viewer: horizontal `PageView`, each page shows media (video player / Image / GIF via `cached_network_image`) + step title + summary.
- If the level has its own `steps`, use those; otherwise fall back to parent challenge `steps`.
- CTA button at bottom:
  - If `locked`: disabled, shows "Complete Level X first"
  - If `completed` (current level): shows "Retry Challenge" (can re-attempt but won't re-count toward level pass - only first pass counts)
  - If `available`: shows "Start Challenge" → navigates to `StartChallengeScreen`

**StartChallengeScreen:**
- Pass `ChallengerRoadChallenge`, `ChallengerRoadLevel`, and `ChallengerRoadAttempt` as arguments.
- Reuse `StartShooting` logic and widgets but:
  - Replace the normal session title with the challenge name + level badge.
  - Show a pinned quota indicator at the top: "X / {shotsToPass} on target - need {shotsToPass}/{shotsRequired}" updating live.
  - Shot type is free (user selects as normal) - quota is on total on-target, not shot-type specific.
  - On session end:
    1. Compute `passed = shotsMade >= shotsToPass`.
    2. Save `ChallengeSession` via `ChallengerRoadService.saveChallengeSession()`.
    3. Also write a normal `ShootingSession` to the global iteration (same shots data) via existing session service.
    4. Call `ChallengerRoadService.incrementChallengerRoadShots()` with total shots count.
    5. If milestone hit → show 10K celebration before result screen.
    6. Show pass/fail result screen.
    7. If passed → check `ChallengerRoadService.isLevelComplete()` → if true → trigger level unlock animation.

**Pass/Fail Result Screen:**
- Full-screen modal.
- Pass: green/gold with "Challenge Complete!" celebratory text, quota met display, confetti/Lottie.
- Fail: encouraging tone, quota missed display, "Try Again" button.
- Both: show updated CR shot count progress bar (X / 10,000).

---

### Phase 7 - Level Advancement Logic ✅ COMPLETE

**In `ChallengerRoadService`:**
```
isLevelComplete():
  1. Fetch all active challenge level docs where level == currentLevel
  2. For each, check if there is a passed challenge_session in currentAttemptId
  3. Return true only if ALL have a passing session

advanceLevel():
  1. Increment attempt.currentLevel by 1
  2. Update attempt.highestLevelReachedThisAttempt if currentLevel > highest
  3. Update users/{uid}/challenger_road.allTimeBestLevel if needed
  4. Write to Firestore
```

**Called from `StartChallengeScreen` after saving a passing session.**

**Edge case:** If the new level has no challenge documents yet (admin hasn't added Level N+1 challenges), show a "You've conquered all available challenges! More coming soon." screen. Do not advance further.

---

### Phase 8 - 10K Milestone & Attempt Restart ✅ COMPLETE

**10K Milestone:**
- Triggered in `ChallengerRoadService.incrementChallengerRoadShots()`.
- Returns `ChallengerRoadMilestoneResult` with `didHitMilestone: true`.
- UI (`StartChallengeScreen` or map screen): on detection, push `ChallengerRoadMilestoneScreen`.
  - Full-screen Rive/Lottie animation (use existing `goal_light.riv` or create new).
  - Text: "10,000 Challenger Road Shots!" + reset count badge ("x{n}").
  - Award "10K × N" badge (see Phase 9).
  - "Keep Going!" button dismisses and returns to map.

**Attempt Restart:**
- "Restart Challenger Road" button lives in the `ChallengerRoadHeader` (with confirmation dialog).
- Calls `ChallengerRoadService.restartChallengerRoad()`.
- This method: marks current attempt as `completed`, reads `highestLevelReachedThisAttempt`, creates new attempt with `startingLevel = max(1, highest - 1)`.
- After restart, map scrolls to Level `startingLevel` automatically.

---

### Phase 9 - Badges & Profile Integration ✅ COMPLETE

#### Badge Types (Challenger Road - pro only)

| Badge ID | Name | Trigger |
|----------|------|---------|
| `cr_personal_best` | Challenger Road Personal Best | Shows a number: highest level ever completed across all attempts. Updates automatically. |
| `cr_attempts` | Road Warrior | Shows attempt count icon. Award tiers: 1, 3, 10, 25, 50 attempts. |
| `cr_10k_x1` | First 10,000 | Hit 10k Challenger Road shots once. |
| `cr_10k_x3` | Triple Threat | Hit 10k Challenger Road shots 3× (across attempts). |
| `cr_10k_x10` | Shot Machine | Hit 10k shots 10× across all attempts. |
| `cr_level_5` | Level 5 Reached | First time reaching Level 5 in any attempt. |
| `cr_level_10` | Double Digits | First time reaching Level 10. |
| `cr_perfect_level` | Flawless | Complete every challenge in any level on the first attempt (no retries). |
| `cr_comeback` | The Comeback | Start an attempt at Level 1 (after previously completing higher) and still complete Level 5+. |
| `cr_all_challenges_v1` | Road Complete | Complete all currently-available challenges at any level. (Re-awardable when new challenges added.) |

**Badge data model:**
- Add to existing user profile or create `lib/models/firestore/ChallengerRoadBadge.dart`.
- Store awarded badges in `users/{uid}/challenger_road` document under a `badges: array<string>` field (badge IDs).
- Badge checking runs in `ChallengerRoadService` after each relevant event (session save, level advance, 10k milestone, attempt create).

**Profile display:**
- Add a "Challenger Road" section to the Profile tab.
- Show `ChallengerRoadPersonalBestBadge` prominently (level number displayed inside badge artwork).
- Show smaller badge icons in a horizontal scroll row for earned badges.
- Non-earned badges shown as greyed-out silhouettes (same "you're missing out" motivator as achievement gaps).

---

### Phase 10 - Free User Teaser View ✅ COMPLETE

**File to create:** `lib/tabs/shots/challenger_road/ChallengerRoadTeaserView.dart`

- Pushed via `Navigator.push` from the "Start Challenger Road" button on the free user Start tab.
- Renders the same `ChallengerRoadMapView` but wrapped in a `Stack`:
  - Map behind with `ImageFilter.blur` (sigma 3.0) and reduced opacity.
  - Centered `Card` overlay: "Challenger Road is a Pro feature", short description, "Go Pro" button → `presentPaywallIfNeeded(context)`.
- Node taps are swallowed (no navigation).
- Use `IgnorePointer` on the map to prevent interaction.
- Still needs to load at least a few challenges from Firestore to look real - fetch the first level's challenges for visual authenticity.

---

### Phase 11 - Router Updates ✅ COMPLETE

**File to modify:** `lib/router.dart`

Add routes:
```dart
GoRoute(path: '/challenger-road', builder: (_, __) => ChallengerRoadTeaserView()),
// StartChallengeScreen may be pushed imperatively (Navigator.push) due to complex args
// If using go_router extra, add:
GoRoute(path: '/challenger-road/challenge', builder: ...)
```

The map itself lives inside the Start tab body, so no top-level route needed for it.

---

### Phase 12 - Unit Tests ✅ COMPLETE

**File created:** `test/challenger_road/challenger_road_test.dart`

31 tests covering all Section 10 unit and integration checklist items:
- Model round-trips: `ChallengerRoadLevel`, `ChallengeSession`, `ChallengeProgressEntry`, `ChallengeAllTimeHistory`
- Service: `isLevelComplete()`, `incrementChallengerRoadShots()`, `restartChallengerRoad()`
- `saveChallengeSession()` - `updateChallengeProgress()` and `updateChallengeAllTimeHistory()` batch writes

**Bug fixed** (discovered by tests): `_buildChallengeProgressUpdate` and `_buildAllTimeHistoryUpdate` in `ChallengerRoadService` were using snake_case keys in Firestore `.update()` calls (`best_level`, `all_time_best_level`, etc.) while the model `fromMap()` methods read camelCase keys. This caused `bestLevel` and `allTimeBestLevel` to never advance past the first session's value. Fixed to use camelCase keys consistent with `toMap()`.

---

## 6. UI Component Inventory

| Component | Path | Description |
|-----------|------|-------------|
| `ChallengerRoadHeader` | `lib/tabs/shots/challenger_road/` | Level badge, CR shot counter (X/10,000), attempt # |
| `ChallengerRoadMapView` | `lib/tabs/shots/challenger_road/` | Full scrollable snake map |
| `ChallengeMapNode` | `lib/tabs/shots/challenger_road/` | Individual challenge bubble (available/completed/locked states) |
| `LevelBannerWidget` | `lib/tabs/shots/challenger_road/` | Level section header between groups |
| `MapPathPainter` | `lib/tabs/shots/challenger_road/` | `CustomPainter` drawing the winding path between nodes |
| `HockeyDecoration` | `lib/tabs/shots/challenger_road/` | Scattered hockey item widgets along the path |
| `ChallengeDetailSheet` | `lib/tabs/shots/challenger_road/` | Bottom sheet with challenge info + CTA; two tabs: "Steps" and "History" |
| `ChallengeHistorySheet` | `lib/tabs/shots/challenger_road/` | History tab content: chronological list of attempt rows for this challenge |
| `ChallengeAttemptHistoryRow` | `lib/tabs/shots/challenger_road/` | Single row: level badge, pass/fail chip, quota result (X/N on target), date |
| `ChallengerRoadStatsCard` | `lib/tabs/profile/` | Per-challenge all-time bests grid (best level, total attempts, total passes); shown in Profile tab |
| `ChallengeStepViewer` | `lib/tabs/shots/challenger_road/` | PageView of media steps |
| `StartChallengeScreen` | `lib/tabs/shots/challenger_road/` | Modified StartShooting for challenge context |
| `ChallengeQuotaIndicator` | `lib/tabs/shots/challenger_road/` | Live "X / N on target" display during session |
| `ChallengeResultScreen` | `lib/tabs/shots/challenger_road/` | Pass/fail full-screen result |
| `ChallengerRoadMilestoneScreen` | `lib/tabs/shots/challenger_road/` | 10K celebration screen |
| `ChallengerRoadTeaserView` | `lib/tabs/shots/challenger_road/` | Blurred map + paywall overlay for free users |
| `ChallengerRoadBadgeBar` | `lib/tabs/profile/` | Badge row for Profile tab |
| `ProgressSection` | `lib/tabs/profile/` | Collapsible section holding pie chart, line chart, target date |

---

## 7. Badges Specification

All badges are visually rendered as circular or shield-shaped widgets with the app's hockey theme.

- `cr_personal_best`: A road/highway icon with a large number overlay. Always shows current best level. Updated automatically (not a one-time award).
- `cr_attempts`: A puck icon with attempt count. 5 tiers: Bronze (1), Silver (3), Gold (10), Platinum (25), Diamond (50).
- Milestone badges (`cr_10k_x1/x3/x10`): Shot counter icon with "×N" overlay. Each tier is a separate badge.
- `cr_level_5`, `cr_level_10`: Trophy icons with level number. Awarded once per milestone.
- `cr_perfect_level`: Star icon. Awarded first time a full level is cleared with zero retries.
- `cr_comeback`: Phoenix/hockey stick rising icon.
- `cr_all_challenges_v1`: Gold road icon. The `v1` suffix is intentional - when new challenges are added, a `v2` version can be introduced without invalidating existing earners.

---

## 8. Admin / PushTable Notes

All global challenge data is managed directly in Firestore via **PushTable** (same workflow as the Explore tab content). No separate admin UI in the Flutter app is required.

**Firestore paths to configure in PushTable:**
- `challenger_road/challenges` - challenge documents
- `challenger_road/challenges/{id}/levels` - level documents

**Field reference for admins:**

*Challenge document:*
| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Display name |
| `description` | string | Player-facing description |
| `active` | bool | Set false to hide from app |
| `steps` | array | Default steps (see below) |
| `createdAt` | timestamp | Auto-set |
| `updatedAt` | timestamp | Update on any edit |

*Level document (inside `levels` subcollection):*
| Field | Type | Notes |
|-------|------|-------|
| `level` | int | 1, 2, 3 … numeric level number |
| `levelName` | string | "Level 1" (display use only) |
| `sequence` | int | Map position at this level. Lower = lower on map. |
| `shotsRequired` | int | Total shots player must take |
| `shotsToPass` | int | Minimum on-target shots to pass |
| `active` | bool | Set false to skip this challenge on this level |
| `steps` | array or null | Optional. If null, inherits from parent challenge. |

*Step object (inside `steps` array):*
| Field | Type | Notes |
|-------|------|-------|
| `stepNumber` | int | Order within the step viewer |
| `title` | string | Step heading (e.g., "Setup") |
| `mediaType` | string | `'video'`, `'image'`, or `'gif'` |
| `mediaUrl` | string | Public Firebase Storage URL |
| `summary` | string | What the player should do |

**To add a Level-3+ only challenge:**
1. Create the challenge document (set `active: true`).
2. Create level sub-documents starting at Level 3 only. Do NOT add Level 1 or 2 docs.
3. The challenge will be invisible on the Level 1/2 map for all users. Level 3 users will see it.

**To reorder challenges on a level:**
1. Edit the `sequence` field on each relevant level document. No challenge document edits needed.

---

## 9. Integration Points with Existing Code

| Existing Code | How Challenger Road Integrates |
|---------------|-------------------------------|
| `lib/services/session.dart` | After saving a `ChallengeSession`, call the same shot-saving logic to write a `ShootingSession` entry to the current `Iteration`. |
| `ChallengerRoadService.saveChallengeSession()` | Must use a Firestore `WriteBatch` to atomically write: (1) `challenge_sessions/{sid}`, (2) upsert `challenge_progress/{challengeId}`, (3) upsert `challenger_road_challenge_history/{challengeId}`. All three succeed or none. |
| `lib/models/firestore/Iteration.dart` | No changes needed. Challenge shots add to `total`, `totalWrist`, etc. via the existing service. |
| `lib/tabs/shots/StartShooting.dart` | `StartChallengeScreen` is a new widget but reuses `ShotButton`, `TargetAccuracyVisualizer`, and `ShotBreakdownDonut` internally. Do not modify `StartShooting.dart` itself - compose from its children. |
| `lib/services/RevenueCat.dart` / `RevenueCatProvider.dart` | Use `CustomerInfoNotifier.isPro` to gate Challenger Road map vs. teaser view. No changes to RevenueCat service. |
| `lib/tabs/Shots.dart` | Conditionally render `ChallengerRoadMapView` (pro) or existing content (free) based on `isPro`. Free path unchanged. |
| `lib/tabs/Profile.dart` | Add collapsible `ProgressSection` and `ChallengerRoadBadgeBar`. Pie chart / line chart moved here from Start tab (pro path). |
| `lib/Navigation.dart` | No tab structure changes needed. Challenger Road lives within the Start tab slot. |
| `assets/animations/goal_light.riv` | Reuse for the 10K milestone celebration and possibly challenge completion. |

---

## 10. Testing Checklist

### Unit Tests
- [x] `ChallengerRoadService.isLevelComplete()` - returns false until all challenges pass _(Phase 12)_
- [x] `ChallengerRoadService.incrementChallengerRoadShots()` - milestone detection at exactly 10,000 and over _(Phase 12)_
- [x] `ChallengerRoadService.restartChallengerRoad()` - starting level = max(1, highest - 1) _(Phase 12)_
- [x] `ChallengerRoadLevel.fromMap()` / `toMap()` round-trip _(Phase 12)_
- [x] `ChallengeSession.fromMap()` / `toMap()` round-trip _(Phase 12)_
- [x] `ChallengeProgressEntry.fromMap()` / `toMap()` round-trip _(Phase 12)_
- [x] `ChallengeAllTimeHistory.fromMap()` / `toMap()` round-trip _(Phase 12)_
- [x] `updateChallengeProgress()` - `bestLevel` updates to max, `totalAttempts` increments, `levelHistory` appended _(Phase 12)_
- [x] `updateChallengeAllTimeHistory()` - `allTimeBestLevel` is max across calls, `allTimeTotalAttempts` increments, `firstPassedAt` set only once _(Phase 12)_
- [ ] Badge award logic - each badge condition fires exactly once (idempotent)

### Integration Tests
- [x] Saving a session atomically updates `challenge_sessions`, `challenge_progress`, and `challenger_road_challenge_history` (all three or none via WriteBatch) _(Phase 12)_
- [x] `challenge_progress.bestLevel` reflects the max level passed across all sessions for that challenge within the attempt _(Phase 12)_
- [ ] `challenger_road_challenge_history.allTimeTotalAttempts` counts sessions across multiple separate attempts correctly
- [ ] Starting a challenge session and saving it updates both `challenge_sessions` and the global `Iteration`
- [ ] Level completion triggers `advanceLevel()` and `highestLevelReachedThisAttempt` is updated
- [x] Restart creates a new attempt with correct `startingLevel` _(Phase 12)_
- [x] 10K milestone: `challengerRoadShotCount` resets, `resetCount` increments, `totalShotsThisAttempt` does not reset _(Phase 12)_

### Widget Tests
- [ ] `ChallengeMapNode` renders correct state for locked/available/completed
- [ ] `ChallengeDetailSheet` shows level-specific steps when available, falls back to challenge steps
- [ ] `StartChallengeScreen` quota indicator updates live with each shot
- [ ] Free user Start tab shows "Start Challenger Road" button; pro user does not
- [ ] Teaser view: map renders but taps are blocked, paywall button visible

### Manual QA
- [ ] Full run: start attempt → complete all Level 1 challenges → level unlocks → advance to Level 2
- [ ] 10K milestone screen fires and counter resets correctly
- [ ] Restart from completed attempt starts 1 level below previous best
- [ ] Free → pro upgrade mid-session updates Start tab without restart
- [ ] New challenge added to Level 2 via PushTable appears on map without breaking Level 1 completions
- [ ] Challenge with no Level 1 doc does not appear at Level 1 on map

---

## Quick Reference Card

```
Firestore paths:
  Global:     challenger_road/challenges/{id}/levels/{lid}
  User state: users/{uid}/challenger_road
              users/{uid}/challenger_road_attempts/{aid}
              users/{uid}/challenger_road_attempts/{aid}/challenge_sessions/{sid}
              users/{uid}/challenger_road_attempts/{aid}/challenge_progress/{cid}
              users/{uid}/challenger_road_challenge_history/{cid}

Pro gate:     CustomerInfoNotifier.isPro (RevenueCatProvider.dart)

Level advance rule:   ALL active challenges at currentLevel must have passed == true session
Restart rule:         newStartingLevel = max(1, previousAttempt.highestLevelReachedThisAttempt - 1)
Quota fields:         ChallengerRoadLevel.shotsRequired, .shotsToPass
Shot double-count:    CR shots → challengerRoadShotCount AND global Iteration.total
                      Normal shots → global Iteration.total ONLY

New file directory:   lib/tabs/shots/challenger_road/
New models dir:       lib/models/firestore/ (6 new files)
New service:          lib/services/ChallengerRoadService.dart
```
