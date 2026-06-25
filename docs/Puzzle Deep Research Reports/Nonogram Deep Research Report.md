# Brainiax Puzzles Monochrome Nonogram Engine Technical Report

## Executive recommendation

The best production architecture for **Brainiax Puzzles** is a **deterministic, bitmap-first, hybrid solver engine** built around four layers: a canonical puzzle model; a **line-domain engine** that can enumerate and filter valid row and column placements; a **complete hybrid propagation-plus-search solver** that can count solutions up to two; and a **deterministic procedural bitmap generator** that produces aesthetically filtered candidate images before clue derivation. This architecture fits what the Nonogram literature and strong practical solvers converge on: dedicated line solving plus propagation, then search only when needed; validation must distinguish “find one solution” from “prove uniqueness”; and difficulty is best measured with solver telemetry rather than size alone. Dedicated solvers and hybrid approaches dominate published solver work and practical implementations, while line-solver caching and probing materially improve runtime. citeturn12view0turn21view0turn12view1turn17view1turn18view3turn35view0turn22view0

My ranked recommendation is this. **First choice:** generate a target bitmap locally from a seeded procedural shape generator, derive clues, then run a complete validator that can return `none`, `unique`, `multiple`, or `unknown_cap`. **Second choice:** use bundled local motif or icon templates as starting scaffolds, then perturb them procedurally before clue derivation. **Third choice:** keep a SAT or CSP backend only as an offline oracle or test harness, not as the primary on-device engine. **Do not** make clue-first synthesis your main path, do not rely on a shallow “human-style only” solver for uniqueness, and do not treat timeout or node-cap exhaustion as proof of uniqueness. The distinction between puzzle solving and puzzle validation is fundamental, and published surveys make that point bluntly: a validator must keep looking for a second solution. citeturn17view1turn12view0turn14view0turn27view1turn27view4

For the **generator loop**, the production path should be: seeded bitmap synthesis → clue derivation → cheap structural and visual screening → propagation-only solve telemetry → full uniqueness count up to two → difficulty scoring → accept or reject → bounded local repair if ambiguity is small → otherwise deterministic retry. That sequencing gives you direct control over image quality, deterministic reproducibility, and the published-puzzle requirement of exactly one solution. Existing research on generating image-like Nonograms starts from gray-level or RGB source images and then uses a solver to assess solvability and difficulty, which is much closer to bitmap-first generation than clue-first search. citeturn10view4turn16view0turn9view1turn9view7

For the **solver**, use **iterative row/column propagation over cached line domains**, then a **depth-first search** that branches on the most constrained unresolved variable, with forward checking and immediate propagation after every assumption. For mobile-size monochrome grids, the most practical branch variable is usually a **cell selected from the most constrained line**, not a whole-line assignment. That gives good locality, easier hint generation, cleaner diagnostics, and efficient row/column updates. The academic literature supports fast dynamic-programming line solvers and stronger probing before backtracking; practical solvers similarly combine line solving, contradiction probing, and search. citeturn21view0turn12view0turn17view4turn35view0turn22view0

For **uniqueness checking**, the engine should count solutions with an **early exit at two**. If the first solution matches the generated bitmap, that proves only that the bitmap is *a* solution, not *the* solution. If the search budget is exceeded, the result must be **unknown**, never “unique.” Theoretically, deciding existence is NP-complete and deciding whether another solution exists is NP-hard even when one solution is given, which is exactly why shallow validation fails so often in production puzzle code. citeturn33view2turn33view1turn17view1

For **difficulty**, use a **hybrid score**. The label shown to players should be driven primarily by a deterministic “human-style” logic solver and secondarily by the complete solver’s search telemetry. That recommendation is consistent with older sweep-based difficulty work for simple puzzles and with newer work that explicitly argues that step count alone is insufficient, and that backtracking distance and advanced deterministic guessing matter for player-perceived difficulty. citeturn11view1turn26view5turn10view0turn26view1

For **hints**, never make the default hint path depend only on the hidden solution bitmap. Instead, run the same explainable logic layer from the player’s current state and surface the next forced deduction with a reason: overlap, forced empty, contradiction on a line, edge logic, or two-way elimination. Reserve “reveal this cell from the solution” as a last resort. That keeps hints honest, avoids hiding solver bugs, and aligns with both human-style difficulty modeling and practical puzzle UX. citeturn30view0turn9view7turn35view3

For **mobile execution**, move generation and full validation off the UI isolate. Flutter and Dart explicitly recommend isolates for computations large enough to block the main isolate, and they also note that repeatedly spawning short-lived isolates has overhead, so a **long-lived worker isolate** is the right default if your app generates random-play puzzles often. `TransferableTypedData` is the right transport if you pass large packed states between isolates. citeturn9view4turn12view6turn32view1turn32view3turn12view7

## Formal model and core data structures

### Formal puzzle model

A monochrome Nonogram puzzle is defined by a **rectangular grid** of width `W > 0` and height `H > 0`. Each solution cell is binary: `filled` or `empty`. During solving and play, each player-visible cell has a tri-state status: `unknown`, `filled`, or `empty-marked` (cross/dot). Academic and practical solver literature formalizes the binary solved image and a partial image with unknown entries in exactly this way. citeturn12view0turn19view0

A **row clue** or **column clue** is an ordered sequence of **positive integers**. Each integer denotes the length of a contiguous run of filled cells on that line, and runs must appear in the exact clue order with **at least one empty cell separating adjacent runs**. A clue sequence is valid for a line of length `L` iff every clue value is `> 0` and  
`sum(clues) + (clues.length - 1) <= L`. That exactly matches the standard formalization used in solver papers and implementations. citeturn12view0turn41view3turn29view0

A line with no filled cells should have the **canonical internal representation `[]`**, not `[0]`. The reason is simple: clues represent **runs**, and a zero-length run is not a run. Some text formats use `0` because blank lines are ignored, and at least one practical library documents that convention explicitly, but your engine should normalize imported `[0]` or `"0"` into `[]` on read and never emit `[0]` internally. That keeps validation logic cleaner and avoids off-by-one bugs in run placement. citeturn39view2turn39view3

A **valid solved grid** is a fully assigned `W × H` bitmap such that every row’s run-length sequence exactly equals its row clue and every column’s run-length sequence exactly equals its column clue. A **valid puzzle** is the tuple `(W, H, rowClues, colClues)` with internally consistent clue syntax; a puzzle is **solvable** if at least one solved grid satisfies it; it is **uniquely solvable** if exactly one solved grid satisfies it. The clue sums across rows and columns must match as a quick sanity check, but equal sums alone do **not** guarantee solvability or uniqueness. citeturn19view0turn39view0

For generated content, store at least this metadata with every puzzle object: puzzle type; schema version; engine/generator version; seed; width; height; difficulty label; difficulty score; row clues; column clues; generation profile; solver telemetry summary; visual-quality score; creation timestamp; and an optional local-only packed solution bitmap or solution checksum. The solution is optional because deterministic regeneration from seed is possible, but versioning is mandatory because deterministic reproduction across app versions only remains true if the generator algorithm is versioned and pinned. That last point is an engineering requirement from your product constraints, not a claim from the literature. citeturn29view0turn22view0

