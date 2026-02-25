# Demo Recording Guide

How to create high-quality demo videos of Zest features using ffmpeg and AppleScript automation.

---
**last_reviewed:** 2026-02-25
**status:** current
---

## Overview

This guide covers the complete workflow for recording demo videos of Zest features:
1. Getting window position and size (in points)
2. Converting to pixels for Retina displays
3. Adding padding around the window
4. Recording with ffmpeg
5. Automating interactions with AppleScript

## Prerequisites

- [ffmpeg](https://ffmpeg.org/) installed (`brew install ffmpeg`)
- Zest app running
- Screen recording permissions granted to Terminal

## Quick Start

```bash
# 1. Start Zest
./scripts/run_app.sh &
sleep 4

# 2. Get window coordinates (see Helper Functions below)
# ... run get-window-coords.sh ...

# 3. Record with calculated values
ffmpeg -f avfoundation -framerate 30 -i "3" -t 15 \
    -filter:v "crop=WIDTH:HEIGHT:X:Y" \
    -pix_fmt yuv420p \
    demo.mp4
```

## Understanding Points vs Pixels

### The Retina Scaling Gotcha

**Critical:** AppleScript returns coordinates in "points", but ffmpeg captures in "pixels".

| Device | Scale Factor |
|--------|--------------|
| Standard display | 1x (points = pixels) |
| Retina display | 2x (pixels = points x 2) |
| Pro Display XDR | 2x |

### Example Conversion

AppleScript output (points): `x=416, y=308, width=680, height=344`

On a 2x Retina display:
```
Pixel X      = 416 * 2 = 832
Pixel Y      = 308 * 2 = 616
Pixel Width  = 680 * 2 = 1360
Pixel Height = 344 * 2 = 688
```

## Getting Window Coordinates

### Method 1: AppleScript (Recommended)

```bash
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
```

Output format: `x, y, width, height` (in points)

### Method 2: Detect Scale Factor Automatically

```bash
# Get scale factor (1 for standard, 2 for Retina)
SCALE=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' | awk '{print $3}')

# If the width is very large, it's likely pixels, not points
# Most Mac screens are 1440-2560 points wide
```

## Adding Padding Around the Window

### Padding Formula

5% padding provides a nice visual buffer:

```
New Width  = Width * 1.1
New Height = Height * 1.1
New X      = X - (Width * 0.05)
New Y      = Y - (Height * 0.05)
```

### Example Calculation

Window in pixels: `x=832, y=616, width=1360, height=688`

```
New Width  = 1360 * 1.1 = 1496
New Height = 688  * 1.1 = 757
New X      = 832 - (1360 * 0.05) = 832 - 68 = 764
New Y      = 616 - (688 * 0.05)  = 616 - 34 = 582
```

### Padding Table

| Padding % | Multiplier | Example Width (1360px) |
|-----------|------------|------------------------|
| 5% | 1.10 | 1496 |
| 10% | 1.20 | 1632 |
| 15% | 1.30 | 1768 |

## Recording with ffmpeg

### Basic Recording

```bash
ffmpeg -f avfoundation -framerate 30 -i "3" -t 15 \
    -filter:v "crop=1496:757:764:582" \
    -pix_fmt yuv420p \
    output.mp4
```

### Parameter Explanation

| Parameter | Meaning |
|-----------|---------|
| `-f avfoundation` | Use macOS AVFoundation capture |
| `-framerate 30` | 30 frames per second |
| `-i "3"` | Input device 3 (usually screen 0) |
| `-t 15` | Record for 15 seconds |
| `-filter:v "crop=W:H:X:Y"` | Crop to window region |
| `-pix_fmt yuv420p` | Compatible pixel format for web |

### List Available Capture Devices

```bash
ffmpeg -f avfoundation -list_devices true -i ""
```

Common outputs:
- `[0] FaceTime HD Camera`
- `[1] Capture screen 0`
- `[2] Capture screen 1`
- `[3]` (sometimes blank - use the number before it)

## Automating Demo Interactions

### Opening the Command Palette

```bash
# Cmd+Space to open
osascript -e 'tell application "System Events" to keystroke " " using {command down}'
```

### Typing Text

```bash
# Type a search query
osascript -e 'tell application "System Events" to keystroke "calendar"'

# Add delay for visual feedback
sleep 0.5
osascript -e 'tell application "System Events" to keystroke " event"'
```

### Clearing Text Fields

```bash
# Cmd+A to select all
osascript -e 'tell application "System Events" to keystroke "a" using {command down}'
sleep 0.1
# Delete key (key code 51)
osascript -e 'tell application "System Events" to key code 51'
```

### Navigation Keys

| Action | Key Code |
|--------|----------|
| Delete | 51 |
| Return | 36 |
| Escape | 53 |
| Up Arrow | 126 |
| Down Arrow | 125 |
| Tab | 48 |

### Using Key Codes for Special Keys

```bash
# Press Escape to close
osascript -e 'tell application "System Events" to key code 53'

# Press Down arrow twice
osascript -e 'tell application "System Events" to key code 125'
osascript -e 'tell application "System Events" to key code 125'
```

## Preparing the Environment

### Minimize All Apps Before Recording

```bash
osascript <<'EOF'
tell application "System Events"
    set appList to name of every process whose background only is false
    repeat with appName in appList
        try
            tell application appName
                if name is not "Finder" and name is not "Zest" then
                    set visible to false
                end if
            end tell
        end try
    end repeat
end tell
EOF
```

### Set Clean Desktop

```bash
# Hide desktop icons
defaults write com.apple.finder CreateDesktop -bool false
killall Finder

# After recording, restore:
defaults write com.apple.finder CreateDesktop -bool true
killall Finder
```

## Complete Demo Script Template

```bash
#!/bin/bash
# demo-recording.sh - Record a Zest feature demo
# Usage: ./demo-recording.sh <output_filename>

set -e

OUTPUT="${1:-demo.mp4}"
DURATION="${2:-15}"
SCALE_FACTOR=2  # Set to 1 for non-Retina displays

echo "=== Zest Demo Recording ==="
echo "Output: $OUTPUT"
echo "Duration: ${DURATION}s"

# 1. Start Zest
echo "Starting Zest..."
./scripts/run_app.sh &
sleep 4

# 2. Get window coordinates (points)
echo "Getting window coordinates..."
COORDS=$(osascript <<'EOF'
tell application "System Events"
    tell process "Zest"
        set frontWindow to window 1
        set windowPos to position of frontWindow
        set windowSize to size of frontWindow
        return {item 1 of windowPos, item 2 of windowPos, item 1 of windowSize, item 2 of windowSize}
    end tell
end tell
EOF
)

# Parse coordinates
X_POINTS=$(echo "$COORDS" | cut -d',' -f1 | tr -d ' ')
Y_POINTS=$(echo "$COORDS" | cut -d',' -f2 | tr -d ' ')
W_POINTS=$(echo "$COORDS" | cut -d',' -f3 | tr -d ' ')
H_POINTS=$(echo "$COORDS" | cut -d',' -f4 | tr -d ' ')

# Convert to pixels with 5% padding
W_PIXELS=$(echo "$W_POINTS * $SCALE_FACTOR" | bc)
H_PIXELS=$(echo "$H_POINTS * $SCALE_FACTOR" | bc)
X_PIXELS=$(echo "$X_POINTS * $SCALE_FACTOR" | bc)
Y_PIXELS=$(echo "$Y_POINTS * $SCALE_FACTOR" | bc)

# Add 5% padding
CROP_W=$(echo "$W_PIXELS * 1.1 / 1" | bc)
CROP_H=$(echo "$H_PIXELS * 1.1 / 1" | bc)
CROP_X=$(echo "$X_PIXELS - ($W_PIXELS * 0.05) / 1" | bc)
CROP_Y=$(echo "$Y_PIXELS - ($H_PIXELS * 0.05) / 1" | bc)

echo "Window: ${W_POINTS}x${H_POINTS} points @ (${X_POINTS}, ${Y_POINTS})"
echo "Crop: ${CROP_W}x${CROP_H} @ (${CROP_X}, ${CROP_Y}) pixels"

# 3. Start recording in background
echo "Starting recording..."
ffmpeg -f avfoundation -framerate 30 -i "3" -t "$DURATION" \
    -filter:v "crop=${CROP_W}:${CROP_H}:${CROP_X}:${CROP_Y}" \
    -pix_fmt yuv420p \
    "$OUTPUT" &
FFMPEG_PID=$!

sleep 2

# 4. Demo interactions
echo "Running demo interactions..."
osascript -e 'tell application "System Events" to keystroke " " using {command down}'
sleep 1
osascript -e 'tell application "System Events" to keystroke "calendar"'
sleep 3

# 5. Wait for recording to complete
echo "Waiting for recording to complete..."
wait $FFMPEG_PID

echo "Demo saved to: $OUTPUT"
echo "Done!"
```

## Helper Functions

### Bash Functions for ~/.zshrc or ~/.bashrc

```bash
# Get Zest window coordinates in pixels
zest-coords() {
    local scale="${1:-2}"
    osascript <<EOF
tell application "System Events"
    tell process "Zest"
        set frontWindow to window 1
        set windowPos to position of frontWindow
        set windowSize to size of frontWindow
        set x to item 1 of windowPos * $scale
        set y to item 2 of windowPos * $scale
        set w to item 1 of windowSize * $scale
        set h to item 2 of windowSize * $scale
        return "Pixels: x=" & x & ", y=" & y & ", w=" & w & ", h=" & h
    end tell
end tell
EOF
}

# Record Zest window with padding
zest-record() {
    local output="${1:-demo.mp4}"
    local duration="${2:-10}"
    local padding="${3:-1.1}"
    
    # Get coords... (full implementation in scripts/)
    echo "Recording for ${duration}s to ${output}..."
    # ffmpeg command here
}

# Type text with realistic delays
type-text() {
    local text="$1"
    for (( i=0; i<${#text}; i++ )); do
        osascript -e "tell application \"System Events\" to keystroke \"${text:$i:1}\""
        sleep 0.05
    done
}
```

## Troubleshooting

### ffmpeg shows black screen

1. Grant screen recording permission to Terminal
2. Check the correct input device: `ffmpeg -f avfoundation -list_devices true -i ""`
3. Try different device numbers (1, 2, 3)

### Window not found error

```bash
# Ensure Zest is running and visible
pgrep -f "Zest" || ./scripts/run_app.sh

# Check if process is visible to System Events
osascript -e 'tell application "System Events" to get name of every process'
```

### Crop area out of bounds

- The crop X,Y must be positive
- The crop area must fit within screen bounds
- Reduce padding if needed

### Recording is blurry

- Ensure using correct scale factor (2 for Retina)
- Check that crop dimensions are even numbers
- Use higher bitrate: `-b:v 5M`

## Best Practices

1. **Record at 30fps** - Smooth motion, reasonable file size
2. **Use yuv420p** - Maximum compatibility for web
3. **Add 5% padding** - Visual breathing room
4. **Keep demos short** - 10-15 seconds ideal
5. **Test timing** - Run interactions manually first
6. **Clean desktop** - Remove distractions

## Related Documentation

- [TDD Guidelines](../TDD_GUIDELINES.md) - Development workflow
- [scripts/run_app.sh](/Users/witek/projects/copies/zest/scripts/run_app.sh) - App launcher script

---

*Last reviewed: 2026-02-25*
