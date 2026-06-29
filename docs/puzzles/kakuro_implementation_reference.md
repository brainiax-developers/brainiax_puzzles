# Kakuro Implementation Reference

This document serves as a technical reference for the current production state of the Kakuro puzzle engine, specifically detailing grid sizes, generation thresholds, and performance constraints.

## Size-Based Difficulty Progression

To guarantee deterministic, real-time, on-device generation, Kakuro difficulty levels are tightly mapped to distinct grid sizes. This structural progression prevents the engine from hitting the backtracking node limit while ensuring a visually and conceptually clear difficulty ramp for players.

| Difficulty | Grid Size | Description |
| :--- | :--- | :--- |
| **Easy** | 6x6 | Minimal runs, many single-combination sums. Extremely fast generation. |
| **Medium** | 7x7 | Occasional overlapping logic and ambiguous sums, perfectly balanced for intermediate play. |
| **Hard** | 8x8 | Advanced overlapping logic with multiple 4-5 cell runs. Very few single-combination clues. |
| **Expert** | 9x9 | Dense logic with high ambiguity. Pushes right up against the boundaries of real-time solvable search spaces. |

> [!WARNING]
> **Why no 10x10 or larger grids?**
> The backtracking uniqueness-solver scales exponentially with the number of white cells. Boards `10x10` and larger frequently exhaust the solver's 150k node cap (taking >15 seconds), causing the generation attempt budget to time out on mobile devices. **9x9 is the mathematically imposed limit for random, on-device generation.**

## Scoring Metrics and Thresholds

When a board is generated, it is passed through the `KakuroDifficultyScorer`, which aggregates telemetry from the solver to assign a final score.

### Base Scoring Formula
```dart
score = (nodes * 1.0) + (backtracks * 5.0) + (whiteCount * 40.0)
```
* **nodes**: The number of search nodes explored by the solver to prove uniqueness.
* **backtracks**: The number of dead-ends hit during the proof.
* **whiteCount**: The total number of playable cells in the grid, serving as a structural base score.

### Difficulty Buckets
The `KakuroEngine` uses calibrated thresholds to cleanly sort the generated sizes into their intended difficulty buckets:

- **Easy**: `score <= 1100` (Easily encompasses 6x6 grids)
- **Medium**: `score <= 1550` (Easily encompasses 7x7 grids)
- **Hard**: `score <= 2100` (Easily encompasses 8x8 grids)
- **Expert**: `score > 2100` (Perfect for 9x9 grids)

## Validation and Generation Mechanics
- **No 1-Cell Runs**: The layout engine ensures every white cell belongs to both an across and a down run of at least length 2.
- **Density Scaling**: Black cell placement uses a density factor (between `0.35` and `0.48`) that scales with grid size to keep larger boards sparse enough to solve within the node budget.
- **Strict Budget**: Generation fails fast if a board cannot be laid out and proved unique within the node cap (`150k`) or the generation attempt budget (`5000`).
