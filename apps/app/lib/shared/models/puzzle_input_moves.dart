import 'package:puzzle_core/puzzle_core.dart' as core;

/// App-level wrapper for applying multiple Nonogram cell changes as one
/// user gesture.
class NonogramBatchMove {
  const NonogramBatchMove(this.moves);

  final List<core.NonogramMove> moves;

  bool get isEmpty => moves.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'nonogram_batch',
    'moves': moves.map((core.NonogramMove move) => move.toJson()).toList(),
  };
}
