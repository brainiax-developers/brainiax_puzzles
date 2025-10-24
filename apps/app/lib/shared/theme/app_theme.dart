import 'package:flutter/material.dart';
import '../models/models.dart';

enum Contrast { normal, high }

class AppTheme {
  static ThemeData light([Contrast c = Contrast.normal]) {
    final baseTheme = ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );

    if (c == Contrast.high) {
      return baseTheme.copyWith(
        // Enhanced contrast colors
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: const Color(0xFF000080), // Darker blue
          secondary: const Color(0xFF000000), // Pure black
          surface: const Color(0xFFFFFFFF), // Pure white
          onSurface: const Color(0xFF000000), // Pure black
          onPrimary: const Color(0xFFFFFFFF), // Pure white
          outline: const Color(0xFF000000), // Black borders
          outlineVariant: const Color(0xFF666666), // Darker gray
        ),
        // Enhanced text theme with higher contrast
        textTheme: baseTheme.textTheme.copyWith(
          displayLarge: baseTheme.textTheme.displayLarge?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w900,
          ),
          displayMedium: baseTheme.textTheme.displayMedium?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w900,
          ),
          displaySmall: baseTheme.textTheme.displaySmall?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w800,
          ),
          headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w700,
          ),
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w700,
          ),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w600,
          ),
          titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        // Enhanced card theme with stronger borders
        cardTheme: baseTheme.cardTheme.copyWith(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF000000), width: 2),
          ),
        ),
        // Enhanced input decoration with stronger borders
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF000000), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF000000), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF000080), width: 3),
          ),
        ),
      );
    }

    return baseTheme;
  }

  static ThemeData dark([Contrast c = Contrast.normal]) {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );

    if (c == Contrast.high) {
      return baseTheme.copyWith(
        // Enhanced contrast colors for dark theme
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: const Color(0xFF4FC3F7), // Bright cyan
          secondary: const Color(0xFFFFFFFF), // Pure white
          surface: const Color(0xFF000000), // Pure black
          onSurface: const Color(0xFFFFFFFF), // Pure white
          onPrimary: const Color(0xFF000000), // Pure black
          outline: const Color(0xFFFFFFFF), // White borders
          outlineVariant: const Color(0xFFCCCCCC), // Light gray
        ),
        // Enhanced text theme with higher contrast
        textTheme: baseTheme.textTheme.copyWith(
          displayLarge: baseTheme.textTheme.displayLarge?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w900,
          ),
          displayMedium: baseTheme.textTheme.displayMedium?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w900,
          ),
          displaySmall: baseTheme.textTheme.displaySmall?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w800,
          ),
          headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w600,
          ),
          titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w500,
          ),
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w500,
          ),
        ),
        // Enhanced card theme with stronger borders
        cardTheme: baseTheme.cardTheme.copyWith(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFFFFFFF), width: 2),
          ),
        ),
        // Enhanced input decoration with stronger borders
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 3),
          ),
        ),
      );
    }

    return baseTheme;
  }
}

// Puzzle-specific theme tweaks.
class AppThemeData {
  /// Return a ThemeData based on [base] but tweaked for [puzzleType].
  /// This is intentionally lightweight: it changes the colorScheme's primary
  /// and secondary colors to give each puzzle type a distinct accent.
  static ThemeData forPuzzleType(PuzzleType? puzzleType, ThemeData base) {
    if (puzzleType == null) return base;

    // Choose an accent color per puzzle type.
    Color seedColor;
    switch (puzzleType) {
      case PuzzleType.sudokuClassic:
        seedColor = Colors.teal;
        break;
      case PuzzleType.nonogramMono:
        seedColor = Colors.deepOrange;
        break;
      case PuzzleType.kakuroClassic:
        seedColor = Colors.purple;
        break;
      case PuzzleType.slitherlinkLoop:
        seedColor = Colors.indigo;
        break;
      case PuzzleType.mathdokuClassic:
        seedColor = Colors.green;
        break;
      case PuzzleType.futoshikiClassic:
        seedColor = Colors.amber;
        break;
      case PuzzleType.takuzuBinary:
        seedColor = Colors.blueGrey;
        break;
      default:
        seedColor = Colors.indigo;
    }

    // Return a copy with a colorScheme seeded from the chosen color.
    final newBase = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: seedColor,
        // `seedColor` may be a plain Color (not MaterialColor) so use a
        // slightly transparent variant as the secondary accent instead
        // of accessing `shade200` which only exists on MaterialColor.
        secondary: seedColor.withOpacity(0.85),
      ),
    );

    return newBase;
  }
}
