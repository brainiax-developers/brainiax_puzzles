import '../slitherlink/slitherlink_board.dart';

enum SlitherlinkVariant { classicLoop, singleLine }

enum SlitherlinkDifficulty { easy, medium, hard, expert }

enum Direction { north, east, south, west }

class EdgeHint {
  final int x;
  final int y;
  final Direction dir;

  const EdgeHint({required this.x, required this.y, required this.dir});

  Map<String, Object?> toJson() => <String, Object?>{
    'x': x,
    'y': y,
    'dir': dir.name,
  };

  factory EdgeHint.fromJson(Map<String, Object?> json) {
    final String dirName = json['dir'] as String? ?? Direction.north.name;
    return EdgeHint(
      x: json['x'] as int? ?? 0,
      y: json['y'] as int? ?? 0,
      dir: Direction.values.firstWhere(
        (Direction d) => d.name == dirName,
        orElse: () => Direction.north,
      ),
    );
  }
}

class SlitherlinkPuzzle {
  final int width;
  final int height;
  final List<int?> clues;
  final SlitherlinkVariant variant;
  final List<EdgeHint> entrances;
  final int? seed;
  final SlitherlinkDifficulty difficulty;
  final Map<String, Object?> telemetry;

  SlitherlinkPuzzle({
    required this.width,
    required this.height,
    required List<int?> clues,
    this.variant = SlitherlinkVariant.classicLoop,
    List<EdgeHint> entrances = const <EdgeHint>[],
    this.seed,
    this.difficulty = SlitherlinkDifficulty.medium,
    Map<String, Object?> telemetry = const <String, Object?>{},
  }) : clues = List<int?>.unmodifiable(List<int?>.from(clues)),
       entrances = List<EdgeHint>.unmodifiable(List<EdgeHint>.from(entrances)),
       telemetry = Map<String, Object?>.unmodifiable(telemetry);

  SlitherlinkBoard toBoard() =>
      SlitherlinkBoard.empty(width: width, height: height, clues: clues);

  Map<String, Object?> toJson() => <String, Object?>{
    'width': width,
    'height': height,
    'clues': clues,
    'variant': variant.name,
    'entrances': entrances.map((EdgeHint e) => e.toJson()).toList(),
    if (seed != null) 'seed': seed,
    'difficulty': difficulty.name,
    if (telemetry.isNotEmpty) 'telemetry': telemetry,
  };

  factory SlitherlinkPuzzle.fromJson(Map<String, Object?> json) {
    final String variantName =
        json['variant'] as String? ?? SlitherlinkVariant.classicLoop.name;
    final String difficultyName =
        json['difficulty'] as String? ?? SlitherlinkDifficulty.medium.name;
    final Iterable<Map<String, Object?>> rawEntrances =
        (json['entrances'] as Iterable?)?.cast<Map<String, Object?>>() ??
        const <Map<String, Object?>>[];
    return SlitherlinkPuzzle(
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      clues: List<int?>.from(json['clues'] as List? ?? const []),
      variant: SlitherlinkVariant.values.firstWhere(
        (SlitherlinkVariant v) => v.name == variantName,
        orElse: () => SlitherlinkVariant.classicLoop,
      ),
      entrances: rawEntrances.map(EdgeHint.fromJson).toList(),
      seed: json['seed'] as int?,
      difficulty: SlitherlinkDifficulty.values.firstWhere(
        (SlitherlinkDifficulty d) => d.name == difficultyName,
        orElse: () => SlitherlinkDifficulty.medium,
      ),
      telemetry: Map<String, Object?>.from(
        json['telemetry'] as Map? ?? const <String, Object?>{},
      ),
    );
  }

  SlitherlinkPuzzle copyWith({
    List<int?>? clues,
    SlitherlinkVariant? variant,
    List<EdgeHint>? entrances,
    int? seed,
    SlitherlinkDifficulty? difficulty,
    Map<String, Object?>? telemetry,
  }) {
    return SlitherlinkPuzzle(
      width: width,
      height: height,
      clues: clues ?? this.clues,
      variant: variant ?? this.variant,
      entrances: entrances ?? this.entrances,
      seed: seed ?? this.seed,
      difficulty: difficulty ?? this.difficulty,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}
