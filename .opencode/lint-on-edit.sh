#!/bin/bash

# OpenCode file.edited trigger script
# Run swiftlint on edited file and output errors only
# Usage: Add to OpenCode config as trigger script for file.edited event

set -e

# Get the file path from first argument (OpenCode passes edited file path)
FILE_PATH="$1"

if [ -z "$FILE_PATH" ]; then
    echo "No file path provided"
    exit 0
fi

# Only lint Swift files
if [[ "$FILE_PATH" != *.swift ]]; then
    exit 0
fi

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Run swiftlint on the file
# Use --strict to catch all issues
# Output only errors (not warnings) to keep output minimal
LINT_OUTPUT=$(swiftlint --strict "$FILE_PATH" 2>&1 || true)

# Count violations
ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -c "error:" || true)
WARNING_COUNT=$(echo "$LINT_OUTPUT" | grep -c "warning:" || true)
TOTAL_COUNT=$((ERROR_COUNT + WARNING_COUNT))

# Only output if there are violations
if [ $TOTAL_COUNT -gt 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ LINT: $(basename "$FILE_PATH") ($TOTAL_COUNT violations)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Show errors first
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "🔴 ERRORS ($ERROR_COUNT):"
        echo "$LINT_OUTPUT" | grep "error:" | head -10
        echo ""
    fi
    
    # Show warnings
    if [ $WARNING_COUNT -gt 0 ]; then
        echo "🟡 WARNINGS ($WARNING_COUNT):"
        echo "$LINT_OUTPUT" | grep "warning:" | head -10
    fi
    
    echo ""
    echo "📖 See docs/guides/SWIFT_CODE_STYLE.md for best practices"
    echo ""
    echo "Run './scripts/lint_file.sh $FILE_PATH' for full output"
    echo ""
    
    # Exit with error to signal to OpenCode that there are issues
    exit 1
fi

# Silent success - no violations
exit 0
