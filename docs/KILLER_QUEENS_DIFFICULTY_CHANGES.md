# Killer Queens Difficulty Changes

## Overview
This document summarizes the changes made to the Killer Queens puzzle game to enhance difficulty differentiation and map grid sizes to difficulty levels.

## Grid Size Changes

The grid sizes have been updated to correspond directly with difficulty levels:

| Difficulty | Old Size | New Size | Change |
|------------|----------|----------|--------|
| Easy       | Variable | **6x6**  | Fixed to smaller grid |
| Medium     | Variable | **8x8**  | Fixed to medium grid |
| Hard       | Variable | **10x10** | Fixed to larger grid |
| Expert     | Variable | **12x12** | Fixed to largest grid |

## Generator Changes

### File: `killer_queens_generator.dart`

1. **Grid Size Mapping**: Added `_getTargetSizeForDifficulty()` method that maps difficulty levels to specific grid sizes.

2. **Dynamic Attempt Calculation**: Added `_calculateMaxAttempts()` method that scales generation attempts based on difficulty and grid size:
   - Easy: base attempts (32 + size*2)
   - Medium: 1.2x base attempts
   - Hard: 1.5x base attempts  
   - Expert: 1.8x base attempts

3. **Initial Cage Size Ranges** (more distinct):
   - Easy: (2, 2) - Uniform small cages
   - Medium: (2, 3) - Slight variety
   - Hard: (2, 4) - More variety
   - Expert: (3, 5) - Larger, more complex cages

4. **Final Cage Size Ranges** (enhanced):
   - Easy: size-0 to size+1 (smaller cages)
   - Medium: size-1 to size+2
   - Hard: size-2 to size+3
   - Expert: size-3 to size+4 (much larger cages)

5. **Givens Ranges** (more distinctive):
   - Easy: 70% minimum (was 65%)
   - Medium: 55% minimum (was 50%)
   - Hard: 40% minimum (was 35%)
   - Expert: 25% minimum (unchanged)

## Difficulty Scoring Changes

### File: `killer_queens_difficulty.dart`

Enhanced the difficulty scoring algorithm to better differentiate between difficulty levels:

1. **Size Score**: Grid size now contributes significantly to difficulty:
   - Formula: `(size - 4) * 0.8`
   - 6x6 = 1.6, 8x8 = 3.2, 10x10 = 4.8, 12x12 = 6.4

2. **Cage Complexity**: Larger average cage sizes increase difficulty:
   - Formula: `(avgCageSize - 2.0) * 1.2`

3. **Givens Adjustment**: Inverted scale where fewer givens = harder:
   - Formula: `(1.0 - givensRatio) * 4.0`
   - More weight on the lack of givens

4. **Additional Metrics**: Added new telemetry fields:
   - `givensRatio`: Percentage of queens that are given
   - `sizeScore`: Contribution of grid size to difficulty
   - `cageComplexity`: Contribution of cage sizes to difficulty
   - `givensAdjustment`: Contribution of givens ratio to difficulty

## Difficulty Threshold Changes

### File: `killer_queens_difficulty_thresholds.json`

Updated thresholds to match the new scoring system:

| Bucket | Old Max | New Max | Change |
|--------|---------|---------|--------|
| easy   | 7.0     | **5.5** | Lower threshold for smaller grids |
| medium | 11.5    | **9.5** | Adjusted for medium grids |
| hard   | 15.5    | **13.5** | Adjusted for larger grids |
| expert | 9999.0  | 9999.0  | Unchanged (catch-all) |

## App Registry Changes

### File: `apps/app/lib/shared/services/puzzle_registry.dart`

Updated the Killer Queens metadata to reflect the new supported sizes:
```dart
supportedSizes: ['6x6', '8x8', '10x10', '12x12']
```

## Testing

Created comprehensive test suite in `killer_queens_difficulty_sizes_test.dart` that verifies:

1. ✅ Correct grid sizes generated for each difficulty
2. ✅ Easy puzzles have more givens (≥65%)
3. ✅ Expert puzzles have fewer givens (≤65%)
4. ✅ Easy puzzles have smaller cage sizes
5. ✅ Expert puzzles have larger cage sizes
6. ✅ All difficulties have exactly `size` number of cages

All existing Killer Queens tests continue to pass.

## Benefits

1. **Progressive Difficulty**: Each difficulty level now has a distinct grid size, making progression clearer to players.

2. **Better Differentiation**: Multiple parameters (grid size, cage sizes, givens ratio) work together to create more distinct difficulty levels.

3. **Balanced Complexity**: Larger grids (Expert) naturally have more complexity, while smaller grids (Easy) are more approachable.

4. **Predictable Performance**: Generation attempts scale with difficulty, ensuring quality puzzles across all levels.

5. **Consistent Experience**: Players can expect a consistent challenge level when selecting a difficulty.

## Implementation Details

All changes maintain:
- Deterministic puzzle generation (same seed = same puzzle)
- Unique solutions for all generated puzzles
- Valid board configurations according to Killer Queens rules
- One queen per row, per column, per cage
- No adjacent queens (including diagonals)
