abstract interface class CrashReportingService {
  Future<void> reportNonFatal({
    required String reason,
    required Object error,
    required StackTrace stackTrace,
    Map<String, Object?> context,
  });
}

abstract interface class CrashlyticsClient {
  Future<void> recordError(
    Object exception,
    StackTrace stack, {
    String? reason,
    Iterable<Object> information,
    bool fatal,
  });
}

class FirebaseCrashReportingService implements CrashReportingService {
  FirebaseCrashReportingService(
    CrashlyticsClient crashlytics, {
    CrashContextSanitizer sanitizer = const CrashContextSanitizer(),
  }) : _crashlytics = crashlytics,
       _sanitizer = sanitizer;

  final CrashlyticsClient _crashlytics;
  final CrashContextSanitizer _sanitizer;

  @override
  Future<void> reportNonFatal({
    required String reason,
    required Object error,
    required StackTrace stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    final Map<String, Object> sanitizedContext = _sanitizer.sanitize(context);
    final List<String> information = <String>[
      'errorType=${error.runtimeType}',
      ..._informationLinesFor(sanitizedContext),
    ];

    try {
      await _crashlytics.recordError(
        _SanitizedCrashError(reason: reason, errorType: error.runtimeType),
        stackTrace,
        reason: reason,
        information: information,
        fatal: false,
      );
    } catch (_) {
      // Crash reporting failures must never affect the app.
    }
  }

  Iterable<String> _informationLinesFor(Map<String, Object> context) {
    final List<MapEntry<String, Object>> entries = context.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}=${entry.value}');
  }
}

class NoopCrashReportingService implements CrashReportingService {
  const NoopCrashReportingService();

  @override
  Future<void> reportNonFatal({
    required String reason,
    required Object error,
    required StackTrace stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {}
}

class CrashContextSanitizer {
  const CrashContextSanitizer();

  static const Set<String> _allowedKeys = <String>{
    'attempt',
    'attempts',
    'difficulty',
    'elapsedMs',
    'engineId',
    'failureCode',
    'generatedDifficulty',
    'height',
    'maxAttempts',
    'operation',
    'provider',
    'puzzleType',
    'queueLimit',
    'requestedDifficulty',
    'resultStatus',
    'size',
    'skippedReason',
    'stage',
    'surface',
    'syncItemAttempts',
    'syncItemId',
    'syncItemType',
    'timeoutMs',
    'upgradePath',
    'width',
  };

  Map<String, Object> sanitize(Map<String, Object?> context) {
    final Map<String, Object> sanitized = <String, Object>{};
    for (final MapEntry<String, Object?> entry in context.entries) {
      if (!_allowedKeys.contains(entry.key)) {
        continue;
      }
      final Object? value = _sanitizeValue(entry.value);
      if (value == null) {
        continue;
      }
      sanitized[entry.key] = value;
    }
    return Map<String, Object>.unmodifiable(sanitized);
  }

  Object? _sanitizeValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return trimmed.length <= 160 ? trimmed : trimmed.substring(0, 160);
    }
    if (value is bool || value is int || value is double) {
      return value;
    }
    if (value is num) {
      return value;
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Duration) {
      return value.inMilliseconds;
    }
    return null;
  }
}

Map<String, Object> sanitizeCrashContext(Map<String, Object?> context) {
  return const CrashContextSanitizer().sanitize(context);
}

class _SanitizedCrashError implements Exception {
  const _SanitizedCrashError({required this.reason, required this.errorType});

  final String reason;
  final Type errorType;

  @override
  String toString() => '$reason (${errorType.toString()})';
}
