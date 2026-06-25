# Production Design for a Brainiax Queens-Style Puzzle Engine

## Puzzle identity and rule definition

**Closest established family.** The puzzle you described is best classified as a **one-star Star Battle** variant with queen or crown theming, not as classic N-Queens. LinkedIn’s official help defines *Queens* as placing exactly one crown in each row, column, and colored region, with crowns forbidden from occupying adjacent cells, including diagonals. Independent Star Battle references define the same core structure, but with a configurable star count per row, column, and region; for **1★** puzzles, the rules are exactly “one per row, column, and shape/region” plus “no touching, even diagonally.” GMPuzzles, which publishes Thomas Snyder’s one-star Star Battle puzzles, explicitly calls them “exactly like Queens” and describes LinkedIn Queens as “a very accessible, one-star version of Star Battle.” citeturn39view0turn41search0turn41search2turn42view0turn33view0

**How it differs from classic N-Queens.** Classic N-Queens forbids queens from sharing any row, any column, or any full diagonal. The LinkedIn-style variant keeps the “one per row” and “one per column” structure but **softens the diagonal rule** to only forbid **adjacent diagonal contact**, then adds the extra rule that each colored region must contain exactly one queen. The recent QUBO paper on LinkedIn Queens states this explicitly: the classic diagonal constraint is replaced by a softer “adjacent diagonal” restriction, and a region constraint is added. Practical solver writeups in SMT, MiniZinc, Haskell, and CP-SAT all encode the puzzle that same way, usually as `abs(q[r] - q[r+1]) > 1` for adjacent rows only. citeturn20view0turn30view0turn35view0turn26view3turn26view2

**How it differs from Star Battle.** It differs mostly in **presentation and common size profile**, not in the underlying constraint family. Standard Star Battle allows 1, 2, or 3 stars per row, column, and region depending on the puzzle. Queens is the **1★ case**, presented with queens or crowns instead of stars, usually on smaller and more beginner-friendly boards. Puzzle Baron, puzzle-star-battle.com, and GMPuzzles all describe Star Battle as a family with variable star count; GMPuzzles repeatedly labels the one-star form as “exactly like Queens,” and a current Play Store listing for a dedicated Queens app says the puzzle is the same as LinkedIn Queens and very similar to Star Battle / Two Not Touch. citeturn41search0turn41search2turn42view0turn33view0

**How it differs from standard chess queen attacks.** For this puzzle family, queens do **not** attack along full diagonals. They merely may not **touch** another queen, which is a king-move style adjacency restriction layered on top of the row and column uniqueness rules. So the interpretation you gave is correct: in LinkedIn Queens-style puzzles, two queens may sit on the same long diagonal as long as they are not diagonally adjacent. That point is stated directly in the QUBO paper and in multiple solver writeups, and it is consistent with LinkedIn’s own rule wording, which bans crowns in “adjacent cells, including diagonally,” not all diagonal lines. citeturn39view0turn20view0turn26view3turn30view0

**Is “Killer Queens” a good app-facing name?** Not really. The established public names around this family are **Queens**, **Star Battle**, and **Two Not Touch**. “Killer Queens” is not a standard term in the puzzle literature or current app ecosystem, and it risks implying a relation to *Killer Sudoku* or to aggressive chess-queen attack rules that this puzzle specifically does **not** use. If your goal is clarity and discoverability, “Killer Queens” is more likely to mislead than to help. citeturn39view0turn41search0turn41search7turn33view0

**Recommended neutral names.** If you want maximum recognizability, **Queens** is the clearest label. If you want something app-safe that avoids looking like a direct LinkedIn clone, the best alternatives are **Crowns**, **Crown Logic**, **Color Queens**, or **Regional Queens**. “Crowns” is especially defensible because LinkedIn’s own help page uses “Crown symbol (Queen)” terminology. My recommendation is: use **Queens** for the internal puzzle-family name, and use **Crowns** or **Crown Logic** for an app-facing branded mode name if you want a little legal and product-distance. citeturn39view0turn33view0turn42view0

**Exact rules Brainiax should adopt.** The cleanest production rule set is: an `N x N` grid partitioned into exactly `N` colored regions; every cell belongs to exactly one region; every region is non-empty; the player must place exactly `N` queens; every row, every column, and every region must contain exactly one queen; and no two queens may occupy Chebyshev-neighboring cells. Full diagonal queen attacks are **allowed** unless the queens are adjacent. I recommend treating **orthogonal region connectivity** as a construction requirement, even though LinkedIn’s public help page does not explicitly state contiguity. Public descriptions and design/solver writeups commonly describe the regions as connected components, and connected regions are much better for readability, generation control, and human difficulty shaping. citeturn39view0turn19search2turn36view0

**Formal solved-board test.** A solved board is valid iff all of the following hold simultaneously: every row has queen count 1; every column has queen count 1; every region has queen count 1; queen count over the board is exactly `N`; and for every queen cell `(r,c)`, no queen exists at `(r±1,c±1)`, `(r±1,c)`, or `(r,c±1)`. In practice, the horizontal and vertical parts of the no-touch rule are already implied by the row/column exact-one constraints, so the additional structural check you actually need beyond row/column/region counts is only the **adjacent diagonal** prohibition. That is exactly how several formal models encode the puzzle. citeturn40view0turn20view0turn35view0

## Executive architecture and formal model

**Executive recommendation.** For a production-quality mobile engine, the best architecture is a **deterministic, pure-Dart, solution-first generator** paired with a **hybrid propagation-plus-search solver** and a **separate human-style logic layer**. In plain English: first generate a legal queen placement; then generate connected regions around those queens; then run a fast solver that counts solutions up to 2 for uniqueness; then run a human-style solver to estimate rating and power hints; then accept or reject. This architecture fits the actual structure of the puzzle, matches how strong practical models represent it, and avoids the maintainability trap of using a generic SAT/SMT/ILP engine as your on-device runtime core. citeturn35view0turn27view0turn10view0turn26view2turn40view0

**Why this architecture wins on mobile.** MiniZinc, CP-SAT, SAT, SMT, and MILP models all solve current Queens instances very quickly in research and hobby writeups, which is great evidence that the constraint system is clean and not intrinsically huge at LinkedIn-sized boards. But those approaches shine most as **modeling and QA tools**, not as the core engine inside an offline Flutter app, especially when you need deterministic seeded generation, cheap uniqueness counts, move-level diagnostics, explainable hints, and a consistent pure-Dart deployment story. The strongest practical production shape for that stack is a custom solver with hand-tuned propagation, MRV branching, and capped solution counting. citeturn31view2turn31view3turn30view0turn26view0turn26view2turn40view0

**Runtime split.** Use three distinct layers: an immutable **`PuzzleDefinition`**; a mutable **`PlayState`** for the UI; and a specialized **`SolverState`** for generation, solving, and uniqueness checking. `PuzzleDefinition` should contain size, region mapping, region cell lists, precomputed neighbor relations, and metadata. `PlayState` should contain user-visible cell states and maybe lightweight conflict flags. `SolverState` should contain compact occupancy masks, candidate masks, and an undo stack. This separation makes the UI sane, the solver fast, and serialization stable. That recommendation lines up with both the strategy-oriented Haskell solver and the mutable-state Star Battle/Queens backtrackers described in public writeups. citeturn27view2turn10view0turn12view0

**Determinism and RNG policy.** Do **not** make your canonical content generation depend on `dart:math Random` if exact reproducibility across engine versions and platforms matters. Dart’s docs describe `Random` as a pseudorandom generator with an optional seed, but they do not promise a permanent cross-platform canonical sequence, and the SDK has had real platform-specific Random issues, including a WASM seeding bug and reports that default `Random()` makes no promise about seed diversity. For daily challenges and seed-locked generation, use an app-owned PRNG such as SplitMix64 or PCG32 implemented in pure Dart and version it as part of the generation recipe. citeturn16search1turn16search5turn17search3turn17search14

**Background execution.** Generation, uniqueness counting, and any heavier difficulty analysis should run in a Dart isolate, not on the main UI isolate. Flutter’s performance docs are blunt here: heavy computation on the main isolate can make the UI unresponsive, and 60 fps rendering implies a roughly 16 ms frame budget. Since all isolates have separate memory and communicate by messages only, keep isolate payloads compact and serializable. In practice that means passing seeds, parameters, and compact board arrays, not giant object graphs. citeturn14search0turn14search1turn29search0turn29search2

**Formal puzzle model.** Let `N` be the board side length. Let cells be indexed either as `(r,c)` for `0 <= r,c < N` or as a flat `i = r*N + c`. Let `regionOf[i] in [0, N-1]` map every cell to exactly one region. Let `state[i]` be one of `{unknown, queen, emptyMark}`. Let `Q` be the set of queen cells. A valid puzzle instance must define exactly `N` non-empty regions covering all `N²` cells, and—if you adopt the recommended construction rule—each region must be orthogonally connected. A valid solved board must satisfy row, column, region, and no-touch constraints. A valid published puzzle must furthermore be **uniquely solvable**. citeturn39view0turn20view0turn36view0

**Constraint model.** In binary form with `x[r,c] ∈ {0,1}`, the constraints are:

```text
For every row r:      Σ_c x[r,c] = 1
For every column c:   Σ_r x[r,c] = 1
For every region k:   Σ_(r,c in region k) x[r,c] = 1
For every diagonal-adjacent pair:
                      x[r,c] + x[r+1,c-1] <= 1
                      x[r,c] + x[r+1,c+1] <= 1
```

That is the cleanest formal representation for correctness, and it is exactly the shape used in IP/QUBO/CP-style formulations of LinkedIn Queens. citeturn40view0turn20view0turn26view2

**What metadata to store.** At minimum store puzzle type, schema version, engine version, deterministic seed, generation profile, board size, region map, difficulty band, numeric difficulty score, solver telemetry from the accepted build, and creation timestamp. Optionally store a local-only solution bitset or local-only hint cache; do not make that a required server field. If you ever change generator logic, version the generation recipe explicitly, or old seeds will drift and your “daily” archive will become Schrödinger’s puzzle. That last part is an engineering recommendation, not a published standard, but it is the only sane way to make deterministic seeded content stable over time.

**Dart-friendly data structures.** Use `Uint8List` for dense fixed-size byte arrays such as `cellState`, `regionOf`, `rowQueenCount`, `colQueenCount`, `regionQueenCount`, and flattened region-border flags; the Dart typed-data docs explicitly note that `Uint8List` is considerably more space- and time-efficient than the default `List<int>` for long fixed-length arrays. Use plain `int` bitmasks inside `List<int>` for candidate masks because your target sizes fit comfortably in small integers and Dart bit operations are straightforward. Prefer **mutable arrays plus an undo stack** over cloned solver states; cloning is simple, but on low-end phones it creates unnecessary GC churn during generation and uniqueness counting. Precompute neighbor lists or diagonal-adjacency masks once per puzzle definition. citeturn15search5turn15search16

## Algorithm survey, recommended solver, and validation

**Survey of practical solver families.** Public Queens solvers fall into a few buckets. Some are very simple backtrackers that recurse over regions or colors, using row/column bookkeeping and local diagonal-touch counters. Others model the puzzle as a row-to-column assignment with `all_different` and adjacent-row constraints. Others encode it as SAT, SMT, CP-SAT, MILP, or QUBO. And human-facing puzzle implementations increasingly pair a brute solver with a deduction layer for hints and difficulty. All of those are legitimate; not all of them are equally good for your exact mobile stack. citeturn12view0turn35view0turn30view0turn26view2turn40view0turn20view0

**Row-by-row DFS.** This is the simplest worthwhile native solver. Represent the final solution as a permutation `queens[row] = column`, keep a used-column mask, enforce `abs(queens[r]-queens[r-1]) > 1`, and check region legality. MiniZinc and SMT writeups both show why this viewpoint is elegant: exactly one queen per row is baked into the variable design, `Distinct` / `all_different` handles columns, and the diagonal-touch rule reduces to adjacent rows only. Its strengths are simplicity, speed, and easy determinism; its weakness is that region reasoning and human-style hint extraction need additional machinery. citeturn35view0turn30view0

**Region-by-region DFS.** The browser-extension solver by brohitbrose recurses over colors/regions and uses short-circuiting backtracking with row/column validity and local diagonal-touch counters. That is also viable, especially because the one-queen-per-region rule is central to the puzzle. The downside is that region size and shape vary much more than row length, so the branching structure is noisier unless you sort by candidate count every step. It is decent, but I would still rank it below a generalized MRV solver that can branch on whichever unit is currently tightest. citeturn12view0

**Exact cover and DLX.** The puzzle can be encoded as a **generalized exact cover** problem: row, column, and region are primary “exactly one” constraints, while diagonal-adjacency conflicts are naturally secondary “at most one” constraints. Knuth’s DLX is excellent for sparse exact-cover search and N-Queens-style formulations, and exact-cover references explicitly discuss primary versus secondary constraints for N-Queens diagonals. The upside is elegance, speed, and easy solution enumeration. The downside is uglier integration with incremental player validation and human-style hints. My recommendation is: use exact cover only as an optional **oracle implementation** for QA, not as the main app engine. citeturn21view0turn23view0turn23view2

**Constraint programming, SAT, SMT, MILP, and QUBO.** These approaches are superb for *prototyping*, *cross-checking*, and *research*. MiniZinc models this puzzle very cleanly with row variables and `all_different`; CP-SAT, SMT, SAT, MILP, and even QUBO formulations all solve current LinkedIn-sized examples quickly. But they are a poor fit for a lean pure-Dart runtime core. They are too heavyweight for your shipping architecture, and they do not naturally provide user-facing explanations such as “this region is locked to this row, therefore these cells are impossible.” I would keep one of these models outside the app as a benchmark harness or golden-reference validator, not inside the app as the main engine. citeturn35view0turn31view2turn31view3turn30view0turn26view0turn26view2turn40view0turn20view0

**Human-style logical solvers.** LinkedIn itself says every grid has one right answer and is solvable without guessing, and its official tutorial teaches four recurring deduction types: giveaway cells, knockout cells, single-color-in-one-row/column interactions, and multi-color-in-k-rows/columns interactions. Those are not just UX garnish; they are direct clues about the puzzle’s intended human logic space. If you care about rating, hints, and “fair” generators, you need a separate human-style logic layer. It does not have to be complete, but it should cover the tutorial deductions and a few stronger locked-set variants. citeturn25view0turn39view0turn34view0

**Recommended production solver architecture.** Use a **hybrid logical + search solver** with these ingredients: compact candidate masks; aggressive propagation; MRV branching over rows, columns, and regions; forward checking; solution counting capped at 2; and a separate explanation-producing rule engine for hints. This is the best balance of speed, determinism, uniqueness checking, diagnostics, and hintability. My ranked recommendation is: first choice, hybrid propagation + MRV DFS; second choice, generalized exact cover as a QA oracle; third choice, solver-model backends for development and batch validation only. citeturn27view0turn27view2turn10view0turn23view2turn31view2

**Contradiction detection.** Contradictions should be detected as soon as any unsatisfied row, column, or region has zero legal candidates, or any placed queen causes a duplicate row/column/region occupancy or a diagonal-touch conflict. Public Star Battle and Queens solvers implement exactly that style of forward failure test, and it is the difference between a pleasant solver and a brute-force potato. citeturn10view0turn27view1

**Solution counting and uniqueness.** The only correct uniqueness test is to count solutions until you either find zero, one, or at least two. “I generated one valid solution” proves absolutely nothing. “My solver found one and timed out” also proves nothing; that result is **unknown**, not unique. Norvig’s Star Battle notebook deliberately yields all solutions so the same search can verify well-formedness, and the exact-cover / CP families naturally support enumeration as well. In production, count only up to 2 and stop immediately once the second solution is found. citeturn10view0turn23view2turn31view2

**Core solver pseudocode.**

```text
initSolver(definition, givens):
    state.rowMask[r] = allColumnsMask
    state.colUsedMask = 0
    state.regionSolved[k] = false
    state.rowSolved[r] = false
    state.colSolved[c] = false
    state.queenAtRow[r] = -1
    state.queenAtRegion[k] = -1
    apply givens with placeQueen()
    recomputeRegionCandidateCounts()
    propagate()

placeQueen(state, r, c):
    if queen already conflicts in row/col/region/diag-adjacent: fail
    pushUndoFrame()
    state.queenAtRow[r] = c
    state.rowSolved[r] = true
    state.colSolved[c] = true
    state.regionSolved[regionOf(r,c)] = true
    state.colUsedMask |= bit(c)

    # eliminate all other cells in row r
    state.rowMask[r] = bit(c)

    # eliminate column c from every other unsolved row
    for each row rr != r where not rowSolved[rr]:
        state.rowMask[rr] &= ~bit(c)

    # eliminate adjacent diagonals in neighboring rows
    for rr in {r-1, r+1} within board:
        state.rowMask[rr] &= ~bit(c-1) & ~bit(c+1)

    # eliminate all cells of solved region except (r,c)
    updateRegionViews(regionOf(r,c))
    if any unsolved row/col/region now has zero candidates: fail

propagate(state):
    repeat:
        changed = false

        # row singles
        for each unsolved row r:
            if popcount(state.rowMask[r]) == 1:
                c = onlyBit(state.rowMask[r])
                placeQueen(state, r, c)
                changed = true

        # column singles
        for each unsolved column c:
            candidates = rowsWhereBitPresent(c)
            if exactly one row r:
                placeQueen(state, r, c)
                changed = true

        # region singles
        for each unsolved region k:
            candidates = legalCellsInRegion(k)
            if candidateCount == 0: fail
            if candidateCount == 1:
                (r,c) = onlyCandidate
                placeQueen(state, r, c)
                changed = true

        # locked interactions / Hall-style unit rules
        applyHumanStyleForcedEliminations()
        if contradiction: fail
    until not changed

chooseBranchVariable(state):
    evaluate candidate counts for every unsolved row, column, and region
    return the unit with minimum remaining legal cells (MRV),
           tie-break by greatest projected eliminations

countSolutions(state, limit = 2):
    propagate(state)
    if contradiction: return 0
    if all rows solved: return 1

    unit = chooseBranchVariable(state)
    total = 0
    for candidate in orderedCandidates(unit):
        save = undoTop()
        if placeQueen(state, candidate.r, candidate.c) succeeds:
            total += countSolutions(state, limit - total)
            if total >= limit: return total
        undoTo(save)
    return total
```

This is the solver you want in the shipping engine.

**Move validation pseudocode.**

```text
validateMove(playState, move):
    if move is markEmpty:
        if cell is fixedQueen: reject
        toggle empty mark
        return partialValidation()

    if move is placeQueen:
        toggle queen
        recompute conflicts for:
            row r, column c, region k, adjacent diagonal cells
        return {
            allowed: true,          # recommended default
            conflicts: list,
            correctSoFar: no current rule violations
        }

validateCompleted(playState):
    if queenCount != N: return false
    if any rowCount != 1: return false
    if any colCount != 1: return false
    if any regionCount != 1: return false
    if any diagonal-adjacent queens: return false
    return true
```

**Validator modes.** Implement three validators, not one. A **definition validator** checks region partitioning, non-empty regions, optional connectivity, and uniqueness. A **play validator** checks current partial board consistency. A **completion validator** confirms the finished board is solved. Mixing these into one god-function is how puzzle engines become haunted.

## Generator design, uniqueness enforcement, and repair

**Queen solution generation.** For this family, the cleanest target-solution generator is a seeded backtracker over row-to-column assignments. MiniZinc’s row-variable model and SMT/Haskell writeups all exploit the same structural fact: with one queen per row and one per column, a complete solution is just a permutation plus the adjacent-diagonal condition and the eventual region rule. That makes row-based seeded DFS extremely natural. citeturn35view0turn30view0turn26view3

**Methods compared.** Random permutations with post-filtering are okay for tiny boards but become wasteful when you also care about aesthetic diversity. Min-conflicts and repair are more useful for very large N-Queens families than for your small mobile sizes. Exact-cover generation works but is overengineering here. Pattern-based construction is fast but produces repetitive, samey boards. The best production option is row-sequential seeded search with light lookahead and an anti-template aesthetic score. That gives you determinism, diversity, and control. This ranking is an engineering judgment grounded in the structure exposed by the row-variable models and practical backtracking solvers. citeturn35view0turn30view0turn26view3turn12view0

**Recommended queen-placement algorithm.**

```text
generateQueenPlacement(N, prng):
    colsFree = allColumnsMask
    placement = [-1] * N

    def dfs(r):
        if r == N:
            return true

        mask = colsFree
        if r > 0:
            prev = placement[r-1]
            mask &= ~bit(prev-1)
            mask &= ~bit(prev+1)

        candidates = shuffleBitsDeterministically(mask, prng)
        candidates = sortByLookahead(candidates,
                     key = futureCandidateCount(r+1, candidate))

        for c in candidates:
            placement[r] = c
            colsFree ^= bit(c)
            if dfs(r+1):
                return true
            colsFree ^= bit(c)
            placement[r] = -1
        return false

    if not dfs(0): fail
    return maybeRescoreAndSelectAmongFirstKCompletions()
```

Use a deterministic shuffle and deterministic tie-breaking. If you want more variety, explore the first `K` completions from the seeded search and choose the one with the best aesthetic score.

**Feasible board sizes.** Sizes `6x6`, `7x7`, `8x8`, `10x10`, and `12x12` are all feasible for this no-touch row/column family in practice. The practical constraint is not existence but UX and difficulty control. `6x6` and `8x8` are ideal for phones. `10x10` is very workable. `12x12` is algorithmically fine, but on phones it is a visual and interaction tax unless you add zoom or larger invisible touch hit areas. The algorithm is not the thing that will complain first; your thumbs will. That last judgment is reinforced by mobile target-size guidance discussed below. citeturn41search3turn28search0turn28search1turn28search8

**Region generation: recommended strategy.** Use **solution-first, multi-source connected region growth from queen seeds**. Start with each queen cell as the seed of its own region. Grow all regions outward over the remaining cells while preserving connectivity and targeting a chosen area distribution. This automatically guarantees exactly one solution queen per region. It also lets you shape human difficulty by controlling spans, compactness, and border complexity. A region-first generator is much harder to steer because it gives you pretty maps that often fail uniqueness or yield bland logic. citeturn25view0turn34view0turn36view0

**How region shape affects difficulty.** LinkedIn’s own tutorial deductions show that region geometry matters enormously. If a region has one cell, it is a giveaway. If a region’s legal candidates are contained in one row or one column, you get strong locked eliminations. If `k` regions are confined to `k` rows or columns, you get a Hall-set style deduction. Shaun Shue’s strategy writeup expands the same family of ideas with row/column allocation and overload checks. Therefore region generation should not merely produce connected blobs; it should deliberately manage row/column spans, remaining-candidate containment, and multi-region overlap patterns. citeturn25view0turn34view0

**Region-quality heuristics.** Easy boards should tolerate a few singleton or near-singleton regions, compact shapes, and obvious row/column containment. Hard boards should suppress trivial singletons, reduce fully-contained single rows/columns, and introduce controlled multi-region overlaps without degenerating into unreadable snakes. In all cases, penalize extreme perimeter-to-area ratios, isolated peninsulas, and “worm” regions that are visually legal but miserable to parse. That last rule is product wisdom, not formal mathematics, and it is worth obeying.

**Recommended region-growth pseudocode.**

```text
generateRegions(def, queenPlacement, targetProfile, prng):
    init each region k with its queen cell q[k]
    assign targetArea[k] from deterministic partition of N*N
    frontier[k] = orthogonal unassigned neighbors of region k

    while unassigned cells remain:
        cell = chooseNextCell(
            prefer highest assigned-neighbor count,
            then fewest feasible neighboring regions,
            tie-break deterministically)

        feasible = neighboring regions touching cell orthogonally
        region = argmax over feasible of score(cell, region):
            + compactnessGain
            + targetAreaFit
            + noHoleBonus
            + profileSpecificSpanBonus
            - snakePenalty
            - overshootPenalty
            - uglyPocketPenalty

        assign cell to region
        update frontier and local metrics

    smooth borders with bounded local swaps:
        for iteration in 1..K:
            choose border cell b that is not a queen
            try reassigning b to adjacent region r2
            keep change only if:
                both regions stay connected
                each region still contains exactly one seed queen
                quality score improves

    return regionMap
```

**Generator loop.** The generator should accept `(size, difficultyProfile, seed, optionalTimeout)`, derive a deterministic attempt stream from that seed, and then repeat: queen placement → region generation → puzzle build → uniqueness count up to 2 → human-style rating → accept/reject. If rejected, mutate or restart using the next deterministic sub-seed. Never use wall-clock randomness inside the loop or you will break seed determinism. Run the whole loop in a background isolate. citeturn14search0turn14search1turn29search0

```text
generatePuzzle(params):
    prng = RecipePRNG(params.seed, params.engineVersion, params.profile)
    deadline = now + params.timeout

    for attempt in 0 .. maxAttempts:
        if timedOut(deadline): return bestFallbackOrTimeout()

        qSeed = prng.split("queens", attempt)
        queenPlacement = generateQueenPlacement(params.N, qSeed)

        rSeed = prng.split("regions", attempt)
        regionMap = generateRegions(queenPlacement, params.profile, rSeed)

        puzzle = buildPuzzle(params, regionMap)

        uniq = countSolutions(initSolver(puzzle), limit=2, cap=params.searchCap)
        if uniq == 0: continue           # construction bug or bad repair
        if uniq >= 2:
            repaired = tryRepairNonUnique(puzzle, queenPlacement, params, prng)
            if repaired is not null:
                puzzle = repaired
            else:
                continue

        rating = rateDifficulty(puzzle)
        if fitsTarget(rating, params.profile):
            return finalize(puzzle, queenPlacement, rating, attempt)

    return fallbackBestSeen()
```

**Uniqueness checking: what is correct.** A published puzzle is unique only if your solver proves there is exactly one satisfying queen placement for that fixed region map. Region-growing around a known solution does **not** imply uniqueness. In fact, one-star Star Battle / Queens boards frequently admit swaps and alternative placements if the regions are not carefully structured. Your uniqueness checker must therefore be solver-based, capped at 2 solutions, and return one of four states: `none`, `unique`, `multiple`, or `unknown`. If the search cap or timeout is hit before proving uniqueness, the status is `unknown`, never `unique`. citeturn10view0turn24search11turn33view0

**How to avoid false uniqueness.** The best defense is not swagger; it is redundancy. Use one fast production solver in the app, but in development and CI cross-check fixed-seed puzzle sets against a second independent model, such as a MiniZinc, CP-SAT, SAT, or MILP formulation. Since all of those formulations for Queens are compact and current examples solve quickly, they make excellent oracle backstops for regression testing. If your native solver says “unique” and your reference model finds a second solution, your app is lying. Fix it before launch. citeturn31view2turn31view3turn30view0turn26view0turn40view0

**Bounded non-unique repair.** Repair is worthwhile, but only within bounds. Compare the first two solutions, find the rows/columns/regions/cells where they differ, and mutate only borders near that ambiguity. Preserve connectivity and the one-seed-per-region invariant. If the repair loop exceeds a small fixed budget, discard and restart; otherwise you will invent an infinite puzzle-generator hostage situation.

```text
tryRepairNonUnique(puzzle, queenPlacement, params, prng):
    sols = findFirstTwoSolutions(puzzle)
    diffCells = symmetricDifference(sols[0], sols[1])
    hotRegions = regionsTouching(diffCells)

    for repairStep in 1..maxRepairSteps:
        candidates = borderCellsNear(hotRegions, diffCells)
        for move in deterministicOrder(candidates, prng):
            if movePreservesConnectivity(move) and
               movePreservesSeedQueenOwnership(move):
                mutated = applyBorderMove(puzzle, move)
                uniq = countSolutions(mutated, limit=2)
                if uniq == 1:
                    if rateDifficulty(mutated) still fits profile:
                        return mutated
        if repairStep % restartMutationWindow == 0:
            hotRegions = expandNeighborhood(hotRegions)

    return null
```

My recommendation is to allow at most a handful of repair steps and then restart from a new deterministic attempt stream.

## Difficulty rating, hints, validation UX, and performance

**Difficulty is not one thing.** You need to separate **generator parameters**, **solver-measured difficulty**, and **human-perceived difficulty**. Generator parameters are just recipe knobs. Solver difficulty is what your search and propagation telemetry says. Human difficulty is what matters to players, and LinkedIn’s own tutorial plus contemporary Queens apps make clear that this family is expected to be solvable through recurring deductions and explanatory hints, not blind search. So use a **hybrid** rating model: human-style rule usage first, search telemetry second, board/region morphology third. citeturn25view0turn39view0turn33view0turn42view0

**Practical scoring model.** Run your human-style rule engine from an empty board and record: number of forced singles; number of knockout-cell eliminations; number of locked row/column-region deductions; number and size of `k`-regions-in-`k`-rows or columns deductions; number of contradiction-based eliminations; total propagation rounds; and whether the human layer finished without fallback search. Then run the full solver and record search nodes, backtracks, and branching factor. Finally, add region-shape metrics such as singleton-region count, area variance, average perimeter-to-area ratio, and visual border complexity. That composite is far more trustworthy than board size alone. citeturn25view0turn34view0turn27view0turn31view2

**A workable rubric.** One production-friendly formula is:

```text
score =
  1 * forcedSingles
+ 2 * knockoutElims
+ 4 * lockedContainmentSteps
+ 6 * kSetSteps
+ 10 * contradictionSteps
+ 8 * log2(searchNodes + 1)
+ 6 * log2(backtracks + 1)
+ 0.5 * regionAreaStdDev
+ 1.5 * averageBorderComplexity
- 2 * singletonRegionCount
```

Then map approximately as follows: `Easy < 25`, `Medium 25–55`, `Hard 56–95`, `Expert >= 96`. Do not treat those numbers as sacred tablets from the mountain; they are starting thresholds. Calibrate them by sampling fixed seeds, timing solves, and testing with humans. The important part is the **shape** of the model, not the divine perfection of the coefficients on day one.

**Difficulty profiles.**  
For **Easy**, prefer `6x6`, optionally gentle `8x8`; allow a few small or visually obvious regions; target completion by singles, easy knockout cells, and simple locked rows/columns; require zero fallback search.  
For **Medium**, prefer `8x8`; reduce obvious singletons; allow some contained-region deductions and modest `k-in-k` interactions; still target human completion without contradiction search.  
For **Hard**, use `8x8` and `10x10`; suppress trivial giveaways; increase overlapping row/column spans and multi-region interactions; allow limited contradiction-style hints and modest search telemetry.  
For **Expert**, prefer `10x10`; use `12x12` only as an opt-in large-board mode, not as a default phone experience; minimize giveaways, maximize overlaid allocation logic, and accept that some boards will require stronger contradiction-based explanation. These recommendations are consistent with current one-star/Star Battle difficulty practice, where the same core rules support a wide difficulty spread through board size and region design. citeturn42view0turn41search3

**Board-size defaults for phones.** My strong recommendation is: default to **6x6**, **8x8**, and **10x10**; keep **12x12** behind a clearly labeled Large or Expert mode. Android accessibility guidance recommends about a `48x48dp` touch target, Apple’s HIG recommends about `44x44pt`, and Android’s own docs repeat the 48dp recommendation for touch interfaces. A 12-column board on a narrow phone simply does not give you that much cell width without additional zoom, pan, or an invisible expanded hit target. So yes, `12x12` is feasible, but on many phones it will be technically valid and ergonomically obnoxious. citeturn28search0turn28search1turn28search8

**Human-style hint engine.** Your hint engine should operate on the current candidate graph, not on secret solution coordinates, except as a final fallback. LinkedIn’s tutorial gives you a ready-made ladder: giveaway cells, knockout cells, single-color-in-one-row/column, and multi-color-locked sets. Shaun Shue’s strategy writeup adds strong row/column allocation and overload variants. Use those as the base rule set. If no rule applies, use bounded contradiction search to prove one candidate impossible, and present that proof—not a magical “because the answer key says so.” citeturn25view0turn34view0turn39view0

**Hint priority order.** The least revealing order I recommend is: highlight a constrained region/row/column; explain a forced elimination; explain a region/row/column singleton; explain a knockout cell; explain a locked region-row or region-column interaction; explain a `k`-regions-in-`k`-rows/columns deduction; explain a contradiction-based elimination; reveal a forced queen; and only as a last resort reveal the next queen outright. LinkedIn’s own help says hints may highlight a region where a crown must be placed or indicate incorrect placements, which fits this graduated approach well. citeturn39view0turn25view0

**Player move validation.** Allow exploratory play by default. When a player places a queen that causes a conflict, keep the move but mark the conflict unless the player has enabled a stricter mode. That mirrors LinkedIn’s Auto-check behavior, which highlights rule violations and marks overfull areas with red stripes. Also expose optional Auto-place X’s, because LinkedIn does and because it removes repetitive clerical labor without changing puzzle logic. Keep undo/redo cheap and unlimited for local play. Completion should trigger only when the board satisfies the formal solved-state test, not when all cells are marked. citeturn39view0

**Visual quality and accessibility.** Do not rely on color alone to identify regions or conflicts. WCAG explicitly warns against using color as the sole means of conveying information, and it requires sufficient contrast for text and UI graphics. In practice, that means: use region color plus border outlines; consider subtle patterns or texture variants for color-blind support; keep queen/crown icons high-contrast; use a distinct conflict overlay that is not just “red means bad”; and ensure borders and marks remain legible in dark mode. Distinguished regions should stay readable even in grayscale screenshots, because users share those constantly. citeturn38search0turn37search1turn37search12

**Interaction recommendations.** Single tap should toggle mark-empty, double tap or long-press should place a queen, and a second tap cycle should clear—unless your audience strongly prefers a two-mode toolbar. Highlight the active row, column, and region on focus. When a hint is shown, spotlight the relevant cells and explanation together. On small phones, support pinch-to-zoom or at least a “focus lens” for `10x10` and especially `12x12`. Landscape mode should be available but not required. If you want to avoid LinkedIn-clone vibes, change the iconography, typography, region palette, and hint phrasing while keeping the underlying logic familiar. That is the right kind of derivative: recognizable mechanics, distinct product identity.

**Performance expectations.** With the recommended solver architecture and small board sizes, player-move validation should be essentially constant-time and imperceptible, hint generation should usually be instant if it stays in the rule layer, and solution counting up to 2 should be fast enough for generation-time use on-device. The expensive part is not single-board solving; it is the reject-heavy generator loop for uniqueness and target difficulty. That is why the isolate boundary matters. Benchmark the generator on low-end Android hardware with cold-start and warm-start runs, and record median and p95 for: queen-placement generation, region growth, uniqueness count, difficulty analysis, accepted-attempt count, and repair-step frequency. Flutter’s own docs give you the “why”: if you shove CPU-heavy work onto the main isolate, you will buy yourself jank. citeturn14search0turn14search1turn29search0turn29search2

## Integration, testing, failure modes, and final blueprint

**Serialization and backend integration.** Make the seed the canonical identity, not the board blob. A compact serialized puzzle object should include: puzzle type, schema version, engine version, seed, difficulty profile, size, flattened region map, optional givens, optional local-only solution bitset, numeric difficulty score, and optional solver telemetry. If you want the backend to avoid storing boards and solutions, sync only the seed, engine/profile/version tuple, completion state, elapsed time, streak data, and maybe a puzzle checksum. The client should reconstruct the board locally from `(seed, engineVersion, profile)`. If you cache the generated board or solution on-device for speed, keep that local.

**Testing strategy.** Your test suite should be unapologetically broad. At the unit level, test row, column, region, and diagonal-touch constraints independently and together. Test region partitioning so every cell belongs to exactly one region and region count equals `N`. Test connectivity on generated regions. Test solver behavior on known unique boards, known multi-solution boards, known no-solution boards, and capped-search boards that must return `unknown`, not `unique`. Test seed determinism with fixed seeds across repeated runs and across isolates. Test serialization round-trips. Test hint correctness by proving that each reported hint is sound from the current candidate state, not merely consistent with the hidden solution. Test difficulty classification stability on a fixed seed corpus. Use property-based fuzzing on random seeds to assert invariants such as “accepted puzzle implies exactly one solution” and “moving borders during repair never disconnects a region or steals a seed queen.” Public solver posts and formal models make good external oracles for a regression pack. citeturn10view0turn31view2turn31view3turn30view0turn40view0

**Common bugs and how to catch them.** The classic mistakes are wonderfully repeatable: treating the puzzle like full N-Queens and forbidding all long diagonals; forgetting the one-queen-per-region rule; accepting disconnected or empty regions; producing the wrong number of regions; timing out during uniqueness search and treating that as success; allowing the generator to “prove” uniqueness only because the solver is accidentally biased toward the planted solution; generating regions that are always trivial; generating regions that look like spilled spaghetti; using nondeterministic randomness in one branch of the generator loop; and labeling difficulty solely by board size. The fix is not heroism. The fix is invariant checks, dual-solver regression testing, and a fixed-seed corpus that you never stop rerunning.

**Implementation roadmap.** Build in phases. First, implement the immutable core model and validators; done means the engine can parse, validate, and serialize a puzzle definition and detect all obvious rule violations. Second, implement region representation and connectivity checks; done means you can assert region partition correctness and connectedness on arbitrary maps. Third, implement the queen-placement generator; done means fixed seeds yield deterministic placements and invalid sizes are rejected cleanly. Fourth, implement the connected region generator; done means every generated region map covers the board, contains exactly one seed queen, and passes quality heuristics. Fifth, implement the hybrid solver and capped uniqueness counter; done means it returns `none`, `unique`, `multiple`, or `unknown` correctly on the regression corpus. Sixth, implement the difficulty scorer; done means it produces stable numeric scores and rough profile bands on fixed seeds. Seventh, implement the human-style hint engine; done means every hint is explainable from current candidates and does not require solution leakage except in the explicit last-resort mode. Eighth, implement move validation and undo/redo. Ninth, finalize serialization and isolate integration. Tenth, freeze a regression corpus and benchmark suite before you touch the UI polish. That order is not glamorous, but it is how you avoid rebuilding the foundation while users are already walking around upstairs.

**Open limitations.** Two points are worth stating plainly. First, LinkedIn’s public help page does **not** explicitly say that regions must be contiguous; I still recommend enforcing orthogonal connectivity as a generation and validation rule because it matches common Queens/Star Battle practice and produces better puzzles. Second, there is no public, canonical difficulty taxonomy for LinkedIn Queens beyond tutorial deductions and analogous one-star Star Battle practice, so any difficulty scale you ship must be calibrated empirically against your own content corpus and playtesting. citeturn39view0turn19search2turn36view0turn25view0turn42view0

**Final concise blueprint.**  
Use these rules: one queen per row, column, and connected region; no Chebyshev-neighboring queens; long diagonals allowed; unique solution required.  
Use this queen generator: deterministic seeded row-based DFS with column uniqueness, adjacent-diagonal filtering, and light aesthetic tie-breaking.  
Use this region generator: deterministic multi-source orthogonally connected growth from queen seeds, followed by bounded border smoothing and occasional bounded repair.  
Use this solver: hybrid propagation + MRV DFS with row/column/region candidate accounting, forward checking, and solution counting capped at 2.  
Use this uniqueness strategy: solver-based count-to-2 only; timeout means `unknown`, never `unique`.  
Use this difficulty strategy: hybrid human-rule telemetry plus search telemetry plus morphology metrics; do not rate by size alone.  
Use this hint strategy: rule-based explanations first, contradiction-backed eliminations second, solution reveal last.  
Use this visual strategy: distinct but non-clone presentation, strong borders, color-blind-safe cues, optional auto-place X’s, optional auto-check, and zoom support for large boards.  
Use these mobile defaults: `6x6`, `8x8`, `10x10` as primary sizes; `12x12` opt-in only.  
Use this test strategy: invariant-heavy unit tests, fixed-seed regression packs, property-based fuzzing, independent reference-model cross-checks, and low-end-device benchmarks.  
Biggest risks: false uniqueness, accidental nondeterminism, region shapes that are either trivial or ugly, and difficulty labels that lie.  
What not to do: do not treat this as classic N-Queens, do not store your canonical daily boards or solutions on the backend, do not rely on `dart:math Random` for long-term canonical generation, and do not ship a solver that can solve puzzles but cannot explain them.