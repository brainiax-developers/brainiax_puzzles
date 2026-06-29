# Brainiax Puzzles — Developer Task Breakdown

Generated: 2026-05-26  
Working assumption: resume from `feat/phase3-play-ux`, stabilize Phase 3, then start Phase 4.

---

## 0. Current state in plain English

You are not starting from scratch.

Completed or effectively completed:

- Flutter/Melos/Firebase scaffold.
- Riverpod/go_router/theme/assets foundation.
- Deterministic `puzzle_core` with current logic engines.
- Phase 3 play UX appears substantially built: select screen, daily/random flow, play screen, timer, undo/redo, hints, renderers, local progress, benchmark access, UI polish.

Not safe to assume without rerunning checks:

- That `main` and `feat/phase3-play-ux` are perfectly reconciled.
- That all tests still pass after the long break.
- That every puzzle is actually playable end-to-end on a device.
- That Phase 3 has production-grade QA.

The next engineering move is boring but correct: **stabilize the branch, run the checks, manually play the app, then start cloud sync.**

---

## 1. Repo recovery checklist

Run these at repo root.

```bash
git fetch --all --prune
git branch -vv
git checkout feat/phase3-play-ux
git status
git log --oneline --decorate --graph --all -40
git diff --stat main...feat/phase3-play-ux
flutter --version
dart --version
melos --version
melos bootstrap
melos analyze
melos test
```

If tests fail, do not start Phase 4. Fix the baseline first. Cloud sync on top of broken game state is just distributed sadness.

### Android dev launch commands

Use whichever matches your app path and flavor setup:

```bash
flutter devices
flutter emulators
flutter emulators --launch <emulator_id>
cd apps/app
flutter pub get
flutter run --flavor dev -t lib/main.dart
flutter run --flavor staging -t lib/main.dart
flutter run --flavor prod -t lib/main.dart
```

If Android Studio launch config is broken, recreate a Flutter configuration with:

- Dart entrypoint: `apps/app/lib/main.dart`
- Build flavor: `dev`
- Additional args: `--flavor dev`

---

## 2. Cursor and Codex usage rules

### Use Cursor for

- Flutter UI implementation.
- Riverpod provider wiring.
- Small model/service additions.
- Widget tests around one screen/provider at a time.
- Manual iterative debugging with emulator visible.

### Use Codex for

- Repo-wide refactors.
- Updating tests across multiple packages.
- Fixing CI failures.
- Large mechanical changes, e.g. renaming models, adding converters everywhere.
- Documentation refresh across README/docs/AGENTS.

### Prompt style for Cursor

Give it one narrow task, affected files, and acceptance criteria.

Example:

```text
We are in the Brainiax Flutter monorepo. Work only on Phase 3 hardening.
Task: Add a visible empty/error state to PlayScreen when puzzle generation fails.
Files to inspect first:
- apps/app/lib/features/play/play_screen.dart
- apps/app/lib/shared/providers/game_state_provider.dart
- apps/app/lib/shared/providers/puzzle_generation_controller.dart
Acceptance criteria:
- No blank board on generation error.
- User can retry generation.
- melos analyze passes.
- Add or update a widget/provider test if practical.
Do not change puzzle_core engine logic.
```

### Prompt style for Codex

```text
Repo task: reconcile documentation with current implementation.
Please inspect packages/puzzle_core/lib/puzzle_core.dart, engine folders, README.md, AGENTS.md, and docs.
Update packages/puzzle_core/README.md so it no longer claims real engines are future work.
Document current engines: Sudoku, Nonogram, Kakuro, Mathdoku, Slitherlink, Takuzu, Killer Queens.
Call out Futoshiki as replaced by Killer Queens / Queens and not planned for V1 unless explicitly re-scoped later.
Run formatting/tests where relevant.
Return a concise diff summary.
```

---

## 3. Phase 3 hardening task list

### P3-HARDEN-001 — Reconcile branch state

**Type:** Task  
**Priority:** P0  
**Owner:** You + Cursor/Codex  
**Files/areas:** Git branches, PR #30, `main`, `feat/phase3-play-ux`

Steps:

1. Fetch/prune remote branches.
2. Compare `main` and `feat/phase3-play-ux`.
3. Identify whether branch contains accepted changes not in `main`.
4. Merge/rebase as appropriate.
5. Push a clean branch or update `main` if that is your workflow.
6. Tag the stable baseline: `phase3-baseline` or similar.

Acceptance criteria:

- There is one obvious source-of-truth branch for Phase 4.
- `git status` is clean.
- Diff vs `main` is understood and documented.

Suggested Cursor/Codex prompt:

```text
Inspect the repository branch state. Compare main and feat/phase3-play-ux. Summarize which files differ and whether the Phase 3 PR appears fully merged. Do not change files yet. Recommend the safest next git action.
```

---

### P3-HARDEN-002 — Run baseline checks

**Type:** Task  
**Priority:** P0

Commands:

```bash
melos bootstrap
melos format
melos analyze
melos test
dart bin/bench.dart --engines "sudoku_classic,nonogram_mono,kakuro_classic,slitherlink_loop,mathdoku_classic,killer_queens,takuzu_binary" --count 50
```

Acceptance criteria:

- Analyze passes.
- Tests pass or failures are captured as bugs.
- Benchmarks run or failures are captured as bugs.
- Output saved under a local notes file or Jira ticket comment.

---

### P3-HARDEN-003 — Manual QA matrix

**Type:** Task  
**Priority:** P0

Test each puzzle in both **Random** and **Daily** mode where supported.

| Puzzle | Random | Daily | Easy | Medium | Hard | Expert | Continue | Solve dialog | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Sudoku | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |  |
| Nonogram | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |  |
| Kakuro | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | Watch generation timeout. |
| Mathdoku | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | Check 9x9 usability. |
| Slitherlink | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | Watch uniqueness/perf. |
| Takuzu | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | Check size by difficulty. |
| Killer Queens | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | Check conflict feedback and solved state. |

Common checks:

- Start puzzle.
- Make valid moves.
- Try invalid moves.
- Undo/redo.
- Pause/resume if available.
- Request hint.
- Background app, return, continue.
- Complete puzzle.
- Restart/new puzzle.
- Rotate screen if supported.
- Kill app, reopen, continue.

Acceptance criteria:

- No blank puzzle screens.
- No infinite loaders.
- No obvious impossible generated boards.
- No double completion tracking.
- No UI overflow on common phone dimensions.

---

### P3-HARDEN-004 — Fix PlayScreen empty/error states

**Type:** Task  
**Priority:** P0  
**Likely files:**

- `apps/app/lib/features/play/play_screen.dart`
- `apps/app/lib/shared/providers/game_state_provider.dart`
- `apps/app/lib/shared/providers/puzzle_generation_controller.dart`

Implementation notes:

- Add a clear generation loading state.
- Add retry button on generation failure.
- Add user-friendly error text in dev; generic message in prod.
- Avoid swallowing exceptions silently unless logged.

Acceptance criteria:

- If engine generation fails, user can retry or go back.
- No permanent blank board.
- Error does not crash the app.

---

### P3-HARDEN-005 — Verify local progress persistence

**Type:** Task  
**Priority:** P0  
**Likely files:**

- `apps/app/lib/shared/services/puzzle_progress_service.dart`
- `apps/app/lib/shared/providers/puzzle_local_store_providers.dart`
- `apps/app/lib/features/play/play_screen.dart`

Test cases:

- Save in-progress puzzle.
- Continue same puzzle type.
- Start new puzzle clears/overwrites previous progress only for that puzzle type.
- Solved puzzle is not offered as continue unless intentionally designed.
- Different puzzle types do not overwrite each other.

Acceptance criteria:

- Continue Game works per puzzle type.
- Corrupt stored JSON fails gracefully.
- Tests cover state parser for each current engine.

---

### P3-HARDEN-006 — Verify completion tracking

**Type:** Task  
**Priority:** P0

Likely files:

- `apps/app/lib/features/play/play_screen.dart`
- `apps/app/lib/shared/services/puzzle_progress_service.dart`
- `apps/app/lib/shared/services/local_queue_telemetry_service.dart` if present
- stats/progress providers

