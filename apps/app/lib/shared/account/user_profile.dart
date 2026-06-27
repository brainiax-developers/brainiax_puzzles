import '../models/puzzle_type.dart';

/// User-level preferences stored with the profile.
class UserPreferences {
  const UserPreferences({
    this.favouritePuzzleTypes = const <PuzzleType>[],
    this.favouritesUpdatedAtUtc,
  });

  final List<PuzzleType> favouritePuzzleTypes;
  final DateTime? favouritesUpdatedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'favouritePuzzleTypes': favouritePuzzleTypes
        .map((PuzzleType type) => type.key)
        .toList(),
    'favouritesUpdatedAtUtc': favouritesUpdatedAtUtc?.toUtc().toIso8601String(),
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mergedJson = <String, dynamic>{
      ...json,
      ..._stringKeyMap(json['preferences']),
    };

    return UserPreferences(
      favouritePuzzleTypes: _puzzleTypesFromJson(
        mergedJson['favouritePuzzleTypes'] ??
            mergedJson['favoritePuzzleTypes'] ??
            mergedJson['favourites'] ??
            mergedJson['favorites'],
      ),
      favouritesUpdatedAtUtc: _dateTimeFromJson(
        mergedJson['favouritesUpdatedAtUtc'] ??
            mergedJson['favoritesUpdatedAtUtc'] ??
            mergedJson['favouriteTypesUpdatedAtUtc'] ??
            mergedJson['updatedAt'],
      ),
    );
  }
}

/// Firebase-agnostic user account profile.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.createdAtUtc,
    this.lastSeenAtUtc,
    this.displayName,
    this.isAnonymous = false,
    this.providerIds = const <String>[],
    this.schemaVersion = 1,
    this.preferences = const UserPreferences(),
  });

  final String uid;
  final DateTime createdAtUtc;
  final DateTime? lastSeenAtUtc;
  final String? displayName;
  final bool isAnonymous;
  final List<String> providerIds;
  final int schemaVersion;
  final UserPreferences preferences;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'lastSeenAtUtc': lastSeenAtUtc?.toUtc().toIso8601String(),
    'displayName': displayName,
    'isAnonymous': isAnonymous,
    'providerIds': providerIds,
    'schemaVersion': schemaVersion,
    'preferences': preferences.toJson(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mergedJson = <String, dynamic>{
      ...json,
      ..._stringKeyMap(json['profile']),
      ..._stringKeyMap(json['userProfile']),
    };

    final String uid = _requiredString(mergedJson, 'uid');
    final DateTime createdAtUtc =
        _dateTimeFromJson(
          mergedJson['createdAtUtc'] ??
              mergedJson['createdAt'] ??
              mergedJson['createdAtUtcMs'] ??
              mergedJson['createdAtMs'],
        ) ??
        (throw FormatException('Missing createdAtUtc in $json'));

    return UserProfile(
      uid: uid,
      createdAtUtc: createdAtUtc,
      lastSeenAtUtc: _dateTimeFromJson(
        mergedJson['lastSeenAtUtc'] ??
            mergedJson['lastSeenAt'] ??
            mergedJson['lastSeenUtc'],
      ),
      displayName: _stringOrNull(
        mergedJson['displayName'] ?? mergedJson['name'],
      ),
      isAnonymous: _boolFromJson(
        mergedJson['isAnonymous'] ?? mergedJson['anonymous'],
      ),
      providerIds: _stringListFromJson(
        mergedJson['providerIds'] ?? mergedJson['providerId'],
      ),
      schemaVersion: _intFromJson(
        mergedJson['schemaVersion'] ?? mergedJson['schema_version'],
        defaultValue: 1,
      ),
      preferences: UserPreferences.fromJson(<String, dynamic>{
        ...json,
        ..._stringKeyMap(mergedJson['preferences']),
      }),
    );
  }
}

List<PuzzleType> _puzzleTypesFromJson(Object? raw) {
  final Iterable<Object?> values;
  if (raw is String) {
    values = <Object?>[raw];
  } else if (raw is Iterable) {
    values = raw;
  } else {
    return const <PuzzleType>[];
  }

  final List<PuzzleType> parsed = <PuzzleType>[];
  for (final Object? value in values) {
    final PuzzleType? puzzleType = value is PuzzleType
        ? value
        : PuzzleType.fromKey(value?.toString() ?? '');
    if (puzzleType != null && !parsed.contains(puzzleType)) {
      parsed.add(puzzleType);
    }
  }
  return List<PuzzleType>.unmodifiable(parsed);
}

List<String> _stringListFromJson(Object? raw) {
  final Iterable<Object?> values;
  if (raw is String) {
    values = <Object?>[raw];
  } else if (raw is Iterable) {
    values = raw;
  } else {
    return const <String>[];
  }

  final List<String> parsed = <String>[];
  for (final Object? value in values) {
    final String? text = _stringOrNull(value);
    if (text == null || text.isEmpty || parsed.contains(text)) {
      continue;
    }
    parsed.add(text);
  }
  return List<String>.unmodifiable(parsed);
}

DateTime? _dateTimeFromJson(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is DateTime) {
    return raw.toUtc();
  }
  if (raw is String) {
    return DateTime.parse(raw).toUtc();
  }
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
  }
  throw FormatException('Invalid date value: $raw');
}

bool _boolFromJson(Object? raw, {bool defaultValue = false}) {
  if (raw == null) {
    return defaultValue;
  }
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    return raw != 0;
  }
  final String text = raw.toString().toLowerCase();
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return defaultValue;
}

int _intFromJson(Object? raw, {required int defaultValue}) {
  if (raw == null) {
    return defaultValue;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse(raw.toString()) ?? defaultValue;
}

String? _stringOrNull(Object? raw) {
  if (raw is String) {
    return raw;
  }
  return null;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final String? value = _stringOrNull(json[key]);
  if (value == null || value.isEmpty) {
    throw FormatException('Missing $key in $json');
  }
  return value;
}

Map<String, dynamic> _stringKeyMap(Object? raw) {
  if (raw is! Map) {
    return const <String, dynamic>{};
  }

  return raw.map<String, dynamic>(
    (dynamic key, dynamic value) =>
        MapEntry<String, dynamic>(key.toString(), value),
  );
}
