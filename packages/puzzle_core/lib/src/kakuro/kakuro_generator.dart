import 'package:puzzle_core/puzzle_core.dart';
import 'kakuro_board.dart';
import 'kakuro_solver.dart';
import 'kakuro_validator.dart';

class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    int w = context.size.width;
    int h = context.size.height;
    
    // Default size fallback if SizeOpt doesn't provide width/height
    if (w <= 0) w = 7;
    if (h <= 0) h = 7;
    
    int maxAttempts = 1000;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // 1. Generate Layout
      final layout = _generateLayout(w, h, context.rng);
      if (layout == null) continue;
      
      // 2. Assign Solution
      final solution = _assignSolution(layout, context.rng);
      if (solution == null) continue;
      
      // 3. Derive Clues
      final puzzle = _deriveClues(solution);
      
      // 4. Validate Uniqueness
      final solver = const KakuroSolver();
      final result = solver.solve(
        puzzle,
        SolverContext(rng: context.rng, maxSolutions: 2),
      );
      if (result.solutionStatus != SolverStatus.unique) {
        if (attempt == maxAttempts - 1) {
          return PuzzleGenerationResult<KakuroBoard>(
            board: puzzle,
            snapshot: GenerationSnapshot(
              telemetry: {},
            ),
          );
        }
        continue;
      }
      
      return PuzzleGenerationResult<KakuroBoard>(
        board: puzzle,
        snapshot: GenerationSnapshot(telemetry: {
          'attempts': attempt + 1,
          'difficulty': context.difficulty.level,
          'solver_nodes': result.telemetry['nodes'],
          'solver_backtracks': result.telemetry['backtracks'],
        }),
      );
    }
    
    throw Exception('Failed to generate Kakuro puzzle after $maxAttempts attempts');
  }
  
  KakuroBoard? _generateLayout(int width, int height, SeededRng rng) {
    List<int> cellTypes = List<int>.filled(width * height, KakuroBoard.cellWhite);
    
    // Top and left edges are black
    for (int c = 0; c < width; c++) cellTypes[c] = KakuroBoard.cellBlack;
    for (int r = 0; r < height; r++) cellTypes[r * width] = KakuroBoard.cellBlack;
    
    int interiorCount = (width - 1) * (height - 1);
    int blackCount = (interiorCount * 0.45).round(); // Increased for more constraints
    
    int placed = 0;
    while (placed < blackCount) {
      int r = rng.nextIntInRange(height - 1) + 1;
      int c = rng.nextIntInRange(width - 1) + 1;
      int idx = r * width + c;
      if (cellTypes[idx] == KakuroBoard.cellWhite) {
        cellTypes[idx] = KakuroBoard.cellBlack;
        placed++;
      }
    }
    
    // Repair 1-cell runs by turning them black
    bool changed = true;
    while (changed) {
      changed = false;
      // Check horizontal runs
      for (int r = 0; r < height; r++) {
        int runLen = 0;
        int runStart = -1;
        for (int c = 0; c <= width; c++) {
          bool isBlack = c == width || cellTypes[r * width + c] == KakuroBoard.cellBlack;
          if (!isBlack) {
            if (runLen == 0) runStart = c;
            runLen++;
          } else {
            if (runLen == 1) {
              cellTypes[r * width + runStart] = KakuroBoard.cellBlack;
              changed = true;
            }
            runLen = 0;
          }
        }
      }
      // Check vertical runs
      for (int c = 0; c < width; c++) {
        int runLen = 0;
        int runStart = -1;
        for (int r = 0; r <= height; r++) {
          bool isBlack = r == height || cellTypes[r * width + c] == KakuroBoard.cellBlack;
          if (!isBlack) {
            if (runLen == 0) runStart = r;
            runLen++;
          } else {
            if (runLen == 1) {
              cellTypes[runStart * width + c] = KakuroBoard.cellBlack;
              changed = true;
            }
            runLen = 0;
          }
        }
      }
    }
    
    // Verify layout rules: no 1-cell runs, all white cells have across and down runs
    if (!_isValidLayout(width, height, cellTypes)) return null;
    
    return KakuroBoard(
      width: width,
      height: height,
      cellTypes: cellTypes,
      cellValues: List<int>.filled(width * height, 0),
      acrossClues: List<int>.filled(width * height, 0),
      downClues: List<int>.filled(width * height, 0),
    );
  }
  
  bool _isValidLayout(int width, int height, List<int> cellTypes) {
    // Check horizontal runs
    for (int r = 0; r < height; r++) {
      int runLen = 0;
      for (int c = 0; c < width; c++) {
        int idx = r * width + c;
        if (cellTypes[idx] == KakuroBoard.cellWhite) {
          runLen++;
        } else {
          if (runLen == 1) return false;
          if (runLen > 9) return false;
          runLen = 0;
        }
      }
      if (runLen == 1) return false;
      if (runLen > 9) return false;
    }
    
    // Check vertical runs
    for (int c = 0; c < width; c++) {
      int runLen = 0;
      for (int r = 0; r < height; r++) {
        int idx = r * width + c;
        if (cellTypes[idx] == KakuroBoard.cellWhite) {
          runLen++;
        } else {
          if (runLen == 1) return false;
          if (runLen > 9) return false;
          runLen = 0;
        }
      }
      if (runLen == 1) return false;
      if (runLen > 9) return false;
    }
    
    // Check connectivity (optional, but good for Kakuro)
    return true;
  }
  
  KakuroBoard? _assignSolution(KakuroBoard layout, SeededRng rng) {
    // Simple CSP to assign 1-9 to white cells without duplicates in runs
    List<int> cells = List<int>.from(layout.cellValues);
    int nodes = 0;
    
    bool solve(int index) {
      if (nodes++ > 5000) return false;
      
      if (index == layout.cellCount) return true;
      
      if (!layout.isWhite(index)) {
        return solve(index + 1);
      }
      
      List<int> candidates = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      // Find used digits in across run
      int r = index ~/ layout.width;
      int c = index % layout.width;
      
      for (int c2 = c - 1; c2 >= 0; c2--) {
        int idx2 = r * layout.width + c2;
        if (!layout.isWhite(idx2)) break;
        if (cells[idx2] != 0) candidates.remove(cells[idx2]);
      }
      // Since we assign top-to-bottom, left-to-right, we only need to check backwards
      for (int r2 = r - 1; r2 >= 0; r2--) {
        int idx2 = r2 * layout.width + c;
        if (!layout.isWhite(idx2)) break;
        if (cells[idx2] != 0) candidates.remove(cells[idx2]);
      }
      
      // Shuffle candidates for random generation
      for (int i = candidates.length - 1; i > 0; i--) {
        int j = rng.nextIntInRange(i + 1);
        int temp = candidates[i];
        candidates[i] = candidates[j];
        candidates[j] = temp;
      }
      
      for (int val in candidates) {
        cells[index] = val;
        if (solve(index + 1)) return true;
        if (nodes > 5000) return false;
        cells[index] = 0;
      }
      
      return false;
    }
    
    if (solve(0)) {
      return KakuroBoard(
        width: layout.width,
        height: layout.height,
        cellTypes: layout.cellTypes,
        cellValues: cells,
        acrossClues: layout.acrossClues,
        downClues: layout.downClues,
      );
    }
    return null;
  }
  
  KakuroBoard _deriveClues(KakuroBoard solution) {
    List<int> acrossClues = List<int>.filled(solution.cellCount, 0);
    List<int> downClues = List<int>.filled(solution.cellCount, 0);
    List<int> cellTypes = List<int>.from(solution.cellTypes);
    
    for (int r = 0; r < solution.height; r++) {
      for (int c = 0; c < solution.width; c++) {
        int idx = r * solution.width + c;
        if (solution.isWhite(idx)) {
          // Check if previous is black
          if (c == 0 || !solution.isWhite(r * solution.width + (c - 1))) {
            int clueIdx = r * solution.width + (c - 1);
            if (c > 0) {
              cellTypes[clueIdx] = KakuroBoard.cellClue;
              int sum = 0;
              for (int c2 = c; c2 < solution.width; c2++) {
                int idx2 = r * solution.width + c2;
                if (!solution.isWhite(idx2)) break;
                sum += solution.getValue(idx2);
              }
              acrossClues[clueIdx] = sum;
            }
          }
          // Check if above is black
          if (r == 0 || !solution.isWhite((r - 1) * solution.width + c)) {
            int clueIdx = (r - 1) * solution.width + c;
            if (r > 0) {
              cellTypes[clueIdx] = KakuroBoard.cellClue;
              int sum = 0;
              for (int r2 = r; r2 < solution.height; r2++) {
                int idx2 = r2 * solution.width + c;
                if (!solution.isWhite(idx2)) break;
                sum += solution.getValue(idx2);
              }
              downClues[clueIdx] = sum;
            }
          }
        }
      }
    }
    
    return KakuroBoard(
      width: solution.width,
      height: solution.height,
      cellTypes: cellTypes,
      cellValues: List<int>.filled(solution.cellCount, 0), // Clear solution
      acrossClues: acrossClues,
      downClues: downClues,
    );
  }
}
