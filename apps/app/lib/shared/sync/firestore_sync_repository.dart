import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> upsertFavourites(String uid, List<PuzzleType> favourites);
}

class FirestoreSyncRepository implements SyncRepository {
  FirestoreSyncRepository(this._firestore, {DateTime Function()? nowUtc})
    : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final FirebaseFirestore _firestore;
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
        'providerIds': identity.isAnonymous
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
  Future<void> uploadRunResult(String uid, PuzzleRunResult result) {
    final DocumentReference<RunResultFirestoreModel> document = _firestore
        .doc(FirestorePaths.userRun(uid: uid, runId: result.id))
        .withConverter<RunResultFirestoreModel>(
          fromFirestore: runResultFirestoreConverter.fromFirestore,
          toFirestore: runResultFirestoreConverter.toFirestore,
        );

    return document.set(
      RunResultFirestoreModel(
        runId: result.id,
        uid: uid,
        puzzleType: result.puzzleType.key,
        mode: result.mode.key,
        difficulty: result.difficulty,
        size: result.size,
        dailyDateKeyUtc: result.dailyDateKeyUtc,
        startedAtUtc: result.startedAtUtc,
        completedAtUtc: result.completedAtUtc,
        sessionUpdatedAtUtc: result.sessionUpdatedAtUtc,
        elapsedMs: result.elapsedMs,
        moveCount: result.moveCount,
        hintsUsed: result.hintsUsed,
      ),
      SetOptions(merge: true),
    );
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
  Future<void> upsertFavourites(String uid, List<PuzzleType> favourites) {
    final List<String> favouriteKeys =
        favourites.map((PuzzleType type) => type.key).toSet().toList()..sort();
    final DateTime nowUtc = _nowUtc().toUtc();

    return _firestore.doc(FirestorePaths.user(uid)).set(<String, dynamic>{
      'schemaVersion': firestoreSchemaVersion,
      'uid': uid,
      'lastSeenAt': FirestoreTimestamp.toTimestamp(nowUtc),
      'preferences': <String, dynamic>{
        'favoritePuzzleTypes': favouriteKeys,
        'updatedAt': FirestoreTimestamp.toTimestamp(nowUtc),
      },
    }, SetOptions(merge: true));
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
