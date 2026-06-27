import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_models.dart';

typedef FirestoreFromJson<T> = T Function(Map<String, dynamic> json);
typedef FirestoreToJson<T> = Map<String, dynamic> Function(T value);

class FirestoreModelConverter<T> {
  const FirestoreModelConverter({required this.fromJson, required this.toJson});

  final FirestoreFromJson<T> fromJson;
  final FirestoreToJson<T> toJson;

  T fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      throw StateError('Missing Firestore document data at ${snapshot.id}.');
    }
    return fromJson(data);
  }

  Map<String, Object?> toFirestore(T value, SetOptions? options) {
    return toJson(value);
  }
}

final userProfileFirestoreConverter =
    FirestoreModelConverter<UserProfileFirestoreModel>(
      fromJson: UserProfileFirestoreModel.fromFirestoreJson,
      toJson: (value) => value.toFirestoreJson(),
    );

final runResultFirestoreConverter =
    FirestoreModelConverter<RunResultFirestoreModel>(
      fromJson: RunResultFirestoreModel.fromFirestoreJson,
      toJson: (value) => value.toFirestoreJson(),
    );

final statsAggregateFirestoreConverter =
    FirestoreModelConverter<StatsAggregateFirestoreModel>(
      fromJson: StatsAggregateFirestoreModel.fromFirestoreJson,
      toJson: (value) => value.toFirestoreJson(),
    );

final dailyStreakStateFirestoreConverter =
    FirestoreModelConverter<DailyStreakStateFirestoreModel>(
      fromJson: DailyStreakStateFirestoreModel.fromFirestoreJson,
      toJson: (value) => value.toFirestoreJson(),
    );

final leaderboardEntryFirestoreConverter =
    FirestoreModelConverter<LeaderboardEntryFirestoreModel>(
      fromJson: LeaderboardEntryFirestoreModel.fromFirestoreJson,
      toJson: (value) => value.toFirestoreJson(),
    );

final appConfigFirestoreConverter =
    FirestoreModelConverter<AppConfigFirestoreModel>(
      fromJson: AppConfigFirestoreModel.fromFirestoreJson,
      toJson: (value) => value.toFirestoreJson(),
    );
