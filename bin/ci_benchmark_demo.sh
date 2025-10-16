#!/bin/bash

# CI Benchmark Integration Demo
# This script demonstrates how the CI benchmark integration works

echo "🚀 CI Benchmark Integration Demo"
echo "================================"
echo ""

# Step 1: Run benchmarks
echo "Step 1: Running benchmarks..."
dart bin/bench.dart \
  --engines "stub,stub_sudoku" \
  --count 10 \
  --difficulty medium \
  --size "9x9" \
  --output benchmark_current.json

echo ""

# Step 2: Check if baseline exists
if [ -f benchmark_baseline.json ]; then
    echo "Step 2: Comparing against baseline..."
    dart bin/bench.dart \
      --ci \
      --baseline benchmark_baseline.json \
      --threshold 20 \
      --output benchmark_current.json
else
    echo "Step 2: No baseline found, creating one..."
    cp benchmark_current.json benchmark_baseline.json
    echo "✅ Baseline created"
fi

echo ""

# Step 3: Show generated artifacts
echo "Step 3: Generated artifacts:"
echo "- benchmark_current.json (full results)"
echo "- benchmark_current_p95.json (p95-only for CI)"
echo "- benchmark_baseline.json (baseline for comparison)"

echo ""

# Step 4: Show p95 artifact content
echo "Step 4: P95 artifact content:"
if [ -f benchmark_current_p95.json ]; then
    cat benchmark_current_p95.json | jq .
else
    echo "P95 artifact not found"
fi

echo ""
echo "✅ Demo completed successfully!"
echo ""
echo "In CI, this would:"
echo "1. Upload artifacts to GitHub Actions"
echo "2. Comment on PRs with performance comparison"
echo "3. Fail the build on >20% regression"
echo "4. Update baseline on main branch pushes"
