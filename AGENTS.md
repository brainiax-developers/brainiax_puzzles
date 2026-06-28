# AGENTS.md

## Scope

These instructions apply to the entire repository unless a more specific `AGENTS.md` is added in a subdirectory.

## Project snapshot

Brainiax Puzzles is a Flutter/Dart monorepo managed through the root Dart workspace and Melos.

Primary areas:

- `apps/app` — Flutter mobile app, screens, routing, Riverpod providers, persistence, Firebase-facing repositories, and puzzle renderers.
- `packages/puzzle_core` — pure-Dart puzzle generation, solving, validation, difficulty scoring, and engine APIs.
- `packages/assets` — bundled local assets such as word lists, icons, templates, and other static resources.

The app is Android-first until feature-complete. iOS support is post-feature-complete unless a task explicitly says otherwise.

## Non-negotiable product rules

- Keep puzzle generation on-device and deterministic. Do not move generated boards or solutions to Firebase or another backend.
- Backend/cloud sync stores metadata only: users, run summaries, stats, Daily Challenge streak state, puzzle-type favourites, leaderboard submissions, analytics/config, and sync status.
- Preserve offline-first play. Network/auth/sync failures must not block local puzzle play.
- V1 has one streak model: the Daily Challenge streak. Completing at least one Daily Challenge puzzle in the UTC daily window secures or advances it. Random Play never affects streaks.
- Do not add fake ranks, fake “people playing,” fake attempts, fake social proof, or placeholder competitive data.
- Futoshiki is not planned for V1. Queens / Killer Queens is the accepted replacement unless a future explicit product decision reverses it.
- Kakuro exists in the codebase but is benched for new product work until the generator is improved. Maintain/fix it when needed, but do not expand or foreground it unless explicitly asked.
- Wordle-style gameplay is excluded because of IP concerns.
- Do not expose unfinished/deferred features as working UI. Hide them or show a safe placeholder only when that is explicitly acceptable.

## Architecture rules

### App layer (`apps/app`)

- Use the existing Riverpod and `go_router` architecture. Do not bypass providers, route models, active-run persistence, daily lockout, favourites, completion records, or existing engine flows.
- Keep puzzle renderers and input handling separate from engine generation/solver logic.
- Play screens must preserve timers, undo/redo, notes, hints, active run persistence, and completion tracking semantics.
- Heavy generation or validation must not run on the UI isolate. Use the existing async/background-generation path or add one deliberately.
- Firebase access must go through repository/service abstractions, not directly from widgets.
- UI should remain truthful: if a value is not backed by real local or synced data, do not display it as fact.

### Puzzle core (`packages/puzzle_core`)

- Keep this package pure Dart. Do not import Flutter, Firebase, SharedPreferences, platform APIs, or app-layer UI code.
- Preserve deterministic generation. Same engine version + same seed + same generation parameters should produce the same puzzle.
- Do not use `dart:math Random` for canonical puzzle generation. Use the engine’s deterministic seeded RNG utilities.
- Generated puzzle validity requires solver-backed proof where applicable. Finding one solution is not uniqueness.
- Uniqueness checks must count solutions up to 2 and exit early. A timeout, cap hit, or incomplete search is `unknown`, not `unique`.
- Keep the exact solver/validator separate from human-style hint and difficulty layers. Hints should explain deductions where supported; exact search should certify correctness.
- Store/version metadata needed for reproducibility: puzzle type, seed, difficulty/profile, size, engine/generator version, and relevant solver telemetry.

## Current puzzle roster guidance

Treat these as the current logic-puzzle roster unless a task explicitly changes scope:

- Sudoku
- Nonogram
- Mathdoku
- Slitherlink
- Takuzu
- Queens / Killer Queens
- Kakuro: maintenance only while benched

Word puzzles are future expansion work unless explicitly scoped.

## Figma/UI implementation rules

When applying Figma output:

