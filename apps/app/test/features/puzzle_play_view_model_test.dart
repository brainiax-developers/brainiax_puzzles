import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import 'package:app/features/play/puzzle_play_view_model.dart';

class _SolvingStubPuzzleEngine extends core.StubPuzzleEngine {
  _SolvingStubPuzzleEngine()
      : super(
          engineId: 'stub_play_engine',
          engineName: 'Stub Play Engine',
        );

  @override
  core.MoveResult<core.StubPuzzleState> validateMove({
    required core.StubPuzzleState currentState,
    required core.StubPuzzleMove move,
  }) {
    final core.MoveResult<core.StubPuzzleState> result =
        super.validateMove(currentState: currentState, move: move);

    if (!result.isValid || result.newState == null) {
      return result;
    }

    if (move.type == 'solve') {
      final Map<String, dynamic> solvedData =
          Map<String, dynamic>.from(result.newState!.data);
      solvedData['solved'] = true;
      return core.MoveResult.success(
        core.StubPuzzleState(id: result.newState!.id, data: solvedData),
      );
    }

    return result;
  }
}

PuzzlePlaySession _createSession({
  void Function(PuzzleSolvedEvent event)? onSolved,
}) {
  final _SolvingStubPuzzleEngine engine = _SolvingStubPuzzleEngine();
  final core.GeneratedPuzzle<dynamic> puzzle = engine.generate(
    seedStr: 'test-seed',
    seed64: 0xabc123,
    size: const core.SizeOpt(id: '5x5', description: '5x5', width: 5, height: 5),
    difficulty: const core.DifficultyScore(value: 0.5, level: 'medium'),
  );

  return PuzzlePlaySession(
    engine: engine,
    puzzle: puzzle,
    onSolved: onSolved,
  );
}

void main() {
  group('PuzzlePlayViewModel', () {
    test('starts timer immediately and tracks elapsed time', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession session = _createSession();
        final ProviderContainer container = ProviderContainer();
        final AutoDisposeNotifierProviderFamily<
            PuzzlePlayViewModel,
            PuzzlePlayState,
            PuzzlePlaySession> provider = puzzlePlayViewModelProvider;
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
        final PuzzlePlaySession session =
            _createSession(onSolved: events.add);
        final ProviderContainer container = ProviderContainer();
        final AutoDisposeNotifierProviderFamily<
            PuzzlePlayViewModel,
            PuzzlePlayState,
            PuzzlePlaySession> provider = puzzlePlayViewModelProvider;
        final PuzzlePlayViewModel viewModel =
            container.read(provider(session).notifier);

        async.elapse(const Duration(seconds: 1));
        final Duration beforeMove = container.read(provider(session)).elapsed;
        expect(beforeMove, isNot(equals(Duration.zero)));

        viewModel.applyMove(
          const core.StubPuzzleMove(type: 'solve', data: <String, dynamic>{}),
        );

        final PuzzlePlayState solvedState = container.read(provider(session));
        expect(solvedState.isSolved, isTrue);
        expect(solvedState.isTimerRunning, isFalse);
        expect(solvedState.moveHistory, hasLength(1));
        expect(events, hasLength(1));

        final PuzzleSolvedEvent event = events.single;
        expect(event.moveCount, 1);
        expect(event.elapsed, solvedState.elapsed);
        expect(event.moveHistory, hasLength(1));

        final Duration solvedElapsed = solvedState.elapsed;
        async.elapse(const Duration(seconds: 5));
        expect(container.read(provider(session)).elapsed, equals(solvedElapsed));

        container.dispose();
      });
    });

    test('undo reverts move and restart resets state', () {
      fakeAsync((FakeAsync async) {
        final List<PuzzleSolvedEvent> events = <PuzzleSolvedEvent>[];
        final PuzzlePlaySession session =
            _createSession(onSolved: events.add);
        final ProviderContainer container = ProviderContainer();
        final AutoDisposeNotifierProviderFamily<
            PuzzlePlayViewModel,
            PuzzlePlayState,
            PuzzlePlaySession> provider = puzzlePlayViewModelProvider;
        final PuzzlePlayViewModel viewModel =
            container.read(provider(session).notifier);

        viewModel.applyMove(
          const core.StubPuzzleMove(
            type: 'progress',
            data: <String, dynamic>{'step': 1},
          ),
        );

        PuzzlePlayState state = container.read(provider(session));
        expect(state.moveHistory, hasLength(1));
        expect(state.isSolved, isFalse);

        async.elapse(const Duration(seconds: 1));

        viewModel.undo();
        state = container.read(provider(session));
        expect(state.moveHistory, isEmpty);
        expect(state.board, equals(session.puzzle.state));
        expect(state.isSolved, isFalse);
        expect(state.isTimerRunning, isTrue);

        viewModel.applyMove(
          const core.StubPuzzleMove(type: 'solve', data: <String, dynamic>{}),
        );
        expect(container.read(provider(session)).isSolved, isTrue);
        expect(events, hasLength(1));

        viewModel.restart();
        state = container.read(provider(session));
        expect(state.board, equals(session.puzzle.state));
        expect(state.moveHistory, isEmpty);
        expect(state.elapsed, Duration.zero);
        expect(state.isSolved, isFalse);
        expect(state.isTimerRunning, isTrue);

        viewModel.applyMove(
          const core.StubPuzzleMove(type: 'solve', data: <String, dynamic>{}),
        );
        expect(events, hasLength(2));

        container.dispose();
      });
    });

    test('invalid moves throw StateError', () {
      fakeAsync((FakeAsync async) {
        final PuzzlePlaySession session = _createSession();
        final ProviderContainer container = ProviderContainer();
        final AutoDisposeNotifierProviderFamily<
            PuzzlePlayViewModel,
            PuzzlePlayState,
            PuzzlePlaySession> provider = puzzlePlayViewModelProvider;
        final PuzzlePlayViewModel viewModel =
            container.read(provider(session).notifier);

        expect(
          () => viewModel.applyMove(
            const core.StubPuzzleMove(type: 'invalid', data: <String, dynamic>{}),
          ),
          throwsStateError,
        );

        container.dispose();
      });
    });
  });
}