Acceptance criteria:

- Completion recorded once per puzzle instance.
- Hints used, moves count, elapsed time, puzzle type, difficulty, mode, and seed are captured locally.
- Completion event is future-compatible with Firestore sync.

Suggested event model:

```dart
class PuzzleRunResult {
  final String localRunId;
  final String puzzleType;
  final String mode; // daily/random
  final String seed;
  final String difficulty;
  final String size;
  final int elapsedMs;
  final int moves;
  final int hintsUsed;
  final bool completed;
  final DateTime startedAt;
  final DateTime completedAt;
  final String engineVersion;
}
```

---

### P3-HARDEN-007 — Refresh documentation

**Type:** Task  
**Priority:** P1

Files:

- `README.md`
- `packages/puzzle_core/README.md`
- `AGENTS.md`
- `docs/SEED_FORMATS.md`
- `docs/BENCHMARKING.md`

Acceptance criteria:

- Docs match current engine roster.
- Docs state Killer Queens / Queens replaces Futoshiki for V1.
- Docs state Futoshiki is not planned and should not be added unless explicitly re-scoped later.
- Docs state Phase 3 status and next Phase 4 entry point.
- Commands are up to date.


### P3-HARDEN-008 — Verify How to Play entry points

**Type:** Task  
**Priority:** P1

Acceptance criteria:

- Every puzzle type exposes a How to Play entry point from Puzzle Detail and/or Play screen.
- If full tutorial content is unavailable, the entry point shows a safe placeholder.
- No How to Play action opens a broken route.

---

### P3-HARDEN-009 — Add safe generated puzzle titles

**Type:** Task  
**Priority:** P2

Acceptance criteria:

- Generated titles come from bundled safe local words/templates.
- Titles are cosmetic only and do not affect puzzle seeds or generated boards.
- Titles persist with active/saved runs if shown in Continue/Saved Game UI.
- Title word lists exclude offensive, adult, political, or sensitive words.

---

### P3-HARDEN-010 — Verify puzzle-type favourites

**Type:** Task  
**Priority:** P1

Acceptance criteria:

- Favourite star toggles puzzle-type favourite.
- Favourite state persists locally.
- Puzzle Library Favourites filter works.
- Favourite Puzzle quick play works if favourites exist.
- Empty favourite state guides the user to Puzzle Library.

---

## 4. Phase 4 implementation breakdown — Accounts & Cloud Sync

### Architecture target

Use a local-first model:

```text
PlayScreen / GameState
        ↓
Local completion event
        ↓
Local stats + Daily Challenge streak update
        ↓
Sync queue item
        ↓
Firebase Auth uid
        ↓
Firestore metadata write
        ↓
Profile / stats / leaderboard reads
```

Do not make puzzle play depend on network.

---

### P4-001 — Add auth domain layer

**Type:** Story  
**Priority:** P0

Files to create:

```text
apps/app/lib/shared/auth/auth_repository.dart
apps/app/lib/shared/auth/auth_state.dart
apps/app/lib/shared/auth/auth_providers.dart
apps/app/lib/shared/auth/user_identity.dart
```

Responsibilities:

- Initialize anonymous auth.
- Expose current user identity.
- Expose auth loading/error states.
- Never block puzzle play forever.
- Provide methods for Google/Apple upgrade later.

Acceptance criteria:

- App signs in anonymously on startup or first sync attempt.
- Timeout/failure does not block offline play.
- Auth state visible through Riverpod.
- Unit tests mock repository behavior.

Cursor prompt:

```text
Implement a Firebase Auth domain layer for Brainiax.
Create auth_repository, auth_state, auth_providers, and user_identity under apps/app/lib/shared/auth.
Support anonymous sign-in with timeout and a non-blocking error state.
Do not wire Google sign-in yet.
Use Riverpod.
Add tests with mocked repository behavior if project test setup allows.
```

---

### P4-002 — Define Firestore schema

**Type:** Story  
**Priority:** P0

Proposed collections:

```text
/users/{uid}
/users/{uid}/stats/{puzzleType}
/users/{uid}/runs/{runId}
/users/{uid}/dailyStreak
/leaderboards/{periodId}/puzzleTypes/{puzzleType}/entries/{uidOrRunId}
/config/appConfig
```

