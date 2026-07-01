import 'dart:async';

import 'sync_engine.dart';

enum SyncLifecycleTrigger {
  startup('startup'),
  resume('resume');

  const SyncLifecycleTrigger(this.key);

  final String key;
}

typedef RetryFailedAndProcessPendingSync =
    Future<SyncEngineResult> Function({int? limit});

class SyncLifecycleController {
  SyncLifecycleController({
    required RetryFailedAndProcessPendingSync retryFailedAndProcessPending,
    SyncFailureReporter? failureReporter,
  }) : _retryFailedAndProcessPending = retryFailedAndProcessPending,
       _failureReporter = failureReporter;

  final RetryFailedAndProcessPendingSync _retryFailedAndProcessPending;
  final SyncFailureReporter? _failureReporter;

  bool _startupFlushScheduled = false;
  bool _isFlushing = false;

  void scheduleStartupFlush({int? limit}) {
    if (_startupFlushScheduled) {
      return;
    }
    _startupFlushScheduled = true;
    unawaited(
      Future<void>.microtask(() async {
        await flushPending(SyncLifecycleTrigger.startup, limit: limit);
      }),
    );
  }

  Future<SyncEngineResult> flushPending(
    SyncLifecycleTrigger trigger, {
    int? limit,
  }) async {
    if (_isFlushing) {
      return const SyncEngineResult.skipped('lifecycle-already-flushing');
    }

    _isFlushing = true;
    try {
      return await _retryFailedAndProcessPending(limit: limit);
    } catch (error, stackTrace) {
      await _reportFailure(error, stackTrace, trigger: trigger);
      return const SyncEngineResult.skipped('lifecycle-flush-failed');
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _reportFailure(
    Object error,
    StackTrace stackTrace, {
    required SyncLifecycleTrigger trigger,
  }) async {
    final SyncFailureReporter? reporter = _failureReporter;
    if (reporter == null) {
      return;
    }

    try {
      await reporter.recordSyncFailure(
        error,
        stackTrace,
        operation: 'lifecycle-${trigger.key}',
      );
    } catch (_) {
      // Lifecycle sync retry failures must never affect app startup or play.
    }
  }
}
