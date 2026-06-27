import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_metadata/app_metadata.dart';
import '../auth/user_identity.dart';
import '../firestore/firestore_converters.dart';
import '../firestore/firestore_models.dart';
import '../firestore/firestore_paths.dart';
import '../models/puzzle_type.dart';
import '../stats/puzzle_run_result.dart';
import '../stats/stats_models.dart';
import '../streak/daily_streak_models.dart';

abstract interface class SyncRepository {
  Future<void> ensureUserProfile(UserIdentity identity);

  Future<void> uploadRunResult(String uid, PuzzleRunResult result);

  Future<void> upsertStats(String uid, PuzzleStatsAggregate stats);

  Future<void> upsertDailyStreak(String uid, DailyStreakStatus status);

  Future<void> upsertFavourites(
    String uid,
    List<PuzzleType> favourites, {
    required DateTime updatedAtUtc,
  });
}

class FirestoreSyncRepository implements SyncRepository {
  FirestoreSyncRepository(
    this._firestore, {
    AppBuildMetadata appMetadata = AppBuildMetadata.current,
    DateTime Function()? nowUtc,
  }) : _appMetadata = appMetadata,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final FirebaseFirestore _firestore;
  final AppBuildMetadata _appMetadata;
  final DateTime Function() _nowUtc;

  @override
  Future<void> ensureUserProfile(UserIdentity identity) async {
    final DocumentReference<Map<String, dynamic>> document = _firestore.doc(
      FirestorePaths.user(identity.uid),
    );
    final DateTime nowUtc = _nowUtc().toUtc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final Map<String, dynamic> data = <String, dynamic>{
        'schemaVersion': firestoreSchemaVersion,
        'uid': identity.uid,
        'lastSeenAt': FirestoreTimestamp.toTimestamp(nowUtc),
        'isAnonymous': identity.isAnonymous,
        'providerIds': identity.providerIds.isNotEmpty
            ? identity.providerIds
            : identity.isAnonymous
            ? const <String>['anonymous']
            : const <String>[],
      };

      if (!snapshot.exists) {
        data['createdAt'] = FirestoreTimestamp.toTimestamp(nowUtc);
      }

      transaction.set(document, data, SetOptions(merge: true));
    });
  }

  @override
  Future<void> uploadRunResult(String uid, PuzzleRunResult result) async {
    final DocumentReference<RunResultFirestoreModel> document = _firestore
        .doc(FirestorePaths.userRun(uid: uid, runId: result.id))
        .withConverter<RunResultFirestoreModel>(
          fromFirestore: runResultFirestoreConverter.fromFirestore,
          toFirestore: runResultFirestoreConverter.toFirestore,
        );
    final DateTime updatedAtUtc = _nowUtc().toUtc();

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<RunResultFirestoreModel> snapshot =
          await transaction.get(document);
      final DateTime createdAtUtc =
          snapshot.data()?.createdAtUtc ?? updatedAtUtc;

      transaction.set(
        document,
        runResultFirestoreModelForUpload(
          uid: uid,
          result: result,
          appMetadata: _appMetadata,
          createdAtUtc: createdAtUtc,
          updatedAtUtc: updatedAtUtc,
        ),
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> upsertStats(String uid, PuzzleStatsAggregate stats) async {
    for (final PuzzleTypeStats puzzleStats in stats.byPuzzle.values) {
      final DocumentReference<StatsAggregateFirestoreModel> document =
          _firestore
              .doc(
                FirestorePaths.userStats(
                  uid: uid,
                  puzzleType: puzzleStats.puzzleType.key,
                ),
              )
              .withConverter<StatsAggregateFirestoreModel>(
                fromFirestore: statsAggregateFirestoreConverter.fromFirestore,
                toFirestore: statsAggregateFirestoreConverter.toFirestore,
              );

      await document.set(
        _statsAggregateModel(uid: uid, stats: puzzleStats),
        SetOptions(merge: true),
      );
    }
  }

  @override
  Future<void> upsertDailyStreak(String uid, DailyStreakStatus status) {
    final DocumentReference<DailyStreakStateFirestoreModel> document =
        _firestore
            .doc(FirestorePaths.dailyStreak(uid))
            .withConverter<DailyStreakStateFirestoreModel>(
              fromFirestore: dailyStreakStateFirestoreConverter.fromFirestore,
              toFirestore: dailyStreakStateFirestoreConverter.toFirestore,
            );

    return document.set(
      DailyStreakStateFirestoreModel(
        uid: uid,
        currentStreak: status.currentStreak,
        bestStreak: status.bestStreak,
        lastCompletedDateKeyUtc: status.lastCompletedDateKeyUtc,
        updatedAtUtc: _nowUtc().toUtc(),
      ),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> upsertFavourites(
    String uid,
    List<PuzzleType> favourites, {
    required DateTime updatedAtUtc,
  }) async {
    final List<String> favouriteKeys =
        favourites.map((PuzzleType type) => type.key).toSet().toList()..sort();
    final DateTime nowUtc = _nowUtc().toUtc();
    final DateTime resolvedUpdatedAtUtc = updatedAtUtc.toUtc();
    final DocumentReference<Map<String, dynamic>> document = _firestore.doc(
      FirestorePaths.user(uid),
    );

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(document);
      final Map<String, dynamic> profile =
          snapshot.data() ?? <String, dynamic>{};
      final FavouritePreferencesMergeResult resolved =
          resolveFavouritePreferencesForSync(
            remotePreferences: _jsonMap(profile['preferences']),
            localFavouriteKeys: favouriteKeys,
            localUpdatedAtUtc: resolvedUpdatedAtUtc,
          );

      transaction.set(document, <String, dynamic>{
        'schemaVersion': firestoreSchemaVersion,
        'uid': uid,
        'lastSeenAt': FirestoreTimestamp.toTimestamp(nowUtc),
        'preferences': <String, dynamic>{
          'favoritePuzzleTypes': resolved.favouriteKeys,
          'updatedAt': FirestoreTimestamp.toTimestamp(resolved.updatedAtUtc),
        },
      }, SetOptions(merge: true));
    });
  }

  StatsAggregateFirestoreModel _statsAggregateModel({
    required String uid,
    required PuzzleTypeStats stats,
  }) {
    return StatsAggregateFirestoreModel(
      uid: uid,
      puzzleType: stats.puzzleType.key,
      totalCompletions: stats.totalCompletions,
      randomCompletions: stats.randomCompletions,
      dailyCompletions: stats.dailyCompletions,
      totalElapsedMs: stats.totalElapsedMs,
      totalMoveCount: stats.totalMoveCount,
      totalHintsUsed: stats.totalHintsUsed,
      bestElapsedMs: stats.bestElapsedMs,
      firstCompletedAtUtc: stats.firstCompletedAtUtc,
      lastCompletedAtUtc: stats.lastCompletedAtUtc,
      byDifficulty: stats.byDifficulty
          .map<String, StatsBreakdownFirestoreModel>((
            String key,
            PuzzleDifficultyStats value,
          ) {
            return MapEntry<String, StatsBreakdownFirestoreModel>(
              key,
              _statsBreakdownModel(value),
            );
          }),
    );
  }

  StatsBreakdownFirestoreModel _statsBreakdownModel(
    PuzzleDifficultyStats stats,
  ) {
    return StatsBreakdownFirestoreModel(
      totalCompletions: stats.totalCompletions,
      randomCompletions: stats.randomCompletions,
      dailyCompletions: stats.dailyCompletions,
      totalElapsedMs: stats.totalElapsedMs,
      totalMoveCount: stats.totalMoveCount,
      totalHintsUsed: stats.totalHintsUsed,
      bestElapsedMs: stats.bestElapsedMs,
      firstCompletedAtUtc: stats.firstCompletedAtUtc,
      lastCompletedAtUtc: stats.lastCompletedAtUtc,
    );
  }
}

RunResultFirestoreModel runResultFirestoreModelForUpload({
  required String uid,
  required PuzzleRunResult result,
  required AppBuildMetadata appMetadata,
  required DateTime createdAtUtc,
  required DateTime updatedAtUtc,
}) {
  final DateTime completedAtUtc = result.completedAtUtc.toUtc();
  final DateTime startedAtUtc =
      result.startedAtUtc?.toUtc() ??
      completedAtUtc.subtract(Duration(milliseconds: result.elapsedMs));

  return RunResultFirestoreModel(
    runId: result.id,
    uid: uid,
    puzzleType: result.puzzleType.key,
    mode: result.mode.key,
    seed: result.seed,
    difficulty: result.difficulty,
    size: result.size,
    completed: true,
    dailyDateKeyUtc: result.dailyDateKeyUtc,
    startedAtUtc: startedAtUtc,
    completedAtUtc: completedAtUtc,
    sessionUpdatedAtUtc: result.sessionUpdatedAtUtc?.toUtc() ?? completedAtUtc,
    elapsedMs: result.elapsedMs,
    moveCount: result.moveCount,
    hintsUsed: result.hintsUsed,
    engineVersion: _nonEmptyOrDefault(
      result.engineVersion,
      appMetadata.defaultEngineVersion,
    ),
    appVersion: _nonEmptyOrDefault(
      appMetadata.appVersion,
      unknownAppMetadataValue,
    ),
    createdAtUtc: createdAtUtc.toUtc(),
    updatedAtUtc: updatedAtUtc.toUtc(),
  );
}

String _nonEmptyOrDefault(String value, String fallback) {
  final String trimmed = value.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return fallback.trim().isEmpty ? unknownAppMetadataValue : fallback;
}

FavouritePreferencesMergeResult resolveFavouritePreferencesForSync({
  required Map<String, dynamic> remotePreferences,
  required List<String> localFavouriteKeys,
  required DateTime localUpdatedAtUtc,
}) {
  final List<String> remoteFavouriteKeys = _stringList(
    remotePreferences['favoritePuzzleTypes'] ??
        remotePreferences['favouritePuzzleTypes'] ??
        remotePreferences['favourites'],
  ).toSet().toList()..sort();
  final DateTime? remoteUpdatedAtUtc = FirestoreTimestamp.toNullableDateTime(
    remotePreferences['updatedAt'],
  );
  final List<String> normalizedLocalKeys = localFavouriteKeys.toSet().toList()
    ..sort();
  final DateTime normalizedLocalUpdatedAtUtc = localUpdatedAtUtc.toUtc();

  if (remoteFavouriteKeys.isEmpty) {
    return FavouritePreferencesMergeResult(
      favouriteKeys: normalizedLocalKeys,
      updatedAtUtc: normalizedLocalUpdatedAtUtc,
    );
  }

  if (remoteUpdatedAtUtc == null) {
    return FavouritePreferencesMergeResult(
      favouriteKeys: <String>{
        ...remoteFavouriteKeys,
        ...normalizedLocalKeys,
      }.toList()..sort(),
      updatedAtUtc: normalizedLocalUpdatedAtUtc,
    );
  }

  if (normalizedLocalUpdatedAtUtc.isBefore(remoteUpdatedAtUtc)) {
    return FavouritePreferencesMergeResult(
      favouriteKeys: remoteFavouriteKeys,
      updatedAtUtc: remoteUpdatedAtUtc,
    );
  }

  return FavouritePreferencesMergeResult(
    favouriteKeys: normalizedLocalKeys,
    updatedAtUtc: normalizedLocalUpdatedAtUtc,
  );
}

class FavouritePreferencesMergeResult {
  const FavouritePreferencesMergeResult({
    required this.favouriteKeys,
    required this.updatedAtUtc,
  });

  final List<String> favouriteKeys;
  final DateTime updatedAtUtc;
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