`users/{uid}`:

```json
{
  "uid": "string",
  "createdAt": "timestamp",
  "lastSeenAt": "timestamp",
  "displayName": "string|null",
  "isAnonymous": true,
  "providers": ["anonymous"],
  "schemaVersion": 1
}
```

`runs/{runId}`:

```json
{
  "runId": "string",
  "puzzleType": "sudoku_classic",
  "mode": "daily",
  "seed": "daily:sudoku_classic:2026-05-26",
  "difficulty": "easy",
  "size": "9x9",
  "elapsedMs": 123456,
  "moves": 42,
  "hintsUsed": 1,
  "completed": true,
  "startedAt": "timestamp",
  "completedAt": "timestamp",
  "engineVersion": "string",
  "appVersion": "string",
  "createdAt": "timestamp"
}
```

Acceptance criteria:

- Schema documented in `docs/FIRESTORE_SCHEMA.md`.
- Dart models and converters exist.
- No board/solution data in Firestore.

---

### P4-003 — Add local stats service

**Type:** Story  
**Priority:** P0

Files to create:

```text
apps/app/lib/shared/stats/local_stats_service.dart
apps/app/lib/shared/stats/stats_models.dart
apps/app/lib/shared/stats/stats_providers.dart
```

Responsibilities:

- Apply `PuzzleRunResult` to local stats.
- Maintain totals by puzzle type and overall.
- Maintain best time per puzzle type/difficulty/mode.
- Maintain hints and moves aggregates.

Acceptance criteria:

- Local stats update immediately after solve.
- Stats can be read without network.
- Tests cover first completion, best time update, non-best completion, and hint count.

---

### P4-004 — Add Daily Challenge streak service

**Type:** Story  
**Priority:** P0

Responsibilities:

- Daily Challenge streak only.
- No global streaks in V1.
- No per-puzzle-type streaks in V1.
- Streak day is based on UTC daily challenge date.
- Completing at least one Daily Challenge puzzle during the UTC window secures/advances the streak.
- Random Play never affects streaks.
- Leave a future hook for Streak Savers, but do not implement saver earning/ads in Phase 4 unless Phase 5 is in scope.

Acceptance criteria:

- Same-day multiple completions do not inflate the Daily Challenge streak.
- Random Play completions do not affect the streak.
- Missed UTC daily window breaks streak unless a future saver later applies.
- Tests cover UTC date boundary behavior.

---

### P4-004A — Sync puzzle-type favourites

**Type:** Story  
**Priority:** P2

Responsibilities:

- Sync favourite puzzle types as user preference metadata.
- Do not sync generated puzzle boards or solutions.
- Preserve offline-first local favourites.

Acceptance criteria:

- Favourite puzzle type list syncs across devices for signed-in users.
- Anonymous users keep local favourites.
- Conflicts resolve predictably, preferably last-write-wins or union with timestamps.

---

### P4-005 — Add sync queue

**Type:** Story  
**Priority:** P0

Files:

```text
apps/app/lib/shared/sync/sync_queue.dart
apps/app/lib/shared/sync/sync_queue_item.dart
apps/app/lib/shared/sync/sync_service.dart
apps/app/lib/shared/sync/sync_providers.dart
```

Queue item fields:

```dart
class SyncQueueItem {
  final String id;
  final String type; // runResult, statsDelta, streakUpdate
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final DateTime? lastAttemptAt;
  final String status; // pending, syncing, failed, synced
}
```

Acceptance criteria:

- Completion event writes local state and enqueues sync item.
- Sync retries on app resume/network availability/manual trigger.
- Writes are idempotent using deterministic run IDs.
- Failed sync never loses local stats.

---

### P4-006 — Add Firestore sync repository

**Type:** Story  
**Priority:** P0

Responsibilities:

- Create/update user doc.
- Upload run result.
- Upsert stats aggregate.
- Upsert streak state.
- Report failures to Crashlytics as non-fatal.

Acceptance criteria:

- Works against Firebase dev project.
- Writes are behind repository abstraction for tests.
- No direct Firestore calls from UI widgets.

