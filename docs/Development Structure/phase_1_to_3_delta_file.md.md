# Brainiax Puzzles — Epic Delta / Work Completed So Far

Generated: 2026-05-26  
Repo inspected: `brainiax-developers/brainiax_puzzles`  
Primary branch context: `feat/phase3-play-ux`  
Companion docs: `brainiax_roadmap_jira.md`, `brainiax_dev_task_breakdown.md`, `prd.md`

---

## 0. Purpose

This file is a compact delta record for AI agents and future contributors. It answers:

- What was originally planned at the epic / phase level?
- What has actually been completed so far?
- What changed from the PRD or earlier roadmap?
- What should still be treated as incomplete, risky, or needing QA?

Use this as a source-of-truth supplement, not a replacement for the roadmap or dev task breakdown.

---

## 1. Current high-level state

| Epic / Phase | Planned intent | Current status | Delta summary |
|---|---|---:|---|
| Phase 0 | Environment & scaffolding | Done | Flutter project, Firebase environments, Melos, CI/CD, lint/analyze baseline completed. |
| Phase 1 | App foundation / repo setup | Done | Theme/layout, Riverpod, routing, asset loading, and puzzle-core integration groundwork completed. |
| Phase 2 | Puzzle core | Done | Deterministic pure-Dart engine layer implemented for the current V1 logic roster, with generation/validation/solving/difficulty APIs. |
| Phase 3 | Game UX & play screens | Feature-complete / hardening needed | PR #30 merged with selection flow, daily/random flows, play screen, timer, undo/redo, hints, renderers, local persistence, telemetry, app icon, privacy policy entry, and UI fixes. Needs fresh QA after project restart. |
| Phase 4 | Accounts & cloud sync | Not started / minor Firebase groundwork only | Firebase setup exists, but user sync, anonymous upgrade, Firestore stats, streak sync, and conflict handling still need implementation. |
| Phase 5 | Monetization | Not started | Ads and Remote Config monetization rules remain future work. |
| Phase 6 | Content expansion | Not started | Word puzzles and any additional puzzle types remain future work. |
| Phase 7 | Leaderboards & events | Not started | Weekly leaderboards and event surfaces remain future work. |
| Phase 8 | Accessibility & store prep | Partial | Some theming/haptics/app-icon/privacy-policy work exists; full accessibility QA and store release prep are not done. |
| Phase 9 | Launch & soft release | Not started | Requires Phase 3 hardening plus Phase 4/5/7 minimum viable production stack. |
| Post-V1 | Multiplayer / anti-cheat / subscriptions | Deferred | Out of V1 scope by product decision. |

Plain English: the app has moved from “foundation and engines” into “playable local app,” but it is not yet a cloud-synced, monetized, launch-ready product.

---

## 2. Evidence snapshot

These are the concrete repo/project facts this delta is based on.

| Evidence | What it proves |
|---|---|
| PR #30 `Feat/phase3 play ux` was merged into `main` on 2026-01-01 with 45 commits, 271 changed files, ~25k additions, and ~6.6k deletions. | Phase 3 was not just a branch name; it was merged as a large feature PR. |
| `packages/puzzle_core/lib/puzzle_core.dart` exports Sudoku, Nonogram, Kakuro, Slitherlink, Mathdoku, Killer Queens, and Takuzu implementations. | The current logic-puzzle engine roster is implemented and publicly exposed. |
| `apps/app/lib/app_router.dart` defines `/puzzles`, `/select`, `/play/:puzzleType/:mode`, `/daily`, `/profile`, `/settings`, and `/bench`. | Phase 3 navigation and play routing exist. |
| `apps/app/lib/features/play/play_screen.dart` handles puzzle type, mode, generated puzzle instances, daily generation, random generation, timer state, hints, persisted progress, and UI state. | Core play-screen UX exists, though it still needs device QA. |
| `apps/app/lib/shared/providers/game_state_provider.dart` contains start-new-game, start-with-generated-puzzle, move validation, undo/redo, notes, hint requests, solve tracking, and some puzzle-specific behavior. | Game session state management exists. |
| `apps/app/lib/shared/services/puzzle_progress_service.dart` stores the last in-progress puzzle per puzzle type via `SharedPreferences`. | Local continue-game/persistence support exists. |
| `apps/app/lib/features/daily/daily_seed_generator.dart` and `daily_providers.dart` generate deterministic daily seeds and daily puzzles. | Daily challenge generation exists locally and remains aligned with the “no hosted boards” architecture. |

