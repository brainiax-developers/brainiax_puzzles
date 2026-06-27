import 'package:app/shared/models/models.dart';
import 'package:app/shared/stats/puzzle_run_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'derives sync-safe run result from completion record and session data',
    () {
      final record = PuzzleCompletionRecord(
        id: 'run-1',
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        difficulty: 'hard',
        size: '9x9',
        seed: 'seed-123',
        completedAtUtc: DateTime.utc(2026, 6, 20, 9, 45),
        elapsedMs: 45000,
        moveCount: 18,
        hintsUsed: 2,
        dailyDateKeyUtc: '2026-06-20',
      );
      final session = ActivePuzzleRun(
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        difficulty: 'hard',
        size: '9x9',
        seed: 'seed-123',
        generatedPuzzleJson: const <String, dynamic>{'id': 'ignored'},
        createdAtUtc: DateTime.utc(2026, 6, 20, 9, 30),
        updatedAtUtc: DateTime.utc(2026, 6, 20, 9, 44),
        elapsedMs: 44000,
        moveCount: 17,
        hintsUsed: 1,
        isSolved: true,
        dailyDateKeyUtc: '2026-06-20',
      );

      final result = PuzzleRunResult.fromCompletionRecord(
        record,
        session: session,
      );

      expect(result.id, 'run-1');
      expect(result.puzzleType, PuzzleType.sudokuClassic);
      expect(result.mode, PuzzleMode.daily);
      expect(result.isDaily, isTrue);
      expect(result.difficulty, 'hard');
      expect(result.size, '9x9');
      expect(result.seed, 'seed-123');
      expect(result.completedAtUtc, DateTime.utc(2026, 6, 20, 9, 45));
      expect(result.startedAtUtc, DateTime.utc(2026, 6, 20, 9, 30));
      expect(result.sessionUpdatedAtUtc, DateTime.utc(2026, 6, 20, 9, 44));
      expect(result.elapsedMs, 45000);
      expect(result.moveCount, 18);
      expect(result.hintsUsed, 2);
      expect(result.dailyDateKeyUtc, '2026-06-20');
      expect(
        PuzzleRunResult.fromJson(result.toJson()).toJson(),
        result.toJson(),
      );
    },
  );
}
