import 'dart:typed_data';

import '../../slitherlink/slitherlink_board.dart';
import '../../slitherlink/slitherlink_topology.dart';

class SlitherlinkGrid {
  final int width;
  final int height;
  final SlitherlinkTopology topology;
  final List<int?> clues;
  final Int8List edges;

  SlitherlinkGrid._({
    required this.width,
    required this.height,
    required this.topology,
    required List<int?> clues,
    required this.edges,
  })  : clues = List<int?>.unmodifiable(List<int?>.from(clues));

  factory SlitherlinkGrid.fromBoard(SlitherlinkBoard board) {
    return SlitherlinkGrid._(
      width: board.width,
      height: board.height,
      topology: board.topology,
      clues: board.clues,
      edges: Int8List.fromList(board.edges),
    );
  }

  factory SlitherlinkGrid.fromClues({
    required int width,
    required int height,
    required List<int?> clues,
  }) {
    final SlitherlinkTopology topology =
        SlitherlinkTopology.forSize(width, height);
    final Int8List edges =
        Int8List(topology.edgeCount)..fillRange(0, topology.edgeCount, -1);
    return SlitherlinkGrid._(
      width: width,
      height: height,
      topology: topology,
      clues: clues,
      edges: edges,
    );
  }

  SlitherlinkBoard toBoard() => SlitherlinkBoard(
        width: width,
        height: height,
        clues: clues,
        edges: edges.toList(),
      );

  SlitherlinkGrid clone() => SlitherlinkGrid._(
        width: width,
        height: height,
        topology: topology,
        clues: clues,
        edges: Int8List.fromList(edges),
      );
}