### Recommended core data structures for Dart

Use a **row-major `Uint8List`** as the canonical mutable board for solver state and player state. Map states as `0 = unknown`, `1 = empty`, `2 = filled`. `Uint8List` is a fixed-length list of 8-bit unsigned integers and is explicitly more space- and time-efficient than the default `List` for long lists. On a 20×20 board that is only 400 bytes for the core mutable state, which is tiny and cache-friendly. citeturn9view5

Use a second packed representation for **solution bitmaps and line placements**. For widths up to 32, pack a line into one `int` or one `Uint32List` entry. For widths up to 64, a `Uint64List` is convenient. For arbitrary widths, use `wordsPerRow = ceil(W / 32)` and store each row as a segment in a shared `Uint32List`. Both `Uint32List` and `Uint64List` are fixed-length typed-data views that are materially more space- and time-efficient than default `List<int>`, and they support buffer views cleanly. citeturn42view2turn42view3

For clues, prefer a two-level representation: public API as immutable `List<int>` for readability; internal compiled form as `Uint8List` or `Uint16List` per line. For your target sizes, `Uint8List` is enough, but leaving the compiled type abstract keeps later expansion painless. This is one of the few places where simplicity beats cleverness: clues are short, hot-read, and rarely mutated.

For line placements, store an immutable **placement pool** per normalized clue key. Each placement should contain at minimum a packed `filledMask`; `emptyMask` is derivable as the complement within line length. Each live line domain can then be represented as either a `List<int>` of active placement indices or a small bitset over placement indices. For 10×10 to 20×20, a simple index list is usually faster to implement and easier to debug than a hyper-compressed domain bitset.

For cached line results, use a `Map<LineCacheKey, LineSummary>`, where the key is `(clueId, knownFilledMask, knownEmptyMask, lineLength)` and the summary contains `status`, `filteredCount`, `mustFillMask`, and `mustEmptyMask`. Jan Wolter’s published notes on line-solution caching are especially relevant here: identical clues and identical partial line states recur heavily, and caching can produce very high hit rates. citeturn18view3turn18view2

For DFS search state, I recommend **mutable state with an undo trail**, not full deep clones of every object graph. Record three things on the trail: changed cells, changed line-domain checkpoints, and changed dirty flags. That said, copying the raw board itself is cheap at your target sizes, so a hybrid approach works well: keep domains and queues trail-based, but snapshot the `Uint8List` board for top-level hint calls or UI-safe background tasks. This keeps the solver fast without turning the codebase into a maintenance tar pit.

For serialization, use a **compact versioned JSON envelope** for app-facing persistence and an optional binary pack for internal caches. JSON is stable and debuggable; typed-data buffers are for performance, not for your public persistence contract.

### Canonical clue derivation

Clue derivation must be dead simple and fully canonical: scan left to right, count consecutive filled cells, emit a run whenever a filled streak ends, and emit `[]` if no filled cell exists. Leading and trailing empty cells contribute nothing except run boundaries. Any alternative representation introduces pointless nondeterminism. This is standard Nonogram behavior, and the XML and text formats used in the ecosystem all revolve around the same run-extraction rule. citeturn29view0turn39view2

```pseudo
function deriveClueFromLine(cells[0..L-1]) -> List<int]:
    runs = []
    runLen = 0
    for i in 0..L-1:
        if cells[i] == FILLED:
            runLen += 1
        else if runLen > 0:
            runs.append(runLen)
            runLen = 0
    if runLen > 0:
        runs.append(runLen)
    return runs   // [] means fully empty line
```

```pseudo
function deriveAllClues(bitmap, width, height):
    rowClues = []
    for y in 0..height-1:
        rowClues.append(deriveClueFromLine(row(bitmap, y)))

    colClues = []
    for x in 0..width-1:
        colClues.append(deriveClueFromLine(column(bitmap, x)))

    return (rowClues, colClues)
```

Test clue derivation by round-tripping thousands of random bitmaps: derive clues, verify the original bitmap satisfies them, and confirm that re-derivation is identical every time. Determinism here is non-negotiable.

## Algorithmic survey

### Generation approaches

The literature and open-source ecosystem heavily favor **generate a bitmap first, then derive clues**. That path is used in image-based generation from gray-level and RGB inputs, and it is the most direct route to recognizable pictures. It also gives you explicit control over density, symmetry, fragmentation, and silhouette before you spend CPU proving uniqueness or rating difficulty. For a mobile product, this is the right default. citeturn9view1turn10view4turn16view0

**Generating clues first and then searching for a bitmap** is mathematically legitimate, but it is a worse engineering fit for your constraints. It gives weaker control over visual quality, tends to produce ugly or accidental images unless you impose strong additional structure, and still requires a full solver to prove existence and uniqueness. I would not use clue-first search as the primary generator loop.

**Pattern-, template-, and image-based generation** are strong if you care about recognizability. The 2007 image-generation work explicitly starts from RGB images, performs thresholding or color reduction, and then uses a solver to test whether the resulting puzzle is acceptable. Batenburg and colleagues similarly discuss generating puzzles of varying difficulty that resemble a gray-level image. If you want “this looks like something” rather than “TV static with clue numbers,” template-biased generation is a good idea. citeturn16view0turn10view4

**Pure random bitmap generation with uniqueness rejection** is the seductive bad idea. It is easy to implement, but published difficulty work shows that random image density has a messy relationship with solvability and uniqueness, and random patterns often either become trivial, underconstrained, or visually ugly. Some open-source generators even document that they do not check uniqueness at all, which is fine for hobby tools and absolutely wrong for a production puzzle app. citeturn37view0turn37view3turn35view2

**Local repair after non-unique generation** is useful, but only as a bounded salvage step. If ambiguity is small and localized, comparing two found solutions and mutating the source bitmap near their disagreement region can save a candidate. If ambiguity is diffuse or the puzzle already looks mediocre, restart. Repair is the right tool for “small crack,” not “rebuild the house.”

### Solving approaches

**Line-placement enumeration** models each line as the set of all valid fillings compatible with its clue. This is the most transparent approach for monochrome mobile puzzles because it supports complete line reasoning, good diagnostics, and easy hinting. It also integrates naturally with propagation across rows and columns. For your target sizes, it is practical. For larger boards, add a dynamic-programming fallback. citeturn12view0turn21view0turn22view0

**Dynamic-programming line solvers** are academically strong and important for scale. Wu et al. reported a fast DP line solver with worst-case complexity `O(kℓ)` for average clue count `k` and line length `ℓ`, improving on earlier `O(kℓ²)` line-solving methods in the literature. If you ever push significantly beyond 20×20 or want a second implementation to cross-check your enumerator, this is the right theoretical backbone. citeturn21view0turn19view0

**Pure line propagation** is fast and human-like, but incomplete. It is perfect for easy and medium difficulty estimation and for first-pass solving, but by itself it cannot validate uniqueness in the general case. Batenburg and Kosters’ work formalizes “simple” puzzles as those solvable by alternating horizontal and vertical settle sweeps, and they show that many published-type puzzles live in this region, but not all. citeturn26view5turn11view2

