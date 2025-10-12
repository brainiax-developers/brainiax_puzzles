# Engine Bench Screen

A hidden development screen for measuring puzzle engine performance on-device.

## Access

The bench screen is accessible via a hidden gesture:
1. Tap the "Puzzle Home" title in the app bar 5 times within 2 seconds
2. This will navigate to the bench screen

## Features

- **Input Configuration**: Set puzzle ID, difficulty, size, and count
- **Isolate-based Benchmarking**: Runs puzzle generation in a separate isolate to avoid blocking the UI
- **Performance Metrics**: Collects p50/p95/p99 generation times and validation p95
- **Device Information**: Displays device model, OS version, and engine version
- **Acceptance Gates**: Validates generation success, validation success, metadata presence, and telemetry presence
- **JSON Export**: Copy benchmark results as JSON for easy sharing in issues

## Usage

1. Enter a valid puzzle engine ID (e.g., 'stub', 'sudoku_classic')
2. Set difficulty level (easy, medium, hard)
3. Specify puzzle size (e.g., '9x9', '6x6')
4. Set the number of puzzles to generate (default: 10)
5. Tap "Run Benchmark"
6. View results and copy JSON if needed

## Available Engines

The bench screen automatically detects and validates against available engines:
- `stub`: Stub puzzle engine for testing
- `stub_sudoku`: Stub sudoku engine
- `sudoku_classic`: Classic sudoku engine
- Other engines as they become available

## Output Format

The JSON export includes:
- Device information (model, OS version)
- Engine information (version, puzzle ID)
- Benchmark configuration (difficulty, size, count)
- Performance metrics (total time, percentiles)
- Acceptance gate results
- Timestamp

This data can be directly pasted into GitHub issues for performance analysis.
