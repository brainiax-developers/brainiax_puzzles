# Production Architecture for Brainiax Puzzles Slitherlink Engine

## Identity and executive recommendation

**Puzzle identity and naming.** Slitherlink is a Nikoli loop puzzle in which players connect adjacent dots with horizontal and vertical segments so that the numbered cells have exactly that many incident segments and the final result is a single loop that never crosses or branches. Nikoli’s own English rules use the name **Slitherlink** and specify clue values only from **0 to 3**. Simon Tatham’s implementation calls the puzzle **Loopy**. Other widely used aliases include **Loop the Loop**, **Fences**, and **Takegaki**; Conceptis and other commercial/mobile sources also list names such as Dotty Dilemma, Number Line, Suriza, and Sli-Lin. There is no important rule difference among those names in the standard square-grid form; the main difference is branding, region, or platform vocabulary. citeturn15view0turn13view0turn15view1turn41search3turn41search6turn41search13turn41search5

**Grid scope for a mobile V1.** The standard version is played on square cells arranged in a rectangular board, so both **square boards** like 8×8 and **rectangular boards** like 10×12 are standard enough to support. Tatham’s Loopy also supports triangular, hexagonal, and more exotic tilings, and some mobile apps ship hex/pentagon/mixed grids, but those variants change strategy, topology, and hint logic enough that they should be treated as a different engineering project. For a production mobile V1, you should ship **only the standard orthogonal square-cell variant on rectangular boards** and explicitly defer alternative tilings. citeturn15view0turn13view0turn34view0turn34view2

**App-facing naming recommendation.** Use **Slitherlink** as the primary in-app name. In help text, subtitle it as “also known as Loop the Loop, Fences, and Loopy.” Mention **Takegaki** only in an expanded help/FAQ/SEO section, not on the main menu. The reason is simple: Slitherlink is the clearest canonical name, Loopy is recognizable to players coming from Simon Tatham, and Loop the Loop/Fences are the most common plain-English aliases; Takegaki is real, but less recognizable to mainstream English-language mobile users. That is the rare case where SEO can be right without making the UI look like a thesaurus had a small accident. citeturn15view0turn13view0turn41search3turn41search6turn41search5

**Executive recommendation.** From first principles, the best production architecture for your constraints is:

- a **versioned, deterministic, pure-Dart engine** with a **custom PRNG** implemented inside the engine, not `dart:math Random`, because Dart explicitly warns that the random stream implementation may change between library releases;  
- a **loop-first generator** that synthesizes a valid single target loop by **expanding a simply connected cell region** and taking its boundary, rather than trying to invent clues first;  
- **full clue derivation** from that loop, followed by **deterministic greedy clue removal** with a **uniqueness checker that counts solutions up to 2 and exits early**;  
- a **hybrid exact solver** built around **constraint propagation + rollback DFS**, with early contradiction checks from cell counts, vertex degree rules, and **premature subloop prevention**;  
- a separate **human-style solver layer** for hinting and difficulty telemetry, sitting on top of the exact solver rather than replacing it;  
- a **difficulty system based primarily on solver telemetry**, not just clue count or board size;  
- a **background-isolate generation service**, ideally long-lived for repeated generation, sending compact packed state via typed data. citeturn25search1turn20view1turn20view2turn38view0turn29view0turn19view0turn19view1turn12view1turn23search0turn23search1turn23search2turn23search4turn23search8

**Why this stack wins on mobile.** Loop-first generation is consistently favored in practical Slitherlink generation literature because clue-first random placement struggles to produce unique puzzles even at small sizes, while naive edge-walk loop generation tends to create undersized or poorly covering loops. Separating an exact solver from a human-style rule layer gives you sound generation and uniqueness checking without giving up good hints and difficulty labels. SAT/SMT/ILP/ZDD approaches are extremely useful as reference models and CI oracles, but they are the wrong default runtime dependency for an offline-first, on-device, low-end-phone-focused Flutter app. citeturn20view0turn20view1turn38view0turn21view0turn29view0turn36view0turn18view0

**Ranked tradeoffs.** If you force me to rank the architectural options for your use case, here is the blunt version. First place: **loop-first + exact uniqueness + hybrid solver + human-style overlay**. Second place: **loop-first + SAT/SMT uniqueness checker only in tooling/CI, not in app**. Third place: **rule-only solver with backtracking fallback**. Distant fourth: **random clue-first generation**. Dead last for mobile V1: **ZDD-style exhaustive instance enumeration** or any architecture that depends on precomputed cloud boards, because your constraints explicitly rule out storing boards/solutions in the backend and the published ZDD generation work becomes expensive even around modest sizes. citeturn20view0turn20view1turn12view1turn21view0turn35search9

## Formal model, topology, and data structures

**Formal puzzle model.** Let the published puzzle be a rectangular cell grid of width `W` and height `H`. The vertex lattice then has dimensions `(W + 1) × (H + 1)`. Legal loop segments are exactly the horizontal and vertical edges between orthogonally adjacent vertices. Each cell clue is either hidden or one of `0, 1, 2, 3`, matching Nikoli’s standard rules. The solved state assigns every edge one of two final values, **on** or **off**; the player/solver state assigns every edge one of three values, **unknown**, **on**, or **off**. A solved board is valid if every revealed clue is satisfied, every vertex has degree 0 or 2, at least one edge is on, and all on-edges belong to one connected cycle. A published puzzle is valid if it has **exactly one** solved board under those rules. citeturn15view0turn13view0turn8view1turn19view0turn19view2

**Rule semantics.** The “no branch” rule is equivalent to forbidding vertex degree 3 or 4. The “no dangling ends” rule is equivalent to forbidding vertex degree 1 in a completed solution. The “single loop” rule is global: local degree validity is necessary but not sufficient, because multiple disjoint loops can satisfy all clue counts and every local degree check while still violating the puzzle. That is why every serious exact model for Slitherlink adds an explicit global connectivity mechanism beyond per-cell and per-vertex constraints. citeturn15view0turn19view0turn19view1turn29view0turn36view0turn11view3

**Why clue 4 should not appear.** Nikoli defines standard Slitherlink using only the four numbers 0–3. On a square cell, a clue 4 would force all four sides on. In any board larger than 1×1, that immediately creates a tiny closed cycle whose four vertices are already saturated at degree 2, so it cannot connect to a larger single simple loop. In practice, standard mobile V1 should treat clue 4 as invalid input for the square-cell ruleset. citeturn15view0turn15view0turn19view0

**Recommended topology indexing.** Use a canonical global edge numbering, even if your UI exposes “horizontal” and “vertical” helpers. Let horizontal edges come first, then vertical edges:

- horizontal edge count: `(H + 1) * W`
- vertical edge count: `H * (W + 1)`
- total edge count: `E = 2WH + W + H`
- vertex count: `V = (W + 1)(H + 1)`

Use row-major formulas:

