# Killer Queens Difficulty Changes

## Overview

Killer Queens difficulty scoring now uses measured solver and region metrics
instead of primarily relying on board size or average cage size. Normal
generated puzzles reveal only the colored regions; they do not include fixed
queen givens. The current thresholds are provisional and are only
regression-covered by the fixed seeds in
`packages/puzzle_core/test/killer_queens_engine_test.dart`; they should not be
treated as broad player-facing calibration.

## Scoring Inputs

The scorer reads the solver telemetry produced during pipeline verification:

- solver nodes
- branches
- backtracks
- average branching factor, when present

It also measures region geometry from the puzzle cages:

- region area variance
- singleton or near-singleton region count
- average region perimeter-to-area ratio
- board size

Generator telemetry contributes accepted generation attempts. Fixed queens are
reported as an informational metric and should be zero for normal generated
puzzles; they are not a scoring driver.

## Current Formula

The raw score combines:

- solver search cost from nodes, branches, and backtracks
- branching factor pressure
- region area variance
- singleton or near-singleton region pressure
- average region perimeter-to-area ratio
- smaller board-size and accepted-attempt modifiers

The scorer emits each component in `DifficultyTelemetry.metrics` alongside the
raw score so future calibration can compare solver behavior against the final
bucket.

## Thresholds

`packages/puzzle_core/assets/killer_queens_difficulty_thresholds.json` contains
provisional thresholds for the measured-score range:

| Bucket | Max Inclusive |
|--------|---------------|
| easy   | 8.5           |
| medium | 11.7          |
| hard   | 14.5          |
| expert | 9999.0        |

These values were chosen to keep the checked fixed seeds stable after the
scoring change. They are not a claim that Killer Queens difficulty is fully
calibrated.

## Uniqueness

Generation still runs the solver with `maxSolutions: 2` and rejects boards that
are unsolved, non-unique, or have unknown uniqueness in the production pipeline.
The difficulty scorer itself does not use hidden solution-only shortcuts and
does not infer difficulty from the solution layout.

Tests cover deterministic generation, uniqueness checks for selected seeds, and
stable measured difficulty telemetry for selected seeds. They do not prove that
all possible generated boards are calibrated or globally unique outside those
pipeline checks.
