#!/bin/bash
# demo-recording.sh - Record Zest feature demos with automatic window detection
#
# Usage:
#   ./scripts/demo-recording.sh [output_file] [duration] [scale_factor]
#
# Examples:
#   ./scripts/demo-recording.sh demo.mp4 15 2    # Retina display
#   ./scripts/demo-recording.sh demo.mp4 10 1    # Standard display
#   ./scripts/demo-recording.sh                   # Defaults: demo.mp4, 15s, 2x scale
#
# Requirements:
#   - ffmpeg installed (brew install ffmpeg)
#   - Screen recording permission for Terminal
#   - Zest app running or will be started automatically

set -e

# Configuration
OUTPUT="${1:-demo.mp4}"
DURATION="${2:-15}"
SCALE_FACTOR="${3:-2}"  # 2 for Retina, 1 for standard displays
PADDING="${PADDING:-1.1}"  # 10% padding (1.1 = width * 1.1)
FPS="${FPS:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get Zest window coordinates using AppleScript
get_window_coords() {
    osascript <<'EOF'
tell application "System Events"
    tell process "Zest"
        set frontWindow to window 1
        set windowPos to position of frontWindow
        set windowSize to size of frontWindow
        return {item 1 of windowPos, item 2 of windowPos, item 1 of windowSize, item 2 of windowSize}
    end tell
end tell
EOF
}

# Check if ffmpeg is installed
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        log_error "ffmpeg not found. Install with: brew install ffmpeg"
        exit 1
    fi
    log_success "ffmpeg found"
}

# Check if Zest is running, start if not
ensure_zest_running() {
    if pgrep -x "Zest" > /dev/null 2>&1; then
        log_success "Zest is already running"
        return 0
    fi
    
    log_info "Starting Zest..."
    if [ -f "./scripts/run_app.sh" ]; then
        ./scripts/run_app.sh &
    elif [ -f "scripts/run_app.sh" ]; then
        ./scripts/run_app.sh &
    else
        log_error "Cannot find run_app.sh. Please start Zest manually."
        exit 1
    fi
    
    log_info "Waiting for Zest to start..."
    sleep 4
    
    if pgrep -x "Zest" > /dev/null 2>&1; then
        log_success "Zest started successfully"
    else
        log_error "Failed to start Zest"
        exit 1
    fi
}

# Calculate crop dimensions with padding
calculate_crop() {
    local x_points=$1
    local y_points=$2
    local w_points=$3
    local h_points=$4
    local scale=$5
    local padding=$6
    
    # Convert to pixels
    local w_pixels=$(echo "$w_points * $scale" | bc | cut -d'.' -f1)
    local h_pixels=$(echo "$h_points * $scale" | bc | cut -d'.' -f1)
    local x_pixels=$(echo "$x_points * $scale" | bc | cut -d'.' -f1)
    local y_pixels=$(echo "$y_points * $scale" | bc | cut -d'.' -f1)
    
    # Add padding
    local crop_w=$(echo "$w_pixels * $padding / 1" | bc)
    local crop_h=$(echo "$h_pixels * $padding / 1" | bc)
    local crop_x=$(echo "$x_pixels - ($w_pixels * ($padding - 1) / 2) / 1" | bc)
    local crop_y=$(echo "$y_pixels - ($h_pixels * ($padding - 1) / 2) / 1" | bc)
    
    # Ensure non-negative values
    crop_x=${crop_x#-}
    crop_y=${crop_y#-}
    
    echo "$crop_x $crop_y $crop_w $crop_h"
}

# Send keystroke to open command palette
open_palette() {
    osascript -e 'tell application "System Events" to keystroke " " using {command down}'
}

# Type text
type_text() {
    osascript -e "tell application \"System Events\" to keystroke \"$1\""
}

# Press key by code
press_key() {
    osascript -e "tell application \"System Events\" to key code $1"
}

# Main recording function
main() {
    echo ""
    echo "=== Zest Demo Recording ==="
    echo "  Output: $OUTPUT"
    echo "  Duration: ${DURATION}s"
    echo "  Scale Factor: ${SCALE_FACTOR}x"
    echo "  Padding: ${PADDING}x"
    echo "  FPS: $FPS"
    echo ""
    
    # Pre-flight checks
    check_ffmpeg
    ensure_zest_running
    
    # Get window coordinates
    log_info "Getting window coordinates..."
    COORDS=$(get_window_coords 2>/dev/null)
    
    if [ -z "$COORDS" ]; then
        log_error "Could not get window coordinates. Is Zest visible?"
        exit 1
    fi
    
    # Parse coordinates (format: x, y, width, height)
    X_POINTS=$(echo "$COORDS" | cut -d',' -f1 | tr -d ' ')
    Y_POINTS=$(echo "$COORDS" | cut -d',' -f2 | tr -d ' ')
    W_POINTS=$(echo "$COORDS" | cut -d',' -f3 | tr -d ' ')
    H_POINTS=$(echo "$COORDS" | cut -d',' -f4 | tr -d ' ')
    
    log_info "Window (points): ${W_POINTS}x${H_POINTS} @ (${X_POINTS}, ${Y_POINTS})"
    
    # Calculate crop dimensions
    read CROP_X CROP_Y CROP_W CROP_H <<< $(calculate_crop $X_POINTS $Y_POINTS $W_POINTS $H_POINTS $SCALE_FACTOR $PADDING)
    
    log_info "Crop (pixels): ${CROP_W}x${CROP_H} @ (${CROP_X}, ${CROP_Y})"
    
    # Start recording
    log_info "Starting ffmpeg recording..."
    ffmpeg -f avfoundation -framerate $FPS -i "3" -t "$DURATION" \
        -filter:v "crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y}" \
        -pix_fmt yuv420p \
        -y \
        "$OUTPUT" 2>/dev/null &
    FFMPEG_PID=$!
    
    # Wait for ffmpeg to initialize
    sleep 2
    
    # Check if ffmpeg is still running
    if ! kill -0 $FFMPEG_PID 2>/dev/null; then
        log_error "ffmpeg failed to start. Check screen recording permissions."
        exit 1
    fi
    
    log_success "Recording started (PID: $FFMPEG_PID)"
    
    # Run demo interactions (customize these for your demo)
    log_info "Running demo interactions..."
    open_palette
    sleep 0.8
    type_text "demo"
    
    # Wait for recording to complete
    log_info "Recording for ${DURATION}s..."
    wait $FFMPEG_PID 2>/dev/null || true
    
    # Verify output
    if [ -f "$OUTPUT" ]; then
        FILE_SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
        log_success "Demo saved to: $OUTPUT ($FILE_SIZE)"
    else
        log_error "Recording failed - output file not created"
        exit 1
    fi
    
    echo ""
    echo "Done! Open with: open $OUTPUT"
}

# Run main function
main "$@"
