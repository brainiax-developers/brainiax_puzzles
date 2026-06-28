import 'package:puzzle_core/puzzle_core.dart';
import 'kakuro_board.dart';
import 'kakuro_dictionary.dart';

class KakuroSolver extends PuzzleSolver<KakuroBoard> {
  const KakuroSolver();

  @override
  SolverResult<KakuroBoard> solve(KakuroBoard board, SolverContext context) {
    final stopwatch = Stopwatch()..start();
    final solver = _KakuroInternalSolver(board, context.maxSolutions);
    final solutions = solver.solve();
    
    return SolverResult<KakuroBoard>(
      solutions: solutions,
      elapsed: stopwatch.elapsed,
      telemetry: {
        'nodes': solver.nodes,
        'backtracks': solver.backtracks,
      },
    );
  }
}

class _RunData {
  final List<int> cells;
  final int targetSum;
  int currentSum = 0;
  int assignedMask = 0;

  _RunData(this.cells, this.targetSum);
}

class _KakuroInternalSolver {
  final KakuroBoard initialBoard;
  final int maxSolutions;
  
  late List<int> cells;
  late List<int> candidates;
  late List<_RunData> acrossRuns;
  late List<_RunData> downRuns;
  late List<_RunData?> cellAcrossRun;
  late List<_RunData?> cellDownRun;
  
  int nodes = 0;
  int backtracks = 0;
  List<KakuroBoard> foundSolutions = [];

  _KakuroInternalSolver(this.initialBoard, this.maxSolutions) {
    cells = List<int>.from(initialBoard.cellValues);
    candidates = List<int>.filled(initialBoard.cellCount, 0x1FF); // 9 bits
    cellAcrossRun = List<_RunData?>.filled(initialBoard.cellCount, null);
    cellDownRun = List<_RunData?>.filled(initialBoard.cellCount, null);
    
    _extractRuns();
    
    // Initialize candidates based on already assigned values
    for (int i = 0; i < initialBoard.cellCount; i++) {
      if (initialBoard.isWhite(i)) {
        if (cells[i] != 0) {
          final val = cells[i];
          candidates[i] = 1 << (val - 1);
          cellAcrossRun[i]?.currentSum += val;
          cellAcrossRun[i]?.assignedMask |= (1 << (val - 1));
          cellDownRun[i]?.currentSum += val;
          cellDownRun[i]?.assignedMask |= (1 << (val - 1));
        }
      } else {
        candidates[i] = 0;
      }
    }
  }
  
  void _extractRuns() {
    acrossRuns = [];
    downRuns = [];
    
    // Extract across runs
    for (int r = 0; r < initialBoard.height; r++) {
      for (int c = 0; c < initialBoard.width; c++) {
        int index = r * initialBoard.width + c;
        if (initialBoard.isClue(index) && initialBoard.acrossClues[index] > 0) {
          List<int> runCells = [];
          for (int c2 = c + 1; c2 < initialBoard.width; c2++) {
            int idx2 = r * initialBoard.width + c2;
            if (initialBoard.isWhite(idx2)) {
              runCells.add(idx2);
            } else {
              break;
            }
          }
          if (runCells.isNotEmpty) {
            final run = _RunData(runCells, initialBoard.acrossClues[index]);
            acrossRuns.add(run);
            for (var cell in runCells) {
              cellAcrossRun[cell] = run;
            }
          }
        }
      }
    }
    
    // Extract down runs
    for (int r = 0; r < initialBoard.height; r++) {
      for (int c = 0; c < initialBoard.width; c++) {
        int index = r * initialBoard.width + c;
        if (initialBoard.isClue(index) && initialBoard.downClues[index] > 0) {
          List<int> runCells = [];
          for (int r2 = r + 1; r2 < initialBoard.height; r2++) {
            int idx2 = r2 * initialBoard.width + c;
            if (initialBoard.isWhite(idx2)) {
              runCells.add(idx2);
            } else {
              break;
            }
          }
          if (runCells.isNotEmpty) {
            final run = _RunData(runCells, initialBoard.downClues[index]);
            downRuns.add(run);
            for (var cell in runCells) {
              cellDownRun[cell] = run;
            }
          }
        }
      }
    }
  }

  List<KakuroBoard> solve() {
    if (!_initialPrune()) return foundSolutions;
    _search();
    return foundSolutions;
  }
  
