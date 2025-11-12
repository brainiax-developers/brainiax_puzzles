# Slitherlink Generator Pipeline

This package exposes the `SlitherlinkGenerator`, which follows a three-stage
pipeline:

1. **Loop synthesis** (`loop_synthesis.dart`): builds a padded 0/1 colour grid
   whose boundary encodes a single non-self-intersecting loop.
2. **Clue derivation** (`clues.dart`): counts colour transitions across the
   four orthogonal neighbours of each cell to produce a full clue matrix.
3. **Uniqueness-preserving removal** (`removal.dart`): removes clues in shuffled
   batches, calling the solver until the puzzle remains uniquely solvable
   within the configured time and search budgets.

To generate a board, create a `GeneratorContext` and call `generate`:

```dart
final SlitherlinkGenerator generator = const SlitherlinkGenerator();
final GeneratorContext context = GeneratorContext(
  rng: SeededRng(Seed.fromString('demo-seed')),
  seedStr: 'demo-seed',
  seed64: Seed.fromString('demo-seed'),
  size: const SizeOpt(id: '10x10', description: '10x10', width: 10, height: 10),
  difficulty: const DifficultyRequest(level: 'medium'),
);

final PuzzleGenerationResult<SlitherlinkBoard> result = generator.generate(context);
final SlitherlinkBoard board = result.board; // Contains nullable clues and unknown edges.
```

The generator telemetry (`result.snapshot.telemetry`) contains the solver
profiling data (calls, depth, elapsed) and the final solution loop as a list of
edge states for diagnostics.
