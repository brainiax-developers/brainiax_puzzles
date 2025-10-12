class DeterminismGuard {
  DeterminismGuard._();

  static void assertNoFloatsOrDateTimes(dynamic value) {
    if (value is double) {
      throw StateError('Floating point values are not allowed in deterministic state');
    }
    if (value is DateTime) {
      throw StateError('DateTime instances are not allowed in deterministic state');
    }
    if (value is Map) {
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        assertNoFloatsOrDateTimes(entry.value);
      }
      return;
    }
    if (value is Iterable) {
      for (final dynamic element in value) {
        assertNoFloatsOrDateTimes(element);
      }
    }
  }
}