  bool _initialPrune() {
    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = 0; i < initialBoard.cellCount; i++) {
        if (initialBoard.isWhite(i) && cells[i] == 0) {
          int oldMask = candidates[i];
          _updateCandidateMask(i);
          if (candidates[i] == 0) return false;
          if (candidates[i] != oldMask) changed = true;
        }
      }
    }
    return true;
  }
  
  void _updateCandidateMask(int cell) {
    int mask = candidates[cell];
    var aRun = cellAcrossRun[cell];
    var dRun = cellDownRun[cell];
    
    if (aRun != null) mask &= ~aRun.assignedMask;
    if (dRun != null) mask &= ~dRun.assignedMask;
    
    // Dictionary pruning
    if (aRun != null) {
      var dictCombs = KakuroDictionary.instance.getCombinations(aRun.cells.length, aRun.targetSum);
      if (dictCombs != null) {
        int allowedDict = 0;
        for (var comb in dictCombs) {
          if ((comb & aRun.assignedMask) == aRun.assignedMask) {
            allowedDict |= comb;
          }
        }
        mask &= allowedDict;
      }
    }
    
    if (dRun != null) {
      var dictCombs = KakuroDictionary.instance.getCombinations(dRun.cells.length, dRun.targetSum);
      if (dictCombs != null) {
        int allowedDict = 0;
        for (var comb in dictCombs) {
          if ((comb & dRun.assignedMask) == dRun.assignedMask) {
            allowedDict |= comb;
          }
        }
        mask &= allowedDict;
      }
    }
    
    candidates[cell] = mask;
  }
  
  int _countBits(int mask) {
    int count = 0;
    while (mask > 0) {
      count++;
      mask &= (mask - 1);
    }
    return count;
  }

  void _search() {
    if (foundSolutions.length >= maxSolutions) return;
    if (nodes++ > 100000) return; // Prevent intractable searches
    
    if (!_initialPrune()) return;
    int minC = 10;
    
    int bestCell = -1;
    
    for (int i = 0; i < initialBoard.cellCount; i++) {
      if (initialBoard.isWhite(i) && cells[i] == 0) {
        int c = _countBits(candidates[i]);
        if (c == 0) return; // Dead end
        if (c < minC) {
          minC = c;
          bestCell = i;
          if (c == 1) break; // MRV optimization
        }
      }
    }
    
    if (bestCell == -1) {
      // Board is fully assigned. Validate sum constraints strictly.
      for (var run in acrossRuns) {
        if (run.currentSum != run.targetSum) return;
      }
      for (var run in downRuns) {
        if (run.currentSum != run.targetSum) return;
      }
      foundSolutions.add(KakuroBoard(
        width: initialBoard.width,
        height: initialBoard.height,
        cellTypes: initialBoard.cellTypes,
        cellValues: List<int>.from(cells),
        acrossClues: initialBoard.acrossClues,
        downClues: initialBoard.downClues,
      ));
      return;
    }
    
    nodes++;
    
    int mask = candidates[bestCell];
    var aRun = cellAcrossRun[bestCell];
    var dRun = cellDownRun[bestCell];
    
    for (int d = 1; d <= 9; d++) {
      if (nodes > 100000) break; // Abort the whole search!
      int bit = 1 << (d - 1);
      if ((mask & bit) != 0) {
        // Fast bounds check
        if (aRun != null && aRun.currentSum + d > aRun.targetSum) continue;
        if (dRun != null && dRun.currentSum + d > dRun.targetSum) continue;
        
        cells[bestCell] = d;
        if (aRun != null) { aRun.currentSum += d; aRun.assignedMask |= bit; }
        if (dRun != null) { dRun.currentSum += d; dRun.assignedMask |= bit; }
        
        // Save state for backtracking
        List<int> oldCandidates = List<int>.from(candidates);
        
        bool possible = true;
        
        // Forward checking - update peers
        if (aRun != null) {
          for (var c in aRun.cells) {
            if (cells[c] == 0) {
              candidates[c] &= ~bit;
              if (candidates[c] == 0) { possible = false; break; }
            }
          }
        }
        if (possible && dRun != null) {
          for (var c in dRun.cells) {
            if (cells[c] == 0) {
              candidates[c] &= ~bit;
              if (candidates[c] == 0) { possible = false; break; }
            }
          }
        }
        
        if (possible) {
          _search();
        } else {
          backtracks++;
        }
        
        if (foundSolutions.length >= maxSolutions) return;
        
        // Restore state
        cells[bestCell] = 0;
        if (aRun != null) { aRun.currentSum -= d; aRun.assignedMask &= ~bit; }
        if (dRun != null) { dRun.currentSum -= d; dRun.assignedMask &= ~bit; }
        candidates = oldCandidates;
      }
    }
    backtracks++;
  }
}
