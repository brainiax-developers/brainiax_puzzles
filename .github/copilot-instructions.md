# Brainiax Puzzles — AI agent guide

This is a Flutter/Dart monorepo (Melos-managed) for a cross‑platform puzzle app. Focus on on-device deterministic generation (no network for puzzles), clean modular boundaries, and fast UX on low-end devices.

## Big picture
- Monorepo layout:
  - `apps/app`: Flutter app (UI, routing, state, Firebase glue)
  - `packages/puzzle_core`: Deterministic engines (generators/solvers/validators)
  - `packages/assets`: Shared wordlists/assets
- Data flow: UI → Riverpod providers/controllers → `puzzle_core` engines. Firebase is used only for auth/analytics/config/crash; puzzle generation is offline.
- Keys & IDs: App `PuzzleType.key` maps 1:1 to engine IDs (e.g., `sudoku_classic`). Seeds encode mode (daily/random) and must reproduce the same board across devices.

## Architecture invariants
- Engine lifecycle: Initialize once via `EngineRegistryService().initialize()`; engines are retrieved from `EngineRegistry()`.
- Fallback policy: If a real engine fails to register, a `StubPuzzleEngine` is registered under the same ID (see `engine_registry_service.dart`). Don’t assume a specific engine implementation is present; program to the `PuzzleEngine` API.
- Seeding: Use `SeedService` for daily/random/test seeds. No wall‑clock or network should influence generation.
- UX performance: Heavy work runs off the first frame. `PuzzlePreloadService.preloadAll()` warms a cache per (type,difficulty) after startup.

## App structure & patterns (apps/app)
- Entry: `lib/main.dart` initializes Firebase (timeouts + Crashlytics safeguards) and engines, then starts `MaterialApp.router`.
- Routing: `lib/app_router.dart` uses `go_router` with `/play/:puzzleType/:mode` (expects valid `PuzzleType`/`PuzzleMode`; optional `state.extra` puzzle instance).
- State: Riverpod 3.0; see providers in `lib/shared/providers/` (e.g., `engine_provider.dart`, `game_state_provider.dart`, `simple_theme_provider.dart`).
- Models: `lib/shared/models/` defines `PuzzleType`, `PuzzleMode`, metadata, categories for UI.
- Firebase: `lib/shared/firebase/` has `firebase_init.dart` + `auth_glue.dart` (anonymous auth with timeouts; Crashlytics only on supported platforms).

## Core engines (packages/puzzle_core)
- Public API: `lib/puzzle_core.dart` exports registry, API types, and engines. Interact via `EngineRegistry` and `PuzzleEngine<S,M>`.
- Determinism: RNG is seeded; given same seed + params, results must match. See `docs/SEED_FORMATS.md` and README for formats and stability goals.
- Benchmarks: `bin/benchmark_runner.dart` (invoked by root `bin/bench.dart`) for p95/p99 timings and CI regression checks.

## Workflows
- Monorepo commands (run at repo root):
  - Analyze: `melos analyze`
  - Tests: `melos test` (app uses `flutter test`; core uses `dart test`)
  - Format: `melos format`
- App run/build:
  - Android flavors: `dev`, `staging`, `prod` (see `android/app/build.gradle.kts`). Ensure `google-services.json` exists per `src/<flavor>/`.
  - Router-driven screens: Home → Select → Play/Daily/Profile/Settings/Bench.
- Benchmarks: `dart bin/bench.dart --engines "sudoku_classic,nonogram_mono" --count 100` (see `docs/BENCHMARKING.md`). CI compares against a baseline; regressions >20% fail.

## Conventions & dos/don’ts
- Do fetch engines via providers/registry; don’t instantiate engine classes directly in UI.
- Do use `SeedService` to create/parse seeds; don’t invent ad‑hoc formats.
- Do handle the stub-engine fallback gracefully in UI (e.g., hide unsupported actions).
- Keep puzzle generation pure/offline; Firebase is not used in engine code.
- Long ops: schedule after first frame or with small yields (see `PuzzlePreloadService`).

## Useful references
- `apps/app/lib/main.dart`, `app_router.dart`
- `apps/app/lib/shared/services/engine_registry_service.dart`, `puzzle_preload_service.dart`, `puzzle_registry.dart`, `seed_service.dart`
- `apps/app/lib/shared/models/puzzle_type.dart`, `puzzle_mode.dart`
- `packages/puzzle_core/lib/puzzle_core.dart` (+ engines under `src/`), `packages/puzzle_core/docs/SEED_FORMATS.md`
- Bench: `bin/bench.dart`, `docs/BENCHMARKING.md`, `docs/CI_BENCHMARK_INTEGRATION.md`
