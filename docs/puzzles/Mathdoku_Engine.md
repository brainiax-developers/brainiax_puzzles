# Brainiax Puzzles — MathDoku Engine Documentation

**Puzzle:** MathDoku / KenKen-style arithmetic Latin-square puzzle  
**Engine ID:** `mathdoku_classic`  
**Package:** `packages/puzzle_core`  
**App integration:** `apps/app`  
**Current product constraint:** Brainiax uses **9×9 MathDoku** as the app-facing default/target, while the core engine may also support smaller internal/test sizes.

---

## 1. Purpose

This document defines the production contract for MathDoku in Brainiax Puzzles.

It covers:

- Formal puzzle rules.
- Generator constraints.
- Solver constraints.
- Validator constraints.
- Difficulty levels and how to distinguish them.
- Runtime/performance expectations.
- App integration expectations.
- Serialization and metadata.
- Testing and benchmark requirements.
- Failure modes and maintenance rules.

The short version: MathDoku must be deterministic, offline-first, locally generated, uniquely solvable, and difficulty-labeled by measured complexity rather than vibes in a trench coat.

---

## 2. Product and architecture principles

### 2.1 Core principles

MathDoku must remain:

1. **Pure Dart inside `packages/puzzle_core`.**
2. **Deterministic from seed.**
3. **Generated on-device.**
4. **Playable offline.**
5. **Validated by solver-backed uniqueness checks.**
6. **Independent of Firebase for puzzle content.**
7. **Safe for seeded daily challenges.**

### 2.2 Cloud rules

Firebase may store:

- User profile metadata.
- Completion summaries.
- Streaks.
- Stats.
- Leaderboard submissions.
- Engine version.
- Difficulty score.
- Seed metadata.

Firebase must not store by default:

- Full daily puzzle boards.
- Puzzle solutions.
- Hidden answer grids.
- Any data needed to solve the puzzle server-side.

Puzzle generation must be reconstructable locally from deterministic seed inputs.

---

## 3. Formal MathDoku model

### 3.1 Board

A MathDoku board is an `N × N` square grid.

For Brainiax app UX, the target board size is:

```text
9 × 9
```

The core engine may support smaller sizes for tutorials, tests, or future UX options, but production app behavior should not accidentally drift away from the 9×9 product requirement unless a product decision is made.

### 3.2 Cell values

Each cell contains an integer:

```text
0 = empty / unfilled
1..N = player or solver value
```

For a 9×9 board, valid solved values are `1..9`.

### 3.3 Latin-square constraints

Every solved board must satisfy:

```text
Each row contains every digit 1..N exactly once.
Each column contains every digit 1..N exactly once.
```

Unlike Sudoku, there are no 3×3 box constraints.

### 3.4 Cages

A cage is a group of one or more cells with:

```dart
id: int
cells: List<int>        // flat indices, row * size + col
operation: MathdokuOperation
target: int
```

Each cage must satisfy:

- Non-empty cell list.
- All cell indices are in board range.
- Orthogonally connected.
- No cell overlap with any other cage.
- Full board coverage across all cages.
- Unique cage ID.
- Positive target.
- Operation-compatible size and target.

### 3.5 Operations

Supported operations:

| Operation | Symbol | Cage size | Rule |
|---|---:|---:|---|
| Equality | `=` | exactly 1 | cell value equals target |
| Addition | `+` | 2+ | sum of values equals target |
| Multiplication | `×` | 2+ | product of values equals target |
| Subtraction | `-` | exactly 2 | absolute/valid difference equals target |
| Division | `÷` | exactly 2 | exact integer division equals target |

Brainiax should keep subtraction and division limited to **2-cell cages**. This is easier to explain, faster to solve, and avoids weird multi-cell arithmetic rules that make players mutter things at their phones.

---

## 4. Valid puzzle definition

A generated MathDoku puzzle is production-valid only if all of the following are true:

1. Board size is supported.
2. Cell array length is exactly `N * N`.
3. Initial puzzle cells are empty unless intentionally seeded givens are supported.
4. Cages cover every cell exactly once.
5. Every cage is orthogonally connected.
6. Every cage operation is valid for its cage size.
7. Every cage target is positive and plausible.
8. At least one solution exists.
9. Exactly one solution exists.
10. The unique solution passes strict solution validation.
11. Generation terminates within deterministic attempt and time bounds.
12. The generated metadata contains enough information for local progress, stats, daily challenges, and future leaderboard submissions.

---

## 5. Data model contract

### 5.1 Board model

The board model should expose:

```dart
class MathdokuBoard {
  final int size;
  final List<int> cells;
  final List<MathdokuCage> cages;
}
```

Expected derived helpers:

- `cellCount`
- `isComplete`
- `rowIndices(row)`
- `columnIndices(col)`
- `cageForCellIndex(index)`
- `setCell(row, col, value)`
- `toJson()`
- `fromJson()`

### 5.2 Cage model

```dart
class MathdokuCage {
  final int id;
  final List<int> cells;
  final MathdokuOperation operation;
  final int target;
}
```

### 5.3 Serialization

Canonical full JSON shape:

```json
{
  "size": 9,
  "cells": [0, 0, 0],
  "cages": [
    {
      "id": 0,
      "cells": [0, 1],
      "operation": "add",
      "target": 7
    }
  ]
}
```

Compact future sync/local-cache shape may be introduced later:

```json
{
  "v": 1,
  "t": "mathdoku",
  "s": 9,
  "seed": "daily:mathdoku_classic:2026-05-29",
  "d": "hard",
  "c": [
    {"i": 0, "cells": [0, 1], "op": "+", "t": 7}
  ],
  "engineVersion": "1.0.0",
  "difficultyScore": 402.3
}
```

Do not include solution in Firestore/backend sync.

---

## 6. Generator documentation

### 6.1 Generator goal

The generator must produce a MathDoku puzzle that is:

- Structurally valid.
- Solvable.
- Uniquely solvable.
- Deterministic from seed.
- Appropriate for requested difficulty when possible.
- Generated within bounded attempts.

### 6.2 Recommended generation architecture

The production generation loop is:

```text
Input: seed, size, requested difficulty

1. Derive deterministic attempt seed.
2. Build solved Latin square.
3. Partition board into connected cages.
4. Assign cage operations and targets from the solved grid.
5. Build empty puzzle from cages.
6. Validate puzzle structure.
7. Run solver with maxSolutions = 2.
8. Reject if no solution or multiple solutions.
9. Validate returned solution strictly.
10. Score measured difficulty.
11. Accept if difficulty bucket matches request.
12. Retry with deterministic attempt seed if rejected.
13. Return bounded best-effort valid puzzle only if product policy allows fallback.
```

### 6.3 Latin-square generation

The solved grid should be generated from a deterministic Latin pattern:

```text
grid[row][col] = ((row + col) % N) + 1
```

Then seed-driven permutations are applied:

- Digit/symbol shuffle.
- Row permutation.
- Column permutation.
- Optional transpose/rotation/reflection if implemented.

This gives `O(N²)` solution generation with no backtracking.

### 6.4 Cage partitioning constraints

Cage partitioning must ensure:

- Every cell belongs to exactly one cage.
- No cage is empty.
- Every cage is orthogonally connected.
- Cage sizes respect difficulty profile.
- Cages do not exceed configured max size.
- Random growth is deterministic from seeded RNG.
- The loop always consumes remaining cells and terminates.

Recommended app-facing constraints for 9×9:

| Difficulty | Max cage size | Cage style |
|---|---:|---|
| Easy | 3 | many singles / 2-cell cages |
| Medium | 4 | mostly 2–3 cells, some 4 |
| Hard | 4 | fewer singles, more 3–4 |
| Expert | 4 | few singles, more 3–4 |

