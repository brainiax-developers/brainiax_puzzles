import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/kakuro_dictionary.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  print('=== Deep Kakuro Debug ===\n');
  
  final String seedStr = 'kakuro_debug_seed';
  final int seed64 = Seed.fromString(seedStr);
  final SeededRng rng = SeededRng(seed64);
  const KakuroSolver solver = KakuroSolver();
  
  // Check dictionary
  print('Dictionary check:');
  for (int length = 2; length <= 9; length++) {
    final combos = KakuroDictionary.getCombinationsForLength(length);
    print('  Length $length: ${combos?.length ?? 0} sums available');
  }
  
  print('\n--- Attempting manual generation ---');
  
  // Simplified template - smaller
  const List<String> layout = <String>[
    '######',
    '##...#',
    '#....#',
    '#....#',
    '#...##',
    '######',
  ];
  
  final int height = layout.length;
  final int width = layout.first.length;
  print('Template size: ${width}x$height');
  
  // Build entries manually
  final List<List<int>> acrossEntries = [];
  final List<List<int>> downEntries = [];
  
  // Across entries
  for (int row = 0; row < height; row++) {
    int col = 0;
    while (col < width) {
      if (layout[row][col] == '.') {
        final List<int> cells = <int>[];
        while (col < width && layout[row][col] == '.') {
          final int index = row * width + col;
          cells.add(index);
          col++;
        }
        if (cells.length >= 2) {
          acrossEntries.add(cells);
        }
      } else {
        col++;
      }
    }
  }
  
  // Down entries
  for (int col = 0; col < width; col++) {
    int row = 0;
    while (row < height) {
      if (layout[row][col] == '.') {
        final List<int> cells = <int>[];
        while (row < height && layout[row][col] == '.') {
          final int index = row * width + col;
          cells.add(index);
          row++;
        }
        if (cells.length >= 2) {
          downEntries.add(cells);
        }
      } else {
        row++;
      }
    }
  }
  
  print('Across entries: ${acrossEntries.length}');
  for (int i = 0; i < acrossEntries.length; i++) {
    print('  Entry $i: length ${acrossEntries[i].length}, cells ${acrossEntries[i]}');
  }
  
  print('Down entries: ${downEntries.length}');
  for (int i = 0; i < downEntries.length; i++) {
    print('  Entry $i: length ${downEntries[i].length}, cells ${downEntries[i]}');
  }
  
  // Try to generate a solution manually
  print('\n--- Attempting solution generation ---');
  int attempts = 0;
  bool success = false;
  
  while (attempts < 100 && !success) {
    attempts++;
    final testRng = SeededRng(seed64 + attempts);
    
    // Try random valid combinations for each entry
    final List<int> values = List<int>.filled(width * height, 0);
    final Map<int, int> entrySums = {};
    bool valid = true;
    
    // Assign combinations to across entries
    int entryId = 0;
    for (final cells in acrossEntries) {
      final combos = KakuroDictionary.getCombinationsForLength(cells.length);
      if (combos == null || combos.isEmpty) {
        valid = false;
        break;
      }
      
      final sums = combos.keys.toList();
      final chosenSum = sums[testRng.nextInt(sums.length)];
      final masks = combos[chosenSum]!.toList();
      final chosenMask = masks[testRng.nextInt(masks.length)];
      
      entrySums[entryId] = chosenSum;
      
      // Extract digits from mask
      final digits = <int>[];
      for (int d = 1; d <= 9; d++) {
        if ((chosenMask & (1 << d)) != 0) {
          digits.add(d);
        }
      }
      
      // Shuffle and assign
      final shuffled = testRng.permute(digits);
      for (int i = 0; i < cells.length; i++) {
        values[cells[i]] = shuffled[i];
      }
      
      entryId++;
    }
    
    if (!valid) continue;
    
    // Check if down entries are satisfied
    for (final cells in downEntries) {
      final Set<int> seen = {};
      int sum = 0;
      for (final idx in cells) {
        final val = values[idx];
        if (val == 0 || !seen.add(val)) {
          valid = false;
          break;
        }
        sum += val;
      }
      if (!valid) break;
      
      // Check if this is a valid Kakuro combination
      final combos = KakuroDictionary.getCombinations(cells.length, sum);
      if (combos == null || combos.isEmpty) {
        valid = false;
        break;
      }
      
      // Check if the actual digits used form a valid mask
      int mask = 0;
      for (final idx in cells) {
        mask |= (1 << values[idx]);
      }
      if (!combos.contains(mask)) {
        valid = false;
        break;
      }
    }
    
    if (valid) {
      print('✓ Found valid solution at attempt $attempts');
      print('  Values: $values');
      success = true;
      
      // Now build a board and test if solver can find unique solution
      // ... (would need full board construction here)
    }
  }
  
  if (!success) {
    print('✗ Failed to find valid solution after $attempts attempts');
    print('\nThis suggests the template or generation logic has fundamental issues.');
  }
}