**Human-style logical solvers** are excellent for difficulty grading and hints, not for final validation. The recent 2024 generation paper explicitly uses a human-like deterministic solver to estimate difficulty and enjoyability, while older work measures difficulty by sweep counts for simple puzzles. That is exactly where this kind of solver belongs in your engine. citeturn9view7turn26view1turn11view1

**Hybrid logic plus search** is the production sweet spot. Strong dedicated solvers and practical libraries repeatedly converge on this pattern: line logic and propagation first, probing or contradiction checks next, and backtracking only when required. Open-source solvers such as nonogrid describe almost exactly this stack, and practical libraries such as nonolib use stacked line solvers before bifurcation. citeturn35view0turn22view0turn17view4

**Fully probing** and contradiction-driven lookahead are strong additions before deeper DFS. Wolter’s pbnsolve notes describe a probing strategy that tests many possible guesses and keeps deductions that are contradicted on one side; Wu’s solver family similarly focused on probing before backtracking. For a mobile engine, a lightweight version of this is worth keeping. citeturn17view4turn21view0

**Constraint programming and CSP models** are legitimate and elegant, especially with regular constraints that model each line as an automaton. But they are not my recommended primary mobile runtime path. They are great as reference solvers or offline oracles. Practical CSP work on Nonograms shows both the modeling appeal and the performance traps: regular constraints are natural, while explicit global-table constraints can become very large and expensive. citeturn27view4turn27view3turn17view0

**SAT formulations** are also real contenders, especially for oracle use. Recent SAT work for Nonograms reports that block-based encodings produce smaller formulas and faster solving than sequence-enumeration encodings. That is interesting and useful if you want an offline cross-checker or a desktop benchmark tool, but it is still more complexity than you need for a pure-Dart on-device engine. citeturn14view0turn27view1turn27view2

**ILP formulations** exist and work, including line-focused models and alternatives to Bosch’s earlier formulation. Again, they are excellent reference models and poor candidates for your primary mobile engine because they complicate deployment, hinting, and deterministic runtime control. citeturn41view1turn41view3turn17view0

**Exact cover** is possible in principle, but I would not build the engine around it. In the accessible solver survey and modern Nonogram literature I found much more evidence for dedicated line solvers, CSP, SAT, and ILP than for exact-cover-first engines. Exact cover also maps poorly to player-facing hints because it hides the line-level reasoning structure that Nonogram players expect. That is an engineering inference from the literature landscape, not a theorem.

### Recommended conclusion from the survey

For your constraints, the clear winner is:

- **Bitmap-first generation**
- **Line-domain propagation**
- **Hybrid DFS uniqueness counter**
- **Human-style overlay for hints and difficulty**
- **Optional DP fallback for large or explosive lines**
- **Optional SAT/CSP oracle only for test infrastructure**

Everything else is either too weak for proof of uniqueness, too heavyweight for mobile-first pure Dart, or too poor at producing visually pleasing puzzles.

## Line engine, solver, and uniqueness

### Line clue and placement engine

A production Nonogram solver lives or dies on its **line engine**. The line engine answers four questions given a line length `L`, a clue list `C`, and current known cell states:  
Can the line still fit the clue?  
How many placements are still possible?  
Which cells are forced filled in every placement?  
Which cells are forced empty in every placement?  
That is the central “settle” capability in the literature, whether implemented by enumeration, dynamic programming, or relaxations. citeturn12view0turn19view0turn22view0

For your mobile target sizes, I recommend a **complete enumerator-backed line engine** with a **DP fallback threshold**. Precompute all valid placements for `(L, C)` when first seen. For `L <= 20`, this is usually totally fine. Then, for every solve step, filter those placements against current known cells and intersect the survivors. If you later support much larger boards, add a DP settle implementation for lines whose placement count exceeds a cap.

```pseudo
function enumeratePlacements(length, clues):
    if clues.isEmpty:
        return [ALL_EMPTY_MASK]

    placements = []

    // prefix sums of remaining clue lengths
    suffixRunSum[i] = sum(clues[i..end])

    function rec(blockIndex, minStart, filledMask):
        if blockIndex == clues.length:
            placements.append(filledMask)
            return

        runLen = clues[blockIndex]
        remainingRuns = clues.length - blockIndex - 1
        minTail = (suffixRunSum[blockIndex + 1] if blockIndex + 1 < clues.length else 0)
        minSeparators = remainingRuns
        maxStart = length - (runLen + minTail + minSeparators)

        for start in minStart..maxStart:
            mask2 = filledMask with bits [start, start + runLen) set
            nextMinStart = start + runLen + 1   // separator after every non-last run
            if blockIndex == clues.length - 1:
                nextMinStart = start + runLen
            rec(blockIndex + 1, nextMinStart, mask2)

    rec(0, 0, 0)
    return placements
```

Compatibility check is straightforward. A placement is compatible if every known-filled cell is filled in the placement and every known-empty cell is empty in the placement.

```pseudo
function filterPlacements(placements, knownFilledMask, knownEmptyMask):
    survivors = []
    for p in placements:
        if (p & knownEmptyMask) != 0:
            continue
        if (knownFilledMask & ~p) != 0:
            continue
        survivors.append(p)
    return survivors
```

Intersection over surviving placements gives forced cells.

```pseudo
function summarizeDomain(survivors, lineLength):
    if survivors.isEmpty:
        return CONTRADICTION

    allFilled = survivors[0]
    anyFilled = survivors[0]

    for i in 1..survivors.length-1:
        allFilled &= survivors[i]
        anyFilled |= survivors[i]

    lineMask = (1 << lineLength) - 1
    mustFill = allFilled
    mustEmpty = lineMask & ~anyFilled

    return {mustFill, mustEmpty, domainSize: survivors.length}
```

Then a single line solve step is just these pieces combined.

```pseudo
function solveLine(length, clues, knownFilledMask, knownEmptyMask, placementPool):
    survivors = filterPlacements(placementPool, knownFilledMask, knownEmptyMask)
    if survivors.isEmpty:
        return {status: CONTRADICTION}

    summary = summarizeDomain(survivors, length)
    return {
        status: OK,
        survivors: survivors,
        forcedFilledMask: summary.mustFill & ~(knownFilledMask),
        forcedEmptyMask: summary.mustEmpty & ~(knownEmptyMask),
        domainSize: summary.domainSize
    }
```

Handle edge cases explicitly:

- `[]` means the only placement is all-empty.
- `[L]` on a line of length `L` means the only placement is all-filled.
- Any clue with `sum(clues) + clues.length - 1 > L` is a contradiction before solving starts.
- During play, a line with existing known marks may become contradictory even when the original clue is valid.

Caching matters. Wolter’s published measurements on pbnsolve show that caching line solutions by clue and initial state can have extremely high hit rates, especially once branching starts, and can materially reduce runtime. I would therefore cache both full placement pools by `(L, C)` and filtered summaries by `(clueId, knownFilledMask, knownEmptyMask)`. The “reversed clue” cache trick is optional; it helps only modestly and should not complicate your first implementation. citeturn18view3turn18view2

For 10×10 and 15×15, explicit placement pools are easy. For 20×20 they are still practical with sensible caps. Above that, the dynamic-programming literature becomes increasingly relevant, and that is where a fallback should kick in. Wu et al.’s `O(kℓ)` line-solving result is the main reason to keep a second path available for future scaling. citeturn21view0turn19view0

### Solver design

The production solver should have two deterministic modes:

- **Logic mode** for hints and human-style difficulty.
- **Complete mode** for validation, uniqueness, and generator rejection.

Both modes should share the same board model and line engine to avoid divergence bugs.

The **complete mode** starts by initializing every line domain from its placement pool and then propagating until no more cells can be forced.

```pseudo
function initializeSolver(puzzle):
    state.board = Uint8List(width * height).fill(UNKNOWN)
    state.rowDomains = [fullPlacementPool(rowClue[y]) for y in rows]
    state.colDomains = [fullPlacementPool(colClue[x]) for x in cols]
    state.queue = all rows + all cols
    return state
```

Propagation updates dirty lines only and pushes perpendicular lines when a cell changes.

```pseudo
function propagate(state):
    while state.queue not empty:
        line = pop(state.queue)
        masks = masksFromBoard(state.board, line)
        result = solveLine(line.length, line.clue, masks.filled, masks.empty, line.currentDomain)

        if result.status == CONTRADICTION:
            return CONTRADICTION

        line.currentDomain = result.survivors

        for each bit in result.forcedFilledMask:
            if assignCell(state, cellAt(line, bit), FILLED) == CONTRADICTION:
                return CONTRADICTION

        for each bit in result.forcedEmptyMask:
            if assignCell(state, cellAt(line, bit), EMPTY) == CONTRADICTION:
                return CONTRADICTION

    return OK
```

Branch selection should be **MRV-flavored but clue-aware**. The best practical choice is:

- Choose the unresolved line with the **smallest nontrivial domain**.
- Inside that line, choose an unresolved cell whose fill probability is closest to `0.5` or whose split creates the most even two branches.

That combines domain-size line selection with cell-level branching and gives more informative branches than arbitrary first-unknown picks. This is a practical adaptation of minimum-remaining-values and forward checking to Nonograms. Specialized heuristics tuned to problem structure also perform better than general heuristics in SAT experiments. citeturn27view2turn14view0

```pseudo
function chooseBranch(state):
    bestLine = unresolved line with domainSize > 1 and minimal domainSize
    bestCell = unknown cell on bestLine maximizing information gain
    return bestCell
```

The solution counter is a bounded DFS.

```pseudo
function countSolutions(state, limit = 2, caps):
    if caps.exceeded():
        return UNKNOWN_CAP

    p = propagate(state)
    if p == CONTRADICTION:
        return 0

    if boardIsFullyAssigned(state.board):
        return 1

    cell = chooseBranch(state)

    count = 0
    for value in [FILLED, EMPTY]:
        checkpoint = pushCheckpoint(state)
        if assignCell(state, cell, value) != CONTRADICTION:
            sub = countSolutions(state, limit - count, caps)
            if sub == UNKNOWN_CAP:
                restore(state, checkpoint)
                return UNKNOWN_CAP
            count += sub
        restore(state, checkpoint)

        if count >= limit:
            return limit

    return count
```

This returns a status map naturally:

- `0` → no solution
- `1` → unique so far
- `>=2` → multiple solutions
- `UNKNOWN_CAP` → unresolved under cap

That status enum is the correct validator contract for your generator and for your test harness.

### Human-style logic overlay

A separate deterministic “human-style” layer should operate over the same line domains but expose only explainable rules. The older “simple” literature is based on single-line settle sweeps; the 2024 work argues that human-perceived difficulty also depends on advanced deterministic guessing and backtracking distance; and practical human-solving sources describe edge logic, two-way logic, and counting tricks that go beyond brute-force search. Put differently: human-style solving is real, but it should be a **layer**, not your proof engine. citeturn26view5turn11view1turn26view1turn30view0

Recommended rule stack for human-style solving:

- overlap and completed-line closure
- forced empty cells around completed runs
- line-domain elimination inside a single line
- edge logic / boundary logic
- two-way contradiction on a small local assumption
- counting / summing logic
- optional shallow probing, but only if you can explain it cleanly

Never let the hint layer silently switch to full DFS and pretend it was “obvious.”

### Correct validation of a completed board

A completed player board is valid iff:

- every cell is either filled or empty-marked,
- the row clues derived from the player’s filled cells equal the canonical row clues,
- the column clues derived from the player’s filled cells equal the canonical column clues.

Cross marks are UI affordances, not logical content. The solved image is just filled versus unfilled.

```pseudo
function validateCompletedBoard(board, puzzle):
    if any cell == UNKNOWN:
        return false
    return deriveAllClues(board.asFilledBitmap()) == (puzzle.rowClues, puzzle.colClues)
```

### Validation of a single player move

There are two honest validation modes.

**Clue-consistency mode** checks only whether the move makes the affected row or column impossible. This does not reveal the hidden solution and is the fairest “real-time feedback” mode.

```pseudo
function validateMoveByConstraints(board, puzzle, cell, newState):
    old = board[cell]
    board[cell] = newState
    if lineContradicts(puzzle.rowOf(cell)) or lineContradicts(puzzle.colOf(cell)):
        board[cell] = old
        return INVALID
    return VALID
```

**Strict mistake mode** compares the move against the hidden solution bitmap stored locally or regenerated locally from seed. This is acceptable only as an optional assist mode, and the hidden solution must remain device-local.

## Generation pipeline

### Recommended solution bitmap generation

The target filled/empty bitmap should be generated by a **deterministic procedural shape synthesizer**, not by pure white-noise random fill. The reason is equal parts puzzle quality and solver stability. Random-density studies show complicated transitions between simple, hard, and non-unique puzzles as black-pixel density changes, and the literature on puzzle construction from images exists precisely because players expect pictures, not soup. The most actionable lesson is that **structure beats randomness**. citeturn37view0turn37view2turn16view0turn10view4

My recommended bitmap generator has five deterministic stages:

- choose a style family from the seed
- synthesize a **coarse low-resolution scaffold**
- upscale it to target size
- apply deterministic smoothing and anti-noise mutations
- apply local edits until density, fragmentation, and visual metrics fit the requested profile

A good style family set for monochrome mobile puzzles is:

- icon-like silhouettes
- region-grown abstract shapes
- mildly symmetric motifs with broken symmetry
- multi-part procedural objects
- abstract but legible geometric patterns

Avoid three extremes: static-like salt-and-pepper noise, giant boring rectangles, and perfect symmetry. Webpbn’s solving notes point out that symmetry can produce a mirror solution and create “cheaty” or ambiguous solving situations if uniqueness is not otherwise established. citeturn30view0

A strong practical generator from first principles looks like this:

