import 'dart:isolate';

import 'package:puzzle_core/puzzle_core.dart' as core;

/// Run a CPU-heavy puzzle generation on a background isolate to keep UI responsive.
Future<core.GeneratedPuzzle<dynamic>> generatePuzzleIsolated({
  required String engineId,
  required String seedStr,
  required int seed64,
  required core.SizeOpt size,
  required core.DifficultyScore difficulty,
}) async {
  // Use Isolate.run (Dart 3) so we can return complex objects without manual
  // SendPort marshalling.
  return await Isolate.run(() {
    final core.PipelinePuzzleEngine<dynamic, dynamic> engine = _createEngine(engineId);
    return engine.generate(
      seedStr: seedStr,
      seed64: seed64,
      size: size,
      difficulty: difficulty,
    );
  });
}

core.PipelinePuzzleEngine<dynamic, dynamic> _createEngine(String engineId) {
  switch (engineId) {
    case 'sudoku_classic':
      return core.SudokuEngine();
    case 'nonogram_mono':
      return core.NonogramEngine();
    case 'kakuro_classic':
      return core.KakuroEngine();
    case 'slitherlink_loop':
      return core.SlitherlinkEngine();
    case 'mathdoku_classic':
      return core.MathdokuEngine();
    case 'futoshiki_classic':
      return core.FutoshikiEngine();
    case 'takuzu_binary':
      return core.TakuzuEngine();
    default:
      // Fallback to a stub engine for unknown types to avoid crashes.
      return core.StubPuzzleEngine(engineId: engineId);
  }
}
