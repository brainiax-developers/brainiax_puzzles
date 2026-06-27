import 'dart:async';

import 'package:app/shared/sync/sync_engine.dart';
import 'package:app/shared/sync/sync_lifecycle_controller.dart';
import 'package:app/shared/sync/sync_queue_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup flush schedules one pending sync retry', () async {
    final process = _RecordingProcess();
    final controller = SyncLifecycleController(
      processPending: process.processPending,
    );

    controller.scheduleStartupFlush();
    controller.scheduleStartupFlush();

    await pumpEventQueue();

    expect(process.calls, 1);
  });

  test('resume flush calls pending sync retry', () async {
    final process = _RecordingProcess();
    final controller = SyncLifecycleController(
      processPending: process.processPending,
    );

    final result = await controller.flushPending(SyncLifecycleTrigger.resume);

    expect(process.calls, 1);
    expect(result.skipped, isFalse);
  });

  test('concurrent lifecycle flushes do not duplicate work', () async {
    final completer = Completer<SyncEngineResult>();
    final controller = SyncLifecycleController(
      processPending: ({int? limit}) => completer.future,
    );

    final first = controller.flushPending(SyncLifecycleTrigger.resume);
    final second = await controller.flushPending(SyncLifecycleTrigger.resume);
    completer.complete(
      const SyncEngineResult(attempted: 1, synced: 1, failed: 0),
    );

    expect(second.skipped, isTrue);
    expect(second.skippedReason, 'lifecycle-already-flushing');
    expect((await first).synced, 1);
  });

  test('sync retry failures are reported and never thrown', () async {
    final reporter = _RecordingFailureReporter();
    final controller = SyncLifecycleController(
      processPending: ({int? limit}) => throw StateError('offline'),
      failureReporter: reporter,
    );

    final result = await controller.flushPending(SyncLifecycleTrigger.startup);

    expect(result.skipped, isTrue);
    expect(result.skippedReason, 'lifecycle-flush-failed');
    expect(reporter.operations, <String>['lifecycle-startup']);
  });

  test('failure reporter errors are swallowed', () async {
    final controller = SyncLifecycleController(
      processPending: ({int? limit}) => throw StateError('offline'),
      failureReporter: _ThrowingFailureReporter(),
    );

    await expectLater(
      controller.flushPending(SyncLifecycleTrigger.resume),
      completes,
    );
  });
}

class _RecordingProcess {
  int calls = 0;

  Future<SyncEngineResult> processPending({int? limit}) async {
    calls += 1;
    return const SyncEngineResult(attempted: 0, synced: 0, failed: 0);
  }
}

class _RecordingFailureReporter implements SyncFailureReporter {
  final List<String?> operations = <String?>[];

  @override
  Future<void> recordSyncFailure(
    Object error,
    StackTrace stackTrace, {
    SyncQueueItem? item,
    String? operation,
  }) async {
    operations.add(operation);
  }
}

class _ThrowingFailureReporter implements SyncFailureReporter {
  @override
  Future<void> recordSyncFailure(
    Object error,
    StackTrace stackTrace, {
    SyncQueueItem? item,
    String? operation,
  }) async {
    throw StateError('Crash reporting unavailable');
  }
}
