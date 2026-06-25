Below is a production-grade technical report for designing a **deterministic, mobile-first, on-device MathDoku (KenKen-style) engine** suitable for Brainiax Puzzles.

This is written from first principles and current best practices in CSP (constraint satisfaction), exact cover, Latin square generation, and puzzle-generation engineering for low-end mobile devices.

No hacks. No cloud crutches. No "hope the solver finds something."\
If you implement this architecture cleanly, you get:

-   Deterministic generation from seed

-   Guaranteed uniqueness

-   On-device performance

-   Reliable difficulty calibration

-   Clean integration with Flutter + pure-Dart engine

* * * * *

1\. Executive Recommendation
============================

Recommended Architecture (Opinionated)
--------------------------------------

### Generator Strategy (Ranked)

**1️⃣ Latin-square-first + constrained cage partition + solver-based rejection (Recommended)**\
**2️⃣ Full CSP generation with cages built into solver loop**\
**3️⃣ Cage-first generation (not recommended)**

Use this loop:

```
Generate solved Latin square
→ Partition into cages (seed-driven, constrained)
→ Assign operations/targets
→ Run solver with solution counting (stop at 2)
→ Score difficulty using instrumented solver
→ Accept or reject

```

### Solver Strategy (Ranked)

**1️⃣ Hybrid CSP solver:**

-   DFS + MRV

-   Row/column bitmasks

-   Cage candidate precomputation

-   Forward checking

-   Early contradiction pruning

-   Solution counter with early exit

**2️⃣ Exact cover (DLX)**

-   Elegant but harder to integrate cage arithmetic cleanly.

**3️⃣ SAT/ILP**

-   Overkill for mobile; not practical on-device.

### Uniqueness Strategy

-   Always **count solutions up to 2**

-   Early exit after 2

-   Use same solver core as validation

-   Never trust generator's original solution alone

### Difficulty Strategy

Hybrid model:

-   Instrumented solver metrics:

    -   Nodes visited

    -   Backtracks

    -   Constraint propagations

-   Cage complexity metrics

-   Branching entropy

-   Human-strategy capability pass

Generator parameters alone are not enough.

* * * * *

2\. Formal Puzzle Model
=======================

Supported Board Sizes (Mobile-Realistic)
----------------------------------------

Recommended:

-   4×4 (tutorial/easy)

-   5×5

-   6×6

-   7×7 (hard)

-   8×8 (expert)

-   9×9 (use sparingly; UI tight)

9×9 is borderline for mobile cage readability. Make it Expert-only.

* * * * *

Latin Square Constraints
------------------------

For size N:

-   Each row contains {1..N} exactly once

-   Each column contains {1..N} exactly once

* * * * *

Cage Representation
-------------------

Each cage:

```
class Cage {
  List<Cell> cells;
  Operation op; // add, mul, sub, div, none
  int target;
}

```

Constraints:

-   Orthogonally connected

-   No overlaps

-   Covers full board

-   Each cell belongs to exactly one cage

* * * * *

Valid Cage Shapes
-----------------

-   Connected via orthogonal adjacency

-   No diagonal-only adjacency

-   Avoid "snake of length 5" shapes on small screens

-   Avoid 1×N thin strips on small boards

Recommend:

-   Max cage size 4 for ≤6×6

-   Max cage size 5 for ≥7×7

* * * * *

Operation Rules
---------------

Allowed operations:

-   Addition (+)

-   Multiplication (×)

-   Subtraction (-)

-   Division (÷)

-   Single-cell (no op)

### Commutative

-   Addition

-   Multiplication

### Non-commutative

Subtraction and division:

**Recommended:**

-   Allow only for 2-cell cages

-   Compute as absolute difference or exact division

-   Division must be integer (no fractions)

* * * * *

Valid Puzzle Definition
-----------------------

A puzzle is valid if:

1.  Full board partitioned into valid cages

2.  Each cage has valid target

3.  At least one solution exists

4.  Exactly one solution exists

* * * * *

Metadata to Store
-----------------

```
{
  size,
  seed,
  difficultyLabel,
  difficultyScore,
  cageCount,
  cageSizeDistribution,
  operationDistribution,
  generatorVersion,
  engineVersion
}

```

Never store solution in backend. Only optionally local.

* * * * *

3\. Survey of Algorithmic Approaches
====================================

A. Backtracking over Grid (CSP)
-------------------------------

**How it works:**

-   Assign cell values

-   Respect row/col + cage constraints

-   DFS search

**Strengths**

-   Easy to integrate

-   Deterministic

-   Fast for N ≤ 9 with pruning

**Weakness**

-   Must optimize heavily

**Suitability**\
✔ Mobile\
✔ Deterministic\
✔ Uniqueness counting\
✔ Difficulty scoring

* * * * *

B. Latin-Square-First Generation
--------------------------------

**Process**

1.  Generate full Latin square

2.  Partition into cages

3.  Assign ops

4.  Validate uniqueness

**Strengths**

-   Fast

-   Deterministic

-   Clean architecture

-   Industry standard

✔ Recommended

* * * * *

C. Cage-First Generation
------------------------

Build cage structure and fill values simultaneously.

**Weakness**

-   Hard to ensure uniqueness

-   Complex

-   Slow

❌ Not recommended

* * * * *

D. Exact Cover (Algorithm X / DLX)
----------------------------------

Can encode:

-   Row constraints

-   Column constraints

-   Cage combination constraints

**Pros**

-   Elegant uniqueness detection

**Cons**

-   Arithmetic cages increase complexity

-   Harder to maintain

-   Harder to instrument for difficulty

Not worth complexity for mobile.

* * * * *

E. SAT / SMT / ILP
------------------

Yes, possible.\
No, not sensible on-device.

* * * * *

F. Human-Strategy Solvers
-------------------------

Rule-based:

-   Cage candidate elimination

-   Naked singles

-   Hidden singles

-   Cage forcing

Useful for difficulty scoring, not generation.

* * * * *

4\. Recommended Data Structures (Dart-Friendly)
===============================================

Grid State
----------

```
Uint8List cells; // length N*N

```

Fast and cache-friendly.

* * * * *

Row/Column Used Values
----------------------

Use bitmasks:

```
List<int> rowMask; // N ints
List<int> colMask;

```

Bit i means number i+1 used.

Extremely fast.

* * * * *

Candidate Sets
--------------

Represent as bitmask:

```
int candidates; // bits 1..N

```

No Sets. No Lists. Bitmasks only.

* * * * *

Cage Definitions
----------------

```
class Cage {
  final List<int> cellIndices;
  final int op;
  final int target;
  final List<int> validCombinations; // bit-packed combinations
}

```

* * * * *

Cage Candidate Combinations
---------------------------

Precompute all value combinations respecting:

-   Size

-   Target

-   Operation

-   Distinctness

Cache per:

```
(size, op, target, N)

```

* * * * *

Solver State
------------

Use mutable arrays with stack of changes for undo:

-   cells

-   rowMask

-   colMask

-   cageProgress

Avoid cloning full board per recursion.

* * * * *

Serialization
-------------

Compact JSON:

```
{
  s: 6,
  seed: "...",
  c: [
    {cells:[0,1], op:"+", t:5},
    ...
  ],
  d: "hard"
}

```

Minify keys for storage.

* * * * *

5\. Solution Grid Generation
============================

Options Compared
----------------

### 1️⃣ Pattern-Based Latin Square (Recommended)

Base pattern:

```
grid[r][c] = (r + c) % N + 1

```

Then apply seed-driven permutations:

-   Shuffle symbols

-   Shuffle rows within bands

-   Shuffle columns within stacks

-   Rotate/reflect

Deterministic and extremely fast.

✔ O(N²)\
✔ No backtracking\
✔ Stable

* * * * *

### 2️⃣ Backtracking Latin Square

Slower, unnecessary.

* * * * *

Recommended Pseudocode
----------------------

```
generateLatinSquare(N, seed):
  rng = SeededRNG(seed)

  grid[r][c] = (r + c) % N + 1

  permuteSymbols(grid, rng)
  permuteRows(grid, rng)
  permuteCols(grid, rng)
  maybeTranspose(grid, rng)

  return grid

```

* * * * *

6\. Cage Generation
===================

Strategy
--------

1.  Start with unassigned cells

2.  While cells remain:

    -   Pick random unassigned cell

    -   Grow cage via BFS/DFS

    -   Respect:

        -   Max cage size

        -   Shape constraints

        -   Difficulty profile

3.  Mark cells assigned

* * * * *

Avoid
-----

-   Huge snake cages

-   Isolated awkward corners

-   1-cell flood (too many trivial cages)

* * * * *

Pseudocode
----------

```
partitionCages(grid, profile, seed):
  unassigned = set(all cells)
  while unassigned not empty:
    root = pick(unassigned)
    size = sampleSize(profile)
    cage = growConnected(root, size)
    assign(cage)

```

* * * * *

7\. Operation & Target Assignment
=================================

After cage built:

Extract solution values.

If size == 1:

-   op = none

-   target = value

If size == 2:

-   Prefer sub/div for Medium+

If size > 2:

-   Use add or multiply only

Avoid:

-   Division producing fractions

-   Subtraction for >2 cells

* * * * *

Recommended Operation Distribution
----------------------------------

### Easy

-   50% addition

-   30% single-cell

-   20% multiplication

-   0% sub/div

### Medium

-   40% addition

-   30% multiplication

-   20% sub/div (2-cell only)

-   10% single

### Hard

-   35% add

-   35% mul

-   25% sub/div

-   5% single

### Expert

-   Maximize multiplication and sub/div

-   Fewer singles

* * * * *

8\. Solver Design
=================

Core Algorithm
--------------

Hybrid CSP:

-   MRV cell selection

-   Bitmask row/col

-   Cage candidate pruning

-   Forward checking

-   Early exit after 2 solutions

* * * * *

Precompute Cage Combinations
----------------------------

For each cage:

Generate all permutations of values 1..N of size k satisfying:

-   Operation

-   Target

-   Distinct values

Filter combinations by row/column constraints dynamically.

* * * * *

MRV Selection
-------------

Choose cell with smallest candidate count.

* * * * *

Solution Counting
-----------------

```
solve(limit=2):
  if solutionCount >= limit: return
  if all assigned:
    solutionCount++
    return
  cell = selectMRV()
  for value in candidates:
    assign
    if consistent:
      solve
    unassign

```

* * * * *

9\. Uniqueness Checking
=======================

Correct method:

-   Count solutions up to 2

-   Stop after 2

-   If count == 1 → unique

-   If count == 0 → invalid

-   If count >= 2 → reject

Never assume generated solution is unique.

* * * * *

10\. Difficulty Rating
======================

Signals to Use
--------------

-   Solver node count

-   Backtracks

-   Max branching factor

-   Cage entropy (combinations per cage)

-   Largest cage size

-   Operation distribution

-   Human-solver pass success

* * * * *

Scoring Formula (Example)
-------------------------

```
score =
  w1 * log(nodes)
+ w2 * log(backtracks)
+ w3 * avgCageCombinations
+ w4 * subDivRatio
+ w5 * maxCageSize

```

Calibrate empirically.

* * * * *

11\. Generator Loop (Full)
==========================

```
generate(size, difficulty, seed):
  rng = SeededRNG(seed)
  attempts = 0

  while attempts < MAX:
    solution = generateLatinSquare(size, rng.next())
    cages = partitionCages(solution, difficultyProfile, rng.next())
    assignOps(cages)

    puzzle = buildPuzzle(cages)

    result = solveAndCount(puzzle, limit=2)

    if result.solutionCount != 1:
      continue

    score = difficultyScore(puzzle)

    if not matchesDifficulty(score, difficulty):
      continue

    return puzzle

  fallback()

```

Deterministic retries: derive attempt seeds from base seed.

* * * * *

12\. Difficulty Profiles (Recommended)
======================================

### Easy

-   4×4, 5×5

-   Many single-cell

-   Mostly addition

-   Nodes < 500

### Medium

-   5×5, 6×6

-   Mixed ops

-   Nodes < 5k

### Hard

-   6×6, 7×7

-   Large cages

-   Nodes < 50k

### Expert

-   7×7, 8×8

-   Few singles

-   Heavy mul/sub/div

-   Nodes < 250k

9×9 only Expert.

* * * * *

13\. Performance & Complexity
=============================

Worst-case exponential.

Practical with pruning:

-   6×6 typical uniqueness check: < 20 ms

-   7×7: 20--80 ms

-   8×8: 50--150 ms

-   9×9: can exceed 200 ms

Use isolates for generation.

* * * * *

14\. Testing Strategy
=====================

Must include:

-   Latin square validity tests

-   Cage validity tests

-   Solver uniqueness tests

-   Known multi-solution test boards

-   Deterministic seed tests

-   Serialization round-trip

-   Fuzz tests

-   Performance benchmarks

* * * * *

15\. Common Failure Modes
=========================

-   Incorrect subtraction handling (order bugs)

-   Accepting multi-solution puzzles

-   Solver biased toward original solution

-   Cage combination cache errors

-   Non-deterministic RNG usage

-   Infinite generator loops

* * * * *

16\. Hint System
================

Recommended hint types:

1.  Highlight row/col conflict

2.  Highlight cage contradiction

3.  Candidate elimination hint

4.  Forced cell hint

5.  Reveal cell (last resort)

Hints should derive from solver logic, not hidden solution.

* * * * *

17\. Serialization Format
=========================

Compact JSON:

```
{
  "v":1,
  "t":"mathdoku",
  "s":6,
  "seed":"abc",
  "d":"hard",
  "c":[
    {"cells":[0,1],"op":"+","t":5},
    ...
  ]
}

```

Do NOT sync solution to backend.

* * * * *

18\. Implementation Roadmap
===========================

Phase order:

1.  Core model

2.  Latin generator

3.  Cage partitioner

4.  Operation assigner

5.  Solver

6.  Uniqueness counter

7.  Difficulty scorer

8.  Hint engine

9.  Serialization

10. Test suite

11. Benchmark harness

Acceptance criteria per phase:

-   Determinism

-   Correctness

-   Benchmarked performance

* * * * *

19\. Final Blueprint
====================

Generator
---------

Latin-square-first\
Seeded permutation\
Constrained cage growth\
Operation assignment\
Solver uniqueness rejection\
Difficulty scoring acceptance

Solver
------

CSP + MRV + bitmasks + forward checking\
Solution counter with early exit

Uniqueness
----------

Count up to 2\
Reject multi-solution

Difficulty
----------

Hybrid:

-   Solver metrics

-   Cage metrics

-   Profile alignment

Defaults for Mobile
-------------------

-   Default sizes: 5×5, 6×6

-   7×7+ only Hard/Expert

-   9×9 optional and rare

-   Max cage size 4 (≤6×6)

* * * * *

Biggest Risks
-------------

-   Weak solver pruning → exponential blowups

-   Bad difficulty calibration

-   Allowing sub/div for >2 cells

-   Overusing 9×9 on mobile

-   Non-deterministic retry logic

* * * * *

What Not To Do
--------------

-   Do not generate cages randomly and "hope" uniqueness passes.

-   Do not skip uniqueness check.

-   Do not rely only on generator parameters for difficulty.

-   Do not clone full board state per recursion.

-   Do not block UI thread during generation.

* * * * *