import 'package:cloud_firestore/cloud_firestore.dart';

const int firestoreSchemaVersion = 1;

class UserPreferencesFirestoreModel {
  const UserPreferencesFirestoreModel({
    this.favoritePuzzleTypes = const <String>[],
    this.preferredDifficulties = const <String, String>{},
    this.updatedAtUtc,
  });

  final List<String> favoritePuzzleTypes;
  final Map<String, String> preferredDifficulties;
  final DateTime? updatedAtUtc;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'favoritePuzzleTypes': favoritePuzzleTypes,
    'preferredDifficulties': preferredDifficulties,
    'updatedAt': FirestoreTimestamp.toNullableTimestamp(updatedAtUtc),
  };

  factory UserPreferencesFirestoreModel.fromFirestoreJson(
    Map<String, dynamic> json,
  ) {
    return UserPreferencesFirestoreModel(
      favoritePuzzleTypes: _stringList(json['favoritePuzzleTypes']),
      preferredDifficulties: _stringMap(json['preferredDifficulties']),
      updatedAtUtc: FirestoreTimestamp.toNullableDateTime(json['updatedAt']),
    );
  }
}

class UserProfileFirestoreModel {
  const UserProfileFirestoreModel({
    required this.uid,
    required this.createdAtUtc,
    this.schemaVersion = firestoreSchemaVersion,
    this.lastSeenAtUtc,
    this.displayName,
    this.isAnonymous = false,
    this.providerIds = const <String>[],
    this.preferences = const UserPreferencesFirestoreModel(),
  });

  final int schemaVersion;
  final String uid;
  final DateTime createdAtUtc;
  final DateTime? lastSeenAtUtc;
  final String? displayName;
  final bool isAnonymous;
  final List<String> providerIds;
  final UserPreferencesFirestoreModel preferences;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'uid': uid,
    'createdAt': FirestoreTimestamp.toTimestamp(createdAtUtc),
    'lastSeenAt': FirestoreTimestamp.toNullableTimestamp(lastSeenAtUtc),
    'displayName': displayName,
    'isAnonymous': isAnonymous,
    'providerIds': providerIds,
    'preferences': preferences.toFirestoreJson(),
  };

  factory UserProfileFirestoreModel.fromFirestoreJson(
    Map<String, dynamic> json,
  ) {
    return UserProfileFirestoreModel(
      schemaVersion: _int(json['schemaVersion'], defaultValue: 1),
      uid: _requiredString(json, 'uid'),
      createdAtUtc: FirestoreTimestamp.toDateTime(json['createdAt']),
      lastSeenAtUtc: FirestoreTimestamp.toNullableDateTime(json['lastSeenAt']),
      displayName: _nullableString(json['displayName']),
      isAnonymous: _bool(json['isAnonymous']),
      providerIds: _stringList(json['providerIds']),
      preferences: UserPreferencesFirestoreModel.fromFirestoreJson(
        _jsonMap(json['preferences']),
      ),
    );
  }
}

class RunResultFirestoreModel {
  const RunResultFirestoreModel({
    required this.runId,
    required this.uid,
    required this.puzzleType,
    required this.mode,
    required this.difficulty,
    required this.size,
    required this.completedAtUtc,
    required this.elapsedMs,
    required this.moveCount,
    required this.hintsUsed,
    this.schemaVersion = firestoreSchemaVersion,
    this.dailyDateKeyUtc,
    this.startedAtUtc,
    this.sessionUpdatedAtUtc,
  });

  final int schemaVersion;
  final String runId;
  final String uid;
  final String puzzleType;
  final String mode;
  final String difficulty;
  final String size;
  final String? dailyDateKeyUtc;
  final DateTime? startedAtUtc;
  final DateTime completedAtUtc;
  final DateTime? sessionUpdatedAtUtc;
  final int elapsedMs;
  final int moveCount;
  final int hintsUsed;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'runId': runId,
    'uid': uid,
    'puzzleType': puzzleType,
    'mode': mode,
    'difficulty': difficulty,
    'size': size,
    'dailyDateKeyUtc': dailyDateKeyUtc,
    'startedAt': FirestoreTimestamp.toNullableTimestamp(startedAtUtc),
    'completedAt': FirestoreTimestamp.toTimestamp(completedAtUtc),
    'sessionUpdatedAt': FirestoreTimestamp.toNullableTimestamp(
      sessionUpdatedAtUtc,
    ),
    'elapsedMs': elapsedMs,
    'moveCount': moveCount,
    'hintsUsed': hintsUsed,
  };

  factory RunResultFirestoreModel.fromFirestoreJson(Map<String, dynamic> json) {
    return RunResultFirestoreModel(
      schemaVersion: _int(json['schemaVersion'], defaultValue: 1),
      runId: _requiredString(json, 'runId'),
      uid: _requiredString(json, 'uid'),
      puzzleType: _requiredString(json, 'puzzleType'),
      mode: _requiredString(json, 'mode'),
      difficulty: _requiredString(json, 'difficulty'),
      size: _requiredString(json, 'size'),
      dailyDateKeyUtc: _nullableString(json['dailyDateKeyUtc']),
      startedAtUtc: FirestoreTimestamp.toNullableDateTime(json['startedAt']),
      completedAtUtc: FirestoreTimestamp.toDateTime(json['completedAt']),
      sessionUpdatedAtUtc: FirestoreTimestamp.toNullableDateTime(
        json['sessionUpdatedAt'],
      ),
      elapsedMs: _int(json['elapsedMs']),
      moveCount: _int(json['moveCount']),
      hintsUsed: _int(json['hintsUsed']),
    );
  }
}

class StatsBreakdownFirestoreModel {
  const StatsBreakdownFirestoreModel({
    required this.totalCompletions,
    required this.randomCompletions,
    required this.dailyCompletions,
    required this.totalElapsedMs,
    required this.totalMoveCount,
    required this.totalHintsUsed,
    this.bestElapsedMs,
    this.firstCompletedAtUtc,
    this.lastCompletedAtUtc,
  });

  const StatsBreakdownFirestoreModel.empty()
    : this(
        totalCompletions: 0,
        randomCompletions: 0,
        dailyCompletions: 0,
        totalElapsedMs: 0,
        totalMoveCount: 0,
        totalHintsUsed: 0,
      );

  final int totalCompletions;
  final int randomCompletions;
  final int dailyCompletions;
  final int totalElapsedMs;
  final int totalMoveCount;
  final int totalHintsUsed;
  final int? bestElapsedMs;
  final DateTime? firstCompletedAtUtc;
  final DateTime? lastCompletedAtUtc;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'totalCompletions': totalCompletions,
    'randomCompletions': randomCompletions,
    'dailyCompletions': dailyCompletions,
    'totalElapsedMs': totalElapsedMs,
    'totalMoveCount': totalMoveCount,
    'totalHintsUsed': totalHintsUsed,
    'bestElapsedMs': bestElapsedMs,
    'firstCompletedAt': FirestoreTimestamp.toNullableTimestamp(
      firstCompletedAtUtc,
    ),
    'lastCompletedAt': FirestoreTimestamp.toNullableTimestamp(
      lastCompletedAtUtc,
    ),
  };

  factory StatsBreakdownFirestoreModel.fromFirestoreJson(
    Map<String, dynamic> json,
  ) {
    return StatsBreakdownFirestoreModel(
      totalCompletions: _int(json['totalCompletions']),
      randomCompletions: _int(json['randomCompletions']),
      dailyCompletions: _int(json['dailyCompletions']),
      totalElapsedMs: _int(json['totalElapsedMs']),
      totalMoveCount: _int(json['totalMoveCount']),
      totalHintsUsed: _int(json['totalHintsUsed']),
      bestElapsedMs: _nullableInt(json['bestElapsedMs']),
      firstCompletedAtUtc: FirestoreTimestamp.toNullableDateTime(
        json['firstCompletedAt'],
      ),
      lastCompletedAtUtc: FirestoreTimestamp.toNullableDateTime(
        json['lastCompletedAt'],
      ),
    );
  }
}

class StatsAggregateFirestoreModel {
  const StatsAggregateFirestoreModel({
    required this.uid,
    required this.puzzleType,
    required this.totalCompletions,
    required this.randomCompletions,
    required this.dailyCompletions,
    required this.totalElapsedMs,
    required this.totalMoveCount,
    required this.totalHintsUsed,
    this.schemaVersion = firestoreSchemaVersion,
    this.bestElapsedMs,
    this.firstCompletedAtUtc,
    this.lastCompletedAtUtc,
    this.byDifficulty = const <String, StatsBreakdownFirestoreModel>{},
  });

  final int schemaVersion;
  final String uid;
  final String puzzleType;
  final int totalCompletions;
  final int randomCompletions;
  final int dailyCompletions;
  final int totalElapsedMs;
  final int totalMoveCount;
  final int totalHintsUsed;
  final int? bestElapsedMs;
  final DateTime? firstCompletedAtUtc;
  final DateTime? lastCompletedAtUtc;
  final Map<String, StatsBreakdownFirestoreModel> byDifficulty;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'uid': uid,
    'puzzleType': puzzleType,
    'totalCompletions': totalCompletions,
    'randomCompletions': randomCompletions,
    'dailyCompletions': dailyCompletions,
    'totalElapsedMs': totalElapsedMs,
    'totalMoveCount': totalMoveCount,
    'totalHintsUsed': totalHintsUsed,
    'bestElapsedMs': bestElapsedMs,
    'firstCompletedAt': FirestoreTimestamp.toNullableTimestamp(
      firstCompletedAtUtc,
    ),
    'lastCompletedAt': FirestoreTimestamp.toNullableTimestamp(
      lastCompletedAtUtc,
    ),
    'byDifficulty': byDifficulty.map<String, dynamic>(
      (key, value) => MapEntry<String, dynamic>(key, value.toFirestoreJson()),
    ),
  };

  factory StatsAggregateFirestoreModel.fromFirestoreJson(
    Map<String, dynamic> json,
  ) {
    return StatsAggregateFirestoreModel(
      schemaVersion: _int(json['schemaVersion'], defaultValue: 1),
      uid: _requiredString(json, 'uid'),
      puzzleType: _requiredString(json, 'puzzleType'),
      totalCompletions: _int(json['totalCompletions']),
      randomCompletions: _int(json['randomCompletions']),
      dailyCompletions: _int(json['dailyCompletions']),
      totalElapsedMs: _int(json['totalElapsedMs']),
      totalMoveCount: _int(json['totalMoveCount']),
      totalHintsUsed: _int(json['totalHintsUsed']),
      bestElapsedMs: _nullableInt(json['bestElapsedMs']),
      firstCompletedAtUtc: FirestoreTimestamp.toNullableDateTime(
        json['firstCompletedAt'],
      ),
      lastCompletedAtUtc: FirestoreTimestamp.toNullableDateTime(
        json['lastCompletedAt'],
      ),
      byDifficulty: _statsBreakdownMap(json['byDifficulty']),
    );
  }
}

class DailyStreakStateFirestoreModel {
  const DailyStreakStateFirestoreModel({
    required this.uid,
    required this.currentStreak,
    required this.bestStreak,
    this.schemaVersion = firestoreSchemaVersion,
    this.lastCompletedDateKeyUtc,
    this.updatedAtUtc,
  });

  final int schemaVersion;
  final String uid;
  final int currentStreak;
  final int bestStreak;
  final String? lastCompletedDateKeyUtc;
  final DateTime? updatedAtUtc;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'uid': uid,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'lastCompletedDateKeyUtc': lastCompletedDateKeyUtc,
    'updatedAt': FirestoreTimestamp.toNullableTimestamp(updatedAtUtc),
  };

  factory DailyStreakStateFirestoreModel.fromFirestoreJson(
    Map<String, dynamic> json,
  ) {
    return DailyStreakStateFirestoreModel(
      schemaVersion: _int(json['schemaVersion'], defaultValue: 1),
      uid: _requiredString(json, 'uid'),
      currentStreak: _int(json['currentStreak']),
      bestStreak: _int(json['bestStreak']),
      lastCompletedDateKeyUtc: _nullableString(json['lastCompletedDateKeyUtc']),
      updatedAtUtc: FirestoreTimestamp.toNullableDateTime(json['updatedAt']),
    );
  }
}

class LeaderboardEntryFirestoreModel {
  const LeaderboardEntryFirestoreModel({
    required this.entryId,
    required this.periodId,
    required this.puzzleType,
    required this.uid,
    required this.score,
    required this.elapsedMs,
    required this.moveCount,
    required this.hintsUsed,
    required this.difficulty,
    required this.size,
    required this.completedAtUtc,
    this.schemaVersion = firestoreSchemaVersion,
    this.displayName,
    this.rank,
    this.updatedAtUtc,
  });

  final int schemaVersion;
  final String entryId;
  final String periodId;
  final String puzzleType;
  final String uid;
  final String? displayName;
  final int score;
  final int? rank;
  final int elapsedMs;
  final int moveCount;
  final int hintsUsed;
  final String difficulty;
  final String size;
  final DateTime completedAtUtc;
  final DateTime? updatedAtUtc;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'entryId': entryId,
    'periodId': periodId,
    'puzzleType': puzzleType,
    'uid': uid,
    'displayName': displayName,
    'score': score,
    'rank': rank,
    'elapsedMs': elapsedMs,
    'moveCount': moveCount,
    'hintsUsed': hintsUsed,
    'difficulty': difficulty,
    'size': size,
    'completedAt': FirestoreTimestamp.toTimestamp(completedAtUtc),
    'updatedAt': FirestoreTimestamp.toNullableTimestamp(updatedAtUtc),
  };

  factory LeaderboardEntryFirestoreModel.fromFirestoreJson(
    Map<String, dynamic> json,
  ) {
    return LeaderboardEntryFirestoreModel(
      schemaVersion: _int(json['schemaVersion'], defaultValue: 1),
      entryId: _requiredString(json, 'entryId'),
      periodId: _requiredString(json, 'periodId'),
      puzzleType: _requiredString(json, 'puzzleType'),
      uid: _requiredString(json, 'uid'),
      displayName: _nullableString(json['displayName']),
      score: _int(json['score']),
      rank: _nullableInt(json['rank']),
      elapsedMs: _int(json['elapsedMs']),
      moveCount: _int(json['moveCount']),
      hintsUsed: _int(json['hintsUsed']),
      difficulty: _requiredString(json, 'difficulty'),
      size: _requiredString(json, 'size'),
      completedAtUtc: FirestoreTimestamp.toDateTime(json['completedAt']),
      updatedAtUtc: FirestoreTimestamp.toNullableDateTime(json['updatedAt']),
    );
  }
}

class AppConfigFirestoreModel {
  const AppConfigFirestoreModel({
    this.schemaVersion = firestoreSchemaVersion,
    this.cloudSyncEnabled = false,
    this.leaderboardsEnabled = false,
    this.minSupportedSchemaVersion = firestoreSchemaVersion,
    this.updatedAtUtc,
  });

  final int schemaVersion;
  final bool cloudSyncEnabled;
  final bool leaderboardsEnabled;
  final int minSupportedSchemaVersion;
  final DateTime? updatedAtUtc;

  Map<String, dynamic> toFirestoreJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'cloudSyncEnabled': cloudSyncEnabled,
    'leaderboardsEnabled': leaderboardsEnabled,
    'minSupportedSchemaVersion': minSupportedSchemaVersion,
    'updatedAt': FirestoreTimestamp.toNullableTimestamp(updatedAtUtc),
  };

  factory AppConfigFirestoreModel.fromFirestoreJson(Map<String, dynamic> json) {
    return AppConfigFirestoreModel(
      schemaVersion: _int(json['schemaVersion'], defaultValue: 1),
      cloudSyncEnabled: _bool(json['cloudSyncEnabled']),
      leaderboardsEnabled: _bool(json['leaderboardsEnabled']),
      minSupportedSchemaVersion: _int(
        json['minSupportedSchemaVersion'],
        defaultValue: 1,
      ),
      updatedAtUtc: FirestoreTimestamp.toNullableDateTime(json['updatedAt']),
    );
  }
}

class FirestoreTimestamp {
  const FirestoreTimestamp._();

  static Timestamp toTimestamp(DateTime value) {
    return Timestamp.fromDate(value.toUtc());
  }

  static Timestamp? toNullableTimestamp(DateTime? value) {
    return value == null ? null : toTimestamp(value);
  }

  static DateTime toDateTime(Object? value) {
    final DateTime? dateTime = toNullableDateTime(value);
    if (dateTime == null) {
      throw const FormatException('Missing Firestore timestamp.');
    }
    return dateTime;
  }

  static DateTime? toNullableDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    throw FormatException('Invalid Firestore timestamp: $value');
  }
}

Map<String, StatsBreakdownFirestoreModel> _statsBreakdownMap(Object? value) {
  final Map<String, dynamic> json = _jsonMap(value);
  return json.map<String, StatsBreakdownFirestoreModel>(
    (key, value) => MapEntry<String, StatsBreakdownFirestoreModel>(
      key,
      StatsBreakdownFirestoreModel.fromFirestoreJson(_jsonMap(value)),
    ),
  );
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }
  throw FormatException('Expected JSON map: $value');
}

Map<String, String> _stringMap(Object? value) {
  final Map<String, dynamic> json = _jsonMap(value);
  return json.map<String, String>(
    (key, value) => MapEntry<String, String>(key, value.toString()),
  );
}

List<String> _stringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is String) {
    return <String>[value];
  }
  if (value is Iterable) {
    return List<String>.unmodifiable(value.map((item) => item.toString()));
  }
  throw FormatException('Expected string list: $value');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final String? value = _nullableString(json[key]);
  if (value == null || value.isEmpty) {
    throw FormatException('Missing $key in $json');
  }
  return value;
}

String? _nullableString(Object? value) {
  return value is String ? value : null;
}

int _int(Object? value, {int defaultValue = 0}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? defaultValue;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _int(value);
}

bool _bool(Object? value, {bool defaultValue = false}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final String text = value.toString().toLowerCase();
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return defaultValue;
}