```pseudo
function generateBitmap(seed, width, height, profile):
    rng = FixedPcg32(hash(seed, width, height, profile.code, "bitmap"))

    style = rng.pick([ICON, REGION, MOTIF, PARTIAL_SYMMETRY, ABSTRACT])

    coarseW = clamp(round(width / 3), 3, 8)
    coarseH = clamp(round(height / 3), 3, 8)

    coarse = makeEmpty(coarseW, coarseH)

    if style == REGION:
        seeds = 1 + rng.nextInt(profile.maxRegions)
        coarse = growRegionsDeterministically(coarse, seeds, rng)

    if style == ICON:
        coarse = drawProceduralIconSkeleton(coarse, rng)

    if style == MOTIF:
        coarse = stampMotifs(coarse, rng)

    if style == PARTIAL_SYMMETRY:
        coarse = growRegionsDeterministically(coarse, 1 + rng.nextInt(2), rng)
        coarse = mirrorOneAxisPartially(coarse, rng, breakRatio = 0.15..0.35)

    bitmap = upscale(coarse, width, height)

    bitmap = smooth(bitmap, rng, passes = profile.smoothPasses)
    bitmap = removeSingletonNoise(bitmap)
    bitmap = trimHugeRectangles(bitmap)
    bitmap = retargetDensity(bitmap, profile.targetDensity, rng)
    bitmap = retargetFragmentation(bitmap, profile.targetFragmentation, rng)

    return bitmap
```

If you want stronger recognizability later, bundle a **small local library of vector or bitmap seed motifs** inside the app and select them deterministically by seed. That still respects your offline-first and backend-no-board constraints because the actual puzzle is still constructed on-device.

### Clue derivation and puzzle object construction

Once the bitmap is fixed, derive row and column clues canonically, normalize empty lines to `[]`, and build the immutable puzzle object. This step must be fully deterministic and free of collection-order nondeterminism.

```pseudo
function buildPuzzleCandidate(bitmap, width, height, seed, profile):
    rowClues, colClues = deriveAllClues(bitmap, width, height)
    return PuzzleCandidate(
        width = width,
        height = height,
        rowClues = rowClues,
        colClues = colClues,
        seed = seed,
        profile = profile
    )
```

### Full generator loop

The full generator loop should be deterministic across retries. That means every retry gets its own derived child seed from `(baseSeed, attemptIndex, stageTag, parameters)`, and the retry order itself must be fixed.

```pseudo
function generatePuzzle(params):
    deadline = now + params.timeout
    acceptedFallback = null

    for attempt in 0..params.maxAttempts-1:
        attemptSeed = mixSeed(params.seed, params.width, params.height,
                              params.difficulty, attempt, "attempt")

        bitmap = generateBitmap(attemptSeed, params.width, params.height, profileFor(params))
        quick = quickScreen(bitmap, profileFor(params))
        if quick.reject:
            continue

        candidate = buildPuzzleCandidate(bitmap, ...)
        logicMetrics = runHumanStyleTelemetry(candidate)
        if logicMetrics.structuralReject:
            continue

        uniqueStatus = validateUniqueness(candidate, deadline, nodeCapFor(params))
        if uniqueStatus == UNKNOWN_CAP:
            continue
        if uniqueStatus == NONE:
            continue

        if uniqueStatus == MULTIPLE:
            repaired = tryRepair(candidate, uniqueStatus.solutionA, uniqueStatus.solutionB, deadline)
            if repaired == null:
                continue
            candidate = repaired

        finalMetrics = scoreDifficulty(candidate, logicMetrics)
        visualMetrics = scoreVisualQuality(bitmap, finalMetrics)

        if matchesTarget(finalMetrics, visualMetrics, params.difficulty):
            return finalize(candidate, bitmap, finalMetrics, visualMetrics)

        acceptedFallback = maybeKeepNearest(acceptedFallback, candidate, finalMetrics, visualMetrics)

        if now >= deadline:
            break

    if acceptedFallback != null:
        return acceptedFallback.withFallbackFlag()

    return FAILURE_TIMEOUT_OR_BUDGET
```

The **quick screen** should reject obvious bad candidates before expensive uniqueness checking. Suggested early-reject features:

- density outside the profile band
- too many isolated single filled cells
- too many line clues at width/height
- too many empty lines for the difficulty
- giant rectangle/blob occupancy
- exact whole-puzzle symmetry
- insufficient visual score

Use a **background isolate** for generation, and for repeated random-play generation, prefer a **long-lived worker isolate** over many short `Isolate.run()` calls. The Dart and Flutter docs are explicit that short-lived isolates have spawn/copy overhead, and long-lived background workers are preferable for repeated computations. citeturn32view1turn32view3turn12view7

### Non-unique puzzle repair

Repair should be **bounded** and **local**. When the uniqueness counter finds two different solutions, compute a `diffMask` of all cells that differ between them. Then evaluate whether that ambiguity is local enough to repair.

```pseudo
function tryRepair(candidate, solA, solB, deadline):
    diffMask = solA xor solB
    if popcount(diffMask) == 0:
        return null
    if popcount(diffMask) > repairMaxDiffCells:
        return null

    region = boundingBoxPlusMargin(diffMask, margin = 1)

    currentBitmap = candidate.solutionBitmap
    for repairStep in 0..maxRepairSteps-1:
        edits = proposeLocalEdits(currentBitmap, region)
        best = pickBestEdit(edits,
                            uniquenessGain,
                            visualPenalty,
                            difficultyDistance)

        if best == null:
            return null

        currentBitmap = applyEdit(currentBitmap, best)
        newCandidate = buildPuzzleCandidate(currentBitmap, ...)

        status = validateUniqueness(newCandidate, deadline, repairNodeCap)
        if status == UNIQUE:
            return newCandidate

        if status == UNKNOWN_CAP:
            return null

        if status == MULTIPLE:
            diffMask = status.solutionA xor status.solutionB
            region = boundingBoxPlusMargin(diffMask, margin = 1)

    return null
```

Recommended local edits:

- flip one cell on the ambiguity boundary
- add or remove a tiny 2–3 cell spur to break interchangeable placements
- merge or separate a run locally by one cell
- eliminate an isolated ambiguity cavity

Do **not** keep repairing forever. If repair runs out of budget, throw the candidate away. Infinite “maybe the next mutation fixes it” loops are classic generator failure modes.

## Difficulty, hints, validation, and aesthetics

### Difficulty should be measured three ways

You should distinguish:

- **generation parameters**: what the generator was *trying* to make
- **actual solver-measured difficulty**: what your solvers *experienced*
- **human-perceived difficulty**: how the puzzle *feels*

Published work strongly supports the idea that a single scalar like “size” or even “number of logical sweeps” is not enough. Older work on simple puzzles uses sweep counts as a difficulty measure; newer work explicitly argues that step count alone produces tedious rather than truly difficult puzzles, and introduces advanced deterministic guessing and backtracking distance as key ingredients. citeturn11view1turn26view5turn10view0turn26view1

### Recommended practical difficulty model

Use a **hybrid score from 0 to 100**:

`FinalDifficulty = 0.45 * HumanLogicScore + 0.35 * SearchScore + 0.10 * StructuralScore + 0.10 * VisualPenaltyAdjust`

Where:

- `HumanLogicScore` measures explainable solving effort
- `SearchScore` measures how much complete solving was needed
- `StructuralScore` captures board features correlated with ambiguity
- `VisualPenaltyAdjust` penalizes tedious garbage that looks “hard” only because it is ugly

A good **HumanLogicScore** can combine:

- normalized number of deterministic steps
- number of propagation rounds
- count of advanced line eliminations
- count of edge-logic or two-way deductions
- count of shallow contradiction probes required

A good **SearchScore** can combine:

- number of speculative branches
- number of DFS nodes
- maximum recursion depth
- number of contradictions found by probing
- whether full search was required at all

A good **StructuralScore** can combine:

- board size
- average clue count per line
- mean initial line-domain size
- entropy of line domains after initial overlap
- completion ratio after pure line logic
- fragmentation and alternation
- density distance from the profile’s target band

A good **VisualPenaltyAdjust** should subtract points for:

- excessive isolated singletons
- checkerboard-like alternation
- giant undifferentiated rectangles
- exact symmetry
- too many empty lines or full lines unless intended for Easy

### Suggested label thresholds

These thresholds are recommendations, not universal laws. They must be calibrated against your actual solver and your players.

- **Easy:** `0–29`
- **Medium:** `30–54`
- **Hard:** `55–79`
- **Expert:** `80–100`

Additional gating rules improve label quality:

- Easy must solve with human-style logic and **no speculative branch**
- Medium may allow **very shallow** speculative logic but should rarely need full DFS
- Hard may require a few contradiction probes or branches
- Expert may require meaningful search, but should still be unique and visually coherent

Calibration should happen empirically: generate thousands of seeded candidates, measure solver telemetry, then compare player completion rates, hint usage, abandonment, and mistake frequency. The 2024 paper’s emphasis on combining steps, deterministic guessing, and backtracking is especially useful guidance for that calibration. citeturn26view1turn34view0

### Difficulty-specific generation profiles

**Easy**

Use 5×5 only for onboarding and tutorials. For normal play, prefer 8×10, 10×10, or mild rectangles like 10×12. Keep density in roughly the `0.38–0.55` band, keep fragmentation low, and target about `1.2–2.0` clues per line on average. Initial pure line logic should solve at least `80%` of cells, and the human-style solver should finish without branching. UX-wise, these should be playable on a phone without zoom. This profile is consistent with the older “simple puzzle” literature: easy puzzles are largely line-sweep-friendly. citeturn26view5turn11view2

**Medium**

Use 10×10, 10×15, 15×10, and 15×15. Density should usually stay around `0.32–0.52` with moderate fragmentation and `1.8–3.0` clues per line on average. Pure line logic should solve roughly `50–80%` of cells, and the human-style layer may need one or two advanced deductions. Full search should still be tiny or absent. These are your daily-driver puzzles for most players.

**Hard**

Use 15×15 as the main hard size, with optional 15×20 or 20×15. Density should stay in a tighter useful band like `0.30–0.50`, fragmentation can be higher, and average clues per line can rise to about `2.5–4.0`. Initial propagation may solve only `25–55%` of cells, and a few contradiction-based deductions are acceptable. The uniqueness counter should still finish comfortably on a low-end phone under your generation cap.

**Expert**

Use 15×15 or 20×20 only. On phones, 20×20 should be opt-in and accompanied by zoom and strong drag input. Density should usually stay around `0.28–0.48`, with high but controlled fragmentation and average clues about `3.0–5.5` per line. Initial propagation may solve less than `35%` of cells, and real branching may be required. Expert should be rare and should still look intentional, not random. The 2024 optimization paper is a nice reminder here: making puzzles computationally nastier does not automatically make them more enjoyable, and larger sizes start to become tedious fast. citeturn34view0turn34view3

### Visual quality and puzzle aesthetics

Players expect Nonograms to reveal a picture. The generation literature explicitly works from input images for that reason, and the 2024 work goes even further by trying to optimize “fun” as distinct from raw difficulty. In practice, your engine should balance four things at once: uniqueness, difficulty, recognizability, and visual cleanliness. citeturn16view0turn9view1turn9view7

I recommend a **visual-quality score** with these components:

- reward one dominant connected component or a small number of balanced components
- reward coherent silhouette after downsampling to a coarser grid
- reward medium stroke variety
- reward partial but not exact symmetry
- penalize isolated singletons and pinholes
- penalize checkerboards and over-alternation
- penalize giant solid blocks without internal clue variety
- penalize trivial diagonals and triangles
- penalize too many empty or full lines unless in Easy

A practical interpretation:

- **Easy/Medium:** icons, silhouettes, mugs, leaves, animals, tools, stars, symbols
- **Hard:** more abstract but still interpretable forms
- **Expert:** abstract is acceptable, but still avoid meaningless noise

### Hint system recommendations

Hints should be ordered from **least revealing and most explainable** to **most revealing and least explainable**.

Recommended priority order:

- explain a row or column that can be progressed
- show overlap on a line
- show a forced filled cell
- show a forced empty cell
- show that a line placement is impossible because it contradicts another line
- show a local contradiction or two-way deduction
- suggest the next line to inspect
- reveal a full line as last strong logic hint
- reveal a single cell from the hidden solution only as final fallback

This is aligned with how practical play tools describe hints and with the newer difficulty work that models human-style deduction rather than raw solver completion. Nonny, for example, describes a hint system that highlights lines that can be progressed, which is much healthier than “here’s the answer cell” as a default behavior. citeturn35view3turn30view0turn9view7

Critically, the normal hint path should run the logic layer from the **player’s current board**, not from the solution bitmap. If your solver cannot justify a hint from the clues and current marks, that is a red flag. Only the explicit “reveal” action should read the local solution directly.

### Player move validation

There are three player-visible cell states:

- unmarked / unknown
- filled
- empty / cross-marked

I recommend allowing wrong moves by default and supporting both of these assist modes:

- **No mistake checking**: the classic logic-puzzle mode
- **Constraint-only checking**: reject or flag a move only if it makes the affected row or column impossible
- **Strict mistake mode**: compare against the local solution bitmap and flag exact mistakes immediately

Constraint-only checking is the fairest default because it does not expose the hidden solution. Strict mode is acceptable as an accessibility or casual mode, but it must remain local and explicit.

Support undo/redo with command objects or a compact move stack:

- cell index
- old state
- new state
- timestamp or sequence number
- optional note changes

Completion detection should happen when there are no unknown cells left and the derived row and column clues match the puzzle clues exactly.

## Performance, serialization, integration, and mobile UX

### Performance and complexity

For explicit line-placement domains, **placement generation** is roughly proportional to the number of valid placements for that clue and line length. **Filtering** is proportional to `domainSize × wordsPerLine`. **Intersection** is proportional to `domainSize`. In practice, the hot path is repeated filtering of the same lines under similar states, which is exactly why line-result caching helps so much. Wolter’s published caching measurements show very high hit rates and significant speedups, especially once search starts. citeturn18view3turn18view2

**Propagation** cost is manageable because cell changes only make one row and one column dirty. If you keep a queue of dirty lines and never rescan untouched lines unnecessarily, your common-case cost stays low. **Search** remains exponential in the worst case; theory gives you no free lunch there, since general Nonogram solving is computationally hard. citeturn33view2turn20view3

The practical safeguard is not pretending worst-case exponential search can be wished away. Your complete solver should have:

- node cap
- recursion-depth cap
- wall-clock budget
- status `unknown_cap`
- telemetry for why it stopped

Those are not optional if you run generation on low-end phones.

Recommended **performance budgets** for low-end Android, as engineering targets:

- move validation: under 1 ms median
- line hint: under 10 ms median
- full hint calculation: under 30 ms median
- clue derivation: effectively instantaneous
- uniqueness check for accepted 10×10: under 100 ms median
- uniqueness check for accepted 15×15: under 300 ms median
- random-play generation: usually under 1 s for Easy/Medium, under a few seconds for Hard/Expert with fallback
- daily challenge generation: okay to use a longer background budget because it is infrequent

These numbers are recommendations, not literature claims, but they are realistic guardrails for your product goals.

### Isolates and background execution

Flutter runs app work on the main isolate by default, and both Flutter and Dart recommend isolates for computations large enough to make the UI unresponsive. The docs also note that short-lived isolates have spawn and message overhead, and that repeated work may benefit from long-lived background workers. `TransferableTypedData` is specifically designed to move byte sequences efficiently between isolates. That gives you a straightforward architecture: a long-lived `PuzzleWorkerIsolate` for generation, uniqueness checks, and large hint computations. citeturn9view4turn12view6turn32view1turn32view3turn12view7

Practical isolate recommendations:

- keep the pure-Dart engine isolate-safe and side-effect free
- send only small parameter objects in
- return packed results, telemetry, and serialized puzzle objects out
- prewarm the worker isolate at app launch or on first puzzle-page entry
- batch random-play generation if the player is likely to request another puzzle soon

### Serialization and app integration

Recommended serialized puzzle schema:

```json
{
  "type": "monochrome_nonogram",
  "version": 3,
  "engineVersion": "1.4.0",
  "generatorVersion": "g3",
  "seed": "0x8b7b6c45f1a2d903",
  "difficultyLabel": "Hard",
  "difficultyScore": 67.4,
  "width": 15,
  "height": 15,
  "rowClues": [[3], [1,1], [], [5], ...],
  "colClues": [[2], [1,2], [4], ...],
  "profile": {
    "family": "icon",
    "targetDensity": 0.39
  },
  "solverTelemetry": {
    "initialCompletion": 0.44,
    "humanSteps": 83,
    "humanAdvancedDeductions": 3,
    "searchNodes": 412,
    "branchDepth": 4,
    "uniquenessStatus": "unique"
  },
  "visualScore": 78,
  "createdAt": "2026-06-04T00:00:00Z",
  "playerState": "optional-packed-tristate",
  "localSolution": "optional-local-only-packed-bitmap",
  "solutionHash": "optional"
}
```

Use `[]` for empty lines. Accept `[0]` only on import and normalize immediately.

If you want the backend to avoid storing puzzle boards and solutions, **do not sync solution bitmaps** and do not sync pre-generated puzzle boards. Sync only what is necessary to reconstruct the puzzle deterministically:

- seed
- puzzle parameters
- engine/generator version
- daily date identifier
- difficulty label and score
- optional player progress state if your privacy/product policy allows it

If you want a truly “seed-only” backend, do not sync row or column clues either; regenerate them on device from seed and generator version. The cost is that backward compatibility becomes vital.

### Mobile UX recommendations

For phones, the best default sizes are **10×10** and **15×15**. Support **5×5** for onboarding only. Support **20×20** only with zoom and strong input ergonomics, and I would not make 20×20 your default daily size on phones. On larger tablets, 20×20 is much more comfortable.

Clue readability matters almost as much as the grid. Flutter’s accessibility guidance says text respects OS font settings, and you should leave room for large text. If your clue gutters collapse under large font scaling, the puzzle becomes inaccessible fast. citeturn42view1

Recommended interaction design:

- row/column highlight on touch-down
- dedicated fill and cross modes, plus optional tap-to-cycle
- drag-fill and drag-cross for long runs
- pinch-to-zoom and pan for 15×15 and larger
- completed-line highlighting
- optional auto-cross of fully solved lines in casual mode
- haptic tick on state change
- subtle contradiction highlight when a move makes a line impossible

For tappable controls around the board, follow Android and Flutter accessibility guidance: aim for at least **48×48 dp** tap targets, and leave enough space for large fonts and high-contrast themes. citeturn42view0turn42view1

Because this is a monochrome puzzle, the core game is naturally color-blind-friendly, but do not make mistake feedback depend on red-vs-green alone. Use icons, line highlights, vibration, and text labels as redundant channels.

## Testing, failure modes, roadmap, and final blueprint

### Testing strategy

Your test suite should be broad and merciless.

**Unit tests**

Verify clue derivation, especially:

- fully empty rows and columns
- fully filled rows and columns
- alternating patterns
- leading/trailing empties
- single run
- multiple runs
- rectangular boards

Verify empty-line normalization:

- import `[]`
- import `[0]`
- import `"0"` from legacy text
- reject `[0, 1]`, `[1, 0]`, negative clues, and oversized clues

Verify line placement generation:

- exact-count cases where `sum + gaps == length`
- empty clue
- single max-length clue
- many one-length runs
- known filled/empty masks
- contradiction when no placement survives

Verify intersection:

- `mustFill`
- `mustEmpty`
- no forced cells
- contradiction on empty domain

**Known-puzzle tests**

Maintain a corpus of fixed puzzles with expected status:

- uniquely solvable
- multiple solutions
- no solution
- cap/timeout expected `unknown`

Include pathological small cases such as 2×2 and symmetry-driven ambiguities. The published literature explicitly discusses switching components and multiple-solution behavior in small puzzles, so those belong in your regression suite. citeturn37view1

**Property-based and fuzz tests**

For small boards, brute-force all bitmaps or large random subsets:

- derive clues from bitmap
- verify original bitmap satisfies clues
- run complete solver
- confirm uniqueness status against brute force where feasible

For line solvers:

- compare enumeration and DP fallback outputs on random `(length, clues, knownMask)` triples

For determinism:

- same seed + params + engine version must always produce identical serialized puzzles
- repeated generation in isolate vs main isolate must match exactly
- platform runs should match across Dart VM targets you support

**Serialization tests**

- JSON round-trip
- progress-state round-trip
- engine version migration tests
- backward compatibility tests for older puzzle versions

**Hint correctness tests**

For every hint returned:

- applying the hinted move must preserve at least one solution
- if the hint is labeled “forced,” the opposite assignment must lead to contradiction under the logic layer or the complete solver, depending on hint category
- “reveal” hints must only appear when no explainable hint exists or when explicitly requested

**Benchmark tests**

Collect at least:

- median and p95 line-solve time
- median and p95 propagation time
- node counts for uniqueness
- generation attempts per accepted puzzle
- accepted/rejected ratios by difficulty
- memory use of placement pools and caches

### Common bugs and failure modes

The most common implementation mistakes are depressingly consistent.

**Incorrect empty-line handling**. Using `[0]` internally or treating empty lines inconsistently produces serialization bugs, invalid clue comparisons, and broken generators. Detect it with dedicated normalization tests and by asserting “all internal clues contain only positive lengths.” citeturn39view2

**Incorrect run extraction**. Off-by-one mistakes in leading or trailing transitions are common. Detect them with exhaustive small-line tests.

**Forgetting required separator cells between runs**. This is the classic Nonogram bug. Detect it with lines like `[1,1]` in tiny widths and by verifying that enumerated placements never merge adjacent runs. citeturn41view3

**Accepting multi-solution puzzles**. This usually happens because a solver stops after the first solution or because a timeout is misreported as success. The “solving vs validation” distinction from the solver survey is exactly about this. Detect it with fixed multi-solution corpora and by enforcing the `unknown_cap` status. citeturn17view1

**Treating timeout as uniqueness**. This is not a bug; it is a lie. Emit `unknown_cap` and reject in generation.

**Solver biased toward the generated bitmap**. If you seed the validator with the intended solution or use it as a branching oracle, you can accidentally “prove” uniqueness by cheating. Detect this by validating the same puzzle without access to the source bitmap and comparing results.

**Nondeterministic RNG usage**. Hidden calls to wall-clock time, unordered map iteration, or mixed random sources will break daily reproducibility. Detect this with seed determinism tests and serialization goldens.

**Infinite retry loops**. If acceptance criteria are too tight for the profile or the repair step never gives up, generation can spin forever. Detect this with capped-attempt tests and deadline tests.

**Difficulty labels detached from reality**. If you score by size alone or by shallow logic alone, players will call your bluff. Detect this by comparing solver telemetry with player metrics and by auditing outliers manually.

**Visually ugly random boards**. A generator can be unique and still look awful. Detect this with visual-score thresholds and curated screenshot review.

**Clue overflow and cramped mobile layout**. Long clue gutters or enlarged accessibility fonts can destroy UI. Flutter explicitly warns to test with the largest font settings, and tap target guidance should drive your controls, not wishful thinking. Detect this with snapshot/UI tests on small devices under maximum text scale. citeturn42view1turn42view0

### Implementation roadmap

**Core model**

Acceptance criteria:

- canonical puzzle model implemented
- empty-line normalization implemented
- deterministic serialization contract defined
- no mutable public clue lists

**Clue derivation**

Acceptance criteria:

- derive row and column clues correctly
- exhaustive line tests passing
- empty and full line tests passing
- regression tests for edge transitions passing

**Line-placement generator**

Acceptance criteria:

- exact placement enumeration correct
- filtering and intersection correct
- contradiction detection correct
- caching keys stable and deterministic

**Line propagation solver**

Acceptance criteria:

- propagation solves easy/simple puzzles without search
- dirty-line queue works
- diagnostics expose forced cells and contradictions

**Full uniqueness counter**

Acceptance criteria:

- statuses `none`, `unique`, `multiple`, `unknown_cap`
- early exit at two solutions
- no timeout mislabeled as unique
- fixed multi-solution corpus passes

**Bitmap generator**

Acceptance criteria:

- deterministic by seed
- no wall-clock dependence
- produces candidates in target density and fragmentation bands
- generations reproducible across repeated runs

**Difficulty scorer**

Acceptance criteria:

- logic telemetry and search telemetry both collected
- label thresholds configurable
- outlier audit tool available
- same puzzle gets identical score on repeated runs

**Visual-quality scorer**

Acceptance criteria:

- noise, blob, symmetry, and silhouette heuristics implemented
- easy visual garbage rejected before uniqueness check
- configurable thresholds by difficulty profile

**Hint system**

Acceptance criteria:

- returns explainable next moves when available
- never returns a “forced” hint that is not actually justified
- only uses solution bitmap for explicit reveal fallback

**Serialization and progress**

Acceptance criteria:

- puzzle round-trips cleanly
- player progress round-trips cleanly
- older versions migrate or remain loadable
- backend sync path can operate seed-only

**Tests and benchmarks**

Acceptance criteria:

- full automated suite in CI
- fixed-seed regression pack
- performance benchmarks recorded
- low-end-device acceptance budgets defined

**UI integration**

Acceptance criteria:

- generation and heavy solve off UI isolate
- cancellation supported
- zoom/input ergonomics implemented for large boards
- accessibility tested with large fonts and tap targets

### Final recommended architecture

Use this blueprint.

**Recommended bitmap-generation algorithm**  
Deterministic procedural **coarse-scaffold region/motif generator** with density, fragmentation, and visual-quality control. Start from a seeded structured scaffold, not from random noise.

**Recommended clue-derivation algorithm**  
Canonical left-to-right run extraction with internal empty-line representation `[]`. Normalize legacy `[0]` on import only.

**Recommended solver algorithm**  
Cached **line-domain propagation** over immutable placement pools, with a complete **DFS solution counter** that branches on a cell chosen from the most constrained unresolved line.

**Recommended uniqueness strategy**  
Count solutions up to **two**, early-exit on the second, and return `unknown_cap` if capped or timed out. Reject all non-`unique` candidates during generation.

**Recommended difficulty strategy**  
Hybrid score using:
- human-style logic telemetry for player label
- full-search telemetry for safety
- structural features for coarse priors
- visual penalties to suppress tedious ugliness

**Recommended hint strategy**  
Run the human-style logic layer from the player’s current state. Prioritize line-progress hints, overlap, forced empty, contradiction, two-way logic, then last-resort reveal.

**Recommended visual-quality strategy**  
Reward coherent silhouettes and moderate component structure. Penalize noise, exact symmetry, checkerboards, giant blobs, and trivial diagonal gimmicks.

**Recommended test strategy**  
Exhaustive small-case tests, fixed-seed regression suites, multi-solution and no-solution corpora, enumeration-vs-DP cross-checks, isolate determinism tests, and performance benchmarks.

**Recommended defaults for mobile**  
Tutorials at 5×5. Main catalog centered on 10×10 and 15×15. 20×20 only with zoom and better ergonomic input, and preferably not as the default phone experience.

**Biggest risks**  
False uniqueness, nondeterministic generation, hint systems that secretly cheat with the solution, and difficulty labels that drift away from actual player experience.

**What not to do**  
Do not rely on a solver that finds only one solution. Do not equate timeout with uniqueness. Do not generate pure random bitmaps and hope post-filters save them. Do not make the backend the source of truth for puzzle boards if your product goal is seed-only reproducibility. Do not let your hint system mask engine bugs by peeking at the answer too early. citeturn17view1turn33view2turn35view2turn9view4turn12view6

### Open questions and limitations

Two areas still require product-specific calibration rather than more theory. First, the exact **difficulty thresholds** should be tuned against your own solver telemetry and player analytics, because published work gives strong guidance on *what to measure* but not a universal label scale. Second, the best balance between **recognizable imagery** and **difficulty diversity** is partly a creative direction decision: the literature strongly supports image-like generation, but the right ratio of icons, silhouettes, and abstract puzzles is a design choice, not a theorem. citeturn9view1turn9view7turn16view0