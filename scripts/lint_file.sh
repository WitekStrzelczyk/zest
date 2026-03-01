#!/bin/bash

# Lint a single Swift file with clear, parseable output
# Usage: ./scripts/lint_file.sh path/to/File.swift [--json]
# 
# Output formats:
#   ✅ PASS: File.swift (0 violations)
#   ❌ FAIL: File.swift (3 violations)
#
# Violations include:
#   Line 42: cyclomatic_complexity - Function has complexity 15 (limit: 12)
#   Line 100: line_length - Line is 250 chars (limit: 180)
#   Line 1: file_length - File has 850 lines (limit: 700)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
FILE_PATH=""
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 <file_path> [--json]"
            echo ""
            echo "Lint a single Swift file with SwiftLint"
            echo ""
            echo "Arguments:"
            echo "  <file_path>    Path to the Swift file to lint"
            echo "  --json         Output results in JSON format"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "Exit codes:"
            echo "  0 - No violations"
            echo "  1 - Violations found"
            echo "  2 - File not found or other error"
            exit 0
            ;;
        *)
            FILE_PATH="$1"
            shift
            ;;
    esac
done

# Validate input
if [ -z "$FILE_PATH" ]; then
    echo -e "${RED}Error: No file path provided${NC}"
    echo "Usage: $0 <file_path> [--json]"
    exit 2
fi

# Resolve absolute path
if [[ "$FILE_PATH" != /* ]]; then
    FILE_PATH="$(pwd)/$FILE_PATH"
fi

# Check file exists
if [ ! -f "$FILE_PATH" ]; then
    echo -e "${RED}Error: File not found: $FILE_PATH${NC}"
    exit 2
fi

# Get just the filename for display
FILENAME=$(basename "$FILE_PATH")

# Check if swiftlint is available
if ! command -v swiftlint &> /dev/null; then
    echo -e "${RED}Error: SwiftLint not installed${NC}"
    echo "Install with: brew install swiftlint"
    exit 2
fi

# Run swiftlint on the specific file
# Use --strict to treat warnings as errors
# Use --format for machine-readable output
LINT_OUTPUT=$(swiftlint --strict "$FILE_PATH" 2>&1 || true)
LINT_EXIT_CODE=$?

# Count violations
ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -c "error:" || true)
WARNING_COUNT=$(echo "$LINT_OUTPUT" | grep -c "warning:" || true)
TOTAL_COUNT=$((ERROR_COUNT + WARNING_COUNT))

# Output based on format requested
if [ "$OUTPUT_JSON" = true ]; then
    # JSON output
    echo "{"
    echo "  \"file\": \"$FILENAME\","
    echo "  \"path\": \"$FILE_PATH\","
    echo "  \"passed\": $([ $TOTAL_COUNT -eq 0 ] && echo "true" || echo "false"),"
    echo "  \"violations\": $TOTAL_COUNT,"
    echo "  \"errors\": $ERROR_COUNT,"
    echo "  \"warnings\": $WARNING_COUNT,"
    echo "  \"details\": ["
    
    # Parse violations into JSON
    VIOLATION_NUM=0
    while IFS= read -r line; do
        if [[ "$line" =~ ([^:]+):([0-9]+):[0-9]+:\ (error|warning):\ (.+)\ -\ (.+) ]]; then
            if [ $VIOLATION_NUM -gt 0 ]; then
                echo ","
            fi
            VIOLATION_NUM=$((VIOLATION_NUM + 1))
            FILE_LINE="${BASH_REMATCH[1]}"
            LINE_NUM="${BASH_REMATCH[2]}"
            SEVERITY="${BASH_REMATCH[3]}"
            RULE="${BASH_REMATCH[4]}"
            MESSAGE="${BASH_REMATCH[5]}"
            
            echo -n "    {\"line\": $LINE_NUM, \"severity\": \"$SEVERITY\", \"rule\": \"$RULE\", \"message\": \"$MESSAGE\"}"
        fi
    done <<< "$LINT_OUTPUT"
    
    echo ""
    echo "  ]"
    echo "}"
else
    # Human-readable output
    if [ $TOTAL_COUNT -eq 0 ]; then
        echo -e "${GREEN}✅ PASS: $FILENAME${NC} (0 violations)"
        exit 0
    else
        echo -e "${RED}❌ FAIL: $FILENAME${NC} ($TOTAL_COUNT violations)"
        echo ""
        echo -e "${YELLOW}Violations:${NC}"
        echo ""
        
        # Show violations in a nice format
        echo "$LINT_OUTPUT" | grep -E "error:|warning:" | while IFS= read -r line; do
            # Format: /path/to/file.swift:LINE:COL: error: RULE Violation: MESSAGE (rule_name)
            if [[ "$line" =~ ^([^:]+):([0-9]+):[0-9]+:\ (error|warning):\ (.+)\ Violation:\ (.+) ]]; then
                LINE_NUM="${BASH_REMATCH[2]}"
                SEVERITY="${BASH_REMATCH[3]}"
                FULL_RULE="${BASH_REMATCH[4]}"
                MESSAGE="${BASH_REMATCH[5]}"
                
                if [ "$SEVERITY" = "error" ]; then
                    echo -e "  ${RED}✗${NC} Line $LINE_NUM: $FULL_RULE - $MESSAGE"
                else
                    echo -e "  ${YELLOW}⚠${NC} Line $LINE_NUM: $FULL_RULE - $MESSAGE"
                fi
            fi
        done
        
        echo ""
        echo -e "${RED}Summary: $ERROR_COUNT errors, $WARNING_COUNT warnings${NC}"
        echo ""
        
        # Suggest fixes
        echo -e "${BLUE}Suggestions:${NC}"
        echo "  • Run 'swiftformat $FILE_PATH' to fix formatting issues"
        echo "  • Break long functions into smaller pieces"
        echo "  • Extract complex logic into separate functions"
        echo "  • Split files that exceed 700 lines"
        
        exit 1
    fi
fi
