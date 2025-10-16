import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart';
import '../lib/shared/providers/engine_provider.dart';
import '../lib/shared/providers/game_state_provider.dart';
import '../lib/shared/services/seed_service.dart';
import '../lib/shared/services/engine_registry_service.dart';

void main() {
  group('App Integration Tests', () {
    late ProviderContainer container;

    setUp(() async {
      // Initialize engines
      await EngineRegistryService().initialize();
      
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Engine Provider Integration', () {
      test('engineProvider returns correct engine', () {
        final stubEngine = container.read(engineProvider('stub'));
        expect(stubEngine, isNotNull);
        expect(stubEngine!.id, equals('stub'));

        final stubSudokuEngine = container.read(engineProvider('stub_sudoku'));
        expect(stubSudokuEngine, isNotNull);
        expect(stubSudokuEngine!.id, equals('stub_sudoku'));
      });

      test('engineProvider returns null for non-existent engine', () {
        final nonExistentEngine = container.read(engineProvider('non_existent'));
        expect(nonExistentEngine, isNull);
      });

      test('availableEnginesProvider returns list of engines', () {
        final engines = container.read(availableEnginesProvider);
        expect(engines, isNotEmpty);
        expect(engines, contains('stub'));
        expect(engines, contains('stub_sudoku'));
      });

      test('isEngineAvailableProvider works correctly', () {
        final isStubAvailable = container.read(isEngineAvailableProvider('stub'));
        expect(isStubAvailable, isTrue);

        final isNonExistentAvailable = container.read(isEngineAvailableProvider('non_existent'));
        expect(isNonExistentAvailable, isFalse);
      });

      test('engineCountProvider returns correct count', () {
        final count = container.read(engineCountProvider);
        expect(count, greaterThan(0));
      });

      test('engineInfoProvider returns correct info', () {
        final stubInfo = container.read(engineInfoProvider('stub'));
        expect(stubInfo, isNotNull);
        expect(stubInfo!.id, equals('stub'));
        expect(stubInfo.name, isNotEmpty);
        expect(stubInfo.version, isNotEmpty);
      });

      test('allEngineInfoProvider returns all engine info', () {
        final allInfo = container.read(allEngineInfoProvider);
        expect(allInfo, isNotEmpty);
        expect(allInfo.length, equals(container.read(engineCountProvider)));
      });
    });

    group('Game State Provider Integration', () {
      test('can start new game', () async {
        final gameStateNotifier = container.read(gameStateProvider.notifier);
        
        await gameStateNotifier.startNewGame(
          engineId: 'stub',
          seed: 'test:stub:0',
          difficulty: 'medium',
          size: '9x9',
        );

        final gameState = container.read(gameStateProvider);
        expect(gameState, isNotNull);
        expect(gameState!.engineId, equals('stub'));
        expect(gameState.seed, equals('test:stub:0'));
        expect(gameState.difficulty, equals('medium'));
        expect(gameState.size, equals('9x9'));
        expect(gameState.isSolved, isFalse);
      });

      test('can make valid move', () async {
        final gameStateNotifier = container.read(gameStateProvider.notifier);
        
        await gameStateNotifier.startNewGame(
          engineId: 'stub',
          seed: 'test:stub:0',
          difficulty: 'medium',
          size: '9x9',
        );

        final move = StubPuzzleMove(type: 'valid', data: {'test': 'value'});
        await gameStateNotifier.makeMove(move);

        final gameState = container.read(gameStateProvider);
        expect(gameState, isNotNull);
        expect(gameStateNotifier.canUndo, isTrue);
      });

      test('rejects invalid move', () async {
        final gameStateNotifier = container.read(gameStateProvider.notifier);
        
        await gameStateNotifier.startNewGame(
          engineId: 'stub',
          seed: 'test:stub:0',
          difficulty: 'medium',
          size: '9x9',
        );

        final move = StubPuzzleMove(type: 'invalid', data: {});
        
        expect(
          () => gameStateNotifier.makeMove(move),
          throwsA(isA<Exception>()),
        );
      });

      test('undo/redo functionality works', () async {
        final gameStateNotifier = container.read(gameStateProvider.notifier);
        
        await gameStateNotifier.startNewGame(
          engineId: 'stub',
          seed: 'test:stub:0',
          difficulty: 'medium',
          size: '9x9',
        );

        // Make a move
        final move = StubPuzzleMove(type: 'valid', data: {'test': 'value'});
        await gameStateNotifier.makeMove(move);

        expect(gameStateNotifier.canUndo, isTrue);
        expect(gameStateNotifier.canRedo, isFalse);

        // Undo
        gameStateNotifier.undo();
        expect(gameStateNotifier.canUndo, isFalse);
        expect(gameStateNotifier.canRedo, isTrue);

        // Redo
        gameStateNotifier.redo();
        expect(gameStateNotifier.canUndo, isTrue);
        expect(gameStateNotifier.canRedo, isFalse);
      });

      test('move history is maintained', () async {
        final gameStateNotifier = container.read(gameStateProvider.notifier);
        
        await gameStateNotifier.startNewGame(
          engineId: 'stub',
          seed: 'test:stub:0',
          difficulty: 'medium',
          size: '9x9',
        );

        // Make multiple moves
        for (int i = 0; i < 3; i++) {
          final move = StubPuzzleMove(type: 'valid', data: {'test': 'value$i'});
          await gameStateNotifier.makeMove(move);
        }

        final moveHistory = gameStateNotifier.moveHistory;
        expect(moveHistory.length, equals(3));
        expect(gameStateNotifier.currentMoveIndex, equals(2));

        // Undo one move
        gameStateNotifier.undo();
        expect(gameStateNotifier.currentMoveIndex, equals(1));

        // Make a new move (should truncate history)
        final newMove = StubPuzzleMove(type: 'valid', data: {'test': 'new'});
        await gameStateNotifier.makeMove(newMove);

        expect(gameStateNotifier.moveHistory.length, equals(3));
        expect(gameStateNotifier.currentMoveIndex, equals(2));
      });
    });

    group('Seed Service Integration', () {
      test('generates daily seeds correctly', () {
        final seedService = SeedService();
        final date = DateTime(2024, 1, 1).toUtc();
        
        final seed = seedService.generateDailySeed('sudoku', date);
        expect(seed, equals('sudoku:20240101'));
      });

      test('generates random play seeds correctly', () {
        final seedService = SeedService();
        
        final seed = seedService.generateRandomPlaySeed('sudoku', 'user123', 'session456');
        expect(seed, equals('sudoku:user123:session456'));
      });

      test('generates test seeds correctly', () {
        final seedService = SeedService();
        
        final seed = seedService.generateTestSeed('sudoku', 0);
        expect(seed, equals('test:sudoku:0'));
      });

      test('parses seeds correctly', () {
        final seedService = SeedService();
        
        // Test daily seed parsing
        final dailyComponents = seedService.parseSeed('sudoku:20240101');
        expect(dailyComponents.type, equals(SeedType.daily));
        expect(dailyComponents.puzzleId, equals('sudoku'));
        expect(dailyComponents.dateStr, equals('20240101'));

        // Test random play seed parsing
        final randomPlayComponents = seedService.parseSeed('sudoku:user123:session456');
        expect(randomPlayComponents.type, equals(SeedType.randomPlay));
        expect(randomPlayComponents.puzzleId, equals('sudoku'));
        expect(randomPlayComponents.userId, equals('user123'));
        expect(randomPlayComponents.sessionNonce, equals('session456'));

        // Test test seed parsing
        final testComponents = seedService.parseSeed('test:sudoku:0');
        expect(testComponents.type, equals(SeedType.test));
        expect(testComponents.puzzleId, equals('sudoku'));
        expect(testComponents.testIndex, equals(0));
      });

      test('validates seeds correctly', () {
        final seedService = SeedService();
        
        expect(seedService.isValidSeed('sudoku:20240101'), isTrue);
        expect(seedService.isValidSeed('sudoku:user123:session456'), isTrue);
        expect(seedService.isValidSeed('test:sudoku:0'), isTrue);
        expect(seedService.isValidSeed('invalid'), isFalse);
        expect(seedService.isValidSeed(''), isFalse);
      });

      test('identifies seed types correctly', () {
        final seedService = SeedService();
        
        expect(seedService.isDailySeed('sudoku:20240101'), isTrue);
        expect(seedService.isRandomPlaySeed('sudoku:user123:session456'), isTrue);
        expect(seedService.isTestSeed('test:sudoku:0'), isTrue);
        expect(seedService.isRandomSeed('random:sudoku:123:456'), isTrue);
      });

      test('extracts puzzle ID correctly', () {
        final seedService = SeedService();
        
        expect(seedService.extractPuzzleId('sudoku:20240101'), equals('sudoku'));
        expect(seedService.extractPuzzleId('sudoku:user123:session456'), equals('sudoku'));
        expect(seedService.extractPuzzleId('test:sudoku:0'), equals('sudoku'));
        expect(seedService.extractPuzzleId('invalid'), isNull);
      });

      test('extracts date from daily seed correctly', () {
        final seedService = SeedService();
        
        final date = seedService.extractDateFromDailySeed('sudoku:20240101');
        expect(date, isNotNull);
        expect(date!.year, equals(2024));
        expect(date.month, equals(1));
        expect(date.day, equals(1));
      });
    });

    group('End-to-End Integration', () {
      test('complete game flow works', () async {
        final seedService = SeedService();
        final gameStateNotifier = container.read(gameStateProvider.notifier);
        
        // Generate a daily seed
        final seed = seedService.getTodaysDailySeed('stub');
        expect(seedService.isDailySeed(seed), isTrue);
        
        // Start a new game
        await gameStateNotifier.startNewGame(
          engineId: 'stub',
          seed: seed,
          difficulty: 'medium',
          size: '9x9',
        );

        final gameState = container.read(gameStateProvider);
        expect(gameState, isNotNull);
        expect(gameState!.seed, equals(seed));

        // Make some moves
        for (int i = 0; i < 3; i++) {
          final move = StubPuzzleMove(type: 'valid', data: {'test': 'value$i'});
          await gameStateNotifier.makeMove(move);
        }

        // Test undo/redo
        expect(gameStateNotifier.canUndo, isTrue);
        gameStateNotifier.undo();
        expect(gameStateNotifier.currentMoveIndex, equals(1));

        gameStateNotifier.redo();
        expect(gameStateNotifier.currentMoveIndex, equals(2));

        // Verify move history
        final moveHistory = gameStateNotifier.moveHistory;
        expect(moveHistory.length, equals(3));
      });

      test('serialization works', () async {
        final gameStateNotifier = container.read(gameStateProvider.notifier);
        
        await gameStateNotifier.startNewGame(
          engineId: 'stub',
          seed: 'test:stub:0',
          difficulty: 'medium',
          size: '9x9',
        );

        // Make a move
        final move = StubPuzzleMove(type: 'valid', data: {'test': 'value'});
        await gameStateNotifier.makeMove(move);

        // Serialize
        final json = gameStateNotifier.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['gameState'], isNotNull);
        expect(json['moveHistory'], isA<List>());
        expect(json['currentMoveIndex'], equals(0));
      });
    });
  });
}
