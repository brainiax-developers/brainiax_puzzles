import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class FavouritePuzzleService {
  FavouritePuzzleService(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'favourites.v1.puzzle_types';

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
    return isFavourite;
  }

  bool isFavourite(PuzzleType puzzleType) => _keys().contains(puzzleType.key);

  List<PuzzleType> favourites() {
    final keys = _keys().toSet();
    return PuzzleType.values.where((type) => keys.contains(type.key)).toList();
  }

  List<String> _keys() => _prefs.getStringList(_key) ?? const <String>[];
}