```text
vertexId(x, y) = y * (W + 1) + x

hEdgeId(x, y) = y * W + x
  where 0 <= x < W and 0 <= y <= H

vEdgeId(x, y) = hCount + y * (W + 1) + x
  where 0 <= x <= W and 0 <= y < H

cellId(x, y) = y * W + x
  where 0 <= x < W and 0 <= y < H
```

Use a fixed cell edge order of **N, E, S, W** everywhere: solver, serializer, tests, and UI helper methods. Most Slitherlink bugs are not deep graph theory bugs; they are off-by-one bugs wearing fake glasses. citeturn15view0turn19view3

**Topology maps to precompute once per board size.** For every supported `(W, H)`, build and cache:

- `cellEdges[cell * 4 + dir]`
- `edgeVerts[edge * 2 + end]`
- `edgeCells[edge * 2 + side]`, with `-1` for border on the missing side
- `vertexEdgeOffsets[v]` plus a flat `vertexEdges[]` array in CSR style
- optional `edgeOrientation[edge]`
- optional `edgeLocalX[edge]`, `edgeLocalY[edge]` only if the renderer benefits

This topology is immutable and tiny, so caching by size is an easy win. The 2025 SMT thesis likewise models Slitherlink as an edge-centered data structure with explicit aliasing between squares and surrounding edges, which matches this recommendation. citeturn19view3turn19view2

**Topology builder pseudocode.**

```text
buildTopology(W, H):
    hCount = (H + 1) * W
    vCount = H * (W + 1)
    eCount = hCount + vCount
    vtxCount = (W + 1) * (H + 1)

    cellEdges = Int32Array(W * H * 4)
    edgeVerts = Int32Array(eCount * 2)
    edgeCells = Int32Array(eCount * 2).fill(-1)
    tempVertexLists = [ [] for _ in 0 ..< vtxCount ]

    for y in 0 .. H:
        for x in 0 ..< W:
            e = hEdgeId(x, y)
            a = vertexId(x, y)
            b = vertexId(x + 1, y)
            edgeVerts[2*e] = a
            edgeVerts[2*e + 1] = b
            tempVertexLists[a].add(e)
            tempVertexLists[b].add(e)
            if y > 0: edgeCells[2*e] = cellId(x, y - 1)
            if y < H: edgeCells[2*e + 1] = cellId(x, y)

    for y in 0 ..< H:
        for x in 0 .. W:
            e = vEdgeId(x, y)
            a = vertexId(x, y)
            b = vertexId(x, y + 1)
            edgeVerts[2*e] = a
            edgeVerts[2*e + 1] = b
            tempVertexLists[a].add(e)
            tempVertexLists[b].add(e)
            if x > 0: edgeCells[2*e] = cellId(x - 1, y)
            if x < W: edgeCells[2*e + 1] = cellId(x, y)

    for y in 0 ..< H:
        for x in 0 ..< W:
            c = cellId(x, y)
            cellEdges[4*c + 0] = hEdgeId(x, y)       // N
            cellEdges[4*c + 1] = vEdgeId(x + 1, y)   // E
            cellEdges[4*c + 2] = hEdgeId(x, y + 1)   // S
            cellEdges[4*c + 3] = vEdgeId(x, y)       // W

    flatten tempVertexLists into CSR arrays
    return Topology(...)
```

**Topology correctness tests.** Test the formulas and maps before you write any solver logic. For every cell, the four `cellEdges` must point back to that cell through `edgeCells`. For every edge, its endpoints must both list that edge in the corresponding vertex incidence list. Border edges must have exactly one incident cell; interior edges must have exactly two. The sum of all cell-side incidences must equal `4WH`; the sum of all vertex-edge incidences must equal `2E`. These are excellent property-based invariants. citeturn15view0turn19view3

**Dart-friendly data structures.** Use fixed-length typed arrays for the hot path. `Uint8List` is explicitly more space- and time-efficient than plain `List` for long numeric arrays, and its fixed-length contiguous storage is a better fit for a solver/generator core. Use `Uint8List` for edge states, clue values, and per-cell/per-vertex counters when the ranges fit in a byte. Use `Int16List`/`Uint16List` or `Int32List` for topology IDs if you implement this in code; if you want to stay very conservative in public API types, expose `int` while storing internally in typed arrays. Use `ByteData` only where you need packed binary serialization or reinterpretation. citeturn24search0turn24search1turn24search6

**Concrete storage recommendation.** Store edge state in one `Uint8List edgeState` of length `E`, with values `0=unknown`, `1=on`, `2=off`. Store published clues in one `Uint8List clues` of length `W*H`, using `255` for hidden; also keep `fullClues` during generation if needed. Store mutable per-cell counters `cellOnCount`, `cellUnknownCount`; per-vertex counters `vertexOnCount`, `vertexUnknownCount`; and a `Uint32List dirtyQueue` or plain `List<int>` deque if your queue code is simpler. Keep immutable topology in cached typed arrays shared by all boards of the same size. This is simpler and safer than a forest of small edge objects. citeturn24search0turn24search1

**Mutable state with undo beats cloned boards.** For search, use mutable arrays plus an undo stack, not full-state cloning at every branch. Rollback search is the standard choice because Slitherlink solving repeatedly applies small local changes and then backs them out. Board cloning is easier to write but becomes a maintenance and performance tax once you add generation, uniqueness checking, and difficulty telemetry. Cloning still has a place for UI snapshots and last-known-unique checkpoints in the generator. citeturn12view1turn29view0turn36view0

**Bitsets: use surgically, not religiously.** If profiling later shows it helps, bitsets are useful for masks such as “unknown edges adjacent to this cell” or “dirty vertices,” but they should not be your primary engine representation in V1. Slitherlink boards in the mobile-friendly range are small enough that clarity matters more than micro-optimizing every branch predictor sneeze. The engine will live longer if a new contributor can read it without bargaining with a bit twiddler at midnight. citeturn24search0turn24search6

**Deterministic PRNG requirement.** Do **not** rely on `dart:math Random(seed)` for persistent cross-version determinism, because the Dart API explicitly says the implementation of the random stream can change between releases. If “same seed + same parameters = same puzzle” is a shipped guarantee, use a custom PRNG embedded in your engine and version it as part of puzzle identity. Also pin tie-break orders, clue-removal iteration order, and branch heuristics to canonical deterministic orders. citeturn25search1

**Metadata to store with a generated puzzle.** At minimum store: puzzle type, ruleset version, engine version, generator profile ID, PRNG/version ID, seed, width, height, published clues, difficulty label, numeric difficulty score, generation telemetry, and optionally a local cached solution or solution checksum. If the board is reproducible from seed plus profile plus engine version, that triple becomes the real puzzle identity; the clue matrix is then a derived artifact you can cache locally, not something the backend has to warehouse forever. citeturn25search1turn23search2

## Algorithm survey and preferred engine architecture

**Established landscape.** Slitherlink is not a toy problem algorithmically. Standard and common graph variants are NP-complete, and the “another solution” problem is ASP-complete, which also implies counting solutions is hard in the worst case. So production design should assume that exact solving and uniqueness checking can become exponential and should be bounded, profiled, and instrumented accordingly. That does not make on-device solving impossible; it just means you should build for robust *typical-case* performance and sound fallbacks instead of pretending worst cases do not exist. citeturn26search1turn35search0turn35search7