---

## 3. Epic-by-epic delta

### EPIC 0 — Environment & Scaffolding

**Original goal**  
Create a functioning Flutter project with Android-first setup, Firebase environments, Melos monorepo, CI/CD, and linting.

**Completed**

- Flutter project initialized and app launch path established.
- Base app navigation created.
- Firebase multi-environment setup planned and wired around `dev`, `staging`, and `prod` flavors.
- Melos monorepo configured.
- GitHub Actions CI/CD created.
- Shared lint/analyze setup standardized.

**Delta from plan**

- No major product delta. This phase is stable foundation work.

**Remaining work**

- Re-run all bootstrap commands after the long break.
- Verify Android Studio launch config still points to the correct app path and `dev` flavor.
- Confirm Firebase config files are present locally and not accidentally missing due to `.gitignore` or machine migration.

**Recommended closeout command set**

```bash
git fetch --all --prune
flutter doctor
melos bootstrap
melos analyze
melos test
cd apps/app
flutter run --flavor dev -t lib/main.dart
```

---

### EPIC 1 — Foundation & Repo Setup

**Original goal**  
Build shared UI foundation, global state management, routing, asset loading, and integration seams for `puzzle_core`.

**Completed**

- Shared UI theme and layout system created.
- Riverpod state management integrated.
- `go_router` route system integrated.
- Base navigation routes and feature screens established.
- Asset loading pipeline started.
- Early puzzle-core integration test work started.

**Delta from plan**

- This epic appears complete and has been extended by later Phase 3 UI work.
- The app moved beyond shell navigation into real puzzle selection and play routing.

**Remaining work**

- Validate route naming and screen ownership before Phase 4.
- Remove or clearly hide unfinished Profile/Stats surfaces until sync exists.
- Confirm theme settings persist correctly and are covered by widget tests.

---

### EPIC 2 — Puzzle Core

**Original goal**  
Implement deterministic, on-device puzzle engines, separate from Flutter UI, with generation, validation, solving, and difficulty scoring.

**Completed**

- Pure-Dart `packages/puzzle_core` package exists.
- Stable public API exists around `PuzzleEngine`, `EngineRegistry`, `GeneratedPuzzle`, metadata, move validation, hints, size options, and difficulty score types.
- Deterministic generation principle is implemented around seed strings and 64-bit seeds.
- Current logic puzzle roster implemented:
  - Sudoku
  - Nonogram
  - Kakuro
  - Mathdoku
  - Killer Queens
  - Slitherlink
  - Takuzu
- Benchmark and performance infrastructure exists.
- Engine exports are available through `puzzle_core.dart`.

**Delta from plan**

- **Futoshiki was replaced by Killer Queens / Queens.** Futoshiki should not be added to V1 or Phase 6 unless explicitly re-scoped by a future product decision.
- Word puzzle engines are not part of the completed core roster yet.
- Some README text may still contain old/future wording from earlier engine milestones; trust code exports and tests over old prose.

**Remaining work**

- Re-run full engine tests and benchmarks.
- Run deterministic seed regression tests across every supported puzzle type and difficulty.
- Confirm all engines support serialization/deserialization cleanly for local persistence and future cloud metadata sync.
- Verify generation p95 targets after recent UI/isolate changes.

**Recommended closeout tasks**

```bash
melos test
melos run perf_gate
dart bin/bench.dart --engines "sudoku_classic,nonogram_mono,kakuro_classic,slitherlink_loop,mathdoku_classic,killer_queens,takuzu_binary" --count 100
```

---

### EPIC 3 — Game UX & Play Screens

**Original goal**  
Turn puzzle engines into an actual playable app: puzzle selection, daily/random play, board renderers, input handling, hints, timer, persistence, polish, and performance-safe generation.

**Completed / merged**

- PR #30 `Feat/phase3 play ux` merged.
- Puzzle registry and routes added.
- Puzzle selection screen added.
- Puzzle-type favourites and the Puzzle Library Favourites filter were added/refined as local-first UX features.
- Favourite Puzzle quick play was added/refined for the Home surface.
- Daily seed and “today’s puzzle” generation added.
- Random play flow added.
- Async puzzle-generation controller added.
- Puzzle play view model / game state added with timer and undo support.
- Local puzzle store / progress persistence added.
- `PuzzleRenderer` base and per-puzzle renderers added/refined.
- Solve/completion tracking added locally.
- Hint capabilities, hint UI, hint animation, and haptics added.
- How to Play / tutorial entry points are required for every puzzle type; full tutorial content can remain future work if entry points are safe.
- Local queue telemetry service added.
- Testing, performance, and coverage infrastructure expanded.
- Sudoku, Nonogram, Kakuro, Slitherlink, Mathdoku, Killer Queens, and Takuzu UI/logic issues were iteratively fixed.
- Kakuro generation moved toward background/on-demand generation to reduce blocking and improve reliability.
- Slitherlink uniqueness/generation handling was iteratively hardened.
- App icon added.
- Privacy policy button added.

