# Monochrome Nonogram Engine Documentation

Status: production-hardening reference
Puzzle ID: `nonogram_mono`
Display name: Monochrome Nonogram
Package area: `packages/puzzle_core`
App integration area: `apps/app`
Primary engine files:

* `packages/puzzle_core/lib/src/nonogram/nonogram_engine.dart`
* `packages/puzzle_core/lib/src/nonogram/nonogram_board.dart`
* `packages/puzzle_core/lib/src/nonogram/nonogram_generator.dart`
* `packages/puzzle_core/lib/src/nonogram/nonogram_solver.dart`
* `packages/puzzle_core/lib/src/nonogram/nonogram_validator.dart`
* `packages/puzzle_core/lib/src/nonogram/nonogram_difficulty.dart`
* `packages/puzzle_core/lib/src/util/nonogram.dart`

## 1. Purpose

This document defines the production constraints for the Brainiax Puzzles Monochrome Nonogram engine.

It covers:

* puzzle rules
* board representation
* clue constraints
* generator constraints
* solver constraints
* validator constraints
* difficulty separation
* hints
* metadata and serialization
* performance budgets
* app integration
* test requirements
* known risks and non-negotiable invariants

The goal is simple: every generated Nonogram must be valid, solvable, uniquely solvable, deterministic from seed, reasonably fast on mobile, and honestly labeled by difficulty.

No cloud crutches. No stored backend solutions. No “the solver found one answer, ship it.” That way lies cursed puzzle soup.

---

## 2. Puzzle identity and rules

A Monochrome Nonogram is a rectangular grid puzzle.

Each solved cell is binary:

```text
filled
empty
```

During play, each visible cell is tri-state:

```text
unknown
filled
empty-marked
```

A puzzle is defined by:

```text
width
height
rowClues
columnClues
currentCells
metadata
```

A clue is an ordered sequence of positive integers. Each integer represents the length of one contiguous run of filled cells.

Example:

```text
[3]      means exactly one run of 3 filled cells.
[1, 2]   means one filled cell, at least one empty separator, then two filled cells.
[]       means the whole line is empty.
```

Internal empty-line representation must always be:

```text
[]
```

Do not use `[0]` internally. `[0]` may be accepted only as a legacy/import format and normalized immediately to `[]`.

---

## 3. Formal validity constraints

For a board of width `W` and height `H`:

### 3.1 Dimension constraints

* `W > 0`
* `H > 0`
* `cells.length == W * H`
* `rowClues.length == H`
* `columnClues.length == W`

### 3.2 Cell value constraints

Allowed cell values:

```text
null = unknown
0    = empty
1    = filled
```

No other value is valid.

### 3.3 Clue syntax constraints

Every clue value must be positive.

Valid:

```text
[]
[1]
[2, 1]
[5]
```

Invalid:

```text
[0]
[-1]
[1, 0]
```

### 3.4 Clue fit constraints

For a line of length `L`:

```text
sum(clues) + clues.length - 1 <= L
```

For an empty clue:

```text
[] requires 0 filled cells
```

Examples:

```text
L = 5, clue [3, 1] is valid because 3 + 1 + 1 separator = 5
L = 5, clue [3, 2] is valid because 3 + 2 + 1 separator = 6 is false, so invalid
L = 5, clue [] is valid
```

### 3.5 Solved-board constraints

A board is solved only when:

* every cell is non-null
* every row’s derived clue exactly equals its row clue
* every column’s derived clue exactly equals its column clue

Unknown cells must never be treated as empty for solved-state detection.

---

## 4. Supported sizes

Current engine-supported sizes:

```text
10x10
15x15
```

The generator must reject unsupported sizes with a clear error.

Current app metadata must not advertise unsupported sizes. If the app exposes `5x5` or `20x20`, either the engine must support them or the app must remove them from the Nonogram selection surface.

Recommended production stance:

| Size  | Status                        | Notes                                                |
| ----- | ----------------------------- | ---------------------------------------------------- |
| 5x5   | onboarding-only future option | Only after renderer and generator support it         |
| 10x10 | supported                     | Main Easy/Medium size                                |
| 15x15 | supported                     | Main Medium/Hard size                                |
| 20x20 | future/opt-in                 | Needs zoom, drag ergonomics, and stronger perf gates |

---

## 5. Board representation

Public model:

