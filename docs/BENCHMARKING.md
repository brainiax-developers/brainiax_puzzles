# Performance Benchmarking

This document describes the performance benchmarking system for puzzle engines.

## Overview

The benchmarking system consists of:
- **Local/CI Scripts**: Command-line tools for running benchmarks
- **CI Integration**: Automated performance regression detection
- **Baseline Management**: Tools for managing performance baselines

## Quick Start

### Running Benchmarks Locally

```bash
# Run benchmarks for default engines
dart bin/bench.dart

# Run benchmarks for specific engines
dart bin/bench.dart --engines "stub,stub_sudoku" --count 100

# Run in CI mode with regression checking
dart bin/bench.dart --ci --baseline benchmark_baseline.json --threshold 20
```

### Managing Baselines

```bash
# Set current results as baseline
dart bin/benchmark_baseline.dart set --file benchmark_results.json

# Get current baseline
dart bin/benchmark_baseline.dart get

# Compare results with baseline
dart bin/benchmark_baseline.dart compare --current benchmark_results.json
```

## Scripts

### `bin/bench.dart`

Main benchmark runner script.

**Options:**
- `--engines, -e`: Comma-separated list of engine IDs (default: "stub,stub_sudoku")
- `--count, -c`: Number of iterations per engine (default: 100)
- `--difficulty, -d`: Difficulty level (default: "medium")
- `--size, -s`: Puzzle size (default: "9x9")
- `--output, -o`: Output file for results (default: "benchmark_results.json")
- `--baseline, -b`: Baseline file to compare against
- `--ci`: Run in CI mode (exit with error code on regression)
- `--threshold`: Regression threshold percentage (default: 20)

**Examples:**
```bash
# Basic benchmark
dart bin/bench.dart

# High-precision benchmark
dart bin/bench.dart --count 1000 --engines "stub,stub_sudoku,sudoku_classic"

# CI regression check
dart bin/bench.dart --ci --baseline benchmark_baseline.json --threshold 20
```

### `bin/benchmark_baseline.dart`

Baseline management utility.

**Commands:**
- `set`: Set a benchmark results file as the baseline
- `get`: Get the current baseline
- `compare`: Compare current results with baseline

**Examples:**
```bash
# Set baseline
dart bin/benchmark_baseline.dart set --file benchmark_results.json

# Compare with baseline
dart bin/benchmark_baseline.dart compare --current benchmark_results.json --threshold 15
```

## CI Integration

### GitHub Actions

The `.github/workflows/benchmark.yml` workflow:
- Runs on pushes to main/develop branches
- Runs on pull requests
- Runs daily at 2 AM UTC
- Compares current performance with baseline
- Fails on >20% regression
- Updates baseline on main branch
- Comments PRs with benchmark results

### Regression Detection

The CI system:
1. Runs benchmarks with 50 iterations per engine
2. Compares P95 times with baseline
3. Fails if any engine shows >20% regression
4. Updates baseline on main branch pushes
5. Comments PRs with performance comparison

## Output Format

Benchmark results are saved as JSON:

```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "results": {
    "stub": {
      "engineId": "stub",
      "success": true,
      "error": null,
      "p95Ms": 15.2,
      "p99Ms": 18.7,
      "totalTimeMs": 1520.0,
      "iterations": 100
    }
  }
}
```

## Performance Metrics

- **P95**: 95th percentile generation time
- **P99**: 99th percentile generation time
- **Total Time**: Total time for all iterations
- **Iterations**: Number of successful iterations

## Regression Thresholds

- **Green**: <10% change
- **Yellow**: 10-20% change (warning)
- **Red**: >20% change (regression)

## Best Practices

1. **Baseline Updates**: Update baselines after performance improvements
2. **Iteration Count**: Use at least 100 iterations for stable results
3. **Multiple Engines**: Test all available engines
4. **CI Monitoring**: Monitor CI failures for performance regressions
5. **Documentation**: Document performance changes in PRs

## Troubleshooting

### Common Issues

1. **Engine Not Found**: Ensure engines are properly registered
2. **High Variance**: Increase iteration count for more stable results
3. **CI Failures**: Check for actual regressions vs. noise
4. **Baseline Missing**: Set initial baseline with `benchmark_baseline.dart set`

### Debug Mode

Run with verbose output:
```bash
dart bin/bench.dart --engines "stub" --count 10
```

This will show detailed timing information for debugging.
