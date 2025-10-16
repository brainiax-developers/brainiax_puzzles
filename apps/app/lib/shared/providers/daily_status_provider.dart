import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Daily completion status for a specific puzzle type.
class DailyStatus {
  const DailyStatus({
    required this.puzzleType,
    required this.isCompleted,
    required this.completedAt,
    required this.timeUntilReset,
  });

  final PuzzleType puzzleType;
  final bool isCompleted;
  final DateTime? completedAt;
  final Duration timeUntilReset;

  /// Get the next reset time (local midnight).
  DateTime get nextResetTime {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow;
  }

  /// Get formatted time until reset (e.g., "2h 15m" or "23h 45m").
  String get formattedTimeUntilReset {
    final hours = timeUntilReset.inHours;
    final minutes = timeUntilReset.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if the daily challenge is available (not completed today).
  bool get isAvailable => !isCompleted;

  /// Get the completion percentage for today (0.0 to 1.0).
  double get completionPercentage => isCompleted ? 1.0 : 0.0;
}

/// Overall daily completion status.
class DailyOverallStatus {
  const DailyOverallStatus({
    required this.completedCount,
    required this.totalCount,
    required this.completionPercentage,
    required this.timeUntilReset,
  });

  final int completedCount;
  final int totalCount;
  final double completionPercentage;
  final Duration timeUntilReset;

  /// Get formatted time until reset.
  String get formattedTimeUntilReset {
    final hours = timeUntilReset.inHours;
    final minutes = timeUntilReset.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if all puzzles are completed today.
  bool get isAllCompleted => completedCount == totalCount;

  /// Get completion text (e.g., "3 of 7 completed").
  String get completionText => '$completedCount of $totalCount completed';
}

/// Simple provider for daily status management.
class DailyStatusService {
  static final DailyStatusService _instance = DailyStatusService._internal();
  factory DailyStatusService() => _instance;
  DailyStatusService._internal();

  Map<PuzzleType, DailyStatus> _statuses = {};

  /// Initialize daily statuses for all puzzle types.
  void initialize() {
    _statuses = {};
    for (final puzzleType in PuzzleType.values) {
      _statuses[puzzleType] = _createDailyStatus(puzzleType);
    }
  }

  /// Create daily status for a puzzle type.
  DailyStatus _createDailyStatus(PuzzleType puzzleType) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextReset = DateTime(now.year, now.month, now.day + 1);
    
    // For now, we'll use a simple stub - in real implementation,
    // this would check SharedPreferences or a database
    final isCompleted = _isCompletedToday(puzzleType, today);
    final completedAt = isCompleted ? now : null;
    final timeUntilReset = nextReset.difference(now);
    
    return DailyStatus(
      puzzleType: puzzleType,
      isCompleted: isCompleted,
      completedAt: completedAt,
      timeUntilReset: timeUntilReset,
    );
  }

  /// Check if a puzzle type is completed today (stub implementation).
  bool _isCompletedToday(PuzzleType puzzleType, DateTime today) {
    // Stub: Randomly mark some puzzles as completed for demo purposes
    // In real implementation, this would check SharedPreferences or database
    final seed = today.millisecondsSinceEpoch + puzzleType.index;
    return (seed % 3) == 0; // ~33% chance of being completed
  }

  /// Mark a puzzle type as completed for today.
  Future<void> markCompleted(PuzzleType puzzleType) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextReset = DateTime(now.year, now.month, now.day + 1);
    
    // In real implementation, save to SharedPreferences or database
    await _saveCompletionStatus(puzzleType, today, now);
    
    // Update status
    _statuses[puzzleType] = DailyStatus(
      puzzleType: puzzleType,
      isCompleted: true,
      completedAt: now,
      timeUntilReset: nextReset.difference(now),
    );
  }

  /// Save completion status (stub implementation).
  Future<void> _saveCompletionStatus(PuzzleType puzzleType, DateTime date, DateTime completedAt) async {
    // Stub: In real implementation, save to SharedPreferences or database
    final prefs = await SharedPreferences.getInstance();
    final key = 'daily_${puzzleType.key}_${date.millisecondsSinceEpoch}';
    await prefs.setBool(key, true);
    await prefs.setInt('${key}_completed_at', completedAt.millisecondsSinceEpoch);
  }

  /// Refresh all statuses (useful when time changes).
  void refreshStatuses() {
    initialize();
  }

  /// Get status for a specific puzzle type.
  DailyStatus? getStatus(PuzzleType puzzleType) {
    return _statuses[puzzleType];
  }

  /// Get all statuses.
  Map<PuzzleType, DailyStatus> get allStatuses => Map.unmodifiable(_statuses);

  /// Get overall daily completion status.
  DailyOverallStatus get overallStatus {
    final completedCount = _statuses.values.where((status) => status.isCompleted).length;
    final totalCount = _statuses.length;
    final completionPercentage = totalCount > 0 ? completedCount / totalCount : 0.0;
    
    return DailyOverallStatus(
      completedCount: completedCount,
      totalCount: totalCount,
      completionPercentage: completionPercentage,
      timeUntilReset: _statuses.values.isNotEmpty 
          ? _statuses.values.first.timeUntilReset 
          : const Duration(hours: 24),
    );
  }
}

/// Provider for daily status service.
final dailyStatusServiceProvider = Provider<DailyStatusService>((ref) {
  final service = DailyStatusService();
  service.initialize();
  return service;
});

/// Provider for all daily statuses.
final dailyStatusProvider = Provider<Map<PuzzleType, DailyStatus>>((ref) {
  final service = ref.watch(dailyStatusServiceProvider);
  return service.allStatuses;
});

/// Provider for overall daily status.
final dailyOverallStatusProvider = Provider<DailyOverallStatus>((ref) {
  final service = ref.watch(dailyStatusServiceProvider);
  return service.overallStatus;
});

/// Provider for a specific puzzle type's daily status.
final dailyStatusForPuzzleProvider = Provider.family<DailyStatus?, PuzzleType>((ref, puzzleType) {
  final service = ref.watch(dailyStatusServiceProvider);
  return service.getStatus(puzzleType);
});