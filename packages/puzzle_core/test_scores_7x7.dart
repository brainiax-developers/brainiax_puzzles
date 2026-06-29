import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';

void main() {
  final engine = KakuroEngine();
  final generator = KakuroGenerator();
  
  for (int i = 0; i < 5; i++) {
    final ctx = GeneratorContext(
      seedStr: 'test_7x7_$i',
      seed64: 0,
      rng: SeededRng(i),
      difficulty: const DifficultyRequest(level: 'easy'),
      size: const SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7),
    );
    final result = generator.generate(ctx);
    final telemetry = result.snapshot?.telemetry ?? {};
    final nodes = (telemetry['solver_nodes'] as num?)?.toDouble() ?? 0.0;
    final backtracks = (telemetry['solver_backtracks'] as num?)?.toDouble() ?? 0.0;
    final score = nodes * 1.0 + backtracks * 5.0;
    print('Board $i: nodes=$nodes, backtracks=$backtracks, score=$score');
  }
}
