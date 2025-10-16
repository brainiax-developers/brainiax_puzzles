# CI Benchmark Integration

This document describes the CI integration for performance benchmarking and regression detection.

## Overview

The CI benchmark integration provides:
- **Non-blocking dev metrics**: Performance data without blocking releases
- **Regression detection**: Automatic detection of >20% performance regressions
- **Device-specific data**: Integration with in-app benchmark results
- **PR automation**: Automatic comments with performance comparisons

## Components

### 1. CLI Benchmark Script (`bin/bench.dart`)

The main benchmark runner that:
- Runs puzzle engine benchmarks on the host
- Outputs comprehensive JSON results
- Generates p95-only artifacts for CI consumption
- Supports regression comparison against baselines

**Usage:**
```bash
# Basic benchmark run
dart bin/bench.dart --engines "stub,stub_sudoku" --count 100

# CI mode with regression check
dart bin/bench.dart --ci --baseline baseline.json --threshold 20
```

**Output Files:**
- `benchmark_results.json`: Full benchmark results with metadata
- `benchmark_results_p95.json`: P95-only data for CI consumption

### 2. CI Workflow (`.github/workflows/benchmark.yml`)

Automated workflow that:
- Runs on pushes to main/develop branches
- Runs on pull requests
- Runs daily at 2 AM UTC
- Compares against baseline and detects regressions
- Uploads artifacts and comments on PRs

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`
- Daily schedule (2 AM UTC)

**Actions:**
- Runs benchmarks with 100 iterations per engine
- Compares against baseline (20% regression threshold)
- Updates baseline on main branch pushes
- Comments on PRs with performance comparison
- Fails build on significant regressions

### 3. PR Template (`.github/pull_request_template.md`)

Template that includes:
- Performance impact checklist
- Instructions for device benchmark attachment
- Links to CI benchmark results

## Usage

### For Developers

1. **Host Benchmarks**: Automatically run in CI
2. **Device Benchmarks**: Manual attachment to PRs
   - Access benchmark screen: Tap "Puzzle Home" 5 times
   - Run benchmark with default settings
   - Export JSON and attach to PR

### For CI/CD

The workflow automatically:
- Detects performance regressions
- Updates baselines on main branch
- Provides performance feedback on PRs
- Maintains performance history

## Regression Detection

**Threshold**: 20% increase in P95 generation time
**Scope**: Per-engine comparison against baseline
**Action**: Fails CI build on regression detection

**Example:**
```
⚠️  Regression in stub: 25.3%
❌ Performance regression detected!
Regression: 25.3%
Threshold: 20%
```

## Artifacts

### Host Benchmark Artifacts
- `benchmark_current.json`: Full results with metadata
- `benchmark_current_p95.json`: P95-only data for CI
- `benchmark_baseline.json`: Baseline for comparison

### Device Benchmark Integration
- Manual JSON attachment to PRs
- Device-specific performance metrics
- Cross-device performance comparison

## Configuration

### Environment Variables
- `BENCHMARK_ENGINES`: Comma-separated engine list (default: "stub,stub_sudoku")
- `BENCHMARK_COUNT`: Iterations per engine (default: 100)
- `BENCHMARK_THRESHOLD`: Regression threshold % (default: 20)

### Workflow Customization
Edit `.github/workflows/benchmark.yml` to:
- Change trigger conditions
- Modify benchmark parameters
- Adjust regression thresholds
- Customize PR comments

## Monitoring

### Performance Trends
- Daily benchmark runs provide trend data
- Baseline updates track performance evolution
- PR comments show performance impact

### Regression Alerts
- CI failures on regressions
- PR comments highlight performance changes
- Artifact uploads preserve performance history

## Troubleshooting

### Common Issues

1. **Benchmark Failures**
   - Check engine availability
   - Verify dependency installation
   - Review error logs in CI

2. **Regression False Positives**
   - Adjust threshold in workflow
   - Review baseline freshness
   - Check for environmental factors

3. **Missing Baselines**
   - Workflow creates baseline on first run
   - Manual baseline creation: `cp current.json baseline.json`

### Debug Commands

```bash
# Run benchmark locally
dart bin/bench.dart --engines "stub" --count 10

# Test regression detection
dart bin/bench.dart --ci --baseline baseline.json --threshold 20

# Demo CI workflow
bash bin/ci_benchmark_demo.sh
```

## Future Enhancements

- [ ] Automated device benchmark collection
- [ ] Performance trend visualization
- [ ] Cross-platform benchmark comparison
- [ ] Performance regression notifications
- [ ] Benchmark result caching
