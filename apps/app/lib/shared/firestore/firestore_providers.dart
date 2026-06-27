import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_converters.dart';
import 'firestore_models.dart';
import 'firestore_paths.dart';

typedef UserPuzzleTypeDocumentKey = ({String uid, String puzzleType});
typedef UserRunDocumentKey = ({String uid, String runId});
typedef LeaderboardEntryDocumentKey = ({
  String periodId,
  String puzzleType,
  String entryId,
});
typedef LeaderboardEntriesCollectionKey = ({
  String periodId,
  String puzzleType,
});

final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  if (Firebase.apps.isEmpty) {
    return null;
  }

  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
});

final userProfileDocumentProvider =
    Provider.family<DocumentReference<UserProfileFirestoreModel>?, String>((
      ref,
      uid,
    ) {
      final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
      return firestore
          ?.doc(FirestorePaths.user(uid))
          .withConverter<UserProfileFirestoreModel>(
            fromFirestore: userProfileFirestoreConverter.fromFirestore,
            toFirestore: userProfileFirestoreConverter.toFirestore,
          );
    });

final userStatsDocumentProvider =
    Provider.family<
      DocumentReference<StatsAggregateFirestoreModel>?,
      UserPuzzleTypeDocumentKey
    >((ref, key) {
      final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
      return firestore
          ?.doc(
            FirestorePaths.userStats(uid: key.uid, puzzleType: key.puzzleType),
          )
          .withConverter<StatsAggregateFirestoreModel>(
            fromFirestore: statsAggregateFirestoreConverter.fromFirestore,
            toFirestore: statsAggregateFirestoreConverter.toFirestore,
          );
    });

final userRunDocumentProvider =
    Provider.family<
      DocumentReference<RunResultFirestoreModel>?,
      UserRunDocumentKey
    >((ref, key) {
      final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
      return firestore
          ?.doc(FirestorePaths.userRun(uid: key.uid, runId: key.runId))
          .withConverter<RunResultFirestoreModel>(
            fromFirestore: runResultFirestoreConverter.fromFirestore,
            toFirestore: runResultFirestoreConverter.toFirestore,
          );
    });

final userRunsCollectionProvider =
    Provider.family<CollectionReference<RunResultFirestoreModel>?, String>((
      ref,
      uid,
    ) {
      final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
      return firestore
          ?.collection(FirestorePaths.userRunsCollection(uid))
          .withConverter<RunResultFirestoreModel>(
            fromFirestore: runResultFirestoreConverter.fromFirestore,
            toFirestore: runResultFirestoreConverter.toFirestore,
          );
    });

final dailyStreakDocumentProvider =
    Provider.family<DocumentReference<DailyStreakStateFirestoreModel>?, String>(
      (ref, uid) {
        final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
        return firestore
            ?.doc(FirestorePaths.dailyStreak(uid))
            .withConverter<DailyStreakStateFirestoreModel>(
              fromFirestore: dailyStreakStateFirestoreConverter.fromFirestore,
              toFirestore: dailyStreakStateFirestoreConverter.toFirestore,
            );
      },
    );

final leaderboardEntryDocumentProvider =
    Provider.family<
      DocumentReference<LeaderboardEntryFirestoreModel>?,
      LeaderboardEntryDocumentKey
    >((ref, key) {
      final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
      return firestore
          ?.doc(
            FirestorePaths.leaderboardEntry(
              periodId: key.periodId,
              puzzleType: key.puzzleType,
              entryId: key.entryId,
            ),
          )
          .withConverter<LeaderboardEntryFirestoreModel>(
            fromFirestore: leaderboardEntryFirestoreConverter.fromFirestore,
            toFirestore: leaderboardEntryFirestoreConverter.toFirestore,
          );
    });

final leaderboardEntriesCollectionProvider =
    Provider.family<
      CollectionReference<LeaderboardEntryFirestoreModel>?,
      LeaderboardEntriesCollectionKey
    >((ref, key) {
      final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
      return firestore
          ?.collection(
            FirestorePaths.leaderboardEntriesCollection(
              periodId: key.periodId,
              puzzleType: key.puzzleType,
            ),
          )
          .withConverter<LeaderboardEntryFirestoreModel>(
            fromFirestore: leaderboardEntryFirestoreConverter.fromFirestore,
            toFirestore: leaderboardEntryFirestoreConverter.toFirestore,
          );
    });

final appConfigDocumentProvider =
    Provider<DocumentReference<AppConfigFirestoreModel>?>((ref) {
      final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
      return firestore
          ?.doc(FirestorePaths.appConfig())
          .withConverter<AppConfigFirestoreModel>(
            fromFirestore: appConfigFirestoreConverter.fromFirestore,
            toFirestore: appConfigFirestoreConverter.toFirestore,
          );
    });
