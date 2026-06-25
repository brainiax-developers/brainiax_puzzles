abstract final class AppRoutes {
  static const String home = '/';
  static const String daily = '/daily';
  static const String puzzles = '/puzzles';
  static const String legacyPuzzles = '/select';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String bench = '/bench';

  static String play(String puzzleTypeKey, String modeKey) =>
      '/play/$puzzleTypeKey/$modeKey';

  static String legacyPlay(String puzzleTypeKey) => '/play/$puzzleTypeKey';
}