```dart
class NonogramBoard {
  final int width;
  final int height;
  final List<List<int>> rowClues;
  final List<List<int>> columnClues;
  final List<int?> cells;
}
```

Recommended internal hot-path representation for future optimization:

```text
Uint8List cells
0 = unknown
1 = empty
2 = filled
```

Current public values:

```text
null = unknown
0 = empty
1 = filled
```

Public clue lists should be immutable after construction.

The board JSON should include:

```json
{
  "width": 10,
  "height": 10,
  "rowClues": [[3], [], [1, 1]],
  "columnClues": [[2], [1], []],
  "cells": [null, 1, 0]
}
```

---

## 6. Clue derivation

Clue derivation must be canonical.

Algorithm:

```text
for each line:
  scan from start to end
  count consecutive filled cells
  emit count when run ends
  emit [] if no run exists
```

Rules:

* leading empty cells do not create clues
* trailing empty cells do not create clues
* adjacent runs must be separated by at least one empty cell
* generated clues must never contain `0`

Example:

```text
filled filled empty filled empty
=> [2, 1]
```

Example:

```text
empty empty empty
=> []
```

---

## 7. Generator architecture

The generator is bitmap-first.

Production flow:

```text
seed + size + difficulty
→ deterministic bitmap synthesis
→ visual/structural quick screen
→ derive row and column clues
→ solve and count solutions up to 2
→ require unique
→ require solved result matches generated bitmap
→ emit puzzle + telemetry
```

The generator must not synthesize clues first.

The generated bitmap is only a candidate solution. It does not prove uniqueness.

---

## 8. Generator hard constraints

Every accepted generated puzzle must satisfy:

* supported size
* deterministic from seed
* valid row and column clues
* at least one filled cell
* no invalid clue values
* clue sums across rows and columns match naturally by derivation
* solver status is `unique`
* solution count is exactly 1
* uniqueness proof is complete
* solver did not return `unknown`
* solver did not hit a cap that invalidates proof
* accepted solution matches the generated bitmap
* difficulty telemetry is emitted
* generation attempts are bounded

The generator must reject:

* invalid size
* empty all-blank bitmap unless explicitly allowed for tests
* clue overflow
* solver status `noSolution`
* solver status `multiple`
* solver status `unknown`
* timeout/cap exhaustion
* visual garbage below minimum score
* density outside profile
* too many isolated filled cells
* too many empty/full lines
* giant solid rectangle patterns
* giant undifferentiated blobs
* exact symmetry when the profile rejects exact symmetry

---

## 9. Generator attempt limits

The generator must have a hard attempt cap.

Current primary cap:

```text
maxUniquenessAttempts = 64
```

No generator loop may run forever.

Failure must be explicit:

```text
throw StateError("Unable to generate unique nonogram...")
```

Do not silently downgrade correctness.

Acceptable fallback behavior:

* deterministic fallback bitmap
* deterministic retry sub-seeds
* return nearest difficulty only if the pipeline clearly marks it as a difficulty mismatch fallback

Unacceptable fallback behavior:

* accepting multi-solution puzzles
* accepting solver `unknown`
* accepting timeout as unique
* storing a prebuilt cloud board to escape generation failure

---

## 10. Bitmap generation profiles

The current generator uses structured bitmap generation, not pure noise.

Generation stages:

```text
coarse scaffold
→ region/motif/icon family
→ target density
→ target fragmentation
→ cleanup singletons and pinholes
→ target density again
→ cleanup again
```

Supported bitmap families:

```text
region family
motif family
icon family
```

Icon-like families may include shapes such as:

```text
house
key
leaf
boat
```

The exact icon output is not product content; it is a seeded scaffold used to create clean candidate bitmaps.

---

## 11. Visual quick-screen constraints

The quick screen exists to reject bad candidates before expensive uniqueness checks.

Tracked visual metrics:

```text
density
fragmentation
visualScore
isolatedFilledRatio
emptyFullLineRatio
largestFilledComponentRatio
largestSolidRectangleRatio
hasExactSymmetry
```

Rejection reasons:

```text
density_outside_profile
fragmentation_outside_profile
too_many_isolated_filled_cells
too_many_empty_or_full_lines
giant_rectangle
giant_blob
exact_symmetry
low_visual_score
not_unique
```

The quick screen should stay deterministic and cheap.

---

## 12. Current generation profile intent

### Easy

Intent:

* lower fragmentation
* smoother shapes
* more contiguous areas
* fewer cuts/chips
* less noisy
* high visual clarity

