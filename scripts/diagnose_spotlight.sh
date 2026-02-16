#!/bin/bash
#
# Spotlight Index Health Diagnostic
# Checks Spotlight indexing status and identifies potential issues
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=============================================="
echo "Spotlight Index Health Diagnostic"
echo "=============================================="
echo ""

# Check if Spotlight indexing is enabled
echo "1. Checking if Spotlight indexing is enabled..."
if mdutil -s / | grep -q "Indexing and searching are enabled"; then
    echo -e "${GREEN}✓ Spotlight indexing is enabled${NC}"
else
    echo -e "${RED}✗ Spotlight indexing is DISABLED${NC}"
    echo "  Run: sudo mdutil -i on /"
    exit 1
fi

echo ""
echo "2. Checking indexing status for common directories..."

# Define directories to check
DIRS=(
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/Desktop"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        status=$(mdutil -s "$dir" 2>/dev/null || echo "Unknown")
        if echo "$status" | grep -q "Indexing enabled"; then
            echo -e "  ${GREEN}✓${NC} $dir: $status"
        else
            echo -e "  ${YELLOW}⚠${NC} $dir: $status"
        fi
    fi
done

echo ""
echo "3. Checking Spotlight index size..."
index_path="/.Spotlight-V100"
if [ -d "$index_path" ]; then
    index_size=$(du -sh "$index_path" 2>/dev/null | cut -f1)
    echo "   Index size: $index_size"
else
    echo -e "   ${YELLOW}Cannot determine index size (permission denied)${NC}"
fi

echo ""
echo "4. Running quick search test (with timeout)..."
# Use perl to add timeout
test_result=$(perl -e 'alarm 5; exec @ARGV' mdfind -name "test" 2>&1 | head -5 || echo "TIMEOUT or ERROR")
if echo "$test_result" | grep -q "TIMEOUT"; then
    echo -e "${RED}✗ mdfind query timed out - possible index issue${NC}"
else
    echo -e "${GREEN}✓ mdfind query responded${NC}"
fi

echo ""
echo "5. Checking for index corruption signs..."
# Check if there are any obvious corruption indicators
error_count=$(mdutil -v / 2>&1 | grep -ci "error" || true)
if [ "$error_count" -gt 0 ]; then
    echo -e "${RED}✗ Found $error_count error messages in Spotlight${NC}"
    mdutil -v / 2>&1 | grep -i "error" | head -5
else
    echo -e "${GREEN}✓ No obvious error messages${NC}"
fi

echo ""
echo "=============================================="
echo "Diagnostic complete"
echo "=============================================="
echo ""
echo "If issues found, try:"
echo "  1. Rebuild index: mdutil -E /"
echo "  2. Check disk: First Aid in Disk Utility"
echo "  3. Verify permissions: mdutil -i /"
