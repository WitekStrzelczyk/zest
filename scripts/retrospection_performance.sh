#!/bin/bash
# Retrospection Performance Benchmark Script
# Runs performance tests and captures metrics for retrospection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Zest Performance Retrospection"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

cd "$PROJECT_DIR"

echo "Running performance benchmarks..."
echo ""

# Run the common searches performance test
echo "=== Common Searches Performance ==="
swift test --filter PerformanceBenchmarkTests/test_common_searches_performance_with_memory 2>&1 | grep -E "(Search|PASS|FAIL|error:)" || true

echo ""
echo "=== Search Latency Test ==="
swift test --filter PerformanceBenchmarkTests/test_search_latency_is_under_100ms 2>&1 | grep -E "(latency|Average|Max|results|PASS|FAIL)" || true

echo ""
echo "=== Memory Baseline Test ==="
swift test --filter PerformanceBenchmarkTests/test_memory_baseline_is_reasonable 2>&1 | grep -E "(Memory|PASS|FAIL|MB)" || true

echo ""
echo "=== Full Test Suite ==="
swift test --filter PerformanceBenchmarkTests 2>&1 | tail -20

echo ""
echo "=========================================="
echo "Retrospection complete"
echo "=========================================="
