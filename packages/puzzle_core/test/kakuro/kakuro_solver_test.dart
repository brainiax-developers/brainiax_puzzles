import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('KakuroSolver Uniqueness Tests', () {
    test('Identifies unique solution', () {
      // 2x2 board, top-left is black, others are white.
      // Black cell is a clue: across=3, down=3
      // White cells: (0,1) down=3, (1,0) across=3, (1,1)
      
      // Let's make a 3x3 board to be safe and clear.
      // 0: black, 1: clue(a:3), 2: clue(a:4)
      // 3: clue(d:3), 4: white(1), 5: white(2) -> across=3
      // 6: clue(d:4), 7: white(2), 8: white(3) -> across=5? Let's just manually set up a simple board.
      
      final cellTypes = [
        0, 1, 1,
        1, 2, 2,
        1, 2, 2,
      ];
      
      final acrossClues = [
        0, 0, 0,
        0, 3, 0, // row 1, col 0 clue -> across=3 (length 2)
        0, 4, 0, // row 2, col 0 clue -> across=4 (length 2) => impossible! Wait. 1+3=4. 3 can be 1+2.
      ];
      // 3 = 1+2. So (1,1) and (1,2) must be {1, 2}.
      // 4 = 1+3. So (2,1) and (2,2) must be {1, 3}.
      // Down clues:
      // col 1: down = 4 -> (1,1) and (2,1) must be {1, 3}.
      // col 2: down = 3 -> (1,2) and (2,2) must be {1, 2}.
      // Intersection:
      // (1,1) in {1,2} and {1,3} -> must be 1.
      // (1,2) in {1,2} and {1,2}. Since (1,1)=1, (1,2) must be 2. (sum=3)
      // (2,1) in {1,3} and {1,3}. Since (1,1)=1, (2,1) must be 3. (sum=4)
      // (2,2) in {1,3} and {1,2}. Since (2,1)=3, (2,2) must be 1. (sum=4). Wait, (1,2)=2, so down sum = 2+1=3. Correct.
      // Solution is unique:
      // (1,1)=1, (1,2)=2
      // (2,1)=3, (2,2)=1
      
      final downClues = [
        0, 0, 0,
        4, 0, 0, // col 1 down=4
        3, 0, 0, // col 2 down=3
      ];
      
      // Let's place the clues in the right cells.
      // Clues at (1,0) and (2,0) have across.
      final aClues = List<int>.filled(9, 0);
      aClues[3] = 3;
      aClues[6] = 4;
      
      // Clues at (0,1) and (0,2) have down.
      final dClues = List<int>.filled(9, 0);
      dClues[1] = 4;
      dClues[2] = 3;
      
      final board = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: cellTypes,
        cellValues: List<int>.filled(9, 0),
        acrossClues: aClues,
        downClues: dClues,
      );
      
      final solver = const KakuroSolver();
      final context = SolverContext(rng: SeededRng(123), maxSolutions: 2);
      
      final result = solver.solve(board, context);
      
      expect(result.solutionStatus, equals(SolverStatus.unique));
      expect(result.solutions.length, equals(1));
      
      final sol = result.solutions.first;
      expect(sol.getValue(4), equals(1)); // (1,1)
      expect(sol.getValue(5), equals(2)); // (1,2)
      expect(sol.getValue(7), equals(3)); // (2,1)
      expect(sol.getValue(8), equals(1)); // (2,2)
    });
    
    test('Identifies multiple solutions and exits early', () {
      // 3x3 board where clues allow swapping (ambiguous rectangle)
      // Across 3 (1+2 or 2+1), Across 3 (2+1 or 1+2)
      // Down 3 (1+2 or 2+1), Down 3 (2+1 or 1+2)
      
      final cellTypes = [
        0, 1, 1,
        1, 2, 2,
        1, 2, 2,
      ];
      
      final aClues = List<int>.filled(9, 0);
      aClues[3] = 3;
      aClues[6] = 3;
      
      final dClues = List<int>.filled(9, 0);
      dClues[1] = 3;
      dClues[2] = 3;
      
      final board = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: cellTypes,
        cellValues: List<int>.filled(9, 0),
        acrossClues: aClues,
        downClues: dClues,
      );
      
      final solver = const KakuroSolver();
      final context = SolverContext(rng: SeededRng(123), maxSolutions: 2);
      
      final result = solver.solve(board, context);
      
      // Should find exactly 2 solutions and exit (status = multiple)
      expect(result.solutionStatus, equals(SolverStatus.multiple));
      expect(result.solutions.length, equals(2));
    });
    
    test('Identifies no solution', () {
      // Impossible sums: across 3 (1,2), down 3 (1,2), but across 17 (8,9)
      final cellTypes = [
        0, 1, 1,
        1, 2, 2,
        1, 2, 2,
      ];
      
      final aClues = List<int>.filled(9, 0);
      aClues[3] = 3;
      aClues[6] = 17; // requires 8,9
      
      final dClues = List<int>.filled(9, 0);
      dClues[1] = 3;  // requires 1,2
      dClues[2] = 3;  // requires 1,2
      
      final board = KakuroBoard(
        width: 3,
        height: 3,
        cellTypes: cellTypes,
        cellValues: List<int>.filled(9, 0),
        acrossClues: aClues,
        downClues: dClues,
      );
      
      final solver = const KakuroSolver();
      final context = SolverContext(rng: SeededRng(123), maxSolutions: 2);
      
      final result = solver.solve(board, context);
      
      expect(result.solutionStatus, equals(SolverStatus.noSolution));
      expect(result.solutions.length, equals(0));
    });
  });
}
