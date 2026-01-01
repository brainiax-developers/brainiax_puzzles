import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

class DifficultyBucketThreshold {
  final String id;
  final double maxInclusive;

  const DifficultyBucketThreshold({
    required this.id,
    required this.maxInclusive,
  });

  factory DifficultyBucketThreshold.fromJson(Map<String, dynamic> json) =>
      DifficultyBucketThreshold(
        id: json['id'] as String,
        maxInclusive: (json['maxInclusive'] as num).toDouble(),
      );
}

class DifficultyBucketConfig {
  final List<DifficultyBucketThreshold> buckets;

  const DifficultyBucketConfig({required this.buckets});

  factory DifficultyBucketConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> bucketJson = json['buckets'] as List<dynamic>;
    final buckets = bucketJson
        .map((dynamic e) => DifficultyBucketThreshold.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.maxInclusive.compareTo(b.maxInclusive));
    return DifficultyBucketConfig(buckets: buckets);
  }

  String bucketFor(double rawScore) {
    for (final bucket in buckets) {
      if (rawScore <= bucket.maxInclusive) {
        return bucket.id;
      }
    }
    return buckets.last.id;
  }
}

class DifficultyConfigLoader {
  const DifficultyConfigLoader();

  Future<DifficultyBucketConfig> loadFromAsset(String assetPath) async {
    final Uri packageUri = Uri.parse('package:puzzle_core/$assetPath');
    final Uri? resolved = await Isolate.resolvePackageUri(packageUri);
    if (resolved == null) {
      throw StateError('Unable to resolve difficulty config: $assetPath');
    }
    final file = File.fromUri(resolved);
    final jsonMap = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return DifficultyBucketConfig.fromJson(jsonMap);
  }

  DifficultyBucketConfig loadSync(String assetPath) {
    // 1) Try to resolve package: URI
    try {
      final Uri packageUri = Uri.parse('package:puzzle_core/$assetPath');
      final Uri? resolved = Isolate.resolvePackageUriSync(packageUri);
      if (resolved != null) {
        final file = File.fromUri(resolved);
        if (file.existsSync()) {
          final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          return DifficultyBucketConfig.fromJson(jsonMap);
        }
      }
    } catch (_) {
      // fallthrough to filesystem attempts
    }

    // 2) Try common filesystem locations synchronously (useful for tests/CI)
    final candidates = <String>[
      assetPath,
      'packages/puzzle_core/$assetPath',
      'assets/difficulty_thresholds.json',
      'packages/puzzle_core/assets/difficulty_thresholds.json',
    ];
    for (final path in candidates) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          return DifficultyBucketConfig.fromJson(jsonMap);
        }
      } catch (_) {
        // try next
      }
    }

    // 3) Fallback: return a safe default bucket config to avoid crash-on-start.
    //    This mirrors the simple easy/medium/hard thresholds used elsewhere.
    //    Log a visible warning so developers know the asset was not found.
    print('Warning: Unable to read difficulty config synchronously: $assetPath. Using built-in defaults.');
    return const DifficultyBucketConfig(
      buckets: <DifficultyBucketThreshold>[
        DifficultyBucketThreshold(id: 'easy', maxInclusive: 0.4),
        DifficultyBucketThreshold(id: 'medium', maxInclusive: 0.7),
        DifficultyBucketThreshold(id: 'hard', maxInclusive: 1.0),
      ],
    );
  }
}
