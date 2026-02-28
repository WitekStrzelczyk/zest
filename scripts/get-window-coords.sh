#!/bin/bash
# get-window-coords.sh - Get window coordinates for any macOS app
#
# Usage:
#   ./scripts/get-window-coords.sh [app_name] [scale_factor]
#
# Examples:
#   ./scripts/get-window-coords.sh Zest 2      # Zest on Retina
#   ./scripts/get-window-coords.sh Finder 1    # Finder on standard display
#   ./scripts/get-window-coords.sh Zest        # Default: Zest, auto-detect scale

APP_NAME="${1:-Zest}"
SCALE_FACTOR="${2:-}"

# Auto-detect scale factor if not provided
if [ -z "$SCALE_FACTOR" ]; then
    # Check if we're on Retina by looking at screen pixel depth
    RETINA_CHECK=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Retina")
    if [ "$RETINA_CHECK" -gt 0 ]; then
        SCALE_FACTOR=2
    else
        SCALE_FACTOR=1
    fi
fi

# Get window coordinates
COORDS=$(osascript <<EOF
tell application "System Events"
    try
        tell process "$APP_NAME"
            set frontWindow to window 1
            set windowPos to position of frontWindow
            set windowSize to size of frontWindow
            return {item 1 of windowPos, item 2 of windowPos, item 1 of windowSize, item 2 of windowSize}
        end tell
    on error
        return "ERROR: Cannot find window for '$APP_NAME'"
    end try
end tell
EOF
)

if [[ "$COORDS" == ERROR* ]]; then
    echo "$COORDS"
    exit 1
fi

# Parse coordinates
X_POINTS=$(echo "$COORDS" | cut -d',' -f1 | tr -d ' ')
Y_POINTS=$(echo "$COORDS" | cut -d',' -f2 | tr -d ' ')
W_POINTS=$(echo "$COORDS" | cut -d',' -f3 | tr -d ' ')
H_POINTS=$(echo "$COORDS" | cut -d',' -f4 | tr -d ' ')

# Calculate pixel values
X_PIXELS=$(echo "$X_POINTS * $SCALE_FACTOR" | bc | cut -d'.' -f1)
Y_PIXELS=$(echo "$Y_POINTS * $SCALE_FACTOR" | bc | cut -d'.' -f1)
W_PIXELS=$(echo "$W_POINTS * $SCALE_FACTOR" | bc | cut -d'.' -f1)
H_PIXELS=$(echo "$H_POINTS * $SCALE_FACTOR" | bc | cut -d'.' -f1)

# Calculate with 5% padding
PADDING=1.1
CROP_W=$(echo "$W_PIXELS * $PADDING / 1" | bc)
CROP_H=$(echo "$H_PIXELS * $PADDING / 1" | bc)
CROP_X=$(echo "$X_PIXELS - ($W_PIXELS * 0.05) / 1" | bc)
CROP_Y=$(echo "$Y_PIXELS - ($H_PIXELS * 0.05) / 1" | bc)

echo "=== Window Coordinates for '$APP_NAME' ==="
echo ""
echo "Points (AppleScript):"
echo "  X: $X_POINTS  Y: $Y_POINTS"
echo "  Width: $W_POINTS  Height: $H_POINTS"
echo ""
echo "Pixels (${SCALE_FACTOR}x scale):"
echo "  X: $X_PIXELS  Y: $Y_PIXELS"
echo "  Width: $W_PIXELS  Height: $H_PIXELS"
echo ""
echo "ffmpeg crop with 5% padding:"
echo "  -filter:v \"crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y}\""
echo ""
echo "Quick copy for ffmpeg:"
echo "  crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y}"