The deep research report allows max cage size 5 for larger boards, but the current Brainiax implementation is safer with max 4 on mobile. Keep it boring until benchmarks say otherwise.

### 6.5 Operation assignment constraints

Operation is assigned after cage cells are chosen, using values from the hidden solved Latin square.

Rules:

```text
size == 1:
  equality only

size == 2:
  addition, multiplication, subtraction, division allowed
  subtraction target must be positive
  division target must be integer-achievable

size > 2:
  addition or multiplication only
```

### 6.6 Generator difficulty profiles

Current generator behavior should be documented as weighted probabilities, not hard guarantees. The difficulty profile influences the generator, but final difficulty must be measured by solver telemetry.

Recommended profile contract:

| Difficulty | Cage size bias | Operation bias | Non-commutative target | Intended feel |
|---|---|---|---:|---|
| Easy | More 1–2 cell cages, some 3 | equality/addition favored | low | approachable, many anchors |
| Medium | 2–3 cell cages, some 4 | addition/multiplication mixed, some sub/div | moderate | fewer free anchors |
| Hard | 2–4 cell cages | balanced ops, fewer equality cages | higher | more branching |
| Expert | 3–4 cell cages, few singles | heavier multiplication and sub/div | highest | highest search pressure |

### 6.7 Generator telemetry

Generator should emit:

```text
durationUs
cageCount
maxCageSize
avgCageSize
opCounts
adjacentEdges
graphDensity
singleCageCount
longCageCount
sizeHistogram
```

Future recommended additions:

```text
attempt
requestedDifficulty
acceptedDifficulty
difficultyFallbackUsed
generationRejectedReason
uniquenessCheckMs
```

---

## 7. Solver documentation

### 7.1 Solver responsibilities

The solver must:

- Solve valid puzzles.
- Return zero solutions for invalid/contradictory puzzles.
- Count solutions up to `maxSolutions`.
- Stop early when solution count reaches `maxSolutions`.
- Support uniqueness checks with `maxSolutions = 2`.
- Avoid using the generator’s hidden solution.
- Emit useful telemetry for difficulty scoring.

### 7.2 Solver approach

Recommended/current architecture:

```text
Hybrid CSP solver:
- row masks
- column masks
- cell domains as bitmasks
- cage candidate combination precomputation
- MRV cell selection
- forward checking
- DFS search
- early contradiction pruning
- early exit after maxSolutions
```

### 7.3 Domain representation

Each unfilled cell has a bitmask domain:

```text
bit 0 = digit 1
bit 1 = digit 2
...
bit N-1 = digit N
```

Rows and columns keep used-value masks:

```dart
List<int> rowMask;
List<int> colMask;
```

### 7.4 Cage combination generation

For each cage, precompute all ordered value lists satisfying the cage operation/target for the cage’s cells.

Required constraints:

- Every value is in `1..N`.
- Combination matches operation and target.
- It must remain compatible with row/column masks during propagation.
- Equality cages have exactly one combo: `[target]`.
- Subtraction/division combos only occur for 2-cell cages.

### 7.5 Propagation rules

On initialization and after each assignment:

1. Remove row/column used values from unassigned cell domains.
2. For each cage, filter cage combos against:
   - assigned cell values,
   - row masks,
   - column masks,
   - current domains.
3. If no fitting cage combo exists, return contradiction.
4. For each unassigned cage cell, intersect current domain with values still appearing in fitting cage combos.
5. Repeat until no domains change.

### 7.6 Search rules

Search must:

- Select an unassigned cell using MRV.
- Try values from that cell’s domain.
- Assign value.
- Propagate constraints.
- Recurse if consistent.
- Restore state after branch.
- Stop after `maxSolutions`.

### 7.7 Solver telemetry

Current required telemetry:

```text
searchNodes
searchDepth
propagationDepth
branchDecisions
```

Recommended future telemetry:

```text
backtracks
contradictions
forcedAssignments
maxBranchingFactor
avgBranchingFactor
avgCageComboCount
maxCageComboCount
solveElapsedUs
```

---

## 8. Validator documentation

### 8.1 Validator responsibilities

The validator has three distinct responsibilities:

1. **Puzzle validation** — checks empty/in-progress puzzle structure and non-strict constraints.
2. **Solution validation** — checks a proposed completed solution against all strict constraints.
3. **Solved-state detection** — determines whether the current player board is completely solved.

### 8.2 `validatePuzzle(board)`

Should check:

- Positive board size.
- Row duplicates among filled values.
- Column duplicates among filled values.
- Filled values in range `0..N`.
- Cage IDs are unique.
- Cages are orthogonally connected.
- Equality cages have exactly one cell.
- Subtraction cages have exactly two cells.
- Division cages have exactly two cells.
- Cage targets are positive.
- Cage targets are plausible for size and operation.
- Non-strict equality cage conflicts if already filled.

`validatePuzzle` does **not** require the board to be complete.

### 8.3 `validateSolution(puzzle, solution)`

Should check:

- Puzzle and solution sizes match.
- Puzzle and solution cage counts match.
- All rows are complete and contain no duplicates.
- All columns are complete and contain no duplicates.
- Every cell value is in `1..N`.
- Every cage is complete.
- Every cage exactly matches its operation/target.

### 8.4 `isSolved(board)`

Returns true only if:

- Board is complete.
- No row conflict exists.
- No column conflict exists.
- Every cage strictly matches operation/target.

### 8.5 Move validation

A user move is valid if:

- Row is in range.
- Column is in range.
- Value is in `0..N`.
- Resulting board passes non-strict puzzle validation.

`0` means clear cell and should be allowed unless the UI has a separate erase mechanism.

---

## 9. Difficulty documentation

### 9.1 Difficulty is not only generator parameters

Generator parameters are not enough. A puzzle is only truly Easy/Medium/Hard/Expert if measured solver/cage metrics support that label.

Difficulty must combine:

- Generator profile.
- Cage structure.
- Operation distribution.
- Solver telemetry.
- Final calibrated thresholds.

### 9.2 Current scoring signals

Current scorer uses:

```text
cageCount
avgCageSize
maxCageSize
graphDensity
subtractiveRatio
multiplicativeRatio
singleCageRatio
longCageRatio
propagationDepth
searchDepth
searchNodes
branchDecisions
```

### 9.3 Current raw score formula

Current formula:

```text
cageComplexity =
  avgCageSize * 1.5
+ maxCageSize * 2.0
+ longCageRatio * 16.0

opPressure =
  subtractiveRatio * 32.0
+ multiplicativeRatio * 10.0

solverPressure =
  propagationDepth * 2.8
+ searchDepth * 4.5
+ searchNodes / 12.0

adjacencyPressure =
  graphDensity * 20.0

relief =
  singleCageRatio * 10.0

rawScore =
  max(0, cageComplexity + opPressure + solverPressure + adjacencyPressure - relief)
```

### 9.4 Current bucket thresholds

Current thresholds:

| Bucket | Max inclusive score |
|---|---:|
| Easy | 391.5 |
| Medium | 399.5 |
| Hard | 415.0 |
| Expert | 9999.0 |

These thresholds are calibrated for the current implementation and may look narrow. That is acceptable only if benchmark distributions prove separation. If not, recalibrate immediately; fake difficulty labels are worse than no labels.

### 9.5 How to differentiate difficulty levels

#### Easy

Expected signals:

- Highest single-cage ratio.
- Smaller average cage size.
- Lower long-cage ratio.
- More equality/addition.
- Fewer subtraction/division cages.
- Lower solver search nodes.
- Lower search depth.
- Lower branch decisions.
- More propagation-driven solves.

Player feel:

- More obvious anchors.
- More row/column elimination.
- Fewer arithmetic traps.

#### Medium

Expected signals:

