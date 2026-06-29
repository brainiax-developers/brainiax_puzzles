import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';

void main() {
  final generator = KakuroGenerator();
    for (int size in [10]) {
    print('\n--- Benchmarking Size $size x $size ---');
    int successes = 0;
    List<double> scores = [];
    final sw = Stopwatch()..start();
    
    for (int i = 0; i < 5; i++) {
      final ctx = GeneratorContext(
        seedStr: 'benchmark_${size}x${size}_$i',
        seed64: 0,
        rng: SeededRng(i * 999),
        difficulty: const DifficultyRequest(level: 'expert'),
        size: SizeOpt(id: '${size}x${size}', description: '${size}x${size}', width: size, height: size),
      );
      try {
        final iterSw = Stopwatch()..start();
        final result = generator.generate(ctx);
        final board = result.board as KakuroBoard;
        int whiteCount = 0;
        for (int c = 0; c < board.cellCount; c++) {
          if (board.isWhite(c)) whiteCount++;
        }
        final telemetry = result.snapshot?.telemetry ?? {};
        final nodes = (telemetry['solver_nodes'] as num?)?.toDouble() ?? 0.0;
        final backtracks = (telemetry['solver_backtracks'] as num?)?.toDouble() ?? 0.0;
        final attempts = (telemetry['attempts'] as num?)?.toInt() ?? 1;
        
        final score = nodes * 1.0 + backtracks * 5.0 + (whiteCount * 40.0);
        scores.add(score);
        successes++;
        print('Board $i generated in ${iterSw.elapsedMilliseconds}ms (Attempts: $attempts, Score: $score)');
      } catch (e) {
        print('Board $i failed: $e');

      }
      sw.stop();
      print('\n--- Results ---');
      if (scores.isNotEmpty) {
        scores.sort();
        print('Size $size x $size: $successes/10 succeeded');
        print('Total benchmark time: ${sw.elapsedMilliseconds}ms (Average: ${sw.elapsedMilliseconds / 10}ms per request)');
        print('Min score: ${scores.first}');
        print('Median score: ${scores[scores.length ~/ 2]}');
        print('Max score: ${scores.last}');
      } else {
        print('All attempts failed.');
      }
    }
    
    sw.stop();
    print('\n--- Results ---');
    if (scores.isNotEmpty) {
      scores.sort();
      print('Size $size x $size: $successes/5 succeeded');
      print('Total benchmark time: ${sw.elapsedMilliseconds}ms (Average: ${sw.elapsedMilliseconds / 5}ms per request)');
      print('Min score: ${scores.first}');
      print('Median score: ${scores[scores.length ~/ 2]}');
      print('Max score: ${scores.last}');
    } else {
      print('All attempts failed.');
    }
  }
}
