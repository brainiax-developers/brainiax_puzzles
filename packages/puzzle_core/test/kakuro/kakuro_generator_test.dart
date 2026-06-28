import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('KakuroGenerator', () {
    test('Generates deterministic puzzles', () {
      final generator = const KakuroGenerator();
      
      final context1 = GeneratorContext(
        rng: SeededRng(12345),
        seedStr: '12345',
        seed64: 12345,
        size: SizeOpt(id: '4x4', description: '4x4', width: 4, height: 4),
        difficulty: DifficultyRequest(level: 'easy'),
      );
      
      final result1 = generator.generate(context1);
      final board1 = result1.board;
      
      final context2 = GeneratorContext(
        rng: SeededRng(12345),
        seedStr: '12345',
        seed64: 12345,
        size: SizeOpt(id: '4x4', description: '4x4', width: 4, height: 4),
        difficulty: DifficultyRequest(level: 'easy'),
      );
      
      final result2 = generator.generate(context2);
      final board2 = result2.board;
      
      expect(board1.width, equals(board2.width));
      expect(board1.height, equals(board2.height));
      expect(board1.cellTypes, orderedEquals(board2.cellTypes));
      expect(board1.acrossClues, orderedEquals(board2.acrossClues));
      expect(board1.downClues, orderedEquals(board2.downClues));
    });

    test('Generated puzzles are solvable', () {
      final generator = const KakuroGenerator();
      final context = GeneratorContext(
        rng: SeededRng(999),
        seedStr: '999',
        seed64: 999,
        size: SizeOpt(id: '4x4', description: '4x4', width: 4, height: 4),
        difficulty: DifficultyRequest(level: 'medium'),
      );
      
      final result = generator.generate(context);
      final board = result.board;
      
      final solver = const KakuroSolver();
      final solverResult = solver.solve(
        board, 
        SolverContext(rng: SeededRng(999), maxSolutions: 2)
      );
      
      expect(
        solverResult.solutionStatus == SolverStatus.unique || 
        solverResult.solutionStatus == SolverStatus.multiple, 
        isTrue
      );
    });
  });
}