**Loop-first generation.** In loop-first generation, you first synthesize a valid single loop, then derive full clues, then remove clues while preserving uniqueness. This is the most practical family for mobile Slitherlink. Both the 2021 and 2025 Radboud theses converged on loop-first generation after finding clue-first approaches poor or infeasible, and open-source generators like Slinker also center the workflow around generated loops, rules, uniqueness, and hints. citeturn20view0turn20view1turn38view0turn12view1turn33view0

**Clue-first generation.** In clue-first generation, you place some clues and ask a solver whether the result has a unique loop. The appeal is obvious: if it works, you skip some clue-removal work. The problem is that it scales badly and tends to generate uninteresting or overly direct puzzles unless clue distributions are heavily engineered. The 2025 SMT thesis reports that random clue placement with uniqueness testing was already unable to find unique 7×7 puzzles within 1000 attempts. For your constraints, clue-first should be treated as a research branch or offline tool, not the production default. citeturn20view0turn40view0

**Random edge-walk loop synthesis.** A naive edge random walk tries to grow a path and reconnect it into a loop. In practice this produces small loops, failed reconnections, or loops that cover too little of the board. Both the 2021 and 2025 theses report this general problem, and the 2025 thesis specifically notes that DFS-like search often found loops that covered only a fraction of the grid. This approach is fine for prototypes and terrible for shipped quality. citeturn20view1turn38view0

**Region-coloring and inside/outside generation.** An alternative view is that the loop is the boundary between inside and outside regions. Liam Appelbe’s write-up makes this especially clear: if two orthogonally contiguous regions define the boundary, then the line inherits the single non-branching path property from the partition. Jonathan Olson’s solving guide likewise emphasizes inside/outside coloring as a powerful global representation for Slitherlink reasoning. This viewpoint is extremely useful both for generation and for an advanced human-style hint layer. citeturn12view0turn12view2turn8view0

**Production recommendation on loop synthesis.** For mobile V1, the best synthesis method is not truly “random walk” and not truly “freeform region coloring.” It is a **cell-region expansion algorithm**: start from a small simply connected inside region, repeatedly absorb adjacent cells using deterministic seeded choice and shape scoring, and take the region boundary as the loop. This is equivalent to growing a loop by local rewrite moves, preserves single-loop validity by construction, and naturally supports tuning for coverage and aesthetics. It is the cleanest production compromise among the approaches described above. citeturn20view1turn38view0turn17view0turn12view0

**Full clue generation plus clue removal.** Once a target loop exists, clue derivation is trivial and exact. The real generation problem becomes clue removal under uniqueness and difficulty constraints. This pattern is shared across the practical literature and open-source tools because it gives you a known valid solution before the hard part starts. It also gives you a precise target for diagnostics when uniqueness fails. citeturn12view0turn20view2turn38view0

**Greedy clue removal.** Greedy one-clue-at-a-time removal with uniqueness checks is the right baseline because it is deterministic, debuggable, and easy to repair after ambiguity appears. The 2021 and 2025 theses both use this general removal idea. Slinker’s open-source notes also point to the next natural refinement: instead of removing clues randomly, remove ones that preserve or increase rule complexity. That is exactly the right direction once the baseline works. citeturn38view0turn20view2turn20view3turn33view0

**Batch removal and binary-search-style removal.** Batch removal can speed up large boards because it reduces expensive exact uniqueness checks. However, it makes failure diagnosis worse, because when a batch breaks uniqueness you do not know which clue caused the ambiguity. Binary search is not a natural fit for clue removal because uniqueness and difficulty are not monotone with respect to any simple clue ordering; removing clue X after removing clue Y is not the same as removing X first. So batch removal is acceptable only as a bounded optimization pass before a final exact greedy phase, and binary search should not be a first-line strategy here. citeturn20view3turn38view0

**Constraint programming, SAT, SMT, and ILP.** These are excellent *reference formulations* of Slitherlink. The OptiLog paper shows a SAT encoding with vertex degree constraints, per-cell exact-count constraints, and an incremental cycle-management loop that forbids extra cycles until exactly one remains. The 2025 and 2021 theses show SMT encodings using reachability/order labeling to enforce one-loop connectivity. The ILP write-up shows a subtour-elimination loop that repeatedly solves, finds multiple loops, and adds cuts. These are all sound and useful, especially in CI, solver verification, and offline corpus generation. They are just not the first thing I would put in the runtime dependency graph of a low-end offline mobile game. citeturn29view0turn19view1turn11view0turn11view1turn36view0

**ZDD and exhaustive instance enumeration.** The ZDD work is intellectually beautiful and useful for designer assistance, instance enumeration, and studying minimal clue sets, but it is not a sensible on-device runtime strategy for your app. The paper reports billions of good instances for one 5×7 setup and also reports an 8×8 case that could not finish in a day when all 64 cells were candidate hint locations. That is spectacular research and spectacularly misaligned with low-end-phone generation. citeturn21view0turn35search9

**Union-find and graph checking.** Union-find is a good runtime helper for exact solving because it supports fast component tracking and early prevention of premature subloops. But union-find alone is not a full solver. It must be paired with cell and vertex bookkeeping and a final explicit loop validation pass, because local connectivity tracking cannot replace global clue satisfaction or final graph traversal. citeturn19view0turn36view0turn29view0

**Plain DFS vs propagated DFS.** Plain DFS over edge states is correct but wasteful. A propagated DFS that immediately applies cell saturation, vertex degree, and subloop-prevention rules after each assignment is the production choice. Academic SAT/SMT encodings effectively do the same thing with clause propagation and global constraints; in your pure-Dart engine, do it directly with mutable arrays and a work queue. citeturn29view0turn19view0turn19view2

**Pattern-based and human-style solvers.** Human-style Slitherlink solving relies on reusable local and semi-global deductions: 0-cells, adjacent 0/3, adjacent 3s, diagonal 3s, corner logic, path continuation, avoiding separate loops, parity, sectors, and inside/outside coloring. Conceptis explicitly stages solving into starting, basic, and advanced techniques, and Olson pushes further into parity/sector/coloring tools. This is the right foundation for a hint engine and for difficulty telemetry. It is *not* enough by itself for sound uniqueness checking unless you intentionally allow “unknown” results. citeturn8view1turn9view0turn8view0

**Best production solver architecture.** Use **two layers**. Layer one is the **exact core solver**: generic local propagation plus DFS plus rollback, capable of `0/1/2+` solution counting and definitive completion validation. Layer two is the **human-style reasoning layer**: explicit logical rules grouped by difficulty, capable of step explanations and telemetry. The human layer calls the exact core only for bounded contradiction hints or to certify that a proposed hint is entailed by the current state. That split is the single most important architecture decision in this whole report. It prevents hint quality from contaminating correctness and prevents exact generation logic from being held hostage by how elegant a hint sentence sounds in English. citeturn12view1turn33view0turn8view1turn8view0turn20view3

