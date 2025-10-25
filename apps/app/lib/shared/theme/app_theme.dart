import 'package:flutter/material.dart';
import '../models/models.dart';

// Spacing scale ThemeExtension for consistent paddings and gaps across the app.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs; // 4
  final double s; // 8
  final double m; // 12
  final double l; // 16
  final double xl; // 24
  final double xxl; // 32

  const AppSpacing({
    this.xs = 4,
    this.s = 8,
    this.m = 12,
    this.l = 16,
    this.xl = 24,
    this.xxl = 32,
  });

  static const standard = AppSpacing();

  @override
  AppSpacing copyWith({double? xs, double? s, double? m, double? l, double? xl, double? xxl}) {
    return AppSpacing(
      xs: xs ?? this.xs,
      s: s ?? this.s,
      m: m ?? this.m,
      l: l ?? this.l,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    double _lerp(double a, double b) => a + (b - a) * t;
    return AppSpacing(
      xs: _lerp(xs, other.xs),
      s: _lerp(s, other.s),
      m: _lerp(m, other.m),
      l: _lerp(l, other.l),
      xl: _lerp(xl, other.xl),
      xxl: _lerp(xxl, other.xxl),
    );
  }
}

enum Contrast { normal, high }

class AppTheme {
  static ThemeData _applyCommonTweaks(ThemeData baseTheme) {
    final withTextContrast = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        bodyColor: baseTheme.colorScheme.onSurface,
        displayColor: baseTheme.colorScheme.onSurface,
      ),
    );

    return withTextContrast.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.padded, // 48px min
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: withTextContrast.textTheme.labelLarge,
          disabledForegroundColor: withTextContrast.colorScheme.onSurface.withOpacity(0.38),
          disabledBackgroundColor: withTextContrast.colorScheme.onSurface.withOpacity(0.12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: withTextContrast.textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.padded,
          minimumSize: MaterialStateProperty.all(const Size.square(48)),
          padding: MaterialStateProperty.all(const EdgeInsets.all(12)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        horizontalTitleGap: 12,
        minVerticalPadding: 8,
        minLeadingWidth: 24,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppSpacing.standard,
      ],
    );
  }

  static ThemeData light([Contrast c = Contrast.normal]) {
    final baseTheme = ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );

    if (c == Contrast.high) {
      final high = baseTheme.copyWith(
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
      return _applyCommonTweaks(high);
    }
    return _applyCommonTweaks(baseTheme);
  }

  static ThemeData dark([Contrast c = Contrast.normal]) {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );

    if (c == Contrast.high) {
      final high = baseTheme.copyWith(
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
      return _applyCommonTweaks(high);
    }
    return _applyCommonTweaks(baseTheme);
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
    Color seedColor = Colors.indigo;
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
