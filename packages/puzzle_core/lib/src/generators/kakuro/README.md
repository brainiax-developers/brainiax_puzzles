# Kakuro On-Demand Generator

This directory contains the new Kakuro generation pipeline that powers the on-demand
experience in the Flutter app. The generator follows the “solution-first” strategy
described in https://puzzling.stackexchange.com/a/49935:

- `layout.dart` builds a randomized, newspaper-style layout with rotational symmetry,
  run lengths between 2 and 9, and a solid border for clue cells.
- `generator_solution_first.dart` fills the layout with digits while maintaining the
  Kakuro constraints, then derives the across/down sums.
- `solver.dart` exposes the bitmask CSP solver that performs propagation,
  uniqueness checks, and emits telemetry used for difficulty gating.
- `api.dart` wires everything together and exposes both a synchronous generator
  (`KakuroPuzzleGenerator`) and an isolate-friendly entrypoint
  (`generateKakuroInIsolate`) that returns a serialisable `KakuroPuzzle`.

## Difficulty knobs

`KakuroDifficultyProfile` (in `models.dart`) controls the gating thresholds:

| Field               | Effect                                                           |
|---------------------|------------------------------------------------------------------|
| `maxBacktrackNodes` | Upper bound on solver search nodes before rejecting the puzzle.  |
| `minForcedRatio`    | Minimum fraction of cells forced by propagation (higher = easier).|
| `maxSearchDepth`    | Solver depth cap for uniqueness checks.                          |
| `maxPropagationRounds` | Ensures puzzles require some logical deductions without stalling. |

The generator collects solver telemetry (shrink %, forced assignments, propagation
rounds, backtrack nodes) and feeds it into `KakuroDifficultyScorer`. The resulting
`DifficultyTelemetry.rawScore` is bucketed via `kakuro_difficulty_thresholds.json`.

## Strategy

`GenerateKakuroRequest.strategy` exposes only `solutionFirst`, the implemented
generator. Bottom-up clue forcing is intentionally not a selectable strategy
until a real implementation exists.

## Uniqueness guarantees

Every candidate puzzle is validated by `KakuroSolver` with `maxSolutions: 2`.
If multiple solutions are found, the puzzle is rejected and the generator restarts.
Telemetry is emitted on every attempt so the app can provide meaningful
diagnostics and surface a retryable failure when the configured budget elapses.
