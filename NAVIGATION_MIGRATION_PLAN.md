# Navigation Migration Rollout Plan

Date: 2026-04-01
Owner: App Team
Status: In Progress
Target IA: Option D (Train, Community, Learn, Me)

## Goals
- Simplify primary navigation from 5 tabs to 4 task-oriented tabs.
- Preserve all existing functionality with minimal behavioral regressions.
- Keep migration incremental, reversible, and easy to validate.

## Non-Goals (Phase 1)
- Large visual redesign of individual feature screens.
- Deep route namespace overhaul for every screen.
- Data/model changes.

## Success Criteria
- Bottom navigation is: Train, Community, Learn, Me.
- All existing feature paths remain reachable.
- Friends and Team are grouped under a single Community entry point.
- Legacy tab deep links still resolve without crashes.
- No new analyzer errors in modified files.

## Rollout Phases

### Phase 0: Baseline and Safety
- [x] Capture current nav behavior notes (done in audit).
- [x] Confirm route inventory and high-traffic flows.
- [x] Add migration plan doc and checkpoints.

Exit criteria:
- Migration checklist committed and shared.

### Phase 1: IA Shell Migration (Implement now)
- [x] Create Community hub screen with segmented switch: Friends | Team.
- [x] Update main navigation shell to 4 tabs:
  - Train -> existing Shots
  - Community -> new Community hub
  - Learn -> existing Explore
  - Me -> existing Profile
- [x] Keep existing sub-screens/routing intact.
- [x] Add legacy tab aliases (start/friends/team/explore/profile) to map into new tabs.
- [x] Update obvious return routes to new tab ids where low risk.

Exit criteria:
- App launches and all major areas are accessible from the new shell.
- Legacy tab links still open expected destination.

### Phase 2: Route Ownership Cleanup
- [x] Reorganize routes by section ownership (Train/Community/Learn/Me).
- [x] Standardize tab changes with `go`, details with `push`.
- [x] Remove duplicate navigation entry patterns where possible.

Exit criteria:
- Consistent back-stack behavior across all sections.

Verification notes:
- Focused `flutter analyze` pass completed for migrated navigation files with no issues found.
- Runtime/device smoke test still pending.

### Phase 3: UX Polish and Instrumentation
- [x] Align section titles/action affordances.
- [x] Update analytics screen naming to new IA.
- [x] Add lightweight UX polish for Community switching.

Exit criteria:
- Updated analytics dashboards and stable UX interactions.

Verification notes:
- Community section is now route-synced, so returns into Friends vs Team resolve to the correct sub-section.
- Community app bar title/actions are now contextual to the active sub-section.
- Router routes now expose section-aligned analytics names, including dynamic naming for the `/app` shell tabs.
- Focused `flutter analyze` pass completed after analytics naming changes with no issues found.

## Risk Register
- Risk: Broken deep links due to tab id rename.
  - Mitigation: alias mapper for old tab ids.
- Risk: Discoverability drop for Team actions after merge.
  - Mitigation: keep Team actions visible in Community screen and app bar.
- Risk: Back-stack inconsistencies persist.
  - Mitigation: Phase 2 explicitly standardizes push/go usage.

## Test Checklist (Manual)
- [ ] Login -> lands in Train.
- [ ] Bottom tabs switch correctly among all 4 sections.
- [ ] Community defaults to Friends and can switch to Team.
- [ ] Add Friend works from Community.
- [ ] Team create/join/edit remain reachable.
- [ ] Profile settings/history/edit flows remain reachable from Me.
- [ ] Legacy `/app?tab=team` and `/app?tab=friends` still function.

## Rollback Plan
- Revert `Navigation.dart` and remove `Community.dart`.
- Keep router and old tab names as-is.
- No data migration required.
