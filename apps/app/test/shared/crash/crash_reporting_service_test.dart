import 'package:app/shared/crash/crash_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeCrashContext keeps only allowlisted scalar fields', () {
    final Map<String, Object> sanitized = sanitizeCrashContext(
      <String, Object?>{
        'puzzleType': 'sudoku_classic',
        'difficulty': 'hard',
        'attempts': 3,
        'width': 9,
        'board': '1,2,3,4',
        'solution': '4,3,2,1',
        'generatedPuzzleJson': '{"board":[[1,2],[3,4]]}',
        'payload': <String, Object?>{'notes': 'secret'},
        'notes': 'private note',
        'clues': <int>[1, 2, 3],
      },
    );

    expect(sanitized, <String, Object>{
      'puzzleType': 'sudoku_classic',
      'difficulty': 'hard',
      'attempts': 3,
      'width': 9,
    });
  });

  test(
    'firebase crash reporting drops unsafe payloads and error messages',
    () async {
      final _FakeCrashlyticsClient client = _FakeCrashlyticsClient();
      final FirebaseCrashReportingService service =
          FirebaseCrashReportingService(client);

      await service.reportNonFatal(
        reason: 'puzzle_generation_failure',
        error: StateError('solution={"grid":[1,2,3]}'),
        stackTrace: StackTrace.current,
        context: <String, Object?>{
          'puzzleType': 'kakuro_classic',
          'difficulty': 'expert',
          'board': '{"cells":[1,2,3]}',
          'notes': 'do not send',
          'clues': <int>[1, 2, 3],
        },
      );

      expect(client.records, hasLength(1));
      final _RecordedCrash record = client.records.single;
      expect(record.reason, 'puzzle_generation_failure');
      expect(record.fatal, isFalse);
      expect(
        record.exception.toString(),
        'puzzle_generation_failure (StateError)',
      );
      expect(record.exception.toString(), isNot(contains('solution')));
      expect(record.information, contains('errorType=StateError'));
      expect(record.information, contains('difficulty=expert'));
      expect(record.information, contains('puzzleType=kakuro_classic'));
      expect(
        record.information.join(' '),
        isNot(anyOf(contains('board'), contains('notes'), contains('clues'))),
      );
    },
  );

  test('firebase crash reporting swallows client failures', () async {
    final FirebaseCrashReportingService service = FirebaseCrashReportingService(
      _ThrowingCrashlyticsClient(),
    );

    await expectLater(
      service.reportNonFatal(
        reason: 'sync_failure',
        error: StateError('should not escape'),
        stackTrace: StackTrace.current,
      ),
      completes,
    );
  });

  test('noop crash reporting service is safe to call', () async {
    const NoopCrashReportingService service = NoopCrashReportingService();

    await expectLater(
      service.reportNonFatal(
        reason: 'auth_link_failure',
        error: StateError('ignored'),
        stackTrace: StackTrace.current,
      ),
      completes,
    );
  });
}

class _FakeCrashlyticsClient implements CrashlyticsClient {
  final List<_RecordedCrash> records = <_RecordedCrash>[];

  @override
  Future<void> recordError(
    Object exception,
    StackTrace stack, {
    String? reason,
    Iterable<Object> information = const <Object>[],
    bool fatal = false,
  }) async {
    records.add(
      _RecordedCrash(
        exception: exception,
        stackTrace: stack,
        reason: reason,
        information: information.map((Object item) => item.toString()).toList(),
        fatal: fatal,
      ),
    );
  }
}

class _ThrowingCrashlyticsClient implements CrashlyticsClient {
  @override
  Future<void> recordError(
    Object exception,
    StackTrace stack, {
    String? reason,
    Iterable<Object> information = const <Object>[],
    bool fatal = false,
  }) async {
    throw StateError('Crashlytics unavailable');
  }
}

class _RecordedCrash {
  const _RecordedCrash({
    required this.exception,
    required this.stackTrace,
    required this.reason,
    required this.information,
    required this.fatal,
  });

  final Object exception;
  final StackTrace stackTrace;
  final String? reason;
  final List<String> information;
  final bool fatal;
}
