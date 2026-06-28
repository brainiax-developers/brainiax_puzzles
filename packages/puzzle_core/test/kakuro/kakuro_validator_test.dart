import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('KakuroValidator', () {
    test('Identifies invalid layout (1-cell run)', () {
      final cellTypes = [
        0, 1, 0, // black, white(clue actually, wait 1=clue, 2=white), wait!
        // In my KakuroBoard: 0=black, 1=clue, 2=white
      ];
      final board = KakuroBoard(
        width: 3,
        height: 1,
        cellTypes: [KakuroBoard.cellBlack, KakuroBoard.cellWhite, KakuroBoard.cellBlack], // 0, 2, 0
        cellValues: [0, 0, 0],
        acrossClues: [0, 0, 0],
        downClues: [0, 0, 0],
      );
      
      final validator = KakuroValidator();
      final summary = validator.validatePuzzle(board);
      
      expect(summary.isValid, isFalse);
      expect(summary.issues.any((i) => i.contains('1-cell run')), isTrue);
    });
    
    test('Identifies valid layout', () {
      final board = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: [
          KakuroBoard.cellBlack, KakuroBoard.cellBlack, KakuroBoard.cellBlack,
          KakuroBoard.cellBlack, KakuroBoard.cellWhite, KakuroBoard.cellWhite,
          KakuroBoard.cellBlack, KakuroBoard.cellWhite, KakuroBoard.cellWhite,
        ],
        cellValues: List<int>.filled(9, 0),
        acrossClues: List<int>.filled(9, 0),
        downClues: List<int>.filled(9, 0),
      );
      
      final validator = KakuroValidator();
      final summary = validator.validatePuzzle(board);
      
      expect(summary.isValid, isTrue);
    });

    test('Validates solution constraints', () {
      // 2x2 white cells, clues on top/left
      final board = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: [
          0, 1, 1,
          1, 2, 2,
          1, 2, 2,
        ],
        cellValues: List<int>.filled(9, 0),
        acrossClues: [
          0, 0, 0,
          3, 0, 0,
          4, 0, 0,
        ],
        downClues: [
          0, 4, 3,
          0, 0, 0,
          0, 0, 0,
        ],
      );
      
      final goodSolution = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: board.cellTypes,
        cellValues: [
          0, 0, 0,
          0, 1, 2, // 1+2=3
          0, 3, 1, // 3+1=4
        ],
        acrossClues: board.acrossClues,
        downClues: board.downClues,
      );
      
      final badSolution1 = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: board.cellTypes,
        cellValues: [
          0, 0, 0,
          0, 1, 3, // 1+3=4 (expected 3)
          0, 3, 1,
        ],
        acrossClues: board.acrossClues,
        downClues: board.downClues,
      );
      
      final badSolution2 = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: board.cellTypes,
        cellValues: [
          0, 0, 0,
          0, 2, 2, // duplicate digit 2
          0, 2, 2,
        ],
        acrossClues: board.acrossClues,
        downClues: board.downClues,
      );
      
      final validator = KakuroValidator();
      
      final goodSummary = validator.validateSolution(board, goodSolution);
      if (!goodSummary.isValid) {
        print('goodSolution failed validation: ${goodSummary.issues}');
      }
      expect(goodSummary.isValid, isTrue);
      
      final bad1Summary = validator.validateSolution(board, badSolution1);
      expect(bad1Summary.isValid, isFalse);
      expect(bad1Summary.issues.any((i) => i.contains('has sum 4, expected 3')), isTrue);
      
      final bad2Summary = validator.validateSolution(board, badSolution2);
      expect(bad2Summary.isValid, isFalse);
      expect(bad2Summary.issues.any((i) => i.contains('Duplicate digit 2')), isTrue);
    });
  });
}
