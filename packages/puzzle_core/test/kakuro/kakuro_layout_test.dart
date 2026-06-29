import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';

void main() {
  group('KakuroLayout Validation', () {
    test('Generated boards contain white cells and no length-1 runs', () {
      final generator = const KakuroGenerator();
      final context = GeneratorContext(
        rng: SeededRng(42),
        seedStr: '42',
        seed64: 42,
        size: SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7),
        difficulty: DifficultyRequest(level: 'easy'),
      );
      
      final result = generator.generate(context);
      final board = result.board;
      
      int whiteCount = 0;
      for (int i = 0; i < board.cellTypes.length; i++) {
        if (board.cellTypes[i] == KakuroBoard.cellWhite) {
          whiteCount++;
        }
      }
      
      expect(whiteCount > 0, isTrue, reason: 'Board must have white cells');
      
      // Verify no length 1 runs
      for (int r = 0; r < board.height; r++) {
        int runLen = 0;
        for (int c = 0; c < board.width; c++) {
          if (board.isWhite(r * board.width + c)) {
            runLen++;
          } else {
            expect(runLen, isNot(equals(1)), reason: 'Horizontal run of length 1 found');
            runLen = 0;
          }
        }
        expect(runLen, isNot(equals(1)), reason: 'Horizontal run of length 1 found at edge');
      }
      
      for (int c = 0; c < board.width; c++) {
        int runLen = 0;
        for (int r = 0; r < board.height; r++) {
          if (board.isWhite(r * board.width + c)) {
            runLen++;
          } else {
            expect(runLen, isNot(equals(1)), reason: 'Vertical run of length 1 found');
            runLen = 0;
          }
        }
        expect(runLen, isNot(equals(1)), reason: 'Vertical run of length 1 found at edge');
      }
    });
  });
}
