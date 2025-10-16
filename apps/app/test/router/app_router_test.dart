import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app/app_router.dart';
import 'package:app/shared/models/models.dart';

void main() {
  group('AppRouter', () {
    testWidgets('should navigate to select screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: appRouter.routeInformationProvider,
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
        ),
      );

      // Navigate to select screen
      appRouter.go('/select');
      await tester.pumpAndSettle();

      expect(find.text('Puzzle Selection'), findsOneWidget);
      expect(find.text('Choose your puzzle type and mode'), findsOneWidget);
    });

    testWidgets('should navigate to play screen with valid parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: appRouter.routeInformationProvider,
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
        ),
      );

      // Navigate to play screen with valid parameters
      appRouter.go('/play/sudoku_classic/daily');
      await tester.pumpAndSettle();

      expect(find.text('Classic Sudoku - Daily Challenge'), findsOneWidget);
      expect(find.text('Playing Classic Sudoku'), findsOneWidget);
      expect(find.text('Mode: Daily Challenge'), findsOneWidget);
      expect(find.text('Puzzle Type: sudoku_classic'), findsOneWidget);
      expect(find.text('Mode: daily'), findsOneWidget);
    });

    testWidgets('should navigate to play screen with random mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: appRouter.routeInformationProvider,
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
        ),
      );

      // Navigate to play screen with random mode
      appRouter.go('/play/nonogram_mono/random');
      await tester.pumpAndSettle();

      expect(find.text('Monochrome Nonogram - Random Puzzle'), findsOneWidget);
      expect(find.text('Playing Monochrome Nonogram'), findsOneWidget);
      expect(find.text('Mode: Random Puzzle'), findsOneWidget);
      expect(find.text('Puzzle Type: nonogram_mono'), findsOneWidget);
      expect(find.text('Mode: random'), findsOneWidget);
    });

    testWidgets('should redirect to select screen for invalid puzzle type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: appRouter.routeInformationProvider,
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
        ),
      );

      // Navigate to play screen with invalid puzzle type
      appRouter.go('/play/invalid_puzzle/daily');
      await tester.pumpAndSettle();

      // Should redirect to select screen
      expect(find.text('Puzzle Selection'), findsOneWidget);
    });

    testWidgets('should redirect to select screen for invalid mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: appRouter.routeInformationProvider,
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
        ),
      );

      // Navigate to play screen with invalid mode
      appRouter.go('/play/sudoku_classic/invalid_mode');
      await tester.pumpAndSettle();

      // Should redirect to select screen
      expect(find.text('Puzzle Selection'), findsOneWidget);
    });

    testWidgets('should handle legacy route with default mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: appRouter.routeInformationProvider,
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
        ),
      );

      // Navigate to legacy play route
      appRouter.go('/play/sudoku_classic');
      await tester.pumpAndSettle();

      expect(find.text('Classic Sudoku - Random Puzzle'), findsOneWidget);
      expect(find.text('Playing Classic Sudoku'), findsOneWidget);
      expect(find.text('Mode: Random Puzzle'), findsOneWidget);
    });

    testWidgets('should handle legacy route with invalid puzzle type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: appRouter.routeInformationProvider,
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
        ),
      );

      // Navigate to legacy play route with invalid puzzle type
      appRouter.go('/play/invalid_puzzle');
      await tester.pumpAndSettle();

      // Should default to sudoku_classic with random mode
      expect(find.text('Classic Sudoku - Random Puzzle'), findsOneWidget);
    });
  });

  group('Route Parameter Validation', () {
    test('should validate puzzle type parameters', () {
      expect(PuzzleType.isValidKey('sudoku_classic'), isTrue);
      expect(PuzzleType.isValidKey('nonogram_mono'), isTrue);
      expect(PuzzleType.isValidKey('kakuro_classic'), isTrue);
      expect(PuzzleType.isValidKey('slitherlink_loop'), isTrue);
      expect(PuzzleType.isValidKey('mathdoku_classic'), isTrue);
      expect(PuzzleType.isValidKey('futoshiki_classic'), isTrue);
      expect(PuzzleType.isValidKey('takuzu_binary'), isTrue);
      
      expect(PuzzleType.isValidKey('invalid_type'), isFalse);
      expect(PuzzleType.isValidKey(''), isFalse);
    });

    test('should validate puzzle mode parameters', () {
      expect(PuzzleMode.isValidKey('daily'), isTrue);
      expect(PuzzleMode.isValidKey('random'), isTrue);
      
      expect(PuzzleMode.isValidKey('invalid_mode'), isFalse);
      expect(PuzzleMode.isValidKey(''), isFalse);
    });

    test('should parse puzzle type from key', () {
      expect(PuzzleType.fromKey('sudoku_classic'), equals(PuzzleType.sudokuClassic));
      expect(PuzzleType.fromKey('nonogram_mono'), equals(PuzzleType.nonogramMono));
      expect(PuzzleType.fromKey('invalid_type'), isNull);
    });

    test('should parse puzzle mode from key', () {
      expect(PuzzleMode.fromKey('daily'), equals(PuzzleMode.daily));
      expect(PuzzleMode.fromKey('random'), equals(PuzzleMode.random));
      expect(PuzzleMode.fromKey('invalid_mode'), isNull);
    });
  });
}
