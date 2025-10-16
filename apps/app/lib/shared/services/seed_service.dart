import 'dart:math';

/// Service for generating and managing puzzle seeds.
class SeedService {
  static final SeedService _instance = SeedService._internal();
  factory SeedService() => _instance;
  SeedService._internal();

  final Random _random = Random();

  /// Generate a daily seed for the specified puzzle type and date.
  /// 
  /// Format: "$puzzleId:${yyyyMMdd}"
  /// Timezone: UTC
  String generateDailySeed(String puzzleId, [DateTime? date]) {
    final utcDate = (date ?? DateTime.now()).toUtc();
    final dateStr = '${utcDate.year.toString().padLeft(4, '0')}'
        '${utcDate.month.toString().padLeft(2, '0')}'
        '${utcDate.day.toString().padLeft(2, '0')}';
    return '$puzzleId:$dateStr';
  }

  /// Generate a random play seed for the specified puzzle type, user, and session.
  /// 
  /// Format: "$puzzleId:$userId:$sessionNonce"
  String generateRandomPlaySeed(String puzzleId, String userId, String sessionNonce) {
    return '$puzzleId:$userId:$sessionNonce';
  }

  /// Generate a test seed for the specified puzzle type and test index.
  /// 
  /// Format: "test:$puzzleId:$testIndex"
  String generateTestSeed(String puzzleId, int testIndex) {
    return 'test:$puzzleId:$testIndex';
  }

  /// Generate a random seed for property testing.
  /// 
  /// Format: "random:$puzzleId:$timestamp:$random"
  String generateRandomSeed(String puzzleId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(1000000);
    return 'random:$puzzleId:$timestamp:$random';
  }

  /// Parse a seed and return its components.
  SeedComponents parseSeed(String seed) {
    final parts = seed.split(':');
    
    if (parts.length < 2) {
      throw ArgumentError('Invalid seed format: $seed');
    }
    
    final firstPart = parts[0];
    
    switch (firstPart) {
      case 'test':
        if (parts.length != 3) {
          throw ArgumentError('Invalid test seed format: $seed');
        }
        return SeedComponents(
          type: SeedType.test,
          puzzleId: parts[1],
          testIndex: int.tryParse(parts[2]),
        );
        
      case 'random':
        if (parts.length != 4) {
          throw ArgumentError('Invalid random seed format: $seed');
        }
        return SeedComponents(
          type: SeedType.random,
          puzzleId: parts[1],
          timestamp: int.tryParse(parts[2]),
          random: int.tryParse(parts[3]),
        );
        
      default:
        // Regular puzzle seed
        if (parts.length == 2) {
          // Daily seed: puzzleId:date
          return SeedComponents(
            type: SeedType.daily,
            puzzleId: firstPart,
            dateStr: parts[1],
          );
        } else if (parts.length == 3) {
          // Random play seed: puzzleId:userId:sessionNonce
          return SeedComponents(
            type: SeedType.randomPlay,
            puzzleId: firstPart,
            userId: parts[1],
            sessionNonce: parts[2],
          );
        } else {
          throw ArgumentError('Invalid seed format: $seed');
        }
    }
  }

  /// Validate that a seed has the correct format.
  bool isValidSeed(String seed) {
    try {
      parseSeed(seed);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate a session nonce for random play.
  String generateSessionNonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(1000000);
    return 'session_${timestamp}_$random';
  }

  /// Generate a user ID (for testing purposes).
  String generateUserId() {
    final random = _random.nextInt(1000000);
    return 'user_$random';
  }

  /// Get today's daily seed for a puzzle type.
  String getTodaysDailySeed(String puzzleId) {
    return generateDailySeed(puzzleId);
  }

  /// Get a specific date's daily seed for a puzzle type.
  String getDailySeedForDate(String puzzleId, DateTime date) {
    return generateDailySeed(puzzleId, date);
  }

  /// Check if a seed is a daily seed.
  bool isDailySeed(String seed) {
    try {
      final components = parseSeed(seed);
      return components.type == SeedType.daily;
    } catch (e) {
      return false;
    }
  }

  /// Check if a seed is a random play seed.
  bool isRandomPlaySeed(String seed) {
    try {
      final components = parseSeed(seed);
      return components.type == SeedType.randomPlay;
    } catch (e) {
      return false;
    }
  }

  /// Check if a seed is a test seed.
  bool isTestSeed(String seed) {
    try {
      final components = parseSeed(seed);
      return components.type == SeedType.test;
    } catch (e) {
      return false;
    }
  }

  /// Check if a seed is a random seed.
  bool isRandomSeed(String seed) {
    try {
      final components = parseSeed(seed);
      return components.type == SeedType.random;
    } catch (e) {
      return false;
    }
  }

  /// Extract the puzzle ID from a seed.
  String? extractPuzzleId(String seed) {
    try {
      final components = parseSeed(seed);
      return components.puzzleId;
    } catch (e) {
      return null;
    }
  }

  /// Extract the date from a daily seed.
  DateTime? extractDateFromDailySeed(String seed) {
    try {
      final components = parseSeed(seed);
      if (components.type == SeedType.daily && components.dateStr != null) {
        final dateStr = components.dateStr!;
        if (dateStr.length == 8) {
          final year = int.parse(dateStr.substring(0, 4));
          final month = int.parse(dateStr.substring(4, 6));
          final day = int.parse(dateStr.substring(6, 8));
          return DateTime.utc(year, month, day);
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }
}

/// Components of a parsed seed.
class SeedComponents {
  final SeedType type;
  final String puzzleId;
  final String? dateStr;
  final String? userId;
  final String? sessionNonce;
  final int? testIndex;
  final int? timestamp;
  final int? random;

  const SeedComponents({
    required this.type,
    required this.puzzleId,
    this.dateStr,
    this.userId,
    this.sessionNonce,
    this.testIndex,
    this.timestamp,
    this.random,
  });

  @override
  String toString() => 'SeedComponents(type: $type, puzzleId: $puzzleId)';
}

/// Types of seeds.
enum SeedType {
  daily,
  randomPlay,
  test,
  random,
}
