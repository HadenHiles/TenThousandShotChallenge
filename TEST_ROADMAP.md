# 10,000 Shot Challenge Test Roadmap

This roadmap lists all major areas to cover with automated tests. For each item, copy and paste the command into Copilot to generate or expand tests using your existing patterns.

---

## Test Coverage Checklist

### 1. Authentication & Onboarding

- [x] Generate tests for user login/logout (email, Google, Apple, etc.) using our existing test patterns.
- [x] Generate tests for registration and error handling using our existing test patterns.
- [x] Generate tests for intro screen logic (shown when not completed previously) using our existing test patterns.

### 2. User Profile

- [ ] Generate tests for profile display and editing (name, photo, skill, privacy) using our existing test patterns.
- [ ] Generate tests for preferences (dark mode, notifications, puck count, etc.) using our existing test patterns.
- [ ] Generate tests for FCM token updates and notification settings using our existing test patterns.

### 3. Friends/Teammates

- [ ] Generate tests for sending, accepting, and declining invites using our existing test patterns.
- [ ] Generate tests for displaying friends list and friend status using our existing test patterns.
- [ ] Generate tests for removing/blocking friends using our existing test patterns.
- [ ] Generate tests for edge cases: duplicate invites, invite to self, etc. using our existing test patterns.

### 4. Teams

- [ ] Generate tests for creating, joining, and leaving teams using our existing test patterns.
- [ ] Generate tests for displaying team info and members using our existing test patterns.
- [ ] Generate tests for team owner actions (removing members, disbanding team) using our existing test patterns.
- [ ] Generate tests for team progress and leaderboard using our existing test patterns.

### 5. Iterations/Challenges

- [ ] Generate tests for creating and completing iterations using our existing test patterns.
- [ ] Generate tests for displaying progress, history, and stats using our existing test patterns.
- [ ] Generate tests for handling multiple/completed iterations using our existing test patterns.
- [ ] Generate tests for edge cases: overlapping, missing, or corrupted data using our existing test patterns.

### 6. Sessions & Shots

- [ ] Generate tests for adding sessions and shots using our existing test patterns.
- [ ] Generate tests for editing/deleting sessions using our existing test patterns.
- [ ] Generate tests for calculating totals and accuracy using our existing test patterns.
- [ ] Generate tests for UI for high-volume data (charts, lists, summaries) using our existing test patterns.

### 7. Widgets & Navigation

- [x] Generate tests for tab navigation and deep linking using our existing test patterns.
- [x] Generate tests for widget rendering for all major screens (Profile, Team, Shots, etc.) using our existing test patterns.
- [x] Generate tests for responsive layout and error states using our existing test patterns.

### 8. Notifications

- [ ] Generate tests for receiving and handling push notifications using our existing test patterns.
- [ ] Generate tests for in-app notification display and badge updates using our existing test patterns.

### 9. Data Sync & Offline

- [ ] Generate tests for syncing with Firestore (mock vs. emulator) using our existing test patterns.
- [ ] Generate tests for handling offline mode and re-sync using our existing test patterns.

### 10. Edge Cases & Regression

- [ ] Generate tests for permissions (camera, notifications) using our existing test patterns.
- [ ] Generate tests for data migration/upgrade scenarios using our existing test patterns.
- [ ] Generate tests for error boundaries and fallback UI using our existing test patterns.

---

**Tip:** For any item above, just copy and paste the command into Copilot to generate or expand tests for that area!