**Delta from plan**

- Phase 3 appears larger than originally scoped. It swallowed a lot of engine hardening, puzzle-specific bug fixing, performance work, and UI polish.
- Branch `feat/phase3-play-ux` still exists even though PR #30 is merged. This is a repo hygiene risk.
- The code is probably playable, but after a long project break it must be treated as **unverified**, not launch-ready.

**Known hardening needs**

- Verify How to Play entry points exist for every puzzle type; full tutorial content can remain a later Phase 8 task.
- Add or verify safe generated puzzle titles from bundled local title templates if title UI is shown.

- Manual end-to-end device QA for every puzzle type:
  - open puzzle
  - choose difficulty
  - generate puzzle
  - make valid/invalid moves
  - use notes where relevant
  - undo/redo
  - use hints
  - pause/resume or background/foreground
  - complete puzzle
  - verify completion state
  - continue saved game
- Route-state QA:
  - direct `/play/:puzzleType/:mode`
  - legacy `/play/:type`
  - invalid puzzle/mode params
  - navigating with and without `state.extra`
- Persistence QA:
  - app restart
  - per-puzzle progress save/load
  - stale/corrupt saved state handling
  - puzzle type migration if engine/state schemas changed
- Performance QA:
  - generation latency
  - UI jank during generation
  - isolate timeout handling
  - low-end Android device test
- Test debt:
  - widget tests for select/play/daily flows
  - integration smoke test for all puzzle types
  - golden-ish renderer sanity tests where practical

**Recommended closeout status**

Treat Phase 3 as: **Implemented, merged, awaiting stabilization pass.**

Do not start major Phase 4 work until baseline checks pass.

---

### EPIC 4 — Accounts & Cloud Sync

**Original goal**  
Use Firebase for lightweight auth and metadata sync: anonymous users by default, optional Google/Apple upgrade, Firestore-backed stats, streaks, and cross-device continuity.

**Completed**

- Firebase environment concept exists from earlier setup.
- Auth/Crashlytics/Analytics are planned in the PRD.
- Some app bootstrap glue may exist, but full product behavior is not complete.

**Not completed**

- Anonymous-user lifecycle as a fully tested product path.
- Google sign-in account upgrade.
- Apple sign-in account upgrade.
- `linkWithCredential()` merge flow.
- Firestore schema for user profile, stats, streaks, completions, and sync queue.
- Offline-first sync queue with conflict handling.
- Sync status UI.
- Privacy/account management screens.

**Delta from plan**

- Cloud sync was correctly deferred until after playable local UX.
- This is now the next major development phase.

**Recommended next epic split**

1. Auth foundation and user identity.
2. Local stats model and repository abstraction.
3. Firestore schema and security rules.
4. Offline sync queue.
5. Streak/stat cloud sync.
6. Account upgrade and merge.
7. Profile/stats UI.
8. Analytics and Crashlytics event audit.

---

### EPIC 5 — Monetization

**Original goal**  
Add ads-based monetization: banners, rewarded hints/streak savers, optional interstitials controlled by Remote Config; ad-free pass deferred.

**Completed**

- No production monetization implementation confirmed.
- PRD has monetization strategy.

**Not completed**

- AdMob setup.
- Banner ad placement.
- Rewarded-ad hint flow.
- Streak Saver flow.
  - Max 2 savers.
  - User does not start with 2 automatically.
  - Earn only by completing all daily puzzles for a day or by watching a rewarded ad when eligible.
  - Protects one missed Daily Challenge streak day; no auto-refill.
- Interstitial frequency rules.
- Remote Config integration for monetization values.
- Consent/privacy handling for ads.
- Ad QA across dev/staging/prod.

**Delta from plan**

- Streak Saver rules are now defined, but implementation remains future work in monetization/rewarded-ad scope.
- Monetization remains future work.
- Keep it after Phase 4 basics because ads need user/event context and Remote Config hygiene.