Current profile shape:

```text
density: roughly 0.36–0.66
target density: roughly 0.50
fragmentation: roughly 0.75–1.35
exact symmetry allowed
low chip/cut counts
```

Easy should usually solve mostly through line propagation and simple overlap logic.

### Medium

Intent:

* moderate fragmentation
* still picture-like
* more cuts and accents than Easy
* useful daily-driver difficulty

Current profile shape:

```text
density: roughly 0.34–0.63
target density: roughly 0.47
fragmentation: roughly 1.15–1.55
exact symmetry rejected
moderate region/motif complexity
```

Medium should require more line-domain reasoning but little or no full search.

### Hard

Intent:

* higher fragmentation
* more cuts/chips
* less obvious line progress
* still visually coherent

Current profile shape:

```text
density: roughly 0.31–0.60
target density: roughly 0.445
fragmentation: roughly 2.9–4.45
exact symmetry rejected
higher cut/chip counts
```

Hard may require contradiction-based deductions or shallow branching in the complete solver.

### Expert

Intent:

* highest controlled fragmentation
* more ambiguity
* meaningful search may be required
* still unique and visually intentional

Current profile shape:

```text
density: roughly 0.30–0.61
target density: roughly 0.43
fragmentation: roughly 1.9–4.9
exact symmetry rejected
highest cut/chip counts
```

Current app warning:

The engine has an Expert profile, but the app registry may not expose Expert for Monochrome Nonogram. Do not expose Expert until benchmark and UX gates pass.

---

## 13. Solver architecture

The solver must support two conceptual modes:

```text
logic mode
complete mode
```

### Logic mode

Used for:

* hints
* human-style difficulty telemetry
* simple propagation checks

Logic mode may be incomplete, but it must never claim proof of uniqueness.

### Complete mode

Used for:

* generation acceptance
* uniqueness checking
* validator proof
* fixture testing

Complete mode must count solutions up to 2 and return a definitive status or `unknown`.

---

## 14. Line solver constraints

The line solver is the core primitive.

Given:

```text
line length
clues
current known cells
```

It must answer:

```text
is the line contradictory?
which placements survive?
which cells are forced filled?
which cells are forced empty?
how many placements remain?
```

Line placement rules:

* `[]` has exactly one placement: all-empty
* `[L]` on a line of length `L` has exactly one placement: all-filled
* `[1, 1]` must include at least one empty separator
* overflow clues produce no placements
* known filled cells must be filled in every surviving placement
* known empty cells must be empty in every surviving placement

The line solver must cache:

```text
placement pools by line length + clue list
filtered summaries by clue key + known filled mask + known empty mask
```

The cache must be deterministic.

---

## 15. Complete solver constraints

The complete solver must:

* start with row/column line propagation
* repeatedly propagate until no changes
* branch only when propagation stalls
* choose a branch using constrained-line/MRV-style selection
* branch on a cell from the most constrained unresolved line
* apply propagation after every assumption
* count solutions up to 2
* exit early on the second solution
* report `multiple` as soon as 2 solutions are found
* report `noSolution` only when fully proven
* report `unique` only when exactly one solution is found and proof is complete
* report `unknown` when a proof cap is hit

Caps that can force `unknown`:

```text
maxSearchDepth
maxLineIterations
speculativeStepBudget
wall-clock budget, if added
node budget, if added
```

The solver must never infer uniqueness from `solutions.length == 1` if proof is incomplete.

---

## 16. Solver status contract

Allowed solver statuses:

```text
noSolution
unique
multiple
unknown
```

Meaning:

| Status       | Meaning                                                 | Generator action      |
| ------------ | ------------------------------------------------------- | --------------------- |
| `noSolution` | No valid solution exists and proof is complete          | Reject                |
| `unique`     | Exactly one valid solution exists and proof is complete | Candidate may proceed |
| `multiple`   | At least two solutions exist                            | Reject                |
| `unknown`    | Solver cap or timeout prevented proof                   | Reject                |

`unknown` is not a soft success. It is a rejection condition for generated content.

---

## 17. Solver telemetry

The solver should emit:

```text
status
logicAssignments
initialLogicAssignments
logicCompletion
speculativeSteps
visitedNodes
maxDepth
maxDepthReached
branchCount
contradictionCount
cacheHits
cacheMisses
propagationRounds
lineIterations
depthCapHit
lineIterationCapHit
maxSolutionsCapHit
speculativeStepBudgetHit
proofIncomplete
elapsed
```

