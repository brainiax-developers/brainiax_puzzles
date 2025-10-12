import 'dart:convert';

import 'slitherlink_topology.dart';

class SlitherlinkBoard {
  static const int edgeUnknown = -1;
  static const int edgeOff = 0;
  static const int edgeOn = 1;

  final int width;
  final int height;
  final List<int?> clues;
  final List<int> edges;

  SlitherlinkBoard({
    required this.width,
    required this.height,
    required List<int?> clues,
    required List<int> edges,
  })  : clues = List<int?>.unmodifiable(List<int?>.from(clues)),
        edges = List<int>.unmodifiable(List<int>.from(edges)) {
    final SlitherlinkTopology topology =
        SlitherlinkTopology.forSize(width, height);
    if (this.clues.length != width * height) {
      throw ArgumentError(
        'Expected ${width * height} clues but got ${this.clues.length}',
      );
    }
    if (this.edges.length != topology.edgeCount) {
      throw ArgumentError(
        'Expected ${topology.edgeCount} edges but got ${this.edges.length}',
      );
    }
  }

  factory SlitherlinkBoard.empty({
    required int width,
    required int height,
    required List<int?> clues,
  }) {
    final SlitherlinkTopology topology =
        SlitherlinkTopology.forSize(width, height);
    final List<int> edges =
        List<int>.filled(topology.edgeCount, edgeUnknown, growable: false);
    return SlitherlinkBoard(
      width: width,
      height: height,
      clues: clues,
      edges: edges,
    );
  }

  int get cellCount => width * height;

  bool get isComplete => !edges.contains(edgeUnknown);

  SlitherlinkTopology get topology => SlitherlinkTopology.forSize(width, height);

  int cellIndex(int row, int col) => row * width + col;

  List<int> edgesForCell(int row, int col) =>
      List<int>.from(topology.cellEdges[cellIndex(row, col)]);

  List<int> edgesForCellIndex(int index) =>
      List<int>.from(topology.cellEdges[index]);

  List<int> edgesForVertex(int row, int col) =>
      List<int>.from(topology.vertexEdges[topology.vertexIndex(row, col)]);

  SlitherlinkBoard copyWith({List<int?>? clues, List<int>? edges}) {
    return SlitherlinkBoard(
      width: width,
      height: height,
      clues: clues ?? this.clues,
      edges: edges ?? this.edges,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'width': width,
        'height': height,
        'clues': clues,
        'edges': edges,
      };

  factory SlitherlinkBoard.fromJson(Map<String, dynamic> json) {
    return SlitherlinkBoard(
      width: json['width'] as int,
      height: json['height'] as int,
      clues: List<int?>.from(json['clues'] as List),
      edges: List<int>.from(json['edges'] as List),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SlitherlinkBoard) {
      return false;
    }
    return width == other.width &&
        height == other.height &&
        _listEquals(clues, other.clues) &&
        _listEquals(edges, other.edges);
  }

  @override
  int get hashCode => Object.hash(
        width,
        height,
        Object.hashAll(clues),
        Object.hashAll(edges),
      );

  @override
  String toString() => jsonEncode(toJson());

  static bool _listEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
