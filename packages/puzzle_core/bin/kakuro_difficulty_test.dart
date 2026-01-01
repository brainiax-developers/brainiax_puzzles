import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  print('=== Kakuro Difficulty Test ===\n');
  
  const difficulties = ['easy', 'medium', 'hard'];
  
  for (final diffLevel in difficulties) {
    print('--- Testing difficulty: $diffLevel ---');
    final String seedStr = 'kakuro_${diffLevel}_test';
    final int seed64 = Seed.fromString(seedStr);
    
    const KakuroGenerator generator = KakuroGenerator(maxTemplateAttempts: 500);
    const KakuroSolver solver = KakuroSolver();
    
    try {
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(seed64),
        seedStr: seedStr,
        seed64: seed64,
        size: const SizeOpt(
          id: 'template9x9',
          description: 'Template 9x9',
          width: 9,
          height: 9,
        ),
        difficulty: DifficultyRequest(level: diffLevel),
      );
      
      final stopwatch = Stopwatch()..start();
      final PuzzleGenerationResult<KakuroBoard> result = generator.generate(context);
      stopwatch.stop();
      
      print('✓ Generation successful!');
      print('  Time: ${stopwatch.elapsedMilliseconds}ms');
      print('  Attempts: ${result.snapshot.telemetry['attempts']}');
      print('  Difficulty bucket: ${result.snapshot.telemetry['difficultyBucket']}');
      print('  Difficulty score (milli): ${result.snapshot.telemetry['difficultyScoreMilli']}');
      
      // Verify uniqueness
      final SolverResult<KakuroBoard> solverResult = solver.solve(
        result.board,
        SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
      );
      
      print('  Is unique: ${solverResult.isUnique}');
      print('');
      
    } catch (e) {
      print('✗ Failed: $e\n');
    }
  }
}