This telemetry is used for:

* generation diagnostics
* difficulty scoring
* benchmark gates
* regression detection
* future player-facing analytics

---

## 18. Validator constraints

The validator has three responsibilities:

```text
validatePuzzle
validateSolution
isSolved
```

### validatePuzzle

Must detect:

* row clue count mismatch
* column clue count mismatch
* cell count mismatch
* invalid clue values
* invalid cell values
* clue overflow
* row contradictions
* column contradictions

It may accept incomplete boards if they are still clue-consistent.

### validateSolution

Must detect:

* dimension mismatch
* solution cell count mismatch
* null solution cells
* invalid solution cell values
* row clue mismatch
* column clue mismatch

A solution board must be complete.

### isSolved

Must return true only when:

* board is complete
* all row clues match
* all column clues match

Incomplete boards are not solved.

---

## 19. Move validation constraints

A player move must be rejected if:

* row index is out of range
* column index is out of range
* value is not `null`, `empty`, or `filled`
* applying the move creates a clue contradiction

A player move may clear a cell by setting it to `null`.

Move validation should be clue-consistency based by default. It should not compare against the hidden solution in normal mode.

Strict mistake mode is allowed only if it is explicit, local-only, and product-approved.

---

## 20. Hint constraints

Current behavior may reveal a solved cell from a solver result.

Production target:

* first try explainable line-domain hints
* only reveal from solution as fallback
* never return a “forced” hint unless the opposite value is provably contradictory
* preserve deterministic hint order for the same state and hint iteration
* do not use backend data for hints

Hint categories should eventually include:

```text
line_overlap
completed_line_closure
forced_empty
forced_filled
line_contradiction
two_way_logic
reveal_fallback
```

Hint metadata should include:

```text
engineId
kind
row
column
value
reason, when explainable
```

---

## 21. Difficulty scoring

Difficulty must be measured, not guessed.

The final label should combine:

```text
human-style logic telemetry
complete-solver search telemetry
structural metrics
visual penalties
```

Current scorer uses:

```text
logicCompletion
propagationRounds
visitedNodes
maxDepth
branchCount
contradictionCount
speculativeSteps
fillDensity
averageCluesPerLine
maxCluesPerLine
averageClueLength
alternation
fragmentation
isolatedSingletonRatio
checkerboardAlternation
giantSolidBlobRatio
emptyFullLineRatio
```

Current penalty groups:

```text
logicPenalty
propagationPenalty
searchPenalty
structuralPenalty
visualPenalty
```

A puzzle’s requested difficulty is only a target. The actual emitted difficulty must come from measured telemetry.

---

## 22. Difficulty level definitions

### Easy

Player experience:

* many obvious line deductions
* clean shapes
* low fragmentation
* little ambiguity
* no guessing
* no meaningful DFS needed

Expected telemetry:

```text
logicCompletion: high, ideally >= 0.80
visitedNodes: 0 or very low
branchCount: 0 or very low
maxDepth: 0
contradictionCount: low
fragmentation: low
visualScore: acceptable/high
```

Suggested score band:

```text
0–29
```

### Medium

Player experience:

* still fair for daily play
* some less obvious line-domain deductions
* moderate clue density
* limited ambiguity
* usually no deep search

Expected telemetry:

```text
logicCompletion: roughly 0.50–0.80
visitedNodes: low
branchCount: low
maxDepth: 0–1
contradictionCount: low to moderate
fragmentation: moderate
```

Suggested score band:

```text
30–54
```

### Hard

Player experience:

* more fragmented picture
* line progress is less immediate
* several contradiction-style deductions may be needed
* shallow branching may appear in the complete solver

Expected telemetry:

```text
logicCompletion: roughly 0.25–0.55
visitedNodes: moderate
branchCount: moderate
maxDepth: 1–3
contradictionCount: moderate
fragmentation: high but controlled
```

Suggested score band:

```text
55–79
```

### Expert

Player experience:

* high ambiguity
* meaningful search may be required for proof
* still unique
* still visually intentional
* not just random static wearing a fake mustache

Expected telemetry:

```text
logicCompletion: may be < 0.35
visitedNodes: high but bounded
branchCount: high but bounded
maxDepth: higher than Hard
contradictionCount: higher
fragmentation: high
visualScore: must still pass minimum
```