---

### P4-007 — Wire completion → local stats → sync

**Type:** Story  
**Priority:** P0

Likely files:

- `apps/app/lib/features/play/play_screen.dart`
- `apps/app/lib/shared/providers/game_state_provider.dart`
- new stats/sync services

Acceptance criteria:

- On first solved state transition, app creates `PuzzleRunResult`.
- Local stats update instantly.
- Sync queue item is created.
- Duplicate solved-state rebuilds do not create duplicate runs.

Implementation tip:

Use a local run ID derived from:

```text
uidOrInstallId + puzzleType + mode + seed + startedAtEpochMs
```

For daily challenge leaderboard submissions, use a separate idempotency key:

```text
uid + puzzleType + dailyDate
```

---

### P4-008 — Build Profile/Stats screen

**Type:** Story  
**Priority:** P1

UI sections:

- Anonymous/Google account state.
- Total puzzles solved.
- Current streak / best streak.
- Per-puzzle completion count.
- Best times.
- Hints used.
- Sync status.

Acceptance criteria:

- Works offline with local stats.
- Shows sync pending/error status.
- Upgrade prompt appears after milestone.

---

### P4-009 — Add Google account upgrade

**Type:** Story  
**Priority:** P1

Acceptance criteria:

- User can link anonymous account to Google.
- Existing local/Firebase anonymous stats remain attached.
- Errors are recoverable.
- User is not forced to sign in to play.

Potential package:

- `google_sign_in`
- `firebase_auth`

---

### P4-010 — Firestore security rules

**Type:** Story  
**Priority:** P0

Rules goals:

- User can read/write only own `/users/{uid}` subcollections.
- Leaderboard write allowed only if authenticated and payload fields are valid.
- No client can write arbitrary admin/config fields.

Acceptance criteria:

- Rules are committed.
- Emulator tests exist if Firebase emulator setup is available.
- Manual dev Firebase write/read tested.

---

## 5. Phase 5 monetization breakdown

### P5-001 — Add ads SDK and environment config

**Priority:** P0

Tasks:

- Add Google Mobile Ads package.
- Add dev/staging/prod ad unit config.
- Use test ads in dev.
- Add remote kill switch.

Acceptance criteria:

- Ads can be globally disabled through Remote Config.
- No ad code crashes if SDK init fails.

---

### P5-002 — Rewarded hints

**Priority:** P1

Rules:

- First hint per puzzle can remain free if current UX expects it.
- Extra hints require rewarded ad unless Remote Config disables monetization.
- Reward callback is source of truth.

Acceptance criteria:

- User never loses a reward after watching ad.
- Failed/cancelled ad gives no reward but also no crash.

---

### P5-002A — Add Streak Saver system

**Type:** Story  
**Priority:** P1

Rules:

- Max 2 Streak Savers.
- User does not start with 2 automatically.
- Earn by completing all daily puzzles for a day.
- Earn by watching rewarded ad when eligible.
- Protects one missed Daily Challenge day.
- Does not auto-refill.

Acceptance criteria:

- Saver use affects only Daily Challenge streak.
- Saver earning by all-daily completion is idempotent per UTC day.
- Rewarded ad earning respects Remote Config limits.
- UI never implies savers protect random-play or puzzle-specific streaks.


---

### P5-003 — Banner and interstitial policy

**Priority:** P2

Rules:

- Banner can appear on home/select/profile, not cramped over board.
- Interstitial only after puzzle completion or between sessions.
- No interstitial on app launch.
- No interstitial during active puzzle.

Acceptance criteria:

- Puzzle canvas remains usable on small Android screens.
- Remote Config can tune frequency/cooldown.

---

## 6. Phase 6 content expansion breakdown

### P6-001 — Document no-Futoshiki V1 roster decision

**Priority:** P0

Decision:

- Killer Queens / Queens replaces Futoshiki for V1.
- Futoshiki should not be added unless explicitly re-scoped by a future product decision.
- Phase 6 should focus on word puzzles and/or other non-Futoshiki content expansion.

Acceptance criteria:

