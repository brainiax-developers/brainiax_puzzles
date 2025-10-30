import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  print('=== Simple Kakuro Generation Test ===\n');
  
  final String seedStr = 'test_seed';
  final int seed64 = Seed.fromString(seedStr);
  
  print('Creating generator with increased attempt limit...');
  const KakuroGenerator generator = KakuroGenerator(maxTemplateAttempts: 500);
  const KakuroSolver solver = KakuroSolver();
  
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
    difficulty: const DifficultyRequest(level: 'auto'),
  );
  
  print('Calling generator.generate()...\n');
  
  try {
    final stopwatch = Stopwatch()..start();
    final PuzzleGenerationResult<KakuroBoard> result = generator.generate(context);
    stopwatch.stop();
    
    print('✓ SUCCESS!');
    print('  Time: ${stopwatch.elapsedMilliseconds}ms');
    print('  Telemetry: ${result.snapshot.telemetry}');
    
    // Verify solution
    print('\nVerifying solution...');
    final SolverResult<KakuroBoard> solverResult = solver.solve(
      result.board,
      SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
    );
    
    print('  Has solution: ${solverResult.hasSolution}');
    print('  Is unique: ${solverResult.isUnique}');
    print('  Solutions count: ${solverResult.solutions.length}');
    
  } catch (e, stackTrace) {
    print('✗ FAILED: $e');
    print('\nStack trace:');
    print(stackTrace);
  }
}
