import 'dart:typed_data';

import '../../slitherlink/slitherlink_board.dart';
import '../../slitherlink/slitherlink_topology.dart';

List<int> deriveClues({
  required Uint8List solutionEdges,
  required int width,
  required int height,
}) {
  final SlitherlinkTopology topology =
      SlitherlinkTopology.forSize(width, height);
  final List<int> clues = List<int>.filled(width * height, 0);
  for (int cell = 0; cell < clues.length; cell++) {
    int count = 0;
    for (final int edge in topology.cellEdges[cell]) {
      if (solutionEdges[edge] == SlitherlinkBoard.edgeOn) {
        count++;
      }
    }
    clues[cell] = count;
  }
  return clues;
}
