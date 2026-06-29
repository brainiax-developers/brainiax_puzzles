import 'package:puzzle_core/puzzle_core.dart';
import 'kakuro_board.dart';
import 'kakuro_solver.dart';
import 'kakuro_validator.dart';

class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator();

  static const _solver = KakuroSolver();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    int w = context.size.width;
    int h = context.size.height;
    
    // Default size fallback if SizeOpt doesn't provide width/height
    if (w <= 0) w = 7;
    if (h <= 0) h = 7;
    
    // We increase max attempts because Kakuro uniqueness is rare for low densities.
    const int maxAttempts = 5000;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // 1. Generate Layout
      final layout = _generateLayout(w, h, context.rng, context.difficulty.level);
      if (layout == null) continue;
      
      // 2. Assign Solution
      final solution = _assignSolution(layout, context.rng);
      if (solution == null) continue;
      
      // 3. Derive Clues
      final puzzle = _deriveClues(solution);
      
      // 4. Check Uniqueness
      final result = _solver.solve(
        puzzle, 
        SolverContext(rng: context.rng, maxSolutions: 2),
      );
      if (result.solutionStatus != SolverStatus.unique) continue;
      
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
  
  KakuroBoard? _generateLayout(int width, int height, SeededRng rng, String difficulty) {
    List<int> cellTypes = List<int>.filled(width * height, KakuroBoard.cellWhite);
    
    // Top and left edges are black
    for (int c = 0; c < width; c++) cellTypes[c] = KakuroBoard.cellBlack;
    for (int r = 0; r < height; r++) cellTypes[r * width] = KakuroBoard.cellBlack;
    
    int interiorCount = (width - 1) * (height - 1);
    
    // Using a fixed density of 0.35 for small grids ensures sufficient constraint for uniqueness
    // while leaving 65% of the interior white (which feels open enough).
    // For larger grids like 9x9, we increase density to 0.48 to break up excessively long runs,
    // which would otherwise explode the solver search space and cause timeouts.
    double density;
    if (width >= 13) density = 0.68;
    else if (width >= 11) density = 0.60;
    else if (width >= 9) density = 0.48;
    else density = 0.35;
    
    int targetBlack = (interiorCount * density).round();
    
    int currentBlack = 0;
    int attempts = 0;
    
    while (currentBlack < targetBlack && attempts < 1000) {
      int r = rng.nextIntInRange(height - 1) + 1;
      int c = rng.nextIntInRange(width - 1) + 1;
      int idx = r * width + c;
      
      if (cellTypes[idx] == KakuroBoard.cellWhite) {
        cellTypes[idx] = KakuroBoard.cellBlack;
        
        if (_isValidIntermediateLayout(width, height, cellTypes)) {
          currentBlack++;
        } else {
          cellTypes[idx] = KakuroBoard.cellWhite;
        }
      }
      attempts++;
    }
    
    if (currentBlack < targetBlack * 0.5) return null;
    if (!_isValidIntermediateLayout(width, height, cellTypes)) return null;
    
    return KakuroBoard(
      width: width,
      height: height,
      cellTypes: cellTypes,
      cellValues: List<int>.filled(width * height, 0),
      acrossClues: List<int>.filled(width * height, 0),
      downClues: List<int>.filled(width * height, 0),
    );
  }
  
  bool _isValidIntermediateLayout(int width, int height, List<int> cellTypes) {
    int whiteCount = 0;
    int startWhite = -1;
    
    // Check horizontal 1-cell runs
    for (int r = 0; r < height; r++) {
      int runLen = 0;
      for (int c = 0; c < width; c++) {
        int idx = r * width + c;
        if (cellTypes[idx] == KakuroBoard.cellWhite) {
          runLen++;
          whiteCount++;
          startWhite = idx;
        } else {
          if (runLen == 1) return false;
          runLen = 0;
        }
      }
      if (runLen == 1) return false;
    }
    
    // Check vertical 1-cell runs
    for (int c = 0; c < width; c++) {
      int runLen = 0;
      for (int r = 0; r < height; r++) {
        int idx = r * width + c;
        if (cellTypes[idx] == KakuroBoard.cellWhite) {
          runLen++;
        } else {
          if (runLen == 1) return false;
          runLen = 0;
        }
      }
      if (runLen == 1) return false;
    }
    
    if (startWhite == -1) return false;
    
    List<bool> visited = List<bool>.filled(cellTypes.length, false);
    List<int> queue = [startWhite];
    visited[startWhite] = true;
    int head = 0;
    int visitedCount = 0;
    
    while (head < queue.length) {
      int curr = queue[head++];
      visitedCount++;
      int r = curr ~/ width;
      int c = curr % width;
      
      final List<int> neighbors = [
        if (r > 0) curr - width,
        if (r < height - 1) curr + width,
        if (c > 0) curr - 1,
        if (c < width - 1) curr + 1,
      ];
      
      for (int n in neighbors) {
        if (!visited[n] && cellTypes[n] == KakuroBoard.cellWhite) {
          visited[n] = true;
          queue.add(n);
        }
      }
    }
    
    return visitedCount == whiteCount;
  }
  
  KakuroBoard? _assignSolution(KakuroBoard layout, SeededRng rng) {
    // Simple CSP to assign 1-9 to white cells without duplicates in runs
    List<int> cells = List<int>.from(layout.cellValues);
    int nodes = 0;
    
    bool solve(int index) {
      if (nodes++ > 100000) return false;
      
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
        if (nodes > 100000) return false;
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
