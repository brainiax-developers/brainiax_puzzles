import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import 'package:app/features/play/puzzle_play_view_model.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SolvingStubPuzzleEngine extends core.StubPuzzleEngine {
  _SolvingStubPuzzleEngine()
    : super(engineId: 'stub_play_engine', engineName: 'Stub Play Engine');

  @override
  core.MoveResult<core.StubPuzzleState> validateMove({
    required core.StubPuzzleState currentState,
    required core.StubPuzzleMove move,
  }) {
    final core.MoveResult<core.StubPuzzleState> result = super.validateMove(
      currentState: currentState,
      move: move,
    );

    if (!result.isValid || result.newState == null) {
      return result;
    }

    if (move.type == 'solve') {
      final Map<String, dynamic> solvedData = Map<String, dynamic>.from(
        result.newState!.data,
      );
      solvedData['solved'] = true;
      return core.MoveResult.success(
        core.StubPuzzleState(id: result.newState!.id, data: solvedData),
      );
    }

    return result;
  }
}

class _HintlessStubPuzzleEngine extends _SolvingStubPuzzleEngine {
  @override
  core.PuzzleCapabilities get capabilities => const core.PuzzleCapabilities();

  @override
  core.PuzzleHint? requestHint({
    required core.StubPuzzleState currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }
}

PuzzlePlaySession _createSession({
  void Function(PuzzleSolvedEvent event)? onSolved,
  PuzzleType puzzleType = PuzzleType.sudokuClassic,
  PuzzleMode mode = PuzzleMode.random,
  String difficulty = 'medium',
  core.PuzzleEngine<dynamic, dynamic>? engine,
}) {
  final core.PuzzleEngine<dynamic, dynamic> activeEngine =
      engine ?? _SolvingStubPuzzleEngine();
  final core.GeneratedPuzzle<dynamic> puzzle = activeEngine.generate(
    seedStr: 'test-seed',
    seed64: 0xabc123,
    size: const core.SizeOpt(
      id: '5x5',
      description: '5x5',
      width: 5,
      height: 5,
    ),
    difficulty: const core.DifficultyScore(value: 0.5, level: 'medium'),
  );

  return PuzzlePlaySession(
    engine: activeEngine,
    puzzle: puzzle,
    puzzleType: puzzleType,
    mode: mode,
    difficulty: difficulty,
    onSolved: onSolved,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PuzzlePlayViewModel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts timer immediately and tracks elapsed time', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession session = _createSession();
        final ProviderContainer container = ProviderContainer();
        container.listen(puzzlePlayViewModelProvider(session), (_, __) {});
        final provider = puzzlePlayViewModelProvider;
        container.read(provider(session));

        expect(container.read(provider(session)).elapsed, Duration.zero);
        expect(container.read(provider(session)).isTimerRunning, isTrue);

        async.elapse(const Duration(seconds: 3));

        final PuzzlePlayState state = container.read(provider(session));
        expect(state.elapsed.inSeconds, greaterThanOrEqualTo(3));
        expect(state.isTimerRunning, isTrue);

        container.dispose();
      });
    });

    test('single move triggers solved event and stops timer', () {
      fakeAsync((FakeAsync async) {
        final List<PuzzleSolvedEvent> events = <PuzzleSolvedEvent>[];
        final PuzzlePlaySession session = _createSession(onSolved: events.add);
        final ProviderContainer container = ProviderContainer();
        container.listen(puzzlePlayViewModelProvider(session), (_, __) {});
        final provider = puzzlePlayViewModelProvider;
        final PuzzlePlayViewModel viewModel = container.read(
          provider(session).notifier,
        );

        async.elapse(const Duration(seconds: 1));
        final Duration beforeMove = container.read(provider(session)).elapsed;
        expect(beforeMove, isNot(equals(Duration.zero)));

        viewModel.applyMove(
          const core.StubPuzzleMove(type: 'solve', data: <String, dynamic>{}),
        );

        async.flushMicrotasks();

        final PuzzlePlayState solvedState = container.read(provider(session));
        expect(solvedState.isSolved, isTrue);
        expect(solvedState.isTimerRunning, isFalse);
        expect(solvedState.moveHistory, hasLength(1));
        expect(events, hasLength(1));

        final PuzzleSolvedEvent event = events.single;
        expect(event.moveCount, 1);
        expect(event.elapsed, solvedState.elapsed);
        expect(event.moveHistory, hasLength(1));
        expect(event.completionStatus, isNotNull);

        final Duration solvedElapsed = solvedState.elapsed;
        async.elapse(const Duration(seconds: 5));
        expect(
          container.read(provider(session)).elapsed,
          equals(solvedElapsed),
        );

        container.dispose();
      });
    });

    test('undo reverts move and restart resets state', () {
      fakeAsync((FakeAsync async) {
        final List<PuzzleSolvedEvent> events = <PuzzleSolvedEvent>[];
        final PuzzlePlaySession session = _createSession(onSolved: events.add);
        final ProviderContainer container = ProviderContainer();
        container.listen(puzzlePlayViewModelProvider(session), (_, __) {});
        final provider = puzzlePlayViewModelProvider;
        final PuzzlePlayViewModel viewModel = container.read(
          provider(session).notifier,
        );

        viewModel.applyMove(
          const core.StubPuzzleMove(
            type: 'progress',
            data: <String, dynamic>{'step': 1},
          ),
        );

        PuzzlePlayState state = container.read(provider(session));
        expect(state.moveHistory, hasLength(1));
        expect(state.moveCount, 1);
        expect(state.isSolved, isFalse);

        async.elapse(const Duration(seconds: 1));

        viewModel.undo();
        state = container.read(provider(session));
        expect(state.moveHistory, isEmpty);
        expect(state.moveCount, 2);
        expect(state.board, equals(session.puzzle.state));
        expect(state.isSolved, isFalse);
        expect(state.isTimerRunning, isTrue);

        viewModel.applyMove(
          const core.StubPuzzleMove(type: 'solve', data: <String, dynamic>{}),
        );
        async.flushMicrotasks();
        expect(container.read(provider(session)).isSolved, isTrue);
        expect(events, hasLength(1));

        viewModel.restart();
        state = container.read(provider(session));
        expect(state.board, equals(session.puzzle.state));
        expect(state.moveHistory, isEmpty);
        expect(state.moveCount, 0);
        expect(state.elapsed, Duration.zero);
        expect(state.isSolved, isFalse);
        expect(state.isTimerRunning, isTrue);

        viewModel.applyMove(
          const core.StubPuzzleMove(type: 'solve', data: <String, dynamic>{}),
        );
        async.flushMicrotasks();
        expect(events, hasLength(2));

        container.dispose();
      });
    });

    test('invalid moves throw StateError', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession session = _createSession();
        final ProviderContainer container = ProviderContainer();
        container.listen(puzzlePlayViewModelProvider(session), (_, __) {});
        final provider = puzzlePlayViewModelProvider;
        final PuzzlePlayViewModel viewModel = container.read(
          provider(session).notifier,
        );

        expect(
          () => viewModel.applyMove(
            const core.StubPuzzleMove(
              type: 'invalid',
              data: <String, dynamic>{},
            ),
          ),
          throwsStateError,
        );

        container.dispose();
      });
    });

    test('reflects engine hint capabilities in state', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession hintlessSession = _createSession(
          engine: _HintlessStubPuzzleEngine(),
        );
        final PuzzlePlaySession hintingSession = _createSession();

        final provider = puzzlePlayViewModelProvider;
        final container = ProviderContainer();

        final PuzzlePlayState hintlessState = container.read(
          provider(hintlessSession),
        );
        final PuzzlePlayState hintingState = container.read(
          provider(hintingSession),
        );

        expect(hintlessState.supportsHints, isFalse);
        expect(hintingState.supportsHints, isTrue);

        container.dispose();
      });
    });

    test('requestHint emits and auto clears hint highlight', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession session = _createSession();
        final provider = puzzlePlayViewModelProvider;
        final container = ProviderContainer();
        final PuzzlePlayViewModel viewModel = container.read(
          provider(session).notifier,
        );

        expect(container.read(provider(session)).hintHighlight, isNull);

        viewModel.requestHint();

        PuzzlePlayState stateWithHint = container.read(provider(session));
        expect(stateWithHint.hintHighlight, isNotNull);
        expect(stateWithHint.hintHighlight!.cells, isNotEmpty);
        expect(stateWithHint.hintHighlight!.units, isNotEmpty);

        async.elapse(const Duration(seconds: 4));
        final PuzzlePlayState clearedState = container.read(provider(session));
        expect(clearedState.hintHighlight, isNull);

        container.dispose();
      });
    });

    test('hint sequence is deterministic for stub engine', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession sessionA = _createSession();
        final PuzzlePlaySession sessionB = _createSession();
        final provider = puzzlePlayViewModelProvider;

        final ProviderContainer containerA = ProviderContainer();
        final PuzzlePlayViewModel viewModelA = containerA.read(
          provider(sessionA).notifier,
        );
        viewModelA.requestHint();
        final core.PuzzleHint? hintA1 = containerA
            .read(provider(sessionA))
            .hintHighlight;
        viewModelA.requestHint();
        final core.PuzzleHint? hintA2 = containerA
            .read(provider(sessionA))
            .hintHighlight;

        final ProviderContainer containerB = ProviderContainer();
        final PuzzlePlayViewModel viewModelB = containerB.read(
          provider(sessionB).notifier,
        );
        viewModelB.requestHint();
        final core.PuzzleHint? hintB1 = containerB
            .read(provider(sessionB))
            .hintHighlight;
        viewModelB.requestHint();
        final core.PuzzleHint? hintB2 = containerB
            .read(provider(sessionB))
            .hintHighlight;

        expect(hintA1, equals(hintB1));
        expect(hintA2, equals(hintB2));

        containerA.dispose();
        containerB.dispose();
      });
    });

    test('applyMove clears active hint highlight', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession session = _createSession();
        final provider = puzzlePlayViewModelProvider;
        final container = ProviderContainer();
        final PuzzlePlayViewModel viewModel = container.read(
          provider(session).notifier,
        );

        viewModel.requestHint();
        expect(container.read(provider(session)).hintHighlight, isNotNull);

        viewModel.applyMove(
          const core.StubPuzzleMove(
            type: 'progress',
            data: <String, dynamic>{},
          ),
        );

        expect(container.read(provider(session)).hintHighlight, isNull);

        container.dispose();
      });
    });

    test('solving daily puzzle updates completion metrics', () async {
      SharedPreferences.setMockInitialValues({});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<PuzzleSolvedEvent> events = <PuzzleSolvedEvent>[];
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
        ],
      );
      final PuzzlePlaySession session = _createSession(
        onSolved: events.add,
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        difficulty: 'daily',
      );
      final provider = puzzlePlayViewModelProvider;

      container.read(provider(session));
      final PuzzlePlayViewModel viewModel = container.read(
        provider(session).notifier,
      );

      viewModel.applyMove(
        const core.StubPuzzleMove(type: 'solve', data: <String, dynamic>{}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      final PuzzleSolvedEvent event = events.single;
      final PuzzleCompletionStatus? status = event.completionStatus;
      expect(status, isNotNull);
      expect(status!.bestTime?.inMilliseconds, event.elapsed.inMilliseconds);
      expect(status.isDailyCompleted, isTrue);
      expect(status.dailyStreak, greaterThanOrEqualTo(1));

      final store = await container.read(puzzleLocalStoreProvider.future);
      final String todayKey = DailyUtcDate.todayKey();

      expect((await store.bestTime(session.puzzleType, 'daily'))?.inMilliseconds, event.elapsed.inMilliseconds);
      expect(
        await store.isDailyCompleted(session.puzzleType, todayKey),
        isTrue,
      );
      expect(
        (await store.dailyStreakStatus()).currentStreak,
        status.dailyStreak,
      );

      container.dispose();
    });
  });
}
