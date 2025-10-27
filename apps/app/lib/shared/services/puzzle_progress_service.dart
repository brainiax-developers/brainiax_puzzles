import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart' as app;

/// Stores last in-progress puzzle per puzzle type.
class PuzzleProgressService {
  static const String _ns = 'progress.v1';

  final SharedPreferences _prefs;

  PuzzleProgressService(this._prefs);

  String _key(app.PuzzleType type) => '$_ns.${type.key}';

  Future<void> save(app.PuzzleType type, core.GeneratedPuzzle<dynamic> puzzle) async {
    try {
      final String jsonStr = jsonEncode(puzzle.toJson());
      await _prefs.setString(_key(type), jsonStr);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PuzzleProgressService.save failed: $e');
      }
    }
  }

  Future<void> clear(app.PuzzleType type) async {
    await _prefs.remove(_key(type));
  }

  bool exists(app.PuzzleType type) {
    return _prefs.containsKey(_key(type));
  }

  core.GeneratedPuzzle<dynamic>? load(app.PuzzleType type) {
    final String? jsonStr = _prefs.getString(_key(type));
    if (jsonStr == null) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr) as Map<String, dynamic>;
  final String engineId = type.key; // engines map 1:1 with puzzle type
  final stateFromJson = _stateParserFor(engineId);
      if (stateFromJson == null) return null;
  return core.GeneratedPuzzle<dynamic>.fromJson(map, stateFromJson);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PuzzleProgressService.load failed: $e');
      }
      return null;
    }
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
      case 'futoshiki_classic':
        return (json) => core.FutoshikiBoard.fromJson(json);
      case 'takuzu_binary':
        return (json) => core.TakuzuBoard.fromJson(json);
      default:
        return null;
    }
  }
}