Suggested score band:

```text
80–100+
```

Expert should be exposed only after:

* solver status is sound
* generation p95/p99 is acceptable
* UI supports the target size comfortably
* player-facing labels are calibrated

---

## 23. Difficulty thresholds

The scorer returns a raw score.

The bucket config maps raw scores to labels.

Recommended target buckets:

```json
{
  "buckets": [
    { "id": "easy", "maxInclusive": 29.0 },
    { "id": "medium", "maxInclusive": 54.0 },
    { "id": "hard", "maxInclusive": 79.0 },
    { "id": "expert", "maxInclusive": 9999.0 }
  ]
}
```

Existing thresholds may differ. The important rule is that thresholds must be calibrated from real generated puzzles and solver telemetry.

---

## 24. Difficulty calibration plan

Calibration must be empirical.

For each supported size and requested difficulty:

1. Generate at least 1,000 deterministic seeded candidates.
2. Record accepted/rejected counts.
3. Record solver status distribution.
4. Record generation attempts per accepted puzzle.
5. Record difficulty metrics.
6. Plot score distributions.
7. Manually inspect outliers.
8. Adjust generator profile parameters.
9. Adjust difficulty bucket thresholds.
10. Repeat until labels separate cleanly.

Player analytics should later validate the labels using:

```text
completion rate
average solve time
hint usage
mistake rate
abandonment rate
restart rate
```

Do not tune by vibes alone. Vibes are useful for art direction, not proof.

---

## 25. Performance constraints

Recommended low-end Android budgets:

| Operation                         |                   Target |
| --------------------------------- | -----------------------: |
| Move validation median            |                   < 1 ms |
| Line hint median                  |                  < 10 ms |
| Full hint median                  |                  < 30 ms |
| Clue derivation                   |      effectively instant |
| Accepted 10x10 uniqueness median  |                 < 100 ms |
| Accepted 15x15 uniqueness median  |                 < 300 ms |
| Easy/Medium random generation p95 |                    < 1 s |
| Hard/Expert random generation p95 |                    < 3 s |
| UI frame budget                   | never block main isolate |

Generation and full uniqueness checking should run off the Flutter UI isolate.

Repeated generation should eventually use a long-lived worker isolate rather than many short `Isolate.run` calls.

---

## 26. App integration constraints

Puzzle logic must remain pure Dart inside `packages/puzzle_core`.

The Flutter app may:

* request generation
* display loading/error/success states
* persist local progress
* request hints
* submit moves
* show completion
* sync metadata

The Flutter app must not:

* implement puzzle solving rules
* store canonical puzzle boards in Firebase
* store canonical solutions in Firebase
* block the UI thread during generation
* expose unsupported engine sizes
* silently accept generation failure

---

## 27. Local persistence and metadata

A generated puzzle should carry enough metadata for:

* local progress
* deterministic regeneration
* stats
* future sync
* future leaderboards
* debugging
* seed regression tests

Recommended metadata:

```json
{
  "type": "monochrome_nonogram",
  "engineId": "nonogram_mono",
  "engineVersion": "1.0.0",
  "generatorVersion": "g1",
  "rngId": "seeded_rng",
  "seedStr": "daily:nonogram_mono:2026-06-14",
  "seed64": 123456789,
  "width": 10,
  "height": 10,
  "difficultyLabel": "medium",
  "difficultyScore": 42.7,
  "rowClues": [[3], [], [1, 1]],
  "columnClues": [[2], [1], []],
  "solverTelemetry": {
    "status": "unique",
    "visitedNodes": 12,
    "branchCount": 2
  },
  "generatorTelemetry": {
    "attempts": 5,
    "candidateDensity": 0.47,
    "fragmentation": 1.3,
    "visualScore": 78.0,
    "rejectionReason": "accepted"
  }
}
```

Backend sync should store run metadata and stats, not canonical boards or solutions.

---

## 28. Daily challenge constraints

Daily challenges must remain deterministic and offline-first.

Daily puzzle identity should be derived from:

```text
puzzle type
date
difficulty
size
engine version
generator version
seed recipe version
```

Same input must produce the same puzzle.

If generator behavior changes, bump the generator version. Otherwise old daily seeds can drift.

---

## 29. Testing requirements

### Generator tests

Required:

* deterministic same seed test
* different seed diversity test
* supported size test
* unsupported size rejection test
* generation attempt cap test
* valid puzzle test
* unique solution test
* solver `unknown` rejection test
* multi-solution rejection test
* visual quick-reject test
* difficulty profile separation test

### Solver tests

Required:

* known unique fixture
* known multi-solution fixture
* known no-solution fixture
* capped unknown fixture
* empty-line fixture
* full-line fixture
* `[1, 1]` separator fixture
* contradiction fixture
* solution count up to 2
* no hidden-solution bias test

### Validator tests

Required:

* row count mismatch
* column count mismatch
* cell count mismatch
* invalid clue values
* clue overflow
* invalid cell value
* row contradiction
* column contradiction
* incomplete board is not solved
* completed valid board is solved
* completed invalid board is not solved

### Difficulty tests

Required:

* same puzzle gets same score repeatedly
* Easy sample scores lower than Medium
* Medium sample scores lower than Hard
* scorer records search metrics
* scorer records structural metrics
* scorer records visual penalties
* threshold mapping works

### Serialization tests

Required:

* board JSON round trip
* generated puzzle JSON round trip
* progress-state round trip
* legacy `[0]` import normalization if supported
* engine/generator version preservation

### Performance tests

Required metrics:

```text
median line solve time
p95 line solve time
median propagation time
p95 propagation time
median uniqueness time
p95 uniqueness time
generation attempts per accepted puzzle
accepted/rejected ratio by difficulty
cache hit/miss ratio
memory usage of placement pools
```

---

## 30. Common failure modes

### False uniqueness

Cause:

```text
solver found one solution but did not prove there is no second solution
```

Required behavior:

```text
return unknown or multiple, never unique
```

### Timeout treated as success

Cause:

```text
search budget exceeded but result reported as unique
```

Required behavior:

```text
return unknown
generation rejects
```

### Hidden solution bias

Cause:

```text
solver branches toward generated bitmap
```

Required behavior:

```text
validator must solve from clues only
```

### Empty-line inconsistency

Cause:

```text
using [] in one place and [0] elsewhere
```

Required behavior:

```text
normalize to []
```

### Separator bug

Cause:

```text
line [1, 1] allows adjacent filled cells
```

Required behavior:

```text
always require at least one empty separator between runs
```

### Fake difficulty

Cause:

```text
difficulty label based mostly on requested parameter
```

Required behavior:

```text
label based on measured telemetry
```

### Visual garbage

Cause:

```text
unique random bitmap with ugly noise
```

Required behavior:

```text
reject by visual score and profile metrics
```

### Unsupported app size

Cause:

```text
app advertises size that generator rejects
```

Required behavior:

```text
app registry and engine supported sizes must match
```

---

## 31. Current implementation notes

Current strengths:

* engine is pure Dart
* generator is bitmap-first
* generation attempts are bounded
* solver reports explicit status
* solver includes cache telemetry
* solver uses constrained-line/cell branch selection
* validator rejects incomplete solved states
* difficulty scorer uses solver, structural, and visual metrics
* generation emits useful candidate telemetry

Current known issue to fix:

* app metadata should not expose unsupported Nonogram sizes

Current possible improvement:

* hint system should move from solution-reveal-first to explainable logic-first
* long-lived worker isolate should replace repeated short-lived isolate generation if generation becomes frequent
* Expert should not be exposed until thresholds and UX are calibrated

---

## 32. Release readiness checklist

Before Monochrome Nonogram is considered production-ready:

* all generated puzzles are valid
* all generated puzzles are solvable
* all generated puzzles are uniquely solvable
* solver returns `unknown` on capped proof
* generator rejects `unknown`
* generator attempts are capped
* same seed reproduces same puzzle
* app exposes only supported sizes
* difficulty buckets are telemetry-calibrated
* move validation is near-instant
* generation does not block UI
* hints are deterministic
* no backend board/solution storage
* serialization round-trips
* fixed-seed regression suite passes
* multi-solution fixtures pass
* performance benchmarks pass on low-end Android

---

## 33. Non-negotiable invariants

These are not preferences.

```text
A generated puzzle must never be multi-solution.
A capped solver result must never be unique.
An incomplete board must never be solved.
A clue sequence must never contain 0 internally.
A generator loop must never be unbounded.
A difficulty label must be backed by telemetry.
A daily puzzle must be deterministic from versioned seed inputs.
A backend must not be the canonical source of puzzle boards or solutions.
```

Break any of these and the engine is no longer production-grade.

---