---

### EPIC 6 — Content Expansion

**Original goal**  
Add more puzzle content, especially word puzzles, after the core logic puzzle foundation is stable.

**Completed**

- Logic puzzle roster is broad and usable.
- Current V1 logic roster shifted from Futoshiki to Killer Queens.

**Not completed**

- Crossword mini.
- Word Search.
- Anagram Scramble.
- Cryptogram.
- Word Ladder.
- Word list/content curation pipeline.
- Localization-aware word puzzle handling.

**Delta from plan**

- Word puzzles remain entirely future-facing.
- Avoid adding word puzzles before Phase 4/5 unless the goal changes from launch to content experimentation.

**Recommendation**

For V1, consider launching with the current seven logic puzzles first. Word puzzles can be a Phase 6 expansion or V1.1. Shipping seven polished puzzle types beats shipping twelve half-cooked ones. Users notice smoke.

---

### EPIC 7 — Leaderboards & Events

**Original goal**  
Weekly leaderboards by puzzle type, best/fastest times, daily challenge ranking, and event-style engagement loops.

**Completed**

- Local completion tracking exists.
- Timers and puzzle-completion metadata exist locally.

**Not completed**

- Firestore leaderboard collections.
- Leaderboard write path.
- Leaderboard read/display UI.
- Weekly reset/windowing rules.
- Basic abuse prevention.
- Event configuration model.
- Ranking logic by puzzle type/difficulty/mode.

**Delta from plan**

- Leaderboards depend on Phase 4 identity and sync. Correctly deferred.
- Product decision: show rank only if the user is in the top 1000. Hide rank or show neutral copy otherwise. Fake social proof is not allowed.
- Anti-cheat remains out of V1, but basic sanity validation is still needed before accepting leaderboard submissions.

**Recommended minimal V1 leaderboard policy**

- Only daily challenges count.
- Submit completion metadata, not puzzle boards.
- Include puzzle type, difficulty, date, elapsed time, hints used, mistakes if tracked, app version, engine version, and seed metadata.
- Reject obviously impossible times client-side and server-side rules/function-side where feasible.

---

### EPIC 8 — Accessibility & Store Prep

**Original goal**  
Make the app usable and store-ready: accessibility, haptics, color-safe themes, privacy policy, app icon, Android/iOS release prep, screenshots, metadata, crash monitoring.

**Completed / partial**

- Haptics added in Phase 3 paths.
- Theme and UI polish work exists.
- App icon added.
- Privacy policy button added.
- Benchmark screen exists behind hidden home-title taps.

**Not completed**

- Full accessibility audit.
- Large-font/device text-scale testing.
- Screen reader traversal testing.
- Color contrast verification for all puzzle renderers.
- Store listing copy.
- Screenshot generation.
- Play Console setup/release track validation.
- Production analytics/crash QA.
- iOS TestFlight readiness.

**Delta from plan**

- Store-prep started incidentally, but this epic is not complete.
- Accessibility must be tested specifically on puzzle grids; generic Flutter accessibility is not enough.

---

### EPIC 9 — Launch & Soft Release

**Original goal**  
Ship Android-first soft release, collect analytics/crashes, tune retention, then prepare broader release and iOS.

**Completed**

- No launch work completed.

**Not completed**

- Internal testing release.
- Closed testing release.
- Production signing/release automation verification.
- Store listing.
- Analytics dashboards.
- Crash-free session targets.
- Retention/event funnels.
- Soft launch checklist.

**Delta from plan**

- No major delta. Launch remains downstream of Phase 3 hardening, Phase 4 cloud sync, Phase 5 monetization, and Phase 7 minimum leaderboards.

---

## 4. Product deltas and decisions made so far

### 4.1 Futoshiki replaced by Killer Queens / Queens

The earlier PRD/roadmap referenced Futoshiki. Current code and Phase 3 work use Killer Queens / Queens instead.

**Decision status:** Killer Queens / Queens replaces Futoshiki for V1. Futoshiki should not be added unless explicitly re-scoped in a future product decision.  
**Impact:** Update PRD/marketing copy to avoid stale puzzle names and prevent future agents from adding Futoshiki from stale docs.  
**Risk:** Future agents may reintroduce Futoshiki from stale PRD/roadmap text. Keep docs updated so Futoshiki is not added accidentally.


### 4.1A Daily Challenge streak only

V1 has exactly one streak: the Daily Challenge streak. Completing at least one Daily Challenge puzzle during the UTC daily window secures/advances the streak. Random Play does not affect streaks. Global streaks and per-puzzle-type streaks are removed from V1 scope.

### 4.1B Streak Savers deferred to monetization

Streak Savers are a future Phase 5 monetization/rewarded-ad feature. They can be earned only by completing all daily puzzles for a day or by watching a rewarded ad when eligible. Users can hold at most 2. They do not auto-refill.

### 4.1C Puzzle-type favourites

Puzzle-type favourites were added/refined as a local-first UX feature. Favourites power the Puzzle Library Favourites filter and Home Favourite Puzzle quick play. Favourites are puzzle types, not generated puzzle instances.

### 4.1D Tutorials, safe titles, and rank display

Every puzzle type should expose a safe How to Play entry point. Random/saved puzzle runs may use safe cosmetic titles from bundled local templates. Leaderboard rank should only be displayed when the user is in the top 1000; fake rank and fake social proof are not allowed.

---

### 4.2 Daily puzzles stay on-device

Earlier discussion considered whether daily boards should be stored in Firebase. The better architecture remains deterministic local generation from daily seeds.

**Decision status:** Accepted.  
**Impact:** Firestore should sync completions/stats/leaderboards, not board payloads.  
**Risk:** Daily seed bugs can create cross-device inconsistency, so seed tests matter.

---

### 4.3 Android first, iOS later

The PRD remains Android-first. iOS should not block local Android gameplay and cloud sync.

**Decision status:** Accepted.  
**Impact:** Keep iOS compiling when practical, but do not let iOS polish derail Android V1.  
**Risk:** Postponing iOS too long can create plugin/config drift. Run occasional iOS CI if available.

---

### 4.4 Multiplayer and serious anti-cheat deferred

The app can have leaderboards, but not a high-stakes competitive architecture in V1.

**Decision status:** Accepted.  
**Impact:** Build simple sanity checks, not a fortress.  
**Risk:** Leaderboard spam/cheating can still hurt trust. Keep leaderboard scope narrow.

---

## 5. Branch and repo hygiene delta

Current notable issue: `feat/phase3-play-ux` still exists even though PR #30 merged.

Before new feature work:

```bash
git fetch --all --prune
git checkout main
git pull
git checkout feat/phase3-play-ux
git status
git diff --stat main...feat/phase3-play-ux
git log --oneline --decorate --graph --all -50
```

Expected decision:

| Situation | Action |
|---|---|
| Branch has no meaningful diff from `main` | Delete/archive branch and continue from fresh Phase 4 branch off `main`. |
| Branch has small meaningful diff | Cherry-pick or PR the diff into `main`, then delete/archive branch. |
| Branch has large meaningful diff | Open a reconciliation PR before any Phase 4 work. |

Recommended next branch:

```bash
git checkout main
git pull
git checkout -b feat/phase4-cloud-sync-foundation
```

---

## 6. Current done/not-done boundary

### Done enough to preserve

- Project scaffolding.
- Monorepo setup.
- Firebase flavor direction.
- App foundation with Riverpod and routing.
- Deterministic puzzle core for current logic roster.
- Phase 3 local gameplay features.
- Local daily/random generation.
- Local puzzle progress persistence.
- Hint/polish/haptics groundwork.
- Benchmark/performance infrastructure.

### Not done enough to trust in production

- Phase 3 QA across all puzzle types and devices.
- Cloud identity and sync.
- Firestore security rules.
- Profile/stats product behavior.
- Monetization.
- Leaderboards.
- Accessibility audit.
- Store release setup.
- Soft launch operations.

### Must not be assumed

- That every puzzle currently completes correctly on-device.
- That every saved puzzle can be restored after schema changes.
- That `main` and `feat/phase3-play-ux` are cleanly reconciled.
- That tests still pass after the long break.
- That Firebase dev/staging/prod credentials are still present locally.

---

## 7. Recommended immediate Jira epics from this delta

### BX-E3-HARDEN — Phase 3 Stabilization

**Goal:** Prove the merged local play app works.  
**Exit criteria:** All seven current puzzle types pass manual smoke, automated tests pass, performance gate passes, and branch reconciliation is complete.

Suggested stories:

- BX-E3-HARDEN-01 — Reconcile `feat/phase3-play-ux` with `main`.
- BX-E3-HARDEN-02 — Run and fix `melos analyze` / `melos test`.
- BX-E3-HARDEN-03 — Create all-puzzle manual QA checklist.
- BX-E3-HARDEN-04 — Add app-level smoke/integration tests for select → play → complete.
- BX-E3-HARDEN-05 — Validate local persistence and continue-game flows.
- BX-E3-HARDEN-06 — Run host/device benchmarks and fix regressions.
- BX-E3-HARDEN-07 — Verify How to Play entry points for all puzzle types.
- BX-E3-HARDEN-08 — Verify puzzle-type favourites, Favourite Puzzle quick play, and Favourites filter.
- BX-E3-HARDEN-09 — Add/verify safe generated puzzle titles if title UI is shown.

---

### BX-E4 — Accounts & Cloud Sync Foundation

**Goal:** Introduce Firebase-backed identity and metadata sync without touching puzzle board hosting.

Suggested stories:

- BX-E4-01 — Auth bootstrap and anonymous sign-in product flow.
- BX-E4-02 — Local user profile/stats domain model.
- BX-E4-03 — Firestore schema and security rules.
- BX-E4-04 — Completion event repository abstraction.
- BX-E4-05 — Offline sync queue.
- BX-E4-06 — Daily Challenge streak sync.
- BX-E4-09 — Puzzle-type favourites sync.
- BX-E4-07 — Google/Apple upgrade and anonymous merge.
- BX-E4-08 — Profile/stats UI v1.

---

### BX-E5 — Monetization Foundation

**Goal:** Add non-intrusive ad monetization after core identity and stats are stable.

Suggested stories:

- BX-E5-01 — AdMob setup for dev/staging/prod.
- BX-E5-02 — Remote Config monetization policy.
- BX-E5-03 — Banner ad shell placement.
- BX-E5-04 — Rewarded hint flow.
- BX-E5-05 — Streak Saver earning/consumption.
- BX-E5-06 — Consent/privacy handling.
- BX-E5-06 — Monetization QA.

---

### BX-E7 — Leaderboards MVP

**Goal:** Add simple, weekly, puzzle-type leaderboards with low-cost Firebase backend.

Suggested stories:

- BX-E7-01 — Leaderboard data model.
- BX-E7-02 — Completion submission path.
- BX-E7-03 — Weekly ranking query/read model.
- BX-E7-04 — Leaderboard UI with top-1000 rank display rule.
- BX-E7-05 — Basic abuse/sanity checks.

---

## 8. Cursor / Codex guidance from the delta

### Cursor should handle

- Flutter UI fixes and QA-driven polish.
- Riverpod provider cleanup.
- Firebase repository/service scaffolding.
- Profile/stats screens.
- Widget tests and integration smoke tests.

### Codex should handle

- Repo-wide refactors.
- Test expansion across packages.
- Firestore model/rules review.
- Performance-regression fixes.
- Repetitive renderer consistency work.

### Do not ask agents to do yet

- Add word puzzles before Phase 3 is stable.
- Add monetization before auth/sync decisions are stable.
- Add multiplayer/anti-cheat.
- Store daily puzzle boards in Firebase.
- Rewrite puzzle engines unless a failing test proves it is necessary.

---

## 9. One-page resume checklist

Start here when reopening the project:

```bash
git fetch --all --prune
git checkout main
git pull
git branch -vv
git checkout feat/phase3-play-ux
git diff --stat main...feat/phase3-play-ux
melos bootstrap
melos analyze
melos test
cd apps/app
flutter run --flavor dev -t lib/main.dart
```

Then manually test:

- Sudoku
- Nonogram
- Kakuro
- Slitherlink
- Mathdoku
- Killer Queens
- Takuzu
- Daily challenge
- Random play
- Continue game
- Hint flow
- Settings/theme/haptics
- Bench screen

Only after that, create:

```bash
git checkout main
git pull
git checkout -b feat/phase4-cloud-sync-foundation
```

---

## 10. Final state summary

The project has already accomplished the hard early work: architecture, deterministic engines, and local playable UX. The next risk is not “can this app be built?” — it clearly can. The next risk is quality discipline: stabilizing Phase 3 before piling Firebase sync and ads on top.

Recommended next move:

1. Reconcile branch state.
2. Re-run tests and benchmarks.
3. Manually QA all seven current puzzle types.
4. Fix Phase 3 regressions.
5. Start Phase 4 cloud sync on a clean branch.

Do that, and this project moves from “cool prototype with muscle” to “real product pipeline.”