## Generation pipeline and difficulty system

**Recommended loop synthesis algorithm.** Generate the target solution by growing a simply connected region of cells and taking its boundary as the loop. Start from one random seed cell chosen by your custom PRNG. At each step, consider frontier cells adjacent to the current region, score them deterministically, and absorb one using a seeded tie-break. Update the boundary by XOR-ing the absorbed cell’s perimeter against the current boundary. Because the region remains connected and hole-free under this growth rule, the boundary remains a single, non-self-intersecting loop. This is the same core intuition behind “start with a small loop and expand it” approaches reported in the 2021 and 2025 theses and in Slinker’s growth-rule system. citeturn20view1turn38view0turn17view0

**Shape controls that matter.** Score candidate expansions using production-friendly heuristics: reward interior coverage and loop length; penalize long straight border runs; penalize extreme border hugging; penalize very short isolated wiggles; reward closing large empty deserts; and optionally steer clue entropy by estimating the resulting local clue distribution after hypothetical absorption. The literature shows why this matters: small or sparse loops require denser clues or lots of zeroes to stay unique, and they are usually less interesting. citeturn20view1turn38view0

**Loop synthesis pseudocode.**

```text
synthesizeLoop(W, H, rng, profile):
    inside = { chooseSeedCellDeterministically(rng, W, H) }
    boundary = perimeterEdgesOfSingleCell(seed)
    frontier = orthogonalNeighbors(seed) \ inside

    while true:
        candidates = []
        for cell in frontier:
            if canAbsorb(cell, inside):
                newBoundary = boundary XOR perimeterEdges(cell)
                score = shapeScore(newBoundary, cell, profile)
                candidates.add((cell, score, newBoundary))

        if candidates.isEmpty: break

        chosen = deterministicWeightedChoice(candidates, rng)
        inside.add(chosen.cell)
        boundary = chosen.newBoundary
        frontier.remove(chosen.cell)
        frontier.addAll(neighbors(chosen.cell) \ inside)

        if reachedProfileLoopTarget(boundary, inside, profile):
            if rng.nextBoolWithProfileBias(profile.stopBias): break

    boundary = applyBoundedSmoothingRewrites(boundary, rng, profile)
    return boundary
```

**Clue derivation.** Once the loop is known, derive the full clue matrix by counting on-edges around each cell in canonical `N,E,S,W` order. This is exact and deterministic. Rows should be serialized in row-major order with a single canonical hidden-clue sentinel. You should not store clues as strings inside the engine core unless you enjoy spending future weekends converting integers back out of decorative punctuation. citeturn15view0turn19view3

**Clue derivation pseudocode.**

```text
deriveFullClues(topology, solutionEdgesOn):
    clues = Uint8List(W * H)
    for each cell c:
        count = 0
        for dir in [N, E, S, W]:
            e = topology.cellEdges[4*c + dir]
            if solutionEdgesOn[e]: count += 1
        clues[c] = count
    return clues
```

**Clue removal strategy.** Start from the full clue matrix. Attempt clue removals one at a time in a deterministic, seeded order. Every attempted removal must be checked by the exact solver with a solution cap of 2. If the solver proves exactly one solution and the puzzle remains inside the target difficulty envelope, keep the clue hidden. If the solver finds 0 or 2+ solutions, restore it. If the solver times out or hits a search cap, treat the result as **unknown** and restore it for production generation. That “unknown is not unique” rule is non-negotiable. citeturn20view2turn20view0turn38view0

**Why deriving clues from a generated loop is not enough.** A valid target loop only proves that the clue set has *at least one* solution. It says nothing about uniqueness once clues are hidden. The ZDD paper is a dramatic demonstration of that fact: a single solution cycle can admit a very large family of distinct good clue subsets and minimal clue sets. So “I generated the loop first” is not a uniqueness proof any more than “I bought a lock” is a proof that you shut the door. citeturn21view0turn20view0

**Which clues to try removing first.** Use a deterministic priority function, not pure shuffle. Good removal candidates are clues in redundant local clusters, clues far from current ambiguity hotspots, and clues whose removal does not isolate a large clue-free region. Be cautious around clue islands, corners of strong local structure, and cells adjacent to many ambiguous edges. The 2025 SMT thesis explicitly argues that clue deletion can be improved by restricting which clues are considered and by prioritizing clues surrounded by neighboring clue cells. citeturn20view3

**Avoid trivial-looking but bad clue sets.** Fewer clues does not automatically mean better difficulty. Dense but well-chosen clues can create elegant deductions; sparse but badly distributed clues can create guessy sludge. You should actively avoid puzzles dominated by trivial 0/3 starts, avoid giant blank oceans, and avoid clue islands that contribute nothing until late global search. Conceptis’s technique catalog and Olson’s parity/coloring write-up both underline how much Slitherlink solving depends on the *structure* of clue interactions, not just clue count. citeturn8view1turn9view0turn8view0

**Greedy clue removal pseudocode.**

```text
removeClues(fullClues, targetLoop, profile, rng, timeout):
    clues = fullClues.copy()
    bestUnique = clues.copy()
    order = prioritizedCells(clues, profile, rng)

    for cell in order:
        if timeout.exceeded(): break
        saved = clues[cell]
        clues[cell] = HIDDEN

        result = exactCountSolutions(clues, limit=2, cap=profile.uniquenessCap)
        if result.kind == UNIQUE:
            diff = rateDifficulty(clues, profile)
            if withinTargetBand(diff, profile):
                bestUnique = clues.copy()
                continue

        clues[cell] = saved

    return bestUnique
```

**Bounded repair for non-unique puzzles.** When a removal attempt introduces multiple solutions, capture the first two distinct solutions from the exact solver, compute their symmetric difference, and identify cells adjacent to those differing edges. Hidden clues near that ambiguity region are your first restoration candidates. Restore one or a few clues, re-run uniqueness, and stop after a bounded number of repair steps. If repair fails, revert to the last unique state or restart clue removal from that checkpoint. This approach preserves as much of the current puzzle as possible while keeping the generator deterministic and bounded. citeturn20view0turn20view2turn33view0

**Bounded repair pseudocode.**

```text
repairAmbiguity(clues, fullClues, solA, solB, maxRestores):
    diffEdges = [e where solA[e] != solB[e]]
    candidates = hiddenCellsAdjacentTo(diffEdges)

    ranked = sortBy(
        candidates,
        key = ambiguityCoverageThenClueStrength(fullClues[cell], diffEdges)
    )

    restored = 0
    for cell in ranked:
        clues[cell] = fullClues[cell]
        restored += 1

        result = exactCountSolutions(clues, limit=2, cap=repairCap)
        if result.kind == UNIQUE:
            return SUCCESS
        if restored >= maxRestores:
            break

    return FAILURE
```

**Full generator loop.** The generator should accept `(W, H, difficultyProfile, seed, optionalTimeout)` and produce either a puzzle or a deterministic failure code. Each retry must be deterministically derived from the input seed, such as by advancing the generator PRNG or hashing `(seed, retryIndex, profileVersion)`. Do not call wall-clock time, global RNGs, or collection iteration with unspecified order inside the generation logic. The engine must be boring in exactly the way production engineers grow to love. citeturn25search1turn23search0

```text
generatePuzzle(params):
    rng = EnginePrng(params.seed, params.profileVersion)

    lastUniquePuzzle = null
    for attempt in 0 ..< params.profile.maxAttempts:
        if timeoutExceeded(): return TIMEOUT_OR_FALLBACK(lastUniquePuzzle)

        loop = synthesizeLoop(params.W, params.H, rng.fork(attempt), params.profile)
        fullClues = deriveFullClues(topology(params.W, params.H), loop)

        clues = removeClues(fullClues, loop, params.profile, rng.fork(attempt ^ 0x9E37), timeout)
        verify = exactCountSolutions(clues, limit=2, cap=params.profile.finalUniquenessCap)

        if verify.kind != UNIQUE:
            repaired = tryRepair(clues, fullClues, verify.solA, verify.solB, params.profile)
            if repaired:
                verify = exactCountSolutions(clues, limit=2, cap=params.profile.finalUniquenessCap)

        if verify.kind == UNIQUE:
            difficulty = rateDifficulty(clues, params.profile)
            if acceptDifficulty(difficulty, params.profile):
                return buildPuzzleArtifact(...)
            lastUniquePuzzle = maybeKeepClosestDifficulty(...)

    return deterministicFallback(lastUniquePuzzle, params.profile)
```

**Fallback policy.** If target difficulty cannot be hit quickly, do not keep grinding forever on low-end phones. Your fallback policy should prefer: same seed and size, slightly easier/harder clue envelope, then one smaller board size, then return a generation failure the UI can handle gracefully. Flutter explicitly recommends moving heavy computation off the main isolate because expensive work can make the app unresponsive, and compute/isolate use is the proper way to avoid that. citeturn23search0turn23search1turn23search6turn23search8

**Difficulty rating architecture.** Use a **hybrid** model:

- **generator parameters** only as an initial target,
- **human-style solver telemetry** as the main label source,
- **exact solver search metrics** as a safety backstop.

This split is important because uniqueness does not guarantee human solvability, a point the 2021 and 2025 theses both note explicitly or implicitly, and Slinker’s own future-work notes point toward rating by max/average rule level and need for advanced rules. citeturn38view0turn20view3turn33view0

**Difficulty signals that matter.** Use at least these features: board size, total clue density, clue histogram, clue spacing, loop length, number of assignments forced by local rules, number forced by global rules, propagation rounds, ratio of local to global deductions, maximum contradiction depth needed by the human-style layer, exact-solver search nodes, exact-solver max depth, and whether the human-style layer solved the puzzle without speculative guessing. Conceptis explicitly distinguishes advanced Slitherlink from easier puzzles by the need for recursive look-ahead, and Olson shows that parity, sectors, and coloring add a real qualitative jump in reasoning depth beyond starter patterns. citeturn8view1turn9view0turn8view0turn33view0

**Practical scoring rubric.** Weight rule applications rather than just counting them. A useful production formula is:

```text
score =
  sizeTerm
  + 1 * trivialCellVertexMoves
  + 2 * basicPatternMoves
  + 4 * pathContinuationAndSubloopMoves
  + 6 * parityOrColoringMoves
  + 10 * contradictionDepth1Moves
  + 18 * contradictionDepth2PlusMoves
  + 0.02 * exactSolverSearchNodes
  + 8 * maxHumanReasoningTier
  + ambiguityPenalty
```

Then label by bands *after calibration*. A reasonable starting point is:

- **Easy**: human-style solver completes with only trivial/basic rules, no contradiction search.
- **Medium**: requires path/subloop logic and a few nontrivial patterns, no contradiction search.
- **Hard**: requires parity/coloring/global cuts or very limited depth-1 contradiction.
- **Expert**: requires repeated global reasoning, contradiction search, or significant exact-solver branching.

This is a recommendation, not a published standard, but it is aligned with the way practical engines and published solving guides distinguish hard from easy. citeturn8view1turn9view0turn8view0turn33view0

**Calibration advice.** Do not lock the thresholds on day one. Generate a few thousand puzzles across sizes, record telemetry, hand-solve a representative sample, and then adjust thresholds so the median solve experience matches your label. Keep historical calibration data versioned. If you change thresholds later, do not silently relabel already published daily puzzles unless you enjoy support emails that read like philosophy. citeturn20view3turn33view0

**Recommended generation profiles.** As a mobile-first starting point:

| Label | Recommended sizes | Target clue density | Solver target | UX note |
|---|---|---:|---|---|
| Easy | 5×5, 6×6 | 40–55% | no contradiction search; mostly local rules | no zoom needed |
| Medium | 6×6, 8×8, 6×8 | 30–45% | local + path/subloop + some pattern chaining | zoom optional on small phones |
| Hard | 8×8, 10×10, 8×10 | 22–35% | parity/coloring or shallow contradiction | zoom useful |
| Expert | 10×10, 12×12, 10×12 | 16–28% | repeated global reasoning and/or bounded contradiction search | zoom expected |

These are recommended starting bands, not laws of nature. They intentionally stay smaller than the upper sizes seen in some commercial apps because phone usability matters more than theoretical maximum board area. Conceptis ships up to 16×22 and Simon Tatham’s ecosystem supports massive on-demand boards, but both also provide zoom or small-screen accommodations, which is exactly the point: big boards are possible, just not ideal as mobile defaults. citeturn34view2turn22search8turn13view0turn15view1

**Board-size recommendation.** Ship 5×5, 6×6, 8×8, 10×10, and one or two rectangular sizes such as 6×8 and 10×12. Support 12×12 only for tablets or “expert with zoom.” Avoid making 12×16 or 16×22 mainstream phone defaults in V1. They are playable, but they are cramped, slower to generate for strict uniqueness, and more likely to push players into pinch-zoom fatigue than into delight. citeturn34view2turn22search8turn13view0

## Solving, validation, hinting, and play UX

**Exact solver responsibilities.** Your exact solver must be able to determine existence of a solution, count solutions up to at least 2, stop early after the second, validate a completed board, validate a single move for immediate contradictions, and emit diagnostics for generation rejection. The Copris solver, OptiLog SAT example, and the SMT theses all separate “find a solution” from “check multiplicity,” which is the right production mental model. citeturn18view0turn20view0turn29view0

**Core propagation rules.** Implement these generic rules first:

- **Cell contradiction**: `on > clue` or `on + unknown < clue`.
- **Cell saturation**: if `on == clue`, all remaining unknowns are off.
- **Cell fill**: if `on + unknown == clue`, all remaining unknowns are on.
- **Vertex contradiction**: `on > 2` or `on == 1 && unknown == 0`.
- **Vertex saturation**: if `on == 2`, all remaining unknowns are off.
- **Vertex continuation**: if `on == 1 && unknown == 1`, that unknown is on.
- **Vertex zero**: if `on == 0 && unknown == 1`, that unknown is off.
- **Premature cycle prevention**: disallow an on-edge assignment that closes a cycle unless it would complete the full final loop.

These rules are direct consequences of the official puzzle rules and of the degree-0-or-2 formulation used in exact encodings. citeturn15view0turn8view1turn19view0turn19view2turn29view0

**Constraint propagation pseudocode.**

```text
propagate(state):
    while dirtyCells or dirtyVertices:
        while dirtyCells:
            c = popDirtyCell()
            if !propagateCell(c, state): return CONTRADICTION

        while dirtyVertices:
            v = popDirtyVertex()
            if !propagateVertex(v, state): return CONTRADICTION

        if !propagateNoPrematureSubloops(state): return CONTRADICTION

    return OK
```

```text
propagateCell(c, st):
    clue = st.clues[c]
    if clue == HIDDEN: return true

    on = st.cellOnCount[c]
    unk = st.cellUnknownCount[c]

    if on > clue: return false
    if on + unk < clue: return false

    if on == clue:
        setAllUnknownCellEdgesOff(c)
    else if on + unk == clue:
        setAllUnknownCellEdgesOn(c)

    return true
```

```text
propagateVertex(v, st):
    on = st.vertexOnCount[v]
    unk = st.vertexUnknownCount[v]

    if on > 2: return false
    if on == 1 and unk == 0: return false

    if on == 2:
        setAllUnknownVertexEdgesOff(v)
    else if on == 1 and unk == 1:
        setLastUnknownVertexEdgeOn(v)
    else if on == 0 and unk == 1:
        setLastUnknownVertexEdgeOff(v)

    return true
```

**Applying an edge assignment.** Every `setEdge(e, value)` operation should update exactly four local structures: the edge state itself, the two incident vertices’ `on/unknown` counters, the one or two incident cells’ `on/unknown` counters, and the union-find or component metadata if `value == on`. Push all changes onto the undo stack in a single frame so branch rollback is trivial and bug-resistant. If you spread state changes across helper methods without frame discipline, you are basically writing your own bug bounty program. citeturn19view0turn29view0

**Premature subloop prevention.** If the current on-edge graph under degree constraints consists only of paths and possibly cycles, then an on-assignment that connects two vertices already in the same active component closes a cycle. That move is legal **only** if it completes the final full solution. In all earlier states it creates a forbidden separate loop because no later edge can attach to the closed component without breaking degree 2. Use DSU/component metadata to detect this quickly during search. Exact SAT/ILP methods enforce the same principle via cycle cuts or connectivity constraints; your runtime solver should do it incrementally. citeturn36view0turn29view0turn19view1

**Branching heuristic.** When propagation reaches a fixed point, choose the next edge by “pressure,” not by raw index. A good score is the sum of: number of adjacent revealed clues, tightness of those clues, and saturation of the incident vertices. Canonical tie-break by edge ID so search is deterministic. Do not bias branch order with knowledge of the generated target solution during uniqueness checks, because that can hide bugs and make multiple-solution puzzles look unique under a broken or capped search. citeturn20view0turn35search0

**Counting solutions up to 2.** The generator only needs to distinguish `0`, `1`, and `2+` solutions. That means the solver should stop after the second complete valid solution. This is both correct and practically necessary because full solution counting is hard in the worst case. Return enum values such as `NONE`, `UNIQUE`, `MULTIPLE`, and `UNKNOWN` where `UNKNOWN` means a timeout or cap prevented a sound conclusion. citeturn20view0turn35search0

**Solution-count pseudocode.**

```text
countSolutions(puzzle, limit = 2, cap):
    st = initState(puzzle)
    if applyInitialFacts(st) == CONTRADICTION: return NONE
    if propagate(st) == CONTRADICTION: return NONE
    return search(st, limit, cap)
```

```text
search(st, limit, cap):
    if cap.exhausted(): return UNKNOWN
    if st.unassignedEdges == 0:
        return UNIQUE if validateComplete(st) else NONE

    e = chooseBranchEdge(st)
    found = 0
    sols = []

    for value in branchOrder(e, st):   // canonical, no hidden-solution bias
        frame = st.beginUndoFrame()
        if setEdge(e, value, st) and propagate(st) != CONTRADICTION:
            r = search(st, limit - found, cap)
            if r == UNKNOWN:
                st.rollback(frame)
                return UNKNOWN
            found += r.solutionCount
            sols.addAll(r.solutions)
            if found >= limit:
                st.rollback(frame)
                return MULTIPLE(firstTwoSolutions(sols))
        st.rollback(frame)

    if found == 0: return NONE
    return UNIQUE(oneSolution(sols))
```

**Single-loop verification for a completed board.** Final validation should not rely only on local checks. The correct algorithm is: verify all revealed clues; verify each vertex has degree 0 or 2; ensure at least one on-edge exists; pick one on-edge component and traverse it; verify that traversal reaches every on-edge exactly once up to cycle structure; reject if any on-edge remains outside the visited component. Local degree validity does not rule out multiple disjoint loops. This distinction is the graveyard where many naive validators go to become regression tests. citeturn15view0turn19view0turn19view2turn36view0

**Completed-board validator pseudocode.**

```text
validateComplete(board):
    if any edge is UNKNOWN: return false

    for each revealed cell c:
        if countOn(cellEdges(c)) != clue[c]:
            return false

    onEdges = [e | board[e] == ON]
    if onEdges.isEmpty: return false

    for each vertex v:
        deg = countOn(vertexEdges(v))
        if deg != 0 and deg != 2:
            return false

    startV = any endpoint of any on-edge
    visitedEdges = dfsThroughOnEdges(startV)

    return visitedEdges.count == onEdges.count
```

**Move validation.** Single-move validation should compute **immediate contradictions**, not omniscient future impossibility. When a player turns an edge on, off, or clears it, recompute affected local cells and vertices, and optionally run the subloop-prevention check if the new value is on. Return a structured result like:

- `ok`
- `localConflict`
- `prematureSubloop`
- `completesPuzzle`
- `solved`

This is enough for responsive UI feedback without forcing every tap through a full exact solve. citeturn15view0turn8view1turn9view0

**Human-style hint engine.** The hint engine should use a curated rule stack, not naked solution reveal. Start with the exact current player state. Run human-style rules from least revealing to most revealing. Only if no rule fires should you call bounded contradiction search; only if that still fails should you offer an explicit edge reveal. Slinker’s capabilities list explicitly combines rules, uniqueness, and hints, while Conceptis and Olson provide a practical taxonomy of solvable deduction families from local starters through global coloring and contradiction. citeturn33view0turn8view1turn9view0turn8view0

**Recommended hint priority order.**

1. cell already complete → mark the rest off  
2. cell forced fill → mark remaining edges on  
3. vertex degree 2 → mark others off  
4. vertex has one on-edge and one unknown left → force on  
5. corner and border starters: 0, 1, 2, 3  
6. adjacent 0/3, adjacent 3s, diagonal 0/3, diagonal 3s  
7. path continuation and branch avoidance  
8. avoid separate loop  
9. sector/parity/inside-outside coloring deductions  
10. bounded contradiction hint  
11. reveal one exact edge state as last resort

This ordering mirrors known Slitherlink teaching progressions and preserves player agency. citeturn8view1turn9view0turn8view0

**Hint correctness requirement.** Every generated hint should be verifiable from the current puzzle state. If your hint system relies only on the hidden target solution, it can accidentally hide generator bugs, mislabeled difficulty, or even multi-solution defects. Use the exact solver to verify that the hinted move is entailed by the current state whenever the human-style rule layer is uncertain. That is slower than cheating and much faster than shipping a lie. citeturn20view0turn20view3turn33view0

**Player interaction recommendation.** Support three edge actions: line on, X/off, clear. Support both tap-cycle and drag drawing. Drag should work across consecutive collinear edges and, optionally, across uniquely forced continuations. Simon Tatham’s Loopy exposes auto-following of unique paths, and commercial apps commonly expose auto-complete / highlight tools and segment-highlighting aids to avoid separate loops. Those are good optional assists, not bad manners. citeturn13view0turn34view2turn34view0

**Assist modes.** I recommend three toggles or presets:

- **Relaxed**: allow any move, no mistake highlighting.
- **Assisted**: highlight immediate local and premature-subloop conflicts, but do not block the move.
- **Tutorial**: reject impossible local moves and auto-mark trivial Xs / auto-complete clue closures.

This matches the reality that some players want pure logic, others want guardrails, and your engine should support both without splitting into two codebases that eventually stop speaking to each other. citeturn13view0turn34view2turn8view1

**Undo/redo and completion.** Undo and redo should be unlimited and action-based. Completion detection should run after every move by testing fast local solved preconditions first and the full final validator second. Optional mistake counters are fine for challenge modes but should not be welded into the puzzle logic itself. Several leading mobile implementations advertise unlimited undo/redo and puzzle checking as core UX features, which is unsurprising because logic-puzzle players value reversibility more than fake drama. citeturn34view2turn34view0

**Visual and touch recommendations.** Use thick visible lines with larger invisible hit boxes. Flutter’s accessibility guidance says tap targets should be large enough, citing 48×48 dp on Android and 44×44 pt on iOS, and Apple’s guidelines likewise recommend at least 44×44 points for touchable controls. On dense boards, this means the rendered line can be visually thin while the tappable corridor around it is much larger. Use color plus shape differences for accessibility: line on = thick stroke, line off = X mark, unknown = empty faint guide. citeturn30search2turn30search5turn30search7turn30search13

**Board rendering specifics.** Render dots above faint grid guides; keep clue numerals large and high-contrast; highlight the active edge or drag path; use subtle conflict highlighting on affected cells/vertices; and reserve saturated colors for actual line state, not decoration. For 10×10 and above on phones, support pinch-to-zoom or quick zoom; commercial Slitherlink apps and the Simon Tatham Android port both explicitly provide zoom-oriented accommodations for small screens. Portrait should be the default on phones; landscape is optional on tablets and larger devices. citeturn34view2turn22search8turn34view0

**Haptics and animation restraint.** Use short haptics for confirmed line placement, a softer different haptic for X placement, and maybe a muted error vibration for immediate contradictions in assisted mode. Keep animations restrained: tiny fade/scale transitions are fine; over-animated lines are not. This is a logic puzzle, not a fireworks permit loophole. citeturn30search25turn30search14

## Performance, serialization, testing, roadmap, and blueprint

**Complexity reality.** Exact solving and uniqueness checking are exponential in the worst case because Slitherlink is NP-complete and “find another solution” is also hard. In practice, though, mobile-sized boards are small in memory terms, so performance is dominated by solver search behavior, clue-removal loops, and repeated uniqueness checks—not by storage. The 2021 thesis reports that repeated remove-and-recheck generation grows rapidly with board size, reaching minutes for larger boards under Z3-based generation, which is exactly why on-device production needs lighter-weight exact search than generic SMT at runtime. citeturn26search1turn35search0turn38view0

**Practical performance budget.** For a phone-first offline app, I recommend these approximate budgets: easy/medium generation should usually complete in under one second in a background isolate; hard should usually complete in two to four seconds; expert should be bounded by a visible timeout and fallback strategy. Hint latency should feel instant, ideally under 16–50 ms for local hints and under 100–200 ms for bounded contradiction hints. Final validation should be effectively immediate. These are engineering recommendations, but they follow directly from Flutter’s guidance not to block the main isolate with expensive work. citeturn23search0turn23search1turn23search8

**Why isolates are mandatory here.** Dart and Flutter recommend isolates for computations large enough to block other work, and Flutter warns not to block the main UI execution path. `compute()` can run work in a separate isolate on native platforms, but repeated generation is better served by a long-lived isolate or worker because isolate spawn/teardown has overhead. When transferring packed board state or telemetry, `TransferableTypedData` is the right tool because sending it through a port is constant time after creation. citeturn23search0turn23search1turn23search2turn23search4turn23search6turn23search8

**Serialization format recommendation.** Use a compact, versioned, deterministic puzzle descriptor plus packed edge state. A good schema is:

```json
{
  "type": "slitherlink",
  "version": 1,
  "engineVersion": "slx-1.3",
  "generatorProfile": "hard-8x8-v3",
  "prngVersion": "prng-v1",
  "seed": "0x1234abcd5678ef90",
  "difficultyLabel": "Hard",
  "difficultyScore": 347,
  "width": 8,
  "height": 8,
  "clues": "packed-row-major-bytes",
  "playerEdges": "2-bits-per-edge-packed",
  "initialPlayerState": null,
  "solverTelemetry": { "...": "optional packed stats" },
  "generatedAt": "2026-06-04",
  "solution": "optional local-only packed edges or omitted"
}
```

Pack clues row-major with one byte each in memory and optionally nibble-pack for storage if you care. Pack player edges into 2 bits each for `unknown/on/off` plus one spare code. This is compact, stable, and easy to inspect in tests. citeturn24search6turn23search2

**What should and should not sync.** Because your backend should not store puzzle boards or solutions, the backend should store at most: puzzle identity data such as `(seed, generatorProfile, engineVersion, difficulty label)`, completion stats, timings, hints used, streaks, and maybe user settings. The board itself can be regenerated locally from seed plus versioned generator profile. If you need progress sync, you can either keep progress local-only, or sync only the packed player edge state alongside the seed/profile/version, without syncing the clue matrix or target solution. Daily puzzles should be defined by deterministic seed formulas or by syncing only the seed/version pair, not by uploading board payloads. citeturn25search1turn23search0

**Testing strategy.** This engine needs a serious test suite, not a hopeful one. At minimum include:

- topology indexing and inverse-mapping tests;
- edge/cell/vertex incidence consistency tests;
- clue derivation tests from hand-made loops;
- final loop validator tests for valid loop, multiple loops, branch, dangling path, empty board, and self-inconsistent clue states;
- exact solver tests on known unique, no-solution, and multi-solution puzzles;
- capped-search tests proving `UNKNOWN` is distinct from `UNIQUE`;
- uniqueness tests on generated puzzles with search limit 2;
- clue-removal tests that verify restoration of rejected removals;
- seed determinism tests across repeated runs, isolates, and app restarts;
- serialization round-trip tests;
- difficulty classification calibration tests;
- hint correctness tests that verify each hint is entailed by the current state;
- move validation tests for on/off/clear and drag actions;
- property-based and fuzz tests on random boards and random edge assignments;
- performance benchmark tests by profile and device tier;
- isolate generation tests for worker handoff and cancellation. citeturn23search0turn23search2turn24search0turn25search1

**High-value invariants.** Useful property-based invariants include: every valid solved board has all vertex degrees in `{0,2}`; every valid solved board’s on-edge count equals half the sum of visited-vertex degrees; every clue equals the count of adjacent on-edges in the derived full clue matrix; every generated accepted puzzle returns exactly one solution under the exact solver with limit 2; every timeout/cap returns `UNKNOWN`, never `UNIQUE`; and same `(seed, size, profileVersion, engineVersion, prngVersion)` produces identical serialized output bytes. Those invariants will catch more real bugs than a thousand manually clicked test puzzles. citeturn15view0turn19view0turn20view0turn25search1

**Common bugs and how to detect them.** The most common Slitherlink engine failures are: accepting multiple disjoint loops as solved; accepting a branch because only clue counts were checked; accepting dangling degree-1 endpoints; confusing local degree validity with global one-loop validity; off-by-one errors in horizontal/vertical indexing; deriving clues from the wrong edge order; letting solver branch order depend on the hidden target solution; treating timeout as uniqueness; allowing premature subloops during partial solving; using non-versioned RNG behavior; and labeling difficulty by clue count alone even when human reasoning requires parity or contradiction search. Detect them with adversarial fixtures that isolate exactly one failure each, and keep those fixtures permanently in regression tests. The official rules and the SAT/SMT/ILP papers are all basically warning labels for these bugs written in more polite typography. citeturn15view0turn8view1turn19view1turn29view0turn36view0turn20view0

**Implementation roadmap with acceptance criteria.**

1. **Core topology model.**  
   Acceptance: all incidence, count, and inverse-mapping tests pass for supported sizes.

2. **Board and state model.**  
   Acceptance: can create immutable puzzle descriptors and mutable play/search states with packed edge arrays.

3. **Clue derivation.**  
   Acceptance: derived clues from hand-checked loops match expected row-major matrices.

4. **Final loop validator.**  
   Acceptance: rejects all invalid completion fixtures and accepts all known-valid solved boards.

5. **Exact solver with propagation.**  
   Acceptance: solves a curated corpus of easy/medium puzzles and distinguishes no-solution from solvable.

6. **Solution counter up to 2.**  
   Acceptance: correctly returns `NONE`, `UNIQUE`, `MULTIPLE`, and `UNKNOWN` on capped tests.

7. **Loop synthesizer.**  
   Acceptance: deterministic from seed; produces valid single loops with acceptable coverage/aesthetic metrics.

8. **Clue removal system.**  
   Acceptance: produced puzzles remain uniquely solvable under the exact solver; removals are deterministic.

9. **Difficulty scorer.**  
   Acceptance: telemetry is recorded; generated puzzles cluster into sensible easy/medium/hard/expert bands on sampled corpora.

10. **Human-style hint engine.**  
    Acceptance: emits explanation-bearing hints for most easy/medium states without consulting hidden solution edges directly.

11. **Move validation and assist modes.**  
    Acceptance: on/off/clear/drag interactions produce stable conflict feedback and unlimited undo/redo.

12. **Serialization and isolate integration.**  
    Acceptance: packed puzzle/player state round-trips; background generation works without UI jank.

13. **Benchmarks and regression suite.**  
    Acceptance: P50/P95 generation and hint budgets are known for target device classes; fixed-seed regressions are stable across releases.

**Final recommended architecture.** The blueprint I would actually ship is this:

- **Ruleset:** standard square-cell Slitherlink on rectangular boards only in V1; aliases in help, not in primary branding. citeturn15view0turn13view0
- **Topology model:** canonical global edge IDs with precomputed immutable topology maps cached by board size. citeturn19view3
- **State representation:** typed arrays (`Uint8List` for hot state, packed binary for storage) plus mutable undo-stack search frames. citeturn24search0turn24search6
- **Determinism:** custom versioned PRNG inside the engine; never rely on `dart:math Random` stream stability. citeturn25search1
- **Loop synthesis:** simply connected cell-region expansion with seeded deterministic scoring and bounded smoothing rewrites. citeturn20view1turn38view0turn17view0
- **Clue generation:** derive full clues exactly from the target loop, then remove greedily with exact uniqueness checks. citeturn20view2turn38view0
- **Uniqueness strategy:** exact solution counting capped at 2; timeout or cap means `UNKNOWN`, never `UNIQUE`. citeturn20view0turn35search0
- **Solver:** propagation + rollback DFS + premature-subloop prevention; SAT/SMT/ILP only as offline reference/oracle tooling. citeturn29view0turn19view1turn36view0
- **Difficulty:** hybrid score led by human-style telemetry, with exact-solver search as a safety signal. citeturn8view1turn8view0turn33view0turn20view3
- **Hints:** human-style rules first, bounded contradiction second, exact edge reveal last. citeturn8view1turn9view0turn8view0
- **Mobile execution:** heavy generation and bulk solving in a background isolate; transfer compact state via `TransferableTypedData`; do not block the main isolate. citeturn23search0turn23search1turn23search2turn23search8
- **UX defaults:** 5×5 to 10×10 as mainstream phone sizes; pinch/quick zoom for larger boards; large invisible hit targets; optional assist modes; unlimited undo/redo. citeturn30search2turn34view2turn22search8
- **Backend policy:** sync seeds, profile/version IDs, and stats; do not store puzzle boards or solutions server-side. citeturn25search1

**Biggest risks.** The main risks are not raw solver speed; they are **false uniqueness**, **nondeterminism across releases**, **difficulty labels that do not match human experience**, and **small-screen input quality**. All four are fixable if you design them in as first-class concerns. None of them are fixable by optimism alone. citeturn20view0turn20view3turn25search1turn30search2turn34view0

**What not to do.** Do not ship clue-first random generation as the main generator. Do not trust local degree checks as full loop validation. Do not treat a search cap as proof of uniqueness. Do not use unversioned RNG behavior. Do not fuse your hint engine with hidden-solution reveal logic. Do not make 16×22 phone boards your default and then act surprised when fingers file a labor complaint. citeturn20view0turn19view1turn25search1turn34view2