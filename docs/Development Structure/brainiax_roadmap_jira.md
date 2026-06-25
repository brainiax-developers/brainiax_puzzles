# Brainiax Puzzles — End-to-End Roadmap / Jira Backlog

Generated: 2026-05-26  
Primary repo branch inspected: `feat/phase3-play-ux`  
Repo: `brainiax-developers/brainiax_puzzles`  
Project namespace: `com.brainiax.puzzles`

---

## 0. How to use this file

This is a Jira-style roadmap intended to be uploaded into project sources and used by Cursor/Codex as the product execution spine.

Recommended Jira hierarchy:

- **Initiative:** Brainiax V1 Launch
- **Epics:** Phase 0 through Phase 9, plus Post-V1
- **Stories:** User-visible deliverables or technical milestones
- **Tasks/Subtasks:** Implementation work under each story

Suggested Jira fields:

| Field | Suggested value |
|---|---|
| Project | Brainiax Puzzles |
| Issue Key Prefix | `BX` |
| Issue Types | Epic, Story, Task, Bug, Spike |
| Workflow | Backlog → Selected → In Progress → Code Review → QA → Done |
| Priority | P0 blocker, P1 high, P2 normal, P3 polish |
| Components | App, Puzzle Core, Firebase, Ads, Analytics, QA, Store, Docs |
| Labels | `phase-0`, `phase-1`, `phase-2`, `phase-3`, etc. |

---

## 1. Current reconstructed status

### Confirmed / treated as complete

| Phase | Name | Status | Evidence / Notes |
|---|---:|---|---|
| Phase 0 | Environment & Scaffolding | Complete | Flutter project, base navigation, Firebase flavors, Melos, CI/CD, linting are marked complete in project instructions and PRD history. |
| Phase 1 | Foundation & Repo Setup | Complete | Theme/layout, Riverpod, go_router, asset pipeline, and early `puzzle_core` integration tests are marked complete in project instructions. |
| Phase 2 | Puzzle Core | Complete | Pure-Dart `packages/puzzle_core` exists with engines, deterministic generation, validation, difficulty scoring, API types, benchmarking, and CI tooling. |
| Phase 3 | Game UX & Play Screens | Substantially implemented; needs hardening pass | Branch/PR history shows selection, daily/random flows, play screen, timer, undo/redo, hints, persistence, renderers, local telemetry, app icon, and UI fixes. Treat as feature-complete but not QA-complete until tests and manual device passes are rerun. |

### Important repo sanity note

GitHub metadata indicates PR `#30` — `Feat/phase3 play ux` — was merged into `main` on 2026-01-01, but the branch `feat/phase3-play-ux` still exists and should be reconciled before new development.

Run this before continuing:

```bash
git fetch --all --prune
git checkout feat/phase3-play-ux
git status
git log --oneline --decorate --graph --all -40
git diff --stat main...feat/phase3-play-ux
melos bootstrap
melos analyze
melos test
```

Decision to make:

- If `feat/phase3-play-ux` is truly ahead of `main`, merge/rebase it cleanly before Phase 4.
- If `main` already includes the PR and the branch only has stale/noisy differences, archive/delete the branch after preserving any useful commits.

### Known product divergence

The original PRD listed **Futoshiki** as part of the V1 number/logic puzzle roster. Current repo history replaced Futoshiki with **Killer Queens**. Treat Killer Queens / Queens as the accepted V1 product decision. Futoshiki should not be added to V1 or Phase 6 unless there is a future explicit product reversal.

---

## 2. Product principles that should not change

1. **On-device puzzle generation.** Do not store daily puzzle boards in Firebase. Generate from deterministic seeds.
2. **Offline-first.** App should remain playable without network.
3. **Firebase syncs metadata only.** Sync users, stats, Daily Challenge streak, puzzle-type favourites, completions, leaderboard submissions, analytics, and config. Do not sync puzzle boards/solutions by default.
4. **Daily Challenge streak only for V1.** Completing at least one Daily Challenge puzzle during the UTC daily window secures/advances the streak. Random Play does not affect streaks; global and per-puzzle streaks are out of V1.
5. **No fake competitive/social claims.** Show rank only if the user is top 1000 for a real leaderboard; do not show fake rank, fake “x playing,” or fake social proof.
6. **Futoshiki is not planned.** Killer Queens / Queens replaces Futoshiki for V1 unless a future explicit product decision reverses this.
7. **Android first.** iOS work comes after Android feature-complete unless a task explicitly requires cross-platform setup.
8. **V1 excludes multiplayer and serious anti-cheat.** Leaderboards are allowed, but competitive-grade anti-cheat is post-V1.
9. **Performance target remains 60fps on low-end Android.** Heavy generation must stay off the UI thread.
10. **Cursor should own iterative app implementation. Codex should own isolated repo-wide refactors, CI fixes, and broad test additions.**

---

## 3. Roadmap summary

| Phase | Epic Key | Epic Name | Status | Goal |
|---|---|---|---|---|
| 0 | BX-EPIC-000 | Environment & Scaffolding | Done | Create runnable Flutter/Melos/Firebase baseline. |
| 1 | BX-EPIC-010 | Foundation & Repo Setup | Done | Establish app architecture, routing, state, assets, and tests. |
| 2 | BX-EPIC-020 | Puzzle Core | Done | Build deterministic puzzle engines and stable public API. |
| 3 | BX-EPIC-030 | Game UX & Play Screens | Feature-complete / QA needed | Make puzzles playable with daily/random flows, renderers, hints, timer, undo, persistence. |
| 4 | BX-EPIC-040 | Accounts & Cloud Sync | Next | Add anonymous auth, optional account upgrade, local-first sync of stats/streaks/runs. |
| 5 | BX-EPIC-050 | Monetization | Planned | Add ads, Remote Config controls, rewarded hints/streak savers. |
| 6 | BX-EPIC-060 | Content Expansion | Planned | Add word puzzles and/or new non-Futoshiki puzzle content; deepen puzzle content. |
| 7 | BX-EPIC-070 | Leaderboards & Events | Planned | Weekly leaderboards, daily/weekly events, lightweight ranking. |
| 8 | BX-EPIC-080 | Accessibility & Store Prep | Planned | Accessibility, privacy, store metadata, release readiness. |
| 9 | BX-EPIC-090 | Launch & Soft Release | Planned | Closed/open testing, production rollout, metrics monitoring. |
| Post-V1 | BX-EPIC-100 | Multiplayer & Anti-Cheat | Deferred | Competitive systems only after V1 validation. |

---

# Phase 0 — Environment & Scaffolding

## Epic: BX-EPIC-000 — Environment & Scaffolding

**Status:** Done  
**Objective:** Establish a runnable Flutter monorepo with Firebase environments, CI/CD, and base app navigation.

### Stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0001 | Story | Initialize Flutter app | Done | P0 | App launches on Android emulator. |
| BX-0002 | Story | Configure Melos monorepo | Done | P0 | `apps/app`, `packages/puzzle_core`, and shared packages are bootstrapped with Melos. |
| BX-0003 | Story | Add Firebase multi-environment setup | Done | P0 | `dev`, `staging`, `prod` flavors exist with separate app IDs/config files. |
| BX-0004 | Story | Add base navigation | Done | P1 | Daily, Puzzles, Profile, Settings surfaces exist. |
| BX-0005 | Story | Configure GitHub Actions CI/CD | Done | P0 | Analyze/test/build workflows exist and run from CI. |
| BX-0006 | Story | Standardize linting/analysis | Done | P1 | Shared `analysis_options.yaml`; CI fails on analysis errors. |

---

# Phase 1 — Foundation & Repo Setup

## Epic: BX-EPIC-010 — Foundation & Repo Setup

**Status:** Done  
**Objective:** Build the app foundation needed before puzzle UX.

### Stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0101 | Story | Implement common theme and layout system | Done | P1 | App supports consistent color, typography, spacing, and basic responsive layout. |
| BX-0102 | Story | Integrate Riverpod global state | Done | P0 | App state is managed with Riverpod providers/controllers. |
| BX-0103 | Story | Integrate go_router routes | Done | P0 | App supports route-based navigation including play routes. |
| BX-0104 | Story | Set up asset loading pipeline | Done | P1 | Fonts/icons/word lists can be bundled and loaded. |
| BX-0105 | Story | Begin puzzle_core integration tests | Done | P1 | App can call core package under tests. |
| BX-0106 | Story | Add developer scripts | Done | P2 | Bootstrap/analyze/test/format commands documented. |

---

# Phase 2 — Puzzle Core

## Epic: BX-EPIC-020 — Puzzle Core

**Status:** Done  
**Objective:** Implement deterministic, pure-Dart puzzle generation, solving, validation, and scoring.

### Completed engine scope

| Engine | Status | Notes |
|---|---|---|
| Sudoku | Done | Generation, validation, difficulty targeting, play support. |
| Nonogram | Done | Black-and-white nonogram engine and renderer support. |
| Kakuro | Done / needs perf watch | Solver-backed generation; on-demand/background fallback exists due reliability/perf sensitivity. |
| Mathdoku | Done | 9x9 default in current Phase 3 code. |
| Slitherlink | Done / needs perf watch | Several uniqueness/boundary fixes landed in Phase 3 branch. |
| Takuzu | Done | Difficulty-aware size/density handling. |
| Killer Queens | Done | Replaced Futoshiki in current repo. |
| Futoshiki | Not planned | Present in original PRD but replaced by Killer Queens. Do not add unless explicitly re-scoped by a future product decision. |

### Stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0201 | Story | Define stable puzzle engine API | Done | P0 | `PuzzleEngine`, `EngineRegistry`, `GeneratedPuzzle`, metadata, moves, validation, and difficulty types exist. |
| BX-0202 | Story | Implement deterministic RNG | Done | P0 | Same seed + params generate identical puzzle across devices. |
| BX-0203 | Story | Implement Sudoku engine | Done | P0 | Generated puzzles are solvable, unique, and validated. |
| BX-0204 | Story | Implement Nonogram engine | Done | P0 | Generated puzzles are solvable and renderable. |
| BX-0205 | Story | Implement Mathdoku engine | Done | P1 | Cages/ops/solution are valid; moves validate correctly. |
| BX-0206 | Story | Implement Kakuro engine | Done | P1 | Generated puzzles validate; perf fallback exists. |
| BX-0207 | Story | Implement Slitherlink engine | Done | P1 | Loop synthesis and uniqueness checks pass tests. |
| BX-0208 | Story | Implement Takuzu engine | Done | P1 | Difficulty bands and uniqueness constraints pass tests. |
| BX-0209 | Story | Implement Killer Queens engine | Done | P2 | Board, cages, solver, validation, and UI solve handling work. |
| BX-0210 | Story | Add benchmark CLI and CI performance gate | Done | P1 | p95/p99 metrics can be collected and regressions detected. |
| BX-0211 | Story | Expose stable public package API | Done | P0 | App imports engines through `package:puzzle_core/puzzle_core.dart`. |

### Deferred Phase 2 cleanup

| Key | Type | Summary | Status | Priority | Notes |
|---|---|---|---|---|---|
| BX-0212 | Task | Refresh `packages/puzzle_core/README.md` | To Do | P2 | README appears older than implementation; update to reflect completed engines and current APIs. |
| BX-0213 | Task | Document accepted Futoshiki → Killer Queens product change | To Do | P2 | Prevent future confusion. Docs must state Futoshiki is not planned for V1/Phase 6 unless explicitly re-scoped later. |

---

# Phase 3 — Game UX & Play Screens

## Epic: BX-EPIC-030 — Game UX & Play Screens

**Status:** Feature-complete / QA hardening needed  
**Objective:** Make core puzzle engines playable through polished app screens.

### What appears accomplished

- Puzzle registry/routes and selection UI.
- Daily seed and daily puzzle generation.
- Random play UI flow.
- Play screen with timer and pause/resume behavior.
- Game state provider with move validation, undo/redo, notes, reset, and solved detection.
- Local persistence / continue game support.
- Puzzle renderer layer and replicated renderers across current engines.
- Hint capability API and hint UI/highlights.
- Haptics, animations, and theme polish.
- Local queue telemetry service/tests.
- Testing, coverage, performance infrastructure.
- App icon and privacy policy button.
- Multiple engine-specific fixes for Sudoku, Nonogram, Kakuro, Slitherlink, Mathdoku, Takuzu, Killer Queens.

### Jira stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0301 | Story | Build puzzle selection screen | Done | P0 | Users can browse supported puzzle types and start a puzzle. |
| BX-0302 | Story | Add route model for puzzle play | Done | P0 | `/play/:puzzleType/:mode` opens the correct game with valid params. |
| BX-0303 | Story | Implement daily challenge flow | Done | P0 | Daily puzzle uses deterministic date/type seed and opens from home/daily surface. |
| BX-0304 | Story | Implement random play flow | Done | P0 | User can start a generated random puzzle with selected type/difficulty. |
| BX-0305 | Story | Implement play screen shell | Done | P0 | Timer, status, toolbar, board area, controls render. |
| BX-0306 | Story | Implement game state lifecycle | Done | P0 | Start/restore/reset/solve state handled through provider. |
| BX-0307 | Story | Implement move validation pipeline | Done | P0 | UI moves call engine validation and update state only when valid or puzzle-specific policy allows. |
| BX-0308 | Story | Implement undo/redo | Done | P1 | Move history reconstructs state; controls enable/disable correctly. |
| BX-0309 | Story | Implement notes / pencil marks where applicable | Done | P1 | Sudoku-like note actions persist in game state. |
| BX-0310 | Story | Implement hint capability and UI | Done | P1 | Hint button only works for engines that support hints; highlights appear. |
| BX-0311 | Story | Implement renderer abstraction | Done | P0 | Puzzle-specific renderers plug into shared play screen. |
| BX-0312 | Story | Implement local progress persistence | Done | P0 | In-progress puzzles can be saved/restored per puzzle type. |
| BX-0313 | Story | Track local completion events | Done / verify | P1 | Solved puzzles increment local completion data and do not double-count. |
| BX-0314 | Story | Add benchmark/developer access screen | Done | P2 | Hidden bench screen accessible from home; exports or displays benchmark results. |
| BX-0315 | Story | Add app icon and privacy policy link | Done | P2 | Android icon updated; privacy link visible from settings/home flow. |
| BX-0316 | Story | Phase 3 QA pass across all puzzles | To Do | P0 | Manual matrix passes on emulator + low-end Android device. |
| BX-0317 | Story | Phase 3 regression test pass | To Do | P0 | `melos analyze`, `melos test`, app widget tests, core tests, and perf gate pass. |
| BX-0318 | Story | Phase 3 product acceptance polish | To Do | P1 | No obvious stuck states, blank boards, incorrect solved dialogs, or impossible puzzles. |
| BX-0319 | Bug | Reconcile `feat/phase3-play-ux` vs `main` | To Do | P0 | Main branch contains accepted Phase 3 work or branch is clearly preserved as source of truth. |
| BX-0320 | Story | Add per-puzzle How to Play entry points | To Do / Done if implemented | P1 | Puzzle Detail and Play screen expose safe How to Play entry points for each puzzle type. Placeholder copy is acceptable until full tutorials land. |
| BX-0321 | Story | Add safe generated puzzle titles | To Do | P2 | Random/saved puzzle runs can display safe cosmetic titles from a bundled safe title list. Titles do not affect puzzle seeds or generation. |
| BX-0322 | Story | Add puzzle-type favourites | Done / To Do | P1 | Users can favourite puzzle types. Favourite state is local-first and can be used by Puzzle Library and Home. |
| BX-0323 | Story | Add Favourite Puzzle quick play | Done / To Do | P1 | Home shows Favourite Puzzle quick action. If no favourites exist, user is guided to Puzzle Library. |
| BX-0324 | Story | Add Puzzle Library Favourites filter | Done / To Do | P1 | Puzzle Library filter row includes Favourites and shows an empty state if none exist. |

---

# Phase 4 — Accounts & Cloud Sync

## Epic: BX-EPIC-040 — Accounts & Cloud Sync

**Status:** Next  
**Objective:** Add Firebase-backed identity and cloud sync while preserving offline-first gameplay.

### Scope decisions

- Default user identity is anonymous Firebase Auth.
- Google/Apple sign-in upgrade is optional but should merge anonymous progress using credential linking.
- Firestore stores metadata only: user profile, run summaries, Daily Challenge streak, puzzle-type favourites, stats, leaderboard submissions, device sync queue state.
- Puzzle boards/solutions stay local unless a future explicit feature requires cloud backup.
- V1 streak model is Daily Challenge streak only. No global or per-puzzle-type streaks.
- Streak Savers are only hooks in Phase 4; earning/ads belong to Phase 5.

### Jira stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0401 | Story | Add auth repository | To Do | P0 | Anonymous sign-in works with timeout/error states and app never blocks gameplay indefinitely. |
| BX-0402 | Story | Add user profile model | To Do | P0 | User profile contains uid, createdAt, displayName, provider status, and preferences metadata. |
| BX-0403 | Story | Add local stats domain model | To Do | P0 | Stats track completions, best times, hints, difficulty, puzzle type, daily/random. |
| BX-0404 | Story | Add Daily Challenge streak model | To Do | P0 | V1 tracks one Daily Challenge streak. Completing at least one daily puzzle in the UTC daily window advances/secures the streak. Random Play does not affect streaks. No global or per-puzzle streaks in V1. |
| BX-0404A | Story | Sync puzzle-type favourites | To Do | P2 | Favourite puzzle types can be synced as user preference metadata without syncing puzzle boards. |
| BX-0405 | Story | Add local event queue | To Do | P0 | Completion events are queued offline and retried online. |
| BX-0406 | Story | Add Firestore schema and converters | To Do | P0 | Collections and typed converters exist for users, stats, streaks, runs. |
| BX-0407 | Story | Add sync engine | To Do | P0 | Local events sync to Firestore idempotently without double-counting. |
| BX-0408 | Story | Add profile/stats screen | To Do | P1 | User sees stats, streaks, best times, and sign-in upgrade prompt. |
| BX-0409 | Story | Add account upgrade prompt | To Do | P1 | Prompt appears after 3–5 completions or streak milestone; user can dismiss. |
| BX-0410 | Story | Implement Google sign-in | To Do | P1 | Existing anonymous data merges into Google-auth account. |
| BX-0411 | Story | Implement Apple sign-in shell | To Do | P2 | Required before iOS release; can be deferred until iOS port. |
| BX-0412 | Story | Add Firestore security rules | To Do | P0 | Users can only read/write own profile/stats; leaderboard writes constrained. |
| BX-0413 | Story | Add sync integration tests | To Do | P1 | Offline queue, retry, idempotency, and conflict behavior are tested. |
| BX-0414 | Story | Add Firebase Analytics events | To Do | P1 | Gameplay, completion, hint, ad, onboarding, and sign-in events are logged. |
| BX-0415 | Story | Add Crashlytics non-fatal reporting | To Do | P1 | Generation/sync failures are logged without leaking puzzle solutions. |

---

# Phase 5 — Monetization

## Epic: BX-EPIC-050 — Monetization

**Status:** Planned  
**Objective:** Add low-friction ads while protecting puzzle UX.

### Jira stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0501 | Story | Add mobile ads SDK setup | To Do | P0 | Dev/staging/prod ad IDs are separated; test ads work in dev. |
| BX-0502 | Story | Add Remote Config monetization flags | To Do | P0 | Banner, interstitial, rewarded frequency, and cooldowns are remotely configurable. |
| BX-0503 | Story | Add banner ad slots | To Do | P1 | Banners never overlap puzzle grids or controls. |
| BX-0504 | Story | Add rewarded ad for extra hints | To Do | P1 | User receives extra hint only after reward callback; failure states handled. |
| BX-0505 | Story | Add Streak Saver system | To Do | P1 | Users can hold up to 2 Streak Savers. Streak Savers are earned by completing all daily puzzles for a day or by watching a rewarded ad when eligible. They protect one missed Daily Challenge streak day and do not auto-refill. |
| BX-0506 | Story | Add interstitial policy | To Do | P2 | Interstitials appear only after puzzle completion/session boundary, never mid-puzzle. |
| BX-0507 | Story | Add ad consent / privacy checks | To Do | P0 | App handles GDPR/consent requirements where applicable before production. |
| BX-0508 | Story | Add monetization analytics | To Do | P1 | Ad impressions, rewards, failures, and opt-outs are logged. |
| BX-0509 | Story | Add ad-free pass placeholder | Deferred | P3 | UI/architecture leaves room for IAP after V1; no full implementation required yet. |

---

# Phase 6 — Content Expansion

## Epic: BX-EPIC-060 — Content Expansion

**Status:** Planned  
**Objective:** Expand V1 content beyond current logic puzzle roster.

### Strategy

Ship logic puzzles first if they are stable. Add word puzzles once the gameplay framework, sync, and monetization are stable. Word puzzles have asset/content moderation needs, so they should not be bolted on carelessly. Futoshiki is not part of the current V1/Phase 6 plan.

### Jira stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0601 | Task | Document no-Futoshiki V1 roster decision | To Do | P0 | PRD/README/roadmap state Killer Queens replaces Futoshiki. Futoshiki is not added unless explicitly re-scoped in the future. |
| BX-0602 | Story | Add Word Search engine | To Do | P1 | Deterministic placement, validation, difficulty, and renderer complete. |
| BX-0603 | Story | Add Anagram Scramble engine | To Do | P1 | Word selection, shuffling, validation, hints, and renderer complete. |
| BX-0604 | Story | Add Word Ladder engine | To Do | P2 | Valid transitions, dictionary filtering, difficulty, and renderer complete. |
| BX-0605 | Story | Add Cryptogram engine | To Do | P2 | Deterministic substitution, phrase asset pipeline, validation, and renderer complete. |
| BX-0606 | Story | Add Mini Crossword engine | To Do | P3 | Grid generation/fill, clue model, renderer, validation complete. |
| BX-0607 | Story | Add word list asset QA | To Do | P0 | Offensive/invalid/duplicate words are filtered; assets versioned. |
| BX-0608 | Story | Add content pack architecture | To Do | P2 | Puzzle content can be expanded without app architecture churn. |
| BX-0609 | Story | Add difficulty calibration dashboard/bench | To Do | P2 | Generation times and difficulty distributions can be inspected. |

---

# Phase 7 — Leaderboards & Events

## Epic: BX-EPIC-070 — Leaderboards & Events

**Status:** Planned  
**Objective:** Add weekly competition and event surfaces while keeping V1 anti-cheat lightweight.

### Scope decisions

- Show leaderboard rank only if the user is in the top 1000.
- Users outside top 1000 see no rank or neutral copy.
- Do not show fake rank, fake “x playing,” or fake social proof.

### Jira stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0701 | Story | Define leaderboard submission model | To Do | P0 | Submission includes uid, puzzleType, mode, date/week, duration, hints, difficulty, createdAt. |
| BX-0702 | Story | Add weekly leaderboard collections | To Do | P0 | Firestore stores per-puzzle weekly rankings. |
| BX-0703 | Story | Add leaderboard write path | To Do | P0 | Completed puzzle can submit score once idempotently. |
| BX-0704 | Story | Add leaderboard read UI | To Do | P1 | User can view top scores by puzzle type/week. |
| BX-0705 | Story | Add daily event summary | To Do | P1 | Daily challenge screen shows current event, completion status, and rank if available. |
| BX-0706 | Story | Add basic abuse guardrails | To Do | P1 | Reject impossible times, negative durations, unsupported puzzle types, and duplicate IDs. |
| BX-0707 | Story | Add leaderboard analytics | To Do | P2 | Views, submissions, rank changes, and failures are logged. |
| BX-0708 | Story | Add privacy-friendly display names | To Do | P1 | Anonymous/randomized names available; no email exposed. |
| BX-0709 | Story | Apply top-1000 rank display rule | To Do | P1 | Leaderboard surfaces show rank only when the user is in the top 1000. Outside top 1000, hide rank or show neutral copy. No fake rank/social proof. |

---

# Phase 8 — Accessibility & Store Prep

## Epic: BX-EPIC-080 — Accessibility & Store Prep

**Status:** Planned  
**Objective:** Prepare for Play Store testing with accessibility, policy, privacy, and build hygiene.

### Jira stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0801 | Story | Add accessibility audit pass | To Do | P0 | Large text, semantic labels, contrast, haptics toggles, and screen reader basics pass. |
| BX-0802 | Story | Add color-blind-safe theme checks | To Do | P1 | Puzzle state is not represented by color alone. |
| BX-0803 | Story | Add low-end device performance pass | To Do | P0 | No obvious jank during generation/play; generation off UI isolate. |
| BX-0804 | Story | Add privacy policy final link | To Do | P0 | Production privacy URL is live and linked in app/store listing. |
| BX-0805 | Story | Add terms/support/contact links | To Do | P1 | Settings includes support/contact path. |
| BX-0806 | Story | Add app metadata pack | To Do | P1 | App name, short description, long description, categories, screenshots, icon, feature graphic prepared. |
| BX-0807 | Story | Configure release signing | To Do | P0 | Android release signing is configured securely in CI. |
| BX-0808 | Story | Add production Firebase sanity checks | To Do | P0 | Prod app uses prod Firebase, prod Crashlytics, prod Remote Config defaults. |
| BX-0809 | Story | Add store policy review checklist | To Do | P0 | Ads, data safety, privacy, children/family policy, and permissions reviewed. |
| BX-0810 | Story | Add final regression test plan | To Do | P0 | Manual and automated test plan documented and run before soft launch. |
| BX-0811 | Story | Add full per-puzzle tutorial content | To Do | P1 | Each puzzle type has accessible tutorial content covering rules, controls, examples, and common mistakes. |

---

# Phase 9 — Launch & Soft Release

## Epic: BX-EPIC-090 — Launch & Soft Release

**Status:** Planned  
**Objective:** Ship Android-first release safely, monitor, and iterate.

### Jira stories

| Key | Type | Summary | Status | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| BX-0901 | Story | Create internal testing build | To Do | P0 | APK/AAB available to internal testers through Play Console. |
| BX-0902 | Story | Run closed testing cohort | To Do | P0 | Testers complete onboarding/play/sync/ad flows; issues triaged. |
| BX-0903 | Story | Add launch metrics dashboard | To Do | P1 | Crash-free users, retention, completions, ad events, sync failures visible. |
| BX-0904 | Story | Fix launch blockers | To Do | P0 | P0/P1 bugs closed before open testing. |
| BX-0905 | Story | Run open testing / limited region rollout | To Do | P1 | Rollout percentage controlled; metrics monitored. |
| BX-0906 | Story | Production launch | To Do | P0 | Store listing live; app available in target region(s). |
| BX-0907 | Story | Post-launch triage loop | To Do | P0 | Crash/feedback triage cadence established for first two weeks. |

---

# Post-V1 — Multiplayer & Anti-Cheat

## Epic: BX-EPIC-100 — Multiplayer & Anti-Cheat

**Status:** Deferred  
**Objective:** Add competitive systems only after V1 retention and content stability are proven.

### Deferred stories

| Key | Type | Summary | Status | Priority | Notes |
|---|---|---|---|---|---|
| BX-1001 | Spike | Define competitive multiplayer modes | Deferred | P3 | Async races, live races, tournaments. |
| BX-1002 | Spike | Define anti-cheat architecture | Deferred | P3 | Server verification, signed submissions, replay validation. |
| BX-1003 | Story | Add server-side puzzle verification | Deferred | P3 | Only if competitive leaderboard integrity becomes important. |
| BX-1004 | Story | Add live events/matchmaking | Deferred | P3 | Not V1. |

---

## 4. Immediate next sprint recommendation

### Sprint goal

Stabilize Phase 3 and prepare a clean base for Phase 4.

### Sprint backlog

| Rank | Key | Summary | Why now |
|---:|---|---|---|
| 1 | BX-0319 | Reconcile `feat/phase3-play-ux` vs `main` | Prevent building Phase 4 on the wrong branch. |
| 2 | BX-0317 | Run analyze/test/perf gate | Establish reality before new work. Painful, but cheaper than archaeology later. |
| 3 | BX-0316 | Manual QA all playable puzzles | Catch engine/UI bugs before cloud sync makes bugs permanent. |
| 4 | BX-0318 | Product acceptance polish | Fix blank states, broken continue game, incorrect solve dialogs. |
| 5 | BX-0212 | Refresh puzzle_core README | Align docs with actual implementation for future AI-agent context. |
| 6 | BX-0401 | Add auth repository | First Phase 4 foundation task. |
| 7 | BX-0403 | Add local stats domain model | Needed before sync and profile UI. |
| 8 | BX-0405 | Add local event queue | Enables offline-first sync. |

---

## 5. Jira import helper table

Use this compact table if manually creating Jira issues.

| Issue Type | Key | Parent/Epic | Summary | Status | Priority | Labels |
|---|---|---|---|---|---|---|
| Epic | BX-EPIC-000 | Brainiax V1 Launch | Environment & Scaffolding | Done | P0 | phase-0,foundation |
| Epic | BX-EPIC-010 | Brainiax V1 Launch | Foundation & Repo Setup | Done | P0 | phase-1,foundation |
| Epic | BX-EPIC-020 | Brainiax V1 Launch | Puzzle Core | Done | P0 | phase-2,puzzle-core |
| Epic | BX-EPIC-030 | Brainiax V1 Launch | Game UX & Play Screens | QA | P0 | phase-3,play-ux |
| Epic | BX-EPIC-040 | Brainiax V1 Launch | Accounts & Cloud Sync | To Do | P0 | phase-4,firebase,sync |
| Epic | BX-EPIC-050 | Brainiax V1 Launch | Monetization | To Do | P1 | phase-5,ads |
| Epic | BX-EPIC-060 | Brainiax V1 Launch | Content Expansion | To Do | P1 | phase-6,content |
| Epic | BX-EPIC-070 | Brainiax V1 Launch | Leaderboards & Events | To Do | P1 | phase-7,leaderboards |
| Epic | BX-EPIC-080 | Brainiax V1 Launch | Accessibility & Store Prep | To Do | P0 | phase-8,store,a11y |
| Epic | BX-EPIC-090 | Brainiax V1 Launch | Launch & Soft Release | To Do | P0 | phase-9,launch |
| Epic | BX-EPIC-100 | Post-V1 | Multiplayer & Anti-Cheat | Deferred | P3 | post-v1,deferred |

---

## 6. Definition of done by phase

### Phase 3 done means

- All seven current logic puzzles can be started, played, completed, restarted, and continued.
- Daily mode produces the same puzzle per puzzle type/date.
- Random mode produces new puzzles without blocking the UI.
- Timer, hints, undo/redo, notes, solved state, and persistence are stable.
- No known P0/P1 bugs remain.
- Analyze/test/perf gates pass.

### Phase 4 done means

- Anonymous auth works without blocking play.
- Local stats, Daily Challenge streak, puzzle-type favourites, and runs exist and update offline.
- Sync queue reliably uploads metadata to Firestore when online.
- Google account upgrade merges anonymous data.
- Profile screen shows useful stats.
- Firestore rules protect user data.

### Phase 5 done means

- Ads are integrated but non-hostile.
- Rewarded hints work.
- Streak Savers can be earned by completing all daily puzzles for a day or by watching a rewarded ad when eligible.
- Remote Config can disable/adjust ads instantly.
- Consent/privacy requirements are satisfied.

### Phase 8 done means

- App can survive a store review without embarrassing itself.
- That is the bar. Not perfection. Just no flaming tires rolling down the hill.
