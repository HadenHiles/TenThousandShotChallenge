# Challenges Feature Plan

## Overview

- **Purpose:** Provide pro users with curated shooting drills (challenges) to improve accuracy.
- **Core Elements:**
  - Each challenge has its own accuracy history, separate from global accuracy.
  - Video/GIF demonstrations for each challenge.
  - Clear instructions and rules.
  - Gamified scoring based on accuracy and consistency.
  - Challenge data contributes to total shots taken, with shot type inferred from challenge metadata.

## Feature Breakdown

### 1. Challenge Data Model (Global/Admin)

- **Fields:**
  - `id`, `name`, `description`, `instructions`, `steps`: array of step objects
    - Each step: `{ stepNumber, title, mediaType, mediaUrl (gif/photo), instructions }`
  - `finalDemoUrl`: short video demonstrating the entire drill
  - `shotType`, `difficulty`, `active`, `createdBy`, `highScore`, `consistencyStreak`, etc.
  - `accuracyHistory`: array of ChallengeSession objects
    - Each ChallengeSession: `{ sessionId, timestamp, shotsTaken, accuracyPercentage, shots: [shot objects] }`
    - Each shot object: `{ shotId, stepNumber, shotType, result (made/missed), timestamp, ... }`
  - ChallengeSession shot logging should follow the same structure and logic as existing ShootingSession Firestore documents
- **Challenge Sessions:**
  - Structure mimics `ShootingSessions` (track shots, accuracy, timestamps, etc.)
  - Each session is tied to the current Iteration (Challenge)
  - Store per-session step results, overall accuracy, streaks, and metadata
- **Admin Metadata:**
  - Set shot type(s), difficulty, steps, and other parameters for each challenge.

### 2. Challenge Data Management

- Challenge data will be managed directly in Firestore using PushTable, following the same workflow as the Explore tab. No separate admin UI is required.

### 3. Challenge UI

- **List View:**
  - Display available challenges with preview (title, media, difficulty).
- **Detail View:**
  - Show instructions, demonstration media, and start button.
- **Start Challenge:**
  - Re-use "Start Shooting" UI, but scoped to the selected challenge.
  - Track shots, accuracy, and streaks for the challenge.

### 4. Accuracy & Gamification

- **Accuracy History:**
  - Store per-challenge accuracy stats.
- **Gamified Scoring:**
  - High score updates when user achieves a streak of high accuracy.
  - Visual feedback for streaks, badges, or leaderboards.

### 5. Data Integration

- **Shot Logging:**
  - Challenge shots contribute to global shot count.
  - Shot type inferred from challenge metadata.
- **Profile Integration:**
  - Show challenge stats in user profile.

### 6. Media Integration

- Support video/GIF display in challenge detail view.
- Media Upload & Configuration:
  1. Configure Firebase Storage in your Firebase Console.
  2. Use the Firebase Console or your app to upload GIFs, photos, and videos for challenge steps and demos.
  3. After upload, copy the public download URL for each file.
  4. When updating challenge data in PushTable, paste the media URLs into the appropriate fields (e.g., `mediaUrl`, `finalDemoUrl`, or step media).
  5. Ensure your Firestore security rules allow read access to these media files for your app users.

### 7. Profile & Stats

- Update profile page to show challenge stats and history.
- Ensure challenge shots update global stats.

### 8. User-Created Challenges

- Allow users to create their own custom challenges, separate from global/admin challenges.
- User-created challenges will have simplified metadata (e.g., name, description, steps, media, shot type).
- Each user's custom challenges will be stored in a separate Firestore collection (e.g., `userChallenges`), linked to their account.
- Track accuracy history and gamification stats for user-created challenges independently from global challenges.
- Provide UI for users to view, edit, and start their own challenges, with similar session and shot logging as global challenges.


### 9. Testing & QA

- Write unit/integration tests for challenge flow, accuracy tracking, and gamification.
- Test UI consistency with "Start Shooting".

---

## High-Level Integration Instructions

1. **Navigation:**
   - Move Friends access to the Profile tab (e.g., as a button or section).
   - Use the previous Friends tab slot (index 1) for a dedicated Challenges tab in your main navigation (`NavigationTab`).
2. **Start Screen:**
   - Add a section to the Shots/Start tab to show recent challenges and provide quick access to start a challenge.
3. **Challenge List & Detail:**
   - Create a new page to list challenges from Firestore, accessible from the new Challenges tab and/or the Shots/Start tab.
   - Show instructions, media, and start button for each challenge.
4. **Start Challenge:**
   - Re-use `StartShooting` UI, passing challenge context.
   - Log shots with challenge ID and inferred shot type.
5. **Stats & Profile:**
   - Update user profile to show challenge stats and provide access to Friends features.
6. **Gamification:**
   - Implement streak/high score logic and UI feedback.
7. **Challenge Data Management:**
   - Manage challenge data via PushTable as described above.