- README/PRD/roadmap agree.
- Selection screen reflects final V1 list.
- Future agents cannot accidentally reintroduce Futoshiki from stale docs.

---

### P6-002 — Word Search MVP

**Priority:** P1

Engine tasks:

- Deterministic word selection.
- Deterministic grid placement.
- Difficulty by grid size, word count, directions, overlaps.
- Validator for selected paths.
- Hints.

UI tasks:

- Drag selection renderer.
- Word list panel.
- Found word state.
- Completion detection.

---

### P6-003 — Anagram Scramble MVP

**Priority:** P1

Engine tasks:

- Word asset filter by length/difficulty.
- Deterministic shuffle.
- Answer validation.
- Hint reveal positions.

UI tasks:

- Letter tiles.
- Input slots.
- Shuffle/reset controls.

---

### P6-004 — Word Ladder MVP

**Priority:** P2

Engine tasks:

- Dictionary graph or constrained search.
- Start/end word pair generation.
- Valid one-letter transition validation.
- Difficulty by path length/branching.

---

### P6-005 — Cryptogram MVP

**Priority:** P2

Engine tasks:

- Phrase asset pipeline.
- Deterministic substitution cipher.
- Letter mapping validation.
- Hints reveal one mapping.

---

## 7. Phase 7 leaderboard breakdown

### P7-001 — Leaderboard score model

**Priority:** P0

Fields:

```dart
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String puzzleType;
  final String periodId; // e.g. 2026-W22
  final String mode; // daily/random/event
  final String difficulty;
  final int elapsedMs;
  final int moves;
  final int hintsUsed;
  final DateTime completedAt;
}
```

Ranking suggestion:

1. Completed only.
2. Lower elapsed time wins.
3. Fewer hints breaks tie.
4. Fewer moves breaks tie.
5. Earlier completedAt breaks final tie.

---

### P7-001A — Top-1000 rank display policy

**Priority:** P1

Rules:

- Rank is displayed only for top-1000 leaderboard entries.
- Users outside top 1000 see no rank or neutral copy.
- No fake leaderboard/social proof values are rendered.

Acceptance criteria:

- Leaderboard and Daily Hub surfaces do not display rank unless rank <= 1000.
- No fake “x playing” or fake rank copy exists.
- Tests cover top-1000, outside-top-1000, and no-data states.

---

### P7-002 — Casual anti-abuse rules

**Priority:** P1

Client/server validation:

- Reject elapsed time below puzzle-specific minimum threshold.
- Reject unsupported puzzle type/difficulty/mode.
- Reject duplicate daily submission for same uid/type/date unless replacing with better score is explicitly allowed.
- Rate-limit submissions per user.

Note: This is not serious anti-cheat. Full anti-cheat remains post-V1.

---

## 8. Phase 8 store prep breakdown

### P8-001 — Accessibility checklist

Check:

- Text scale 1.0, 1.3, 1.5, 2.0.
- High contrast theme.
- Color-blind-safe board states.
- Touch targets at least 48dp where possible.
- Haptics can be disabled.
- Screen reader labels for critical controls.
- Timer can be hidden or ignored for relaxed play if needed.

---

### P8-002 — Play Store checklist

Prepare:

- App icon.
- Feature graphic.
- Phone screenshots.
- Short description.
- Long description.
- Privacy policy URL.
- Data safety form.
- Ads disclosure.
- Support email.
- Internal testing release notes.

---

### P8-003 — Release build checklist

Commands:

```bash
cd apps/app
flutter clean
flutter pub get
flutter build appbundle --flavor prod -t lib/main.dart --release
```

Acceptance criteria:

- Release signing configured.
- Prod Firebase config used.
- Crashlytics/Analytics work in prod build.
- No dev/test ad IDs in prod.

---

## 9. Phase 9 launch breakdown

### P9-001 — Internal testing

Tasks:

- Create Play Console internal test release.
- Invite testers.
- Provide test script.
- Collect crash logs and feedback.

Test script:

1. Install app.
2. Open app offline.
3. Start Sudoku random.
4. Complete or partially play.
5. Kill app and continue.
6. Play daily challenge.
7. Open profile/stats.
8. Watch rewarded hint ad if monetization enabled.
9. Report confusing screens or crashes.

---

### P9-002 — Launch monitoring

Metrics to watch:

- Crash-free users.
- ANRs.
- Puzzle generation failures by type.
- Completion rate by puzzle type.
- Hint usage.
- Ad reward failure rate.
- Sync queue failures.
- Day 1 retention.

---

## 10. Suggested issue order for the next 20 tasks

Do these in order:

1. Reconcile `feat/phase3-play-ux` vs `main`.
2. Run `melos bootstrap`.
3. Run `melos analyze`.
4. Run `melos test`.
5. Run benchmark command for all current engines.
6. Create Phase 3 bug list from failures.
7. Manually QA Sudoku random/daily.
8. Manually QA Nonogram random/daily.
9. Manually QA Kakuro random/daily.
10. Manually QA Mathdoku random/daily.
11. Manually QA Slitherlink random/daily.
12. Manually QA Takuzu random/daily.
13. Manually QA Killer Queens random/daily.
14. Fix PlayScreen blank/error/loading states.
15. Fix continue game edge cases.
16. Verify completion event is single-fire.
17. Update docs for current state.
18. Create auth repository.
19. Create stats/run models.
20. Create local sync queue.

---

## 11. Cursor starter prompt for your next session

Paste this into Cursor after opening the repo:

```text
We are resuming the Brainiax Puzzles Flutter/Melos app after a long break.
Current working branch should be feat/phase3-play-ux unless main has already absorbed it.
First goal: Phase 3 hardening, not new features.
Please inspect:
- README.md
- AGENTS.md
- apps/app/lib/app_router.dart
- apps/app/lib/features/play/play_screen.dart
- apps/app/lib/shared/providers/game_state_provider.dart
- apps/app/lib/shared/providers/puzzle_generation_controller.dart
- packages/puzzle_core/lib/puzzle_core.dart
Then produce:
1. Current branch/file risk summary.
2. Commands I should run to validate baseline.
3. The smallest safe fix if PlayScreen can show blank/error states.
Do not modify files until I approve the first patch.
```

---

## 12. Codex starter prompt for a broad repo cleanup

```text
Task: Phase 3 documentation and test hardening for Brainiax Puzzles.
Please inspect the current repository and update stale documentation so it matches actual implementation.
Known context:
- Phase 0/1/2 are complete.
- Phase 3 play UX is implemented but needs QA/hardening.
- Current engines include Sudoku, Nonogram, Kakuro, Mathdoku, Slitherlink, Takuzu, Killer Queens.
- Futoshiki was in the original PRD but is now replaced by Killer Queens / Queens and should not be added unless explicitly re-scoped later.
Please:
1. Update packages/puzzle_core/README.md.
2. Add a docs/CURRENT_STATUS.md file summarizing completed phases and next tasks.
3. Add or update tests only where low-risk.
4. Run format/analyze/tests if available.
5. Return a diff summary and any failing commands.
```

---

## 13. Risk register

| Risk | Severity | Mitigation |
|---|---:|---|
| Branch/source-of-truth confusion | High | Reconcile branch before Phase 4. |
| Puzzle generation jank/timeouts | High | Keep isolate generation, preload/on-demand fallback, perf gate. |
| Duplicate completion events | High | Idempotent local run IDs and solved transition guards. |
| Cloud sync corrupts stats | High | Local-first queue, idempotent writes, tests. |
| Ads harm play UX | Medium | Remote Config kill switch and strict placement rules. |
| Word puzzle content quality | Medium | Curated word lists, filters, asset QA. |
| Leaderboard cheating | Medium | Casual guardrails for V1; real anti-cheat deferred. |
| Store policy surprises | Medium | Privacy/data safety/ads review before release. |

---

## 14. Done-for-now checkpoint

Before starting Phase 4, you want this exact statement to be true:

> `feat/phase3-play-ux` or `main` is clean, tests pass or known failures are ticketed, every current puzzle can be manually started and played, local completion/progress behavior is stable, and docs reflect the current engine roster.

If that is not true yet, Phase 4 can wait. Firebase is not going anywhere; bugs are very happy to travel with you.
