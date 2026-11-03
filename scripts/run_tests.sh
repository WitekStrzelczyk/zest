#!/bin/bash

# Test runner with timeout
# Usage: ./scripts/run_tests.sh [timeout_seconds] [--coverage]

set -e

TIMEOUT=${1:-120}
COVERAGE=""

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --coverage)
            COVERAGE="--enable-code-coverage"
            ;;
        [0-9]*)
            TIMEOUT=$1
            ;;
    esac
    shift
done

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "⏱  Running tests with ${TIMEOUT}s timeout..."

# Cleanup stale processes
pkill -9 -f "swift-build" 2>/dev/null || true
pkill -9 -f "swift-test" 2>/dev/null || true
rm -f .build/.package-lock 2>/dev/null || true
sleep 1

# Build
echo "🔨 Building..."
swift build 2>&1 | grep -E "(error:|warning:|Build complete)" || true

# Run tests with timeout
echo "🧪 Testing..."
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
TESTING_PLUGINS="$(cd "$(dirname "$(xcrun -f swift)")/../lib/swift/host/plugins/testing" && pwd)"
TEST_FLAGS=(--no-parallel --disable-xctest -Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS")

if [[ -f "$SCRIPT_DIR/timeout.sh" ]]; then
    "$SCRIPT_DIR/timeout.sh" "$TIMEOUT" swift test $COVERAGE "${TEST_FLAGS[@]}"
else
    # Fallback: simple background + wait
    swift test $COVERAGE "${TEST_FLAGS[@]}" &
    TEST_PID=$!
    
    COUNT=0
    while kill -0 $TEST_PID 2>/dev/null; do
        if ((COUNT >= TIMEOUT)); then
            echo ""
            echo "❌ Tests timed out after ${TIMEOUT}s"
            kill -9 $TEST_PID 2>/dev/null || true
            exit 124
        fi
        sleep 1
        ((COUNT++))
    done
    
    wait $TEST_PID
fi

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    echo ""
    echo "✅ Tests passed"
elif [[ $EXIT_CODE -eq 124 ]]; then
    echo ""
    echo "❌ Tests timed out after ${TIMEOUT}s"
fi

exit $EXIT_CODE
