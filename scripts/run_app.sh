#!/bin/bash
# Run Zest app - kills existing instances and starts fresh
# Usage: ./scripts/run_app.sh

set -e

# Kill any existing Zest instances
echo "Killing existing Zest instances..."
pkill -f "Zest" 2>/dev/null || true
sleep 0.5

# Build and run
echo "Building and running Zest..."
swift run &

sleep 2
echo "Zest is running. Press Cmd+Space to open the command palette."
