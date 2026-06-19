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

  String _activeRunKey(app.PuzzleType type) => '$_activeRunNs.${type.key}';
  String _legacyKey(app.PuzzleType type) => '$_legacyNs.${type.key}';

  Future<void> saveActiveRun(app.ActivePuzzleRun run) async {
    try {
      await _prefs.setString(
        _activeRunKey(run.puzzleType),
        jsonEncode(run.toJson()),
      );
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
    final existing = await loadActiveRun(puzzleType);
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
      dailyDateKeyUtc: mode == app.PuzzleMode.daily
          ? (dailyDateKeyUtc ?? app.DailyUtcDate.todayKey())
          : null,
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

  Future<app.ActivePuzzleRun?> loadActiveRun(app.PuzzleType type) async {
    final String? jsonStr = _prefs.getString(_activeRunKey(type));
    if (jsonStr != null) {
      try {
        return app.ActivePuzzleRun.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonStr) as Map),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PuzzleProgressService.loadActiveRun failed: $e');
        }
        await _prefs.remove(_activeRunKey(type));
        return null;
      }
    }
    return _loadLegacyRun(type);
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
    await _prefs.remove(_activeRunKey(type));
    await _prefs.remove(_legacyKey(type));
  }

  bool exists(app.PuzzleType type) {
    return _prefs.containsKey(_activeRunKey(type)) ||
        _prefs.containsKey(_legacyKey(type));
  }

  core.GeneratedPuzzle<dynamic>? load(app.PuzzleType type) {
    final String? active = _prefs.getString(_activeRunKey(type));
    if (active != null) {
      try {
        final run = app.ActivePuzzleRun.fromJson(
          Map<String, dynamic>.from(jsonDecode(active) as Map),
        );
        return _decodePuzzle(type, run.generatedPuzzleJson);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PuzzleProgressService.load active failed: $e');
        }
        return null;
      }
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
      case 'kakuro_classic':
        return (json) => core.KakuroBoard.fromJson(json);
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
