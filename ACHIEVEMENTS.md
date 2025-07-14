# Weekly Achievements Feature Plan

## Overview

- **Purpose:** Motivate users to diversify their training and improve consistency by providing weekly achievements.
- **Location:** Achievements will be surfaced in the Start tab for easy access and tracking.

## Feature Breakdown

### 1. Achievement Generation

- Each week, generate a set of achievements for every user.
- Target shot types the user has not practiced recently (based on their shot history).
- Example basic achievement: "Take 25 backhands in your next 3 shooting sessions."
- Pro users receive tailored achievements based on their accuracy stats (e.g., "Achieve 70% accuracy on wrist shots this week").
- Achievements should be reasonable and encourage variety and improvement.

### 2. Data Model

- **Achievement:**
  - `id`, `title`, `description`, `shotType`, `goalType` (e.g., count, accuracy), `goalValue`, `difficulty` (Easy, Hard, Hardest, Impossible), `timeFrame` (e.g., week), `completed`, `dateAssigned`, `dateCompleted`, `userId`, `proLevel` (bool), `isBonus` (for Impossible achievements)
- Store achievements in Firestore under each user (e.g., `userAchievements` collection).

### 3. UI Integration

- Display current weekly achievements in the Start tab.
- Show progress (e.g., shots taken, accuracy, sessions completed).
- Achievements are automatically checked off when the user completes the required actions; there is no manual check-off option.
- Provide feedback and rewards (badges, points, etc.) for completion.
- Show the user's achievement streak in their profile, along with a running count of how many achievements they've completed in their lifetime, including a badge on their profile image with the number of consecutive weeks they've completed every achievement.

### 4. Achievement Assignment Logic

- Run a weekly job (cloud function or app logic) to assign new achievements:
  - Analyze user shot history to find under-practiced shot types.
  - For pro users, analyze accuracy stats to set tailored goals.
  - Assign 2–4 achievements per week, mixing basic and pro-level goals.

### 5. Gamification & Rewards

- Award badges, points, or other incentives for completing achievements.
- Track achievement streaks for consecutive weeks in which the user completes every assigned achievement.
- Show achievement streak and achievement history in the profile tab.
- Impossible bonus achievements do not affect the user's streak if not completed, but provide extra rewards if achieved.

### 6. Achievement Swap Feature

- Allow users to swap any given achievement in their weekly list for a new random achievement of the same difficulty.
- Implement a progressive timeout for swaps:
  - 3 swaps allowed with no delay
  - 4th swap: 1 minute delay
  - 5th swap: 3 minutes delay
  - 6th swap: 5 minutes delay
  - 7th swap: 10 minutes delay
  - 8th swap: 20 minutes delay
  - Maximum delay: 1 day
- Show swap availability and timeout status in the UI.

### 7. Testing & QA

- Test achievement assignment logic for variety and fairness.
- Test UI for progress tracking and completion feedback.

---

## High-Level Integration Instructions

1. **Data Model:**
   - Add `userAchievements` collection in Firestore.
2. **Backend Logic:**
   - Implement weekly assignment logic (cloud function or app-side).
3. **UI:**
   - Display weekly achievements and progress in the Start tab.
   - Show achievement history in the profile tab.
4. **Gamification:**
   - Award badges/points for completion and track streaks.

Let me know if you want sample code, Firestore structure, or UI mockups for any part!
