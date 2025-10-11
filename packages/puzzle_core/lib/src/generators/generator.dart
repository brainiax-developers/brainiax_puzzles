import '../puzzle_type.dart';

abstract class PuzzleGenerator<TBoard> {
  const PuzzleGenerator();
  TBoard generate({required PuzzleType type, required int seed, int? difficulty});
}
