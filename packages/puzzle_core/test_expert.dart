import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';

void main() {
  final generator = KakuroGenerator();
  
  for (int i = 0; i < 20; i++) {
    final ctx = GeneratorContext(
      seedStr: 'test_expert_$i',
      seed64: 0,
      rng: SeededRng(i * 100),
      difficulty: const DifficultyRequest(level: 'expert'),
      size: const SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9),
    );
    final stopwatch = Stopwatch()..start();
    try {
      final result = generator.generate(ctx);
      stopwatch.stop();
      final board = result.board as KakuroBoard;
      int whiteCount = 0;
      for (int c = 0; c < board.cellCount; c++) {
        if (board.isWhite(c)) whiteCount++;
      }
      final telemetry = result.snapshot?.telemetry ?? {};
      final attempts = telemetry['attempts'];
      final nodes = (telemetry['solver_nodes'] as num?)?.toDouble() ?? 0.0;
      final backtracks = (telemetry['solver_backtracks'] as num?)?.toDouble() ?? 0.0;
      
      final oldScore = nodes * 1.0 + backtracks * 5.0;
      final newScore = oldScore + (whiteCount * 40.0);
      print('Board $i (${stopwatch.elapsedMilliseconds}ms, att=$attempts): white=$whiteCount, nodes=$nodes, backtracks=$backtracks | newScore=$newScore');
    } catch (e) {
      print('Board $i failed: $e');
    }
  }
}
