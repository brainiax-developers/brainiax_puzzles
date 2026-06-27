enum SyncQueueItemType {
  puzzleCompletion('puzzle_completion'),
  statsSnapshot('stats_snapshot');

  const SyncQueueItemType(this.key);

  final String key;

  static SyncQueueItemType? fromKey(String key) {
    for (final type in SyncQueueItemType.values) {
      if (type.key == key) {
        return type;
      }
    }
    return null;
  }
}

enum SyncQueueItemStatus {
  pending('pending'),
  syncing('syncing'),
  synced('synced'),
  failed('failed');

  const SyncQueueItemStatus(this.key);

  final String key;

  static SyncQueueItemStatus? fromKey(String key) {
    for (final status in SyncQueueItemStatus.values) {
      if (status.key == key) {
        return status;
      }
    }
    return null;
  }
}

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAtUtc,
    required this.attempts,
    required this.lastAttemptAtUtc,
    required this.status,
    required this.lastError,
  });

  final String id;
  final SyncQueueItemType type;
  final Map<String, dynamic> payload;
  final DateTime createdAtUtc;
  final int attempts;
  final DateTime? lastAttemptAtUtc;
  final SyncQueueItemStatus status;
  final String? lastError;

  SyncQueueItem copyWith({
    String? id,
    SyncQueueItemType? type,
    Map<String, dynamic>? payload,
    DateTime? createdAtUtc,
    int? attempts,
    DateTime? lastAttemptAtUtc,
    bool clearLastAttemptAtUtc = false,
    SyncQueueItemStatus? status,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      createdAtUtc: (createdAtUtc ?? this.createdAtUtc).toUtc(),
      attempts: attempts ?? this.attempts,
      lastAttemptAtUtc: clearLastAttemptAtUtc
          ? null
          : (lastAttemptAtUtc ?? this.lastAttemptAtUtc)?.toUtc(),
      status: status ?? this.status,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.key,
    'payload': payload,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'attempts': attempts,
    'lastAttemptAtUtc': lastAttemptAtUtc?.toUtc().toIso8601String(),
    'status': status.key,
    'lastError': lastError,
  };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    final SyncQueueItemType? type = SyncQueueItemType.fromKey(
      json['type'] as String? ?? '',
    );
    final SyncQueueItemStatus? status = SyncQueueItemStatus.fromKey(
      json['status'] as String? ?? '',
    );
    final Object? rawPayload = json['payload'];
    if (type == null || status == null || rawPayload is! Map) {
      throw FormatException('Invalid sync queue item: $json');
    }

    return SyncQueueItem(
      id: json['id'] as String,
      type: type,
      payload: Map<String, dynamic>.from(rawPayload),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      attempts: json['attempts'] as int? ?? 0,
      lastAttemptAtUtc: json['lastAttemptAtUtc'] == null
          ? null
          : DateTime.parse(json['lastAttemptAtUtc'] as String).toUtc(),
      status: status,
      lastError: json['lastError'] as String?,
    );
  }
}
