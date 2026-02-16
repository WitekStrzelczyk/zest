#!/bin/bash

# Simple test runner with timeout and lock detection
# Usage: ./scripts/run_tests.sh [timeout_seconds] [--coverage]
#        ./scripts/run_tests.sh -h|--help

show_help() {
    echo "Usage: ./scripts/run_tests.sh [timeout_seconds] [--coverage]"
    echo ""
    echo "Arguments:"
    echo "  timeout_seconds  Test timeout in seconds (default: 40)"
    echo "  --coverage       Enable code coverage reporting"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/run_tests.sh              # Run tests with 40s timeout"
    echo "  ./scripts/run_tests.sh 60            # Run tests with 60s timeout"
    echo "  ./scripts/run_tests.sh 40 --coverage # Run tests with coverage"
    echo ""
    echo "The timeout parameter controls how long tests can run before being"
    echo "terminated. This prevents deadlocks and lock issues from freezing"
    echo "the development environment."
}

# Check for help flags
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

TIMEOUT=${1:-40}
shift || true
COVERAGE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --coverage)
            COVERAGE="--enable-code-coverage"
            ;;
        *)
            ;;
    esac
    shift
done

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
cd "$PROJECT_DIR"

echo "Running tests with ${TIMEOUT}s timeout..."

# Kill any stale SwiftPM processes
echo "Cleaning up stale processes..."
pkill -9 -f "swift" 2>/dev/null || true
rm -f .build/.package-lock 2>/dev/null || true
sleep 1

# Build first (separate from test to isolate issues)
echo "Building..."
swift build 2>&1 || {
    echo "Build failed"
    exit 1
}

# Run tests (without coverage first - much faster)
TEST_CMD="swift test"
if [ -n "$COVERAGE" ]; then
    TEST_CMD="swift test --enable-code-coverage"
fi

echo "Running tests..."

perl -e '
    use strict;
    use warnings;
    use POSIX qw(strftime WNOHANG);
    my $timeout = $ARGV[0];
    shift @ARGV;
    my @cmd = @ARGV;

    my $pid = fork();
    if ($pid == 0) {
        exec(@cmd) or die "exec failed: $!";
    } elsif (defined $pid) {
        my $start = time();
        my $done = 0;
        my $status = 0;

        while (!$done && (time() - $start) < $timeout) {
            sleep 1;
            my $ret = waitpid($pid, WNOHANG);
            if ($ret == $pid) {
                $status = $? >> 8;
                $done = 1;
            } elsif ($ret == -1) {
                $status = 1;
                $done = 1;
            }
        }

        if (!$done) {
            kill("TERM", $pid);
            sleep 1;
            kill("KILL", $pid) if kill(0, $pid);
            waitpid($pid, 0);
            print STDERR "\n[TIMEOUT] Tests exceeded ${timeout}s limit\n";
            exit(124);
        }
        exit($status);
    } else {
        die "fork failed";
    }
' "$TIMEOUT" sh -c "$TEST_CMD" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "ERROR: Tests timed out after ${TIMEOUT}s"
    echo "This indicates a lock/deadlock issue"
    echo ""
    echo "Attempting cleanup..."
    pkill -9 -f "swift" 2>/dev/null || true
    exit 1
elif [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Tests failed with exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi

echo ""
echo "Tests completed successfully"
