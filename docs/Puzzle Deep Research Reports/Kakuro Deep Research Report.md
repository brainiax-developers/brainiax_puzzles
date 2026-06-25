Below is a production-grade, from-first-principles technical report for designing a **deterministic, on-device Kakuro engine** suitable for Brainiax Puzzles.

This is intentionally opinionated. It favors correctness, determinism, maintainability, and measurable difficulty over clever shortcuts.

* * * * *

1\. Executive Recommendation
============================

Recommended Overall Architecture
--------------------------------

For a mobile-first, pure-Dart Kakuro engine:

### Generator Strategy (Ranked)

**1️⃣ Layout-first → Solution-first → Derive clues → Solver-based uniqueness check (Recommended)**\
**2️⃣ Integrated CSP construction (layout + fill interleaved)**\
**3️⃣ Clue-first construction (not recommended)**

### Recommended Generator Loop

```
Input: width, height, difficulty, seed

1. Generate deterministic layout (from seed)
2. Assign solution digits via CSP solver
3. Derive clue sums from solution
4. Run uniqueness solver (count ≤ 2)
5. Run instrumented solver for difficulty metrics
6. Accept or reject
7. Retry deterministically if needed

```

Why this ordering?

-   Layout-first gives strong control over difficulty shape.

-   Filling solution before assigning sums guarantees internal consistency.

-   Deriving sums from a known solution avoids invalid clue generation.

-   Uniqueness must always be verified via solver.

-   Difficulty must be measured by solver, not guessed.

* * * * *

Solver Approach (Recommended)
-----------------------------

**Hybrid CSP solver with:**

-   Bitmask candidates per cell

-   Precomputed run-combination dictionaries

-   MRV (minimum remaining values)

-   Forward checking

-   Run-level propagation

-   Early exit when ≥ 2 solutions found

This balances:

-   Speed

-   Determinism

-   Maintainability

-   Fine-grained difficulty instrumentation

* * * * *

Uniqueness Strategy
-------------------

Always:

-   Count solutions up to 2

-   Exit immediately on second solution

-   Distinguish:

    -   Unique

    -   Multi-solution

    -   No solution

    -   Solver timeout

Never assume the constructed solution is unique.

* * * * *

Layout Strategy
---------------

-   Deterministic black-cell generation from seed

-   Enforce:

    -   No 1-cell runs

    -   All white cells belong to exactly one across and one down run

    -   Reasonable run length distribution

-   Optional rotational symmetry (recommended for aesthetics)

* * * * *

Clue Strategy
-------------

-   Always derive sums from completed solution

-   Never "guess" sums first

-   Control difficulty by:

    -   Run length distribution

    -   Ambiguity of sum combinations

    -   Frequency of single-combination runs

* * * * *

Difficulty Strategy
-------------------

Hybrid:

-   Generator parameters define coarse tier

-   Instrumented solver metrics define actual difficulty

-   Final classification uses measured solver complexity

* * * * *

2\. Formal Puzzle Model
=======================

Board Representation
--------------------

Let:

```
Board B: rectangular grid W × H

```

Each cell is either:

-   Black cell (block)

-   Clue cell (black with across/down sums)

-   White/value cell

* * * * *

White Cell Constraints
----------------------

Each white cell:

-   Belongs to exactly one across run

-   Belongs to exactly one down run

-   Must contain digit ∈ {1..9}

-   No repetition within each run

* * * * *

Run Definition
--------------

A run is:

-   A maximal contiguous horizontal or vertical sequence of white cells

-   Length ≥ 2 (1-cell runs are forbidden)

-   Associated with exactly one clue sum

* * * * *

Run Constraints
---------------

For each run R:

-   Let cells = {c₁ ... cₖ}

-   Digits are distinct

-   Sum(c₁ ... cₖ) = clueSum

* * * * *

Valid Layout Rules
------------------

-   No isolated white cells

-   Every white cell must have both across and down runs

-   No runs of length 1

-   No run longer than 9 (digit set constraint)

-   Border rules:

    -   First row and first column must be black or clue cells

    -   Runs start immediately after black cells

* * * * *

Valid Generated Kakuro
----------------------

A Kakuro is valid if:

1.  Layout satisfies structural rules

2.  All sums consistent with a valid solution

3.  Solver finds ≥ 1 solution

4.  Solver confirms exactly 1 solution

* * * * *

Metadata to Store
-----------------

```
{
  version,
  seed,
  width,
  height,
  difficultyLabel,
  difficultyScore,
  whiteCellCount,
  runCount,
  maxRunLength,
  generationAttempts,
  solverMetrics
}

```

* * * * *

3\. Survey of Algorithmic Approaches
====================================

A. Layout-First Generation (Recommended)
----------------------------------------

Generate black/white structure first, then fill digits.

**Strengths**

-   Control visual quality

-   Control difficulty shape

-   Deterministic

-   Newspaper-style layouts possible

**Weakness**

-   Requires strong CSP fill

✔ Best for mobile deterministic generation

* * * * *

B. Solution-First Grid
----------------------

Generate fully solved digit grid first, then carve black cells.

Problem:

-   Removing cells easily breaks uniqueness

-   Hard to preserve run structure

❌ Not recommended

* * * * *

C. CSP-Based Fill
-----------------

Treat entire puzzle as CSP:

-   Variables = white cells

-   Constraints:

    -   Distinct digits per run

    -   Sum per run

This is the solver core.

✔ Necessary for fill and uniqueness

* * * * *

D. Exact Cover / DLX
--------------------

Encode:

-   Cell-digit assignment

-   Run-sum constraint combinations

Elegant but:

-   Harder to integrate sum arithmetic cleanly

-   Harder to instrument for difficulty

Not worth complexity for mobile.

* * * * *

E. SAT/ILP
----------

Possible but heavy for on-device generation.

Not recommended.

* * * * *

F. Human-Style Logical Solvers
------------------------------

Used for difficulty scoring:

-   Single-combination run

-   Naked singles

-   Candidate elimination

-   Subset elimination

Useful for difficulty labeling.

* * * * *

4\. Recommended Data Structures (Dart-Friendly)
===============================================

Cell Representation
-------------------

Use flat index:

```
index = row * width + col

```

Store:

```
Uint8List cellType  // 0=black, 1=white
Int32List cellValue // 0 if unassigned

```

* * * * *

Run Structure
-------------

```
class Run {
  final List<int> cells;      // cell indices
  final int length;
  int sum;
  int usedMask;               // bitmask of assigned digits
}

```

* * * * *

Cell-to-Run Mapping
-------------------

```
List<int> acrossRunOfCell;
List<int> downRunOfCell;

```

* * * * *

Candidate Representation
------------------------

Use 9-bit mask:

```
bit 0 -> digit 1
bit 8 -> digit 9

```

Operations are O(1).

* * * * *

Run Combination Dictionary
--------------------------

Map:

```
Map<int length,
  Map<int sum,
    List<int combinationMasks>
  >
>

```

Where each combinationMask is bitmask of digits.

* * * * *

Solver State
------------

Use:

-   cellValues (mutable array)

-   row-level masks not needed (runs handle distinctness)

-   run.usedMask

-   candidateMasks per cell

Maintain stack of changes for undo.

Avoid copying full arrays per recursion.

* * * * *

5\. Kakuro Combination Dictionary
=================================

Why It Matters
--------------

For run length L and sum S, possible digit sets are finite.

Example:

L=3, S=6 → {1,2,3}

Precompute all valid sets:

-   Digits 1..9

-   No repetition

-   Combination, not permutation

* * * * *

Precompute Algorithm
--------------------

```
for each subset of {1..9}:
  if subset.size >= 2:
    sum = sum(subset)
    store subsetMask under (length, sum)

```

Total subsets = 2^9 = 512 → trivial.

* * * * *

Usage in Solver
---------------

For run R:

-   Get valid combinations for (R.length, R.sum)

-   Filter combinations by:

    -   Excluding digits already used in run

    -   Intersecting with candidate masks of cells

* * * * *

Pseudocode
----------

```
buildDictionary():
  for mask in 1..(1<<9)-1:
    if bitCount(mask) >= 2:
      sum = computeSum(mask)
      store mask in dict[length][sum]

```

* * * * *

6\. Layout Generation
=====================

Recommended Board Sizes (Mobile)
--------------------------------

-   5×5 (mini)

-   7×7

-   9×9

-   11×11

-   13×13 (Hard/Expert max recommended)

15×15 possible but visually cramped on phones.

* * * * *

Layout Strategy (Recommended)
-----------------------------

Deterministic random with repair:

1.  Initialize all cells white

2.  Randomly assign black cells based on density

3.  Enforce:

    -   No 1-cell runs

    -   All white cells have across and down

4.  Repair invalid regions

5.  Extract runs

6.  Validate run-length distribution

* * * * *

Difficulty via Layout
---------------------

-   Easy: many short runs (2--3)

-   Hard: more 4--6 runs

-   Expert: more 6--8 runs

Avoid too many long runs (branching explosion).

* * * * *

Pseudocode
----------

```
generateLayout(seed):
  rng = RNG(seed)
  grid = white
  placeBlackCells(rng, targetDensity)
  repairInvalidRuns()
  ensureAllWhiteHaveAcrossAndDown()
  return grid

```

* * * * *

7\. Solution Assignment
=======================

Treat as CSP.

Algorithm
---------

```
assignSolution(board):
  initialize candidates per cell
  solveCSP(limit=1)

```

* * * * *

MRV Strategy
------------

Choose unassigned cell with smallest candidate count.

* * * * *

Forward Checking
----------------

On assignment:

-   Update run.usedMask

-   Remove digit from candidate masks of run peers

-   Check run sum feasibility via dictionary

* * * * *

Pruning
-------

For each run:

-   Remaining sum must be achievable with remaining cell count

-   Candidate union must include digits needed

* * * * *

8\. Clue/Sum Generation
=======================

After full solution:

For each run:

```
sum = sum(solution values)
assign to clue cell

```

Avoid:

-   Extremely ambiguous sums for easy tier

-   All single-combination sums for hard tier

Ambiguity measured by dictionary entry count.

* * * * *

9\. Solver Design
=================

Requirements
------------

-   Solve

-   Count solutions (limit=2)

-   Validate board

-   Validate move

-   Provide hints

* * * * *

Core Solve Pseudocode
---------------------

```
solve(limit):
  if solutions >= limit: return
  if all assigned:
    solutions++
    return

  cell = selectMRV()
  for digit in candidates(cell):
    assign
    if consistent:
      solve
    undo

```

* * * * *

Consistency Check
-----------------

-   Digit not in run.usedMask

-   Partial run sum ≤ target

-   Remaining sum feasible

* * * * *

Validation
----------

Move validation:

-   Check digit ∈ candidateMask

-   Check no duplicate in run

-   Check partial sum ≤ target

Full board validation:

-   All runs:

    -   distinct digits

    -   exact sum

* * * * *

10\. Uniqueness Checking
========================

Correct method:

```
solve(limit=2)
if solutions == 1 → unique
if solutions >= 2 → reject
if solutions == 0 → invalid

```

Never cap depth without reporting status.

Timeout must return "unknown," not "unique."

* * * * *

11\. Difficulty Rating
======================

Signals
-------

-   Total search nodes

-   Backtracks

-   Max recursion depth

-   Forced moves count

-   Candidate reduction %

-   Average combination count per run

* * * * *

Example Scoring
---------------

```
score =
  w1 * log(nodes)
+ w2 * log(backtracks)
+ w3 * avgRunAmbiguity
+ w4 * maxRunLength

```

Threshold example:

-   Easy: nodes < 1k

-   Medium: < 10k

-   Hard: < 100k

-   Expert: ≥ 100k

Calibrate empirically.

* * * * *

12\. Generator Loop
===================

```
generate(width, height, difficulty, seed):

  for attempt in 0..MAX:
    layout = generateLayout(seed + attempt)
    if invalid: continue

    solution = assignSolution(layout)
    if fail: continue

    clues = deriveClues(solution)

    puzzle = buildPuzzle(layout, clues)

    result = solve(limit=2)
    if result != unique: continue

    score = measureDifficulty(puzzle)
    if not matches(difficulty): continue

    return puzzle

  throw GenerationFailure

```

Deterministic retry:

Use seed + attempt as sub-seed.

* * * * *

13\. Difficulty Profiles
========================

Easy
----

-   5×5, 7×7

-   Mostly 2--3 runs

-   Many single-combination sums

-   Node count < 1k

Medium
------

-   7×7, 9×9

-   Mix of 2--4 runs

-   Some ambiguous sums

-   Node count < 10k

Hard
----

-   9×9, 11×11

-   Many 4--6 runs

-   Few single-combination runs

-   Node count < 100k

Expert
------

-   11×11, 13×13

-   Longer runs

-   High ambiguity

-   Node count high but bounded

* * * * *

14\. Mobile UX Recommendations
==============================

Recommended Sizes
-----------------

Phone:

-   Default: 7×7, 9×9

-   Max: 11×11

Tablet:

-   Up to 13×13

15×15 on phone is visually painful.

* * * * *

UX Notes
--------

-   Highlight full run when cell selected

-   Show run sum near clue

-   Toggle candidate mode

-   Show duplicate conflict highlighting

-   Provide "check mistakes" optionally

-   Hint: highlight forced cell

* * * * *

15\. Performance & Complexity
=============================

Worst-case exponential.

Practical with pruning:

-   7×7 uniqueness: < 10--20 ms

-   9×9: 20--80 ms

-   11×11: 80--200 ms

Use isolate for generation.

Do not block UI thread.

* * * * *

16\. Testing Strategy
=====================

Must include:

-   Combination dictionary correctness

-   Impossible sum tests

-   Layout validity tests

-   Run extraction tests

-   Known unique puzzle tests

-   Known multi-solution tests

-   Deterministic seed tests

-   Serialization round-trip

-   Performance benchmarks

-   Fuzz layout tests

* * * * *

17\. Common Failure Modes
=========================

-   Allowing duplicate digits in run

-   Creating 1-cell runs

-   White cells missing across/down

-   Treating combinations as permutations

-   Accepting multi-solution puzzles

-   Solver depth cap mistaken for uniqueness

-   RNG not seeded consistently

-   Infinite retry loop

-   Difficulty label mismatch

Detect via:

-   Unit tests

-   Random seed fuzz

-   Solver metrics logs

* * * * *

18\. Hint System Recommendations
================================

Hints should use solver logic, not hidden solution:

1.  Identify forced cell via propagation

2.  Highlight conflicting duplicate

3.  Highlight impossible sum

4.  Show run-combination elimination

5.  Reveal cell as last resort

* * * * *

19\. Serialization Format
=========================

Compact JSON:

```
{
  "v":1,
  "t":"kakuro",
  "seed":"abc",
  "w":9,
  "h":9,
  "difficulty":"hard",
  "layout":"encoded bitmask",
  "clues":[...],
  "engineVersion":"1.2.0",
  "difficultyScore":1234
}

```

Do not store solution in backend.

Local storage may optionally cache solution for validation.

* * * * *

20\. Implementation Roadmap
===========================

Phase order:

1.  Core model

2.  Run extractor

3.  Combination dictionary

4.  Solver (solve only)

5.  Solution counter

6.  Layout generator

7.  Solution assignment

8.  Clue derivation

9.  Uniqueness loop

10. Difficulty scoring

11. Hint engine

12. Serialization

13. Performance benchmarks

14. Fuzz tests

Acceptance per phase:

-   Deterministic

-   Tests pass

-   Benchmarks under target

* * * * *

21\. Final Recommended Architecture
===================================

Layout
------

Deterministic layout-first with repair and optional symmetry.

Solution Generation
-------------------

CSP fill with MRV + forward checking.

Clues
-----

Derived strictly from solution.

Solver
------

Hybrid CSP + run-combination dictionary.

Uniqueness
----------

Count ≤ 2 solutions with early exit.

Difficulty
----------

Measured via solver metrics + layout characteristics.

Hint Strategy
-------------

Propagation-based hint extraction.

Mobile Defaults
---------------

-   Default size: 7×7 or 9×9

-   Hard limit: 11×11 on phone

-   Use isolate for generation

-   Precompute combination dictionary once

* * * * *

Biggest Risks
-------------

-   Poor pruning → exponential explosion

-   Accepting false uniqueness due to timeout

-   Overly dense long-run layouts

-   Non-deterministic seed handling

-   Difficulty misclassification

* * * * *

What Not To Do
--------------

-   Do not skip uniqueness checking.

-   Do not rely on generation heuristics for difficulty.

-   Do not block UI thread.

-   Do not store puzzle boards in backend.

-   Do not clone entire solver state per recursion.

* * * * *