- Moderate single-cage ratio.
- More 2–3 cell cages.
- Multiplication appears more often.
- Some 2-cell subtraction/division.
- Solver may branch, but not heavily.

Player feel:

- Requires basic cage reasoning.
- Still forgiving.
- No sustained guessing pressure.

#### Hard

Expected signals:

- Lower single-cage ratio.
- More 3–4 cell cages.
- Higher non-commutative ratio.
- Higher search depth.
- More branch decisions.
- Higher graph density / cage interaction pressure.

Player feel:

- Requires combining row/column constraints with cage possibilities.
- Fewer obvious starts.
- Mistakes are easier to make.

#### Expert

Expected signals:

- Lowest single-cage ratio.
- Highest long-cage ratio.
- Highest multiplication and subtraction/division pressure.
- Highest search nodes and search depth.
- Most branch decisions.
- Highest calibrated raw score.

Player feel:

- Many cages have multiple plausible combinations.
- Row/column/cage interactions matter constantly.
- Not friendly to sleepy thumbs.

### 9.6 Calibration rules

Every difficulty recalibration should:

1. Generate a deterministic corpus:
   - at least 100 seeds per difficulty,
   - preferably 500+ before release.
2. Record raw score and all metrics.
3. Calculate p10, p25, p50, p75, p90, p95 per requested difficulty.
4. Confirm monotonic separation:
   - Easy median < Medium median < Hard median < Expert median.
5. Confirm overlap is acceptable.
6. Update thresholds.
7. Add regression tests that lock representative seeds, not every random seed.
8. Re-run benchmarks on low-end Android hardware.

---

## 10. App integration documentation

### 10.1 UI thread rule

Generation and uniqueness checks may be expensive. App generation should run off the Flutter UI thread, using isolate-based generation or equivalent.

### 10.2 Play screen expectations

The MathDoku play screen should support:

- 9×9 board rendering.
- Cage border rendering.
- Cage target/operator labels.
- Cell selection.
- Number entry 1–9.
- Clear cell.
- Invalid move feedback.
- Solved-state detection.
- Timer.
- Undo/redo.
- Hints.
- Local save/continue.
- Daily/random modes.

### 10.3 Hint behavior

Current simple hint behavior may reveal a single cell from a solver result.

Recommended future hint tiers:

1. Highlight row/column conflict.
2. Highlight cage contradiction.
3. Show candidate elimination.
4. Show forced cell.
5. Reveal cell as last resort.

Hints should derive from solver logic rather than a stored backend solution.

### 10.4 Daily challenge behavior

Daily MathDoku should be generated from deterministic inputs:

```text
date + puzzleType + difficulty + size + engineVersion/seed version
```

All users should get the same daily puzzle for the same date/type/difficulty/size if that is the intended product behavior.

Do not download daily boards from Firebase.

---

## 11. Metadata for stats, progress, sync, and leaderboards

### 11.1 Generated puzzle metadata

Store locally and include in completion events:

```text
engineId
engineVersion
rngId
seedStr
seed64
size
difficultyLabel
difficultyScore
generationAttempt
generatorTelemetry
solverTelemetry
solutionCount
```

### 11.2 Local progress state

Local progress should include:

```text
current cells
notes/pencil marks if supported
elapsed time
move count
hint count
startedAt
lastPlayedAt
seed
difficulty
size
engineVersion
```

### 11.3 Completion event

Future-compatible completion event:

```dart
class PuzzleRunResult {
  final String localRunId;
  final String puzzleType;     // mathdoku_classic
  final String mode;           // daily/random
  final String seed;
  final String difficulty;
  final String size;           // 9x9
  final int elapsedMs;
  final int moves;
  final int hintsUsed;
  final bool completed;
  final DateTime startedAt;
  final DateTime completedAt;
  final String engineVersion;
  final double difficultyScore;
}
```

### 11.4 Leaderboard-safe fields

Leaderboard submission may include:

```text
uid
displayName
puzzleType
mode
periodId/date
difficulty
size
elapsedMs
moves
hintsUsed
completedAt
engineVersion
seed/date identifier
```

Do not submit solution.

---

## 12. Performance requirements

### 12.1 Runtime targets

Recommended targets for 9×9 MathDoku:

| Operation | Target |
|---|---:|
| Move validation | p95 < 5 ms |
| `isSolved` check | p95 < 5 ms |
| Solver uniqueness count | p95 < 250 ms, p99 < 750 ms |
| Isolated generation | p95 < 2 s, p99 < 3 s |
| App UI frame time during generation | no visible jank / no ANR |

If benchmarks prove these too strict or too loose, update this document with measured values.

### 12.2 Complexity warnings

Worst-case solving is exponential.

Main risk drivers:

- High searchNodes.
- High branchDecisions.
- Many large cages.
- Low single-cage ratio.
- High multiplication/subdivision ambiguity.
- Excessive retry attempts.
- Full-state cloning inside DFS.

### 12.3 Optimization priorities

If p95/p99 regresses:

1. Cache cage combinations by `(size, operation, target, cageLength)`.
2. Add backtrack/contradiction telemetry.
3. Replace full snapshot clones with stack-based undo.
4. Tighten difficulty profiles.
5. Lower max cage size or long-cage ratio.
6. Add generation timeout/failure reporting.

---

## 13. Testing requirements

### 13.1 Unit tests

Required:

- Board constructor rejects invalid cell count.
- Board constructor rejects uncovered cells.
- Board constructor rejects overlapping cages.
- Validator rejects duplicate cage IDs.
- Validator rejects disconnected cages.
- Validator rejects invalid equality size.
- Validator rejects subtraction/division cages not size 2.
- Validator rejects non-positive targets.
- Validator rejects target out of plausible range.
- Validator detects row duplicates.
- Validator detects column duplicates.
- Validator detects incomplete strict solution.
- Validator accepts known valid solution.

### 13.2 Solver tests

Required:

- Known unique fixture returns exactly 1 solution.
- Known multi-solution fixture returns 2 when `maxSolutions = 2`.
- Invalid filled cage mismatch returns 0 solutions.
- Row conflict returns 0 solutions.
- Column conflict returns 0 solutions.
- Solver respects `maxSolutions`.
- Solver does not require hidden generator solution.

### 13.3 Generator tests

Required:

- Same seed + size + difficulty returns same puzzle.
- Different seeds produce different puzzles often enough.
- Generated puzzles validate.
- Generated puzzles solve.
- Generated puzzles are unique.
- Generated cages cover full board.
- Generated cages are connected.
- Generated sub/div cages are always size 2.
- Generated 9×9 puzzles pass all above per difficulty.

### 13.4 Difficulty tests

Required:

- Representative Easy score is in Easy bucket.
- Representative Medium score is in Medium bucket.
- Representative Hard score is in Hard bucket.
- Representative Expert score is in Expert bucket.
- Median score separation across sample seeds is monotonic.
- Difficulty mismatch fallback is detected and logged if it occurs.

### 13.5 Serialization tests

Required:

- `toJson -> fromJson` round trip preserves board.
- Serialized puzzle excludes solution.
- Local progress serialization preserves cells, seed, difficulty, size, elapsed time, hints, and moves.

### 13.6 Fuzz/property tests

Recommended:

- Generate 100+ deterministic seeds per difficulty.
- Assert no invalid generated boards.
- Assert no multi-solution generated boards.
- Assert no hangs.
- Track generation failures and attempts.

### 13.7 Benchmark tests

Recommended command shape:

```bash
dart bin/bench.dart --engines "mathdoku_classic" --count 100
```

Recommended matrix:

```text
9x9 easy
9x9 medium
9x9 hard
9x9 expert
```

Record:

```text
p50 generation ms
p95 generation ms
p99 generation ms
p50 uniqueness ms
p95 uniqueness ms
p99 uniqueness ms
searchNodes distribution
branchDecisions distribution
rawScore distribution
fallback/mismatch count
```

---

## 14. Failure modes and required protections

| Failure mode | Protection |
|---|---|
| Multi-solution puzzle accepted | Always solve with `maxSolutions = 2` before accepting |
| No-solution puzzle accepted | Reject zero-solution solver result |
| Solver accepts cage mismatch | Propagation must reject cages with no fitting combo |
| Fake difficulty labels | Calibrate with solver metrics and thresholds |
| Infinite generation loop | Hard deterministic max attempts |
| UI jank | Generate in isolate |
| Non-deterministic daily puzzle | Seeded RNG only; no DateTime/random calls inside core |
| Backend leaks solution | Never sync solution |
| Invalid cage shape | Validator checks orthogonal connectivity |
| Sub/div ambiguity | Restrict sub/div to 2-cell cages |
| Slow 9×9 Expert | Benchmark p95/p99 and optimize/cap profiles |

---

## 15. Maintenance checklist

When changing MathDoku engine code:

1. Update this document if rules or thresholds change.
2. Run MathDoku unit tests.
3. Run all `puzzle_core` tests.
4. Run 9×9 benchmark matrix.
5. Check deterministic seeds.
6. Check generated puzzle uniqueness.
7. Check daily seed reproducibility.
8. Check app play flow manually on emulator.
9. Do not touch Firebase board storage. Seriously. That door has spikes.

---

## 16. Recommended repo location

Recommended path:

```text
docs/puzzles/MATHDOKU_ENGINE.md
```

Alternative package-local path:

```text
packages/puzzle_core/docs/MATHDOKU_ENGINE.md
```

Use the first path if this is intended for product + app + engine contributors. Use the second if it is meant only for core-engine maintainers.

---

## 17. Codex prompt to add this documentation

Use **High** reasoning effort.

```text
Repo: brainiax_puzzles
Branch: feat/phase3-play-ux

Task: Add comprehensive MathDoku engine documentation.

Create:
- docs/puzzles/MATHDOKU_ENGINE.md

The document must cover:
- Formal MathDoku rules used by Brainiax.
- 9x9 app constraint.
- Board/cell/cage model.
- Generator constraints.
- Solver constraints.
- Validator constraints.
- Difficulty profile definitions and score formula.
- Current bucket thresholds from packages/puzzle_core/assets/mathdoku_difficulty_thresholds.json.
- App integration expectations.
- Metadata for progress, stats, sync, and future leaderboards.
- Performance targets.
- Required unit, solver, generator, difficulty, serialization, fuzz, and benchmark tests.
- Failure modes and protections.
- Explicit rule: do not store boards or solutions in Firebase.

Files to inspect before writing:
- packages/puzzle_core/lib/src/mathdoku/mathdoku_board.dart
- packages/puzzle_core/lib/src/mathdoku/mathdoku_generator.dart
- packages/puzzle_core/lib/src/mathdoku/mathdoku_solver.dart
- packages/puzzle_core/lib/src/mathdoku/mathdoku_validator.dart
- packages/puzzle_core/lib/src/mathdoku/mathdoku_difficulty.dart
- packages/puzzle_core/lib/src/mathdoku/mathdoku_engine.dart
- packages/puzzle_core/assets/mathdoku_difficulty_thresholds.json
- apps/app/lib/shared/services/generation_isolate.dart
- apps/app/lib/shared/providers/puzzle_generation_controller.dart
- docs or README files that list puzzle engines

Acceptance criteria:
- Documentation matches current implementation.
- It clearly distinguishes generator, solver, validator, difficulty, app integration, and testing responsibilities.
- It states that sub/div cages are 2-cell only.
- It states that uniqueness is checked by counting solutions up to 2.
- It states that difficulty labels must be measured using solver/cage metrics.
- No code changes unless needed to fix broken links.
- Run formatting if markdown tooling exists.
- Return a concise summary and any commands run.
```
