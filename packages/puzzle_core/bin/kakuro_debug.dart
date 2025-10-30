import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  print('=== Kakuro Debug ===');
  const KakuroGenerator generator = KakuroGenerator(maxTemplateAttempts: 500);
  const KakuroSolver solver = KakuroSolver();
  
  // Try multiple seeds to see which ones work
  final List<String> testSeeds = [
    'kakuro_test_1',
    'kakuro_test_2',
    'kakuro_test_3',
    'kakuro_gen_seed',
    'kakuro_engine_seed',
    'random:123',
    'random:456',
    'random:789',
  ];
  
  for (final String seedStr in testSeeds) {
    print('\n--- Testing seed: $seedStr ---');
    final int seed64 = Seed.fromString(seedStr);
    
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
        difficulty: const DifficultyRequest(level: 'auto'),
      );
      
      final PuzzleGenerationResult<KakuroBoard> result = generator.generate(context);
      
      print('✓ Generation successful!');
      print('  Attempts: ${result.snapshot.telemetry['attempts']}');
      print('  Telemetry: ${result.snapshot.telemetry}');
      
      // Verify uniqueness
      final SolverResult<KakuroBoard> solverResult = solver.solve(
        result.board,
        SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
      );
      
      print('  Solutions found: ${solverResult.solutions.length}');
      print('  Is unique: ${solverResult.isUnique}');
      
    } catch (e) {
      print('✗ Failed: $e');
    }
  }
}
