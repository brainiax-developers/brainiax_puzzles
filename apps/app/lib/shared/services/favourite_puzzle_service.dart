import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class FavouritePuzzleService {
  FavouritePuzzleService(
    this._prefs, {
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final SharedPreferences _prefs;
  final DateTime Function() _nowUtc;

  static const String _key = 'favourites.v1.puzzle_types';
  static const String _updatedAtKey = 'favourites.v1.updated_at_utc';

  Future<bool> toggle(PuzzleType puzzleType) async {
    final values = _keys().toSet();
    final bool isFavourite;
    if (values.contains(puzzleType.key)) {
      values.remove(puzzleType.key);
      isFavourite = false;
    } else {
      values.add(puzzleType.key);
      isFavourite = true;
    }
    await _prefs.setStringList(_key, values.toList()..sort());
    await _prefs.setString(_updatedAtKey, _nowUtc().toUtc().toIso8601String());
    return isFavourite;
  }

  bool isFavourite(PuzzleType puzzleType) => _keys().contains(puzzleType.key);

  List<PuzzleType> favourites() {
    final keys = _keys().toSet();
    return PuzzleType.values.where((type) => keys.contains(type.key)).toList();
  }

  DateTime? updatedAtUtc() {
    final raw = _prefs.getString(_updatedAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  List<String> _keys() => _prefs.getStringList(_key) ?? const <String>[];
}
