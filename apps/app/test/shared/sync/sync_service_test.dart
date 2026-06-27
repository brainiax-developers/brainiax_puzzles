import 'package:app/shared/models/models.dart';
import 'package:app/shared/sync/sync_queue.dart';
import 'package:app/shared/sync/sync_queue_item.dart';
import 'package:app/shared/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    service = SyncService(SharedPreferencesSyncQueue(prefs));
  });

  test('completion queue items contain only minimal sync payload fields', () {
    final PuzzleCompletionRecord record = PuzzleCompletionRecord(
      id: 'record-1',
      puzzleType: PuzzleType.sudokuClassic,
      mode: PuzzleMode.daily,
      difficulty: 'easy',
      size: '9x9',
      seed: 'seed-1',
      completedAtUtc: DateTime.utc(2026, 6, 21, 12),
      elapsedMs: 12345,
      moveCount: 18,
      hintsUsed: 2,
      dailyDateKeyUtc: '2026-06-21',
    );

    final SyncQueueItem item = service.completionQueueItemForRecord(record);

    expect(item.id, 'completion:record-1');
    expect(item.type, SyncQueueItemType.puzzleCompletion);
    expect(item.status, SyncQueueItemStatus.pending);
    expect(item.payload, <String, dynamic>{
      'recordId': 'record-1',
      'puzzleType': 'sudoku_classic',
      'mode': 'daily',
      'difficulty': 'easy',
      'size': '9x9',
      'seed': 'seed-1',
      'completedAtUtc': '2026-06-21T12:00:00.000Z',
      'elapsedMs': 12345,
      'moveCount': 18,
      'hintsUsed': 2,
      'dailyDateKeyUtc': '2026-06-21',
    });
    expect(item.payload.containsKey('board'), isFalse);
    expect(item.payload.containsKey('solution'), isFalse);
  });

  test(
    'enqueue completion record stays idempotent through the queue',
    () async {
      final PuzzleCompletionRecord record = PuzzleCompletionRecord(
        id: 'record-2',
        puzzleType: PuzzleType.nonogramMono,
        mode: PuzzleMode.random,
        difficulty: 'normal',
        size: '10x10',
        seed: 'seed-2',
        completedAtUtc: DateTime.utc(2026, 6, 21, 13),
        elapsedMs: 20000,
        moveCount: 25,
        hintsUsed: 0,
        dailyDateKeyUtc: null,
      );

      await service.enqueueCompletionRecord(record);
      await service.enqueueCompletionRecord(record);

      final List<SyncQueueItem> items = await service.pending();

      expect(items, hasLength(1));
      expect(items.single.payload['recordId'], 'record-2');
    },
  );

  test('favourites update queue item uses timestamp id and metadata payload', () {
    final DateTime updatedAtUtc = DateTime.utc(2026, 6, 21, 14, 15, 16);

    final SyncQueueItem item = service.favouritesUpdateQueueItem(
      <PuzzleType>[
        PuzzleType.sudokuClassic,
        PuzzleType.nonogramMono,
        PuzzleType.sudokuClassic,
      ],
      createdAtUtc: updatedAtUtc,
    );

    expect(
      item.id,
      'favourites-update:${updatedAtUtc.microsecondsSinceEpoch}',
    );
    expect(item.type, SyncQueueItemType.favouritesUpdate);
    expect(item.payload, <String, dynamic>{
      'favourites': <String>['nonogram_mono', 'sudoku_classic'],
      'updatedAtUtc': '2026-06-21T14:15:16.000Z',
    });
  });

  test('duplicate favourites update id stays idempotent through the queue', () async {
    final DateTime updatedAtUtc = DateTime.utc(2026, 6, 21, 14, 15, 16);

    await service.enqueue(
      service.favouritesUpdateQueueItem(
        <PuzzleType>[PuzzleType.sudokuClassic],
        createdAtUtc: updatedAtUtc,
      ),
    );
    await service.enqueue(
      service.favouritesUpdateQueueItem(
        <PuzzleType>[PuzzleType.nonogramMono],
        createdAtUtc: updatedAtUtc,
      ),
    );

    final List<SyncQueueItem> items = await service.pending();

    expect(items, hasLength(1));
    expect(items.single.payload['favourites'], <String>['sudoku_classic']);
  });
}