- Use Figma as visual reference only.
- Do not paste Figma-generated code into production.
- Product overrides and current Flutter architecture take precedence over generated designs.
- Implement native Flutter UI using existing components, providers, routes, and services.
- Keep UI changes separate from puzzle generation, solver logic, completion metadata, and daily lifecycle unless the task explicitly includes those areas.
- Play screen must not show bottom navigation. Settings is not a bottom tab.
- Completed daily puzzles must not start a fresh timed/scored attempt.

## Commands

Run from repo root unless noted.

Initial setup:

```bash
dart pub get
dart pub global activate melos
melos bootstrap
```

Common checks:

```bash
melos format
melos analyze
melos test
```

Coverage/performance checks when relevant:

```bash
melos run coverage
melos run check_coverage
melos run perf_gate
```

Run the app locally:

```bash
cd apps/app
flutter pub get
flutter run --flavor dev -t lib/main.dart
```

Use the same Flutter/Dart versions as CI/project docs unless the task explicitly updates tooling.

## Testing expectations

Add or update tests with behavior changes. Minimum expectations:

- Engine changes: deterministic seed tests, validity tests, uniqueness/multiple-solution tests, serialization tests where applicable, and benchmark/performance checks for generator or solver changes.
- App state changes: provider/unit tests for game lifecycle, persistence, completion, sync, and streak behavior.
- UI changes: widget tests for routing, visible state, empty/error states, and critical puzzle-flow regressions where practical.
- Firebase/sync changes: repository tests with mocks and, where available, emulator/security-rules tests.

For puzzle generation or solving changes, run the relevant focused tests plus `melos run perf_gate` before handing off.

## Manual QA checklist for play-flow work

For any change touching puzzle launch, play, persistence, or completion, manually smoke-test at least one easy puzzle and the affected puzzle type/difficulty:

- start Random Play
- start or resume Daily Challenge where applicable
- make valid and invalid moves
- undo/redo
- use notes where supported
- request a hint where supported
- background and reopen the app
- continue an unfinished run
- complete the puzzle
- verify completion is recorded once
- verify solved Daily Challenge does not start a new scored attempt

## Style and implementation preferences

- Prefer small, targeted changes over broad rewrites.
- Do not perform repo-wide renames/refactors unless explicitly asked.
- Keep public APIs stable where possible, especially `puzzle_core` exports and persisted JSON models.
- Use typed data and bitmasks in hot puzzle-core paths when they improve clarity/performance.
- Avoid global mutable state, wall-clock-dependent generation, non-deterministic iteration order in generators, and hidden network dependencies.
- Do not commit secrets, API keys, private Firebase config changes, keystores, local `.env` files, or generated build artifacts.
- If a generated or persisted schema changes, add migration/compatibility handling or document why old data can be safely discarded.

## Documentation expectations

Update docs when behavior changes. Keep these product decisions reflected in docs and prompts:

- on-device deterministic generation
- offline-first play
- Firebase metadata-only sync
- Daily Challenge streak only
- Futoshiki excluded / Queens accepted
- Kakuro benched pending generator improvements
- no fake leaderboard/social proof data

If documentation conflicts with code, inspect both. Prefer current implementation for mechanics and current product decision docs for scope.

## Codex/Cursor handoff guidance

Use Cursor for narrow Flutter/UI/provider work and iterative emulator debugging.

Use Codex for repo-wide refactors, broad test updates, CI fixes, and documentation sweeps. For Codex tasks in this repo, prefer `GPT-5.5` with `high` reasoning for broad architecture/refactor work, and `GPT-5.4` with `medium` reasoning for mechanical multi-file updates. For changes limited to one or two files, provide direct file edits instead of a Codex prompt.

## When uncertain

Do not guess. Inspect the current code and docs first. If a generation/solver result cannot be proven within the available cap, report `unknown` and keep the production path safe. Better a blunt failure than a haunted puzzle.