import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart' as app;

/// Stores the last active puzzle run per puzzle type.
class PuzzleProgressService {
  static const String _activeRunNs = 'active_run.v1';
  static const String _legacyNs = 'progress.v1';

  final SharedPreferences _prefs;

  PuzzleProgressService(this._prefs);

  String _legacyActiveRunKey(app.PuzzleType type) =>
      '$_activeRunNs.${type.key}';
  String _activeRunPrefix(app.PuzzleType type) => '$_activeRunNs.${type.key}.';
  String _activeRunKey({
    required app.PuzzleType type,
    required app.PuzzleMode mode,
    String? dailyDateKeyUtc,
  }) {
    if (mode == app.PuzzleMode.daily) {
      return '$_activeRunNs.${type.key}.${mode.key}.${dailyDateKeyUtc ?? app.DailyUtcDate.todayKey()}';
    }
    return '$_activeRunNs.${type.key}.${mode.key}';
  }

  String _legacyKey(app.PuzzleType type) => '$_legacyNs.${type.key}';

  Future<void> saveActiveRun(app.ActivePuzzleRun run) async {
    try {
      await _prefs.setString(
        _activeRunKey(
          type: run.puzzleType,
          mode: run.mode,
          dailyDateKeyUtc: run.dailyDateKeyUtc,
        ),
        jsonEncode(run.toJson()),
      );
      await _prefs.remove(_legacyActiveRunKey(run.puzzleType));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PuzzleProgressService.saveActiveRun failed: $e');
      }
    }
  }

  Future<void> saveRunForPuzzle({
    required app.PuzzleType puzzleType,
    required app.PuzzleMode mode,
    required core.GeneratedPuzzle<dynamic> puzzle,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
    bool isSolved = false,
    String? dailyDateKeyUtc,
    Map<int, Set<int>> notes = const <int, Set<int>>{},
  }) async {
    final DateTime nowUtc = DateTime.now().toUtc();
    final String? resolvedDailyDateKeyUtc = mode == app.PuzzleMode.daily
        ? (dailyDateKeyUtc ?? app.DailyUtcDate.todayKey())
        : null;
    final existing = await loadActiveRunFor(
      type: puzzleType,
      mode: mode,
      dailyDateKeyUtc: resolvedDailyDateKeyUtc,
    );
    final run = app.ActivePuzzleRun(
      puzzleType: puzzleType,
      mode: mode,
      difficulty: puzzle.meta.difficulty.level,
      size: puzzle.meta.size.id,
      seed: puzzle.meta.seedStr,
      generatedPuzzleJson: puzzle.toJson(),
      createdAtUtc: existing?.createdAtUtc ?? nowUtc,
      updatedAtUtc: nowUtc,
      elapsedMs: elapsed.inMilliseconds,
      moveCount: moveCount,
      hintsUsed: hintsUsed,
      isSolved: isSolved,
      dailyDateKeyUtc: resolvedDailyDateKeyUtc,
      notes: notes,
    );
    await saveActiveRun(run);
  }

  Future<void> updateStats(
    app.PuzzleType type, {
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
    bool? isSolved,
  }) async {
    final run = await loadActiveRun(type);
    if (run == null) {
      return;
    }
    await saveActiveRun(
      run.copyWith(
        updatedAtUtc: DateTime.now().toUtc(),
        elapsedMs: elapsed.inMilliseconds,
        moveCount: moveCount,
        hintsUsed: hintsUsed,
        isSolved: isSolved,
      ),
    );
  }

  Future<void> updateStatsForRun({
    required app.PuzzleType type,
    required app.PuzzleMode mode,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
    String? dailyDateKeyUtc,
    bool? isSolved,
  }) async {
    final run = await loadActiveRunFor(
      type: type,
      mode: mode,
      dailyDateKeyUtc: dailyDateKeyUtc,
    );
    if (run == null) {
      return;
    }
    await saveActiveRun(
      run.copyWith(
        updatedAtUtc: DateTime.now().toUtc(),
        elapsedMs: elapsed.inMilliseconds,
        moveCount: moveCount,
        hintsUsed: hintsUsed,
        isSolved: isSolved,
      ),
    );
  }

  Future<app.ActivePuzzleRun?> loadActiveRun(app.PuzzleType type) async {
    final runs = await loadActiveRunsForType(type);
    if (runs.isEmpty) {
      return null;
    }
    runs.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return runs.first;
  }

  Future<app.ActivePuzzleRun?> loadActiveRunFor({
    required app.PuzzleType type,
    required app.PuzzleMode mode,
    String? dailyDateKeyUtc,
  }) async {
    final run = await _loadActiveRunFromKey(
      _activeRunKey(type: type, mode: mode, dailyDateKeyUtc: dailyDateKeyUtc),
      removeInvalid: true,
    );
    if (run != null) {
      return run;
    }

    final legacy = await _loadLegacyActiveRun(type);
    if (legacy != null &&
        legacy.mode == mode &&
        (mode != app.PuzzleMode.daily ||
            legacy.dailyDateKeyUtc == dailyDateKeyUtc)) {
      return legacy;
    }
    return null;
  }

  Future<List<app.ActivePuzzleRun>> loadActiveRunsForType(
    app.PuzzleType type,
  ) async {
    final Map<String, app.ActivePuzzleRun> byIdentity =
        <String, app.ActivePuzzleRun>{};

    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_activeRunPrefix(type))) {
        continue;
      }
      final run = await _loadActiveRunFromKey(key, removeInvalid: true);
      if (run != null) {
        byIdentity[_identityFor(run)] = run;
      }
    }

    final legacyActive = await _loadLegacyActiveRun(type);
    if (legacyActive != null) {
      byIdentity.putIfAbsent(_identityFor(legacyActive), () => legacyActive);
    }

    final legacyProgress = _loadLegacyRun(type);
    if (legacyProgress != null) {
      byIdentity.putIfAbsent(
        _identityFor(legacyProgress),
        () => legacyProgress,
      );
    }

    return byIdentity.values.toList(growable: false);
  }

  Future<app.ActivePuzzleRun?> _loadLegacyActiveRun(app.PuzzleType type) async {
    return _loadActiveRunFromKey(
      _legacyActiveRunKey(type),
      removeInvalid: true,
    );
  }

  Future<app.ActivePuzzleRun?> _loadActiveRunFromKey(
    String key, {
    required bool removeInvalid,
  }) async {
    final String? jsonStr = _prefs.getString(key);
    if (jsonStr != null) {
      try {
        return app.ActivePuzzleRun.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonStr) as Map),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PuzzleProgressService.loadActiveRun failed: $e');
        }
        if (removeInvalid) {
          await _prefs.remove(key);
        }
        return null;
      }
    }
    return null;
  }

  Future<void> save(
    app.PuzzleType type,
    core.GeneratedPuzzle<dynamic> puzzle,
  ) async {
    await saveRunForPuzzle(
      puzzleType: type,
      mode: app.PuzzleMode.random,
      puzzle: puzzle,
      elapsed: Duration.zero,
      moveCount: 0,
      hintsUsed: 0,
    );
  }

  Future<void> clear(app.PuzzleType type) async {
    final keysToRemove = _prefs
        .getKeys()
        .where((key) => key.startsWith(_activeRunPrefix(type)))
        .toList(growable: false);
    for (final key in keysToRemove) {
      await _prefs.remove(key);
    }
    await _prefs.remove(_legacyActiveRunKey(type));
    await _prefs.remove(_legacyKey(type));
  }

  Future<void> clearRun({
    required app.PuzzleType type,
    required app.PuzzleMode mode,
    String? dailyDateKeyUtc,
  }) async {
    await _prefs.remove(
      _activeRunKey(type: type, mode: mode, dailyDateKeyUtc: dailyDateKeyUtc),
    );

    final legacy = await _loadLegacyActiveRun(type);
    if (legacy != null &&
        legacy.mode == mode &&
        (mode != app.PuzzleMode.daily ||
            legacy.dailyDateKeyUtc == dailyDateKeyUtc)) {
      await _prefs.remove(_legacyActiveRunKey(type));
    }
    if (mode == app.PuzzleMode.random) {
      await _prefs.remove(_legacyKey(type));
    }
  }

  bool exists(app.PuzzleType type) {
    return _prefs.getKeys().any(
          (key) => key.startsWith(_activeRunPrefix(type)),
        ) ||
        _prefs.containsKey(_legacyActiveRunKey(type)) ||
        _prefs.containsKey(_legacyKey(type));
  }

  core.GeneratedPuzzle<dynamic>? load(app.PuzzleType type) {
    final List<app.ActivePuzzleRun> runs = <app.ActivePuzzleRun>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_activeRunPrefix(type))) {
        continue;
      }
      final String? active = _prefs.getString(key);
      if (active == null) {
        continue;
      }
      try {
        runs.add(
          app.ActivePuzzleRun.fromJson(
            Map<String, dynamic>.from(jsonDecode(active) as Map),
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PuzzleProgressService.load active failed: $e');
        }
      }
    }
    final String? legacyActive = _prefs.getString(_legacyActiveRunKey(type));
    if (legacyActive != null) {
      try {
        runs.add(
          app.ActivePuzzleRun.fromJson(
            Map<String, dynamic>.from(jsonDecode(legacyActive) as Map),
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PuzzleProgressService.load legacy active failed: $e');
        }
      }
    }
    if (runs.isNotEmpty) {
      runs.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
      return loadPuzzleForRun(runs.first);
    }
    final String? legacy = _prefs.getString(_legacyKey(type));
    if (legacy == null) return null;
    try {
      return _decodePuzzle(
        type,
        Map<String, dynamic>.from(jsonDecode(legacy) as Map),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PuzzleProgressService.load legacy failed: $e');
      }
      return null;
    }
  }

  core.GeneratedPuzzle<dynamic>? loadPuzzleForRun(app.ActivePuzzleRun run) {
    return _decodePuzzle(run.puzzleType, run.generatedPuzzleJson);
  }

  String _identityFor(app.ActivePuzzleRun run) {
    if (run.mode == app.PuzzleMode.daily) {
      return '${run.puzzleType.key}:${run.mode.key}:${run.dailyDateKeyUtc ?? ''}';
    }
    return '${run.puzzleType.key}:${run.mode.key}';
  }

  app.ActivePuzzleRun? _loadLegacyRun(app.PuzzleType type) {
    final String? jsonStr = _prefs.getString(_legacyKey(type));
    if (jsonStr == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
      final puzzle = _decodePuzzle(type, map);
      if (puzzle == null) {
        _prefs.remove(_legacyKey(type));
        return null;
      }
      final nowUtc = DateTime.now().toUtc();
      return app.ActivePuzzleRun(
        puzzleType: type,
        mode: app.PuzzleMode.random,
        difficulty: puzzle.meta.difficulty.level,
        size: puzzle.meta.size.id,
        seed: puzzle.meta.seedStr,
        generatedPuzzleJson: map,
        createdAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
        elapsedMs: 0,
        moveCount: 0,
        hintsUsed: 0,
        isSolved: false,
        dailyDateKeyUtc: null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PuzzleProgressService._loadLegacyRun failed: $e');
      }
      _prefs.remove(_legacyKey(type));
      return null;
    }
  }

  core.GeneratedPuzzle<dynamic>? _decodePuzzle(
    app.PuzzleType type,
    Map<String, dynamic> map,
  ) {
    final stateFromJson = _stateParserFor(type.key);
    if (stateFromJson == null) return null;
    return core.GeneratedPuzzle<dynamic>.fromJson(map, stateFromJson);
  }

  dynamic Function(Map<String, dynamic>)? _stateParserFor(String engineId) {
    switch (engineId) {
      case 'sudoku_classic':
        return (json) => core.SudokuBoard.fromJson(json);
      case 'nonogram_mono':
        return (json) => core.NonogramBoard.fromJson(json);

      case 'slitherlink_loop':
        return (json) => core.SlitherlinkBoard.fromJson(json);
      case 'mathdoku_classic':
        return (json) => core.MathdokuBoard.fromJson(json);
      case 'killer_queens':
        return (json) => core.KillerQueensBoard.fromJson(json);
      case 'takuzu_binary':
        return (json) => core.TakuzuBoard.fromJson(json);
      default:
        return null;
    }
  }
}
