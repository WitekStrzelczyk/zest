#!/bin/bash
set -euo pipefail

# =============================================================================
# Zest Release Script
# 
# Requirements (App Store Connect API Key):
#   - CODE_SIGN_IDENTITY: Your code signing identity (e.g., "Developer ID Application: Name (TEAMID)")
#   - APPLE_API_KEY: The App Store Connect API Key ID (e.g., "2X9R7B3D4E")
#   - APPLE_API_ISSUER: The App Store Connect API Issuer ID
#   - APPLE_API_KEY_PATH: Path to the .p8 private key file
#   - APPLE_TEAM_ID: Your Apple Developer Team ID
#   - APP_NAME: The application name (default: Zest)
#   - APP_VERSION: The version string (default: from Info.plist)
#
# Optional Flags:
#   --skip-notarize    Skip notarization (faster for testing)
#   --skip-dmg         Skip DMG creation
#   --skip-sparkle     Skip Sparkle appcast generation
# =============================================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
OUTPUT_DIR="$PROJECT_DIR/dist"
ICONSET_DIR="$PROJECT_DIR/AppIcon.appiconset"

# Default values
APP_NAME="${APP_NAME:-Zest}"
BUNDLE_ID="${BUNDLE_ID:-com.zest.app}"

# Flags
SKIP_NOTARIZE=false
SKIP_DMG=false
SKIP_SPARKLE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --skip-dmg)
            SKIP_DMG=true
            shift
            ;;
        --skip-sparkle)
            SKIP_SPARKLE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

exit_with_error() {
    log_error "$1"
    exit 1
}

# =============================================================================
# Environment Validation
# =============================================================================

check_env() {
    local var_name="$1"
    
    # Check if variable is set using env | grep to avoid unbound variable issues
    if [[ -z "${!var_name:-}" ]]; then
        exit_with_error "Environment variable $var_name is not set. Please set it before running this script."
    fi
    log_info "$var_name is set"
}

validate_environment() {
    log_info "Validating environment variables..."
    
    check_env "CODE_SIGN_IDENTITY"
    
    # Notarization is optional - only check if all are provided
    if [[ -n "${APPLE_API_KEY:-}" ]] && [[ -n "${APPLE_API_ISSUER:-}" ]] && [[ -n "${APPLE_API_KEY_PATH:-}" ]]; then
        check_env "APPLE_API_KEY"
        check_env "APPLE_API_ISSUER"
        check_env "APPLE_API_KEY_PATH"
        check_env "APPLE_TEAM_ID"
        
        # Validate key path exists
        if [[ ! -f "$APPLE_API_KEY_PATH" ]]; then
            exit_with_error "API key file not found at: $APPLE_API_KEY_PATH"
        fi
        log_info "Notarization will be performed"
    else
        log_info "Notarization keys not provided - will skip notarization"
    fi
    
    log_info "All required environment variables are set"
}

# =============================================================================
# Build
# =============================================================================

build_app() {
    log_info "Building $APP_NAME in release mode..."
    
    cd "$PROJECT_DIR"
    swift build -c release
    
    if [[ ! -f "$BUILD_DIR/$APP_NAME" ]]; then
        exit_with_error "Build failed: executable not found at $BUILD_DIR/$APP_NAME"
    fi
    
    log_info "Build successful"
}

# =============================================================================
# Generate ICNS from AppIconSet
# =============================================================================

generate_icns() {
    log_info "Generating .icns from appiconset..."
    
    local temp_iconset="$OUTPUT_DIR/AppIcon.iconset"
    
    # Clean up any existing iconset
    rm -rf "$temp_iconset"
    mkdir -p "$temp_iconset"
    
    # Copy and rename icons to standard iconset structure
    # icon_16x16.png -> icon_16x16.png
    cp "$ICONSET_DIR/icon_16x16.png" "$temp_iconset/" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_16x16@2x.png" "$temp_iconset/icon_16x16@2x.png" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_32x32.png" "$temp_iconset/" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_32x32@2x.png" "$temp_iconset/icon_32x32@2x.png" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_128x128.png" "$temp_iconset/" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_128x128@2x.png" "$temp_iconset/icon_128x128@2x.png" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_256x256.png" "$temp_iconset/" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_256x256@2x.png" "$temp_iconset/icon_256x256@2x.png" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_512x512.png" "$temp_iconset/" 2>/dev/null || true
    cp "$ICONSET_DIR/icon_512x512@2x.png" "$temp_iconset/icon_512x512@2x.png" 2>/dev/null || true
    
    # Generate icns
    if iconutil -c icns "$temp_iconset" -o "$OUTPUT_DIR/AppIcon.icns"; then
        log_info "Generated AppIcon.icns"
        rm -rf "$temp_iconset"
    else
        log_warn "Failed to generate .icns, using fallback method"
        rm -rf "$temp_iconset"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Create App Bundle
# =============================================================================

create_app_bundle() {
    log_info "Creating app bundle..."
    
    mkdir -p "$OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR/$APP_NAME.app"
    
    APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    
    cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
    
    # Embed Sparkle framework
    embed_sparkle_framework
    
    # Generate and copy app icon
    if generate_icns; then
        cp "$OUTPUT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
        log_info "App icon included"
    elif [[ -d "$ICONSET_DIR" ]]; then
        # Fallback: copy the entire appiconset
        cp -r "$ICONSET_DIR" "$APP_BUNDLE/Contents/Resources/"
        log_warn "Using appiconset directly (may not display correctly)"
    else
        log_warn "No app icon found"
    fi
    
    # Resolve placeholder variables in Info.plist
    sed -e "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" \
        -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g" \
        -e "s/\$(PRODUCT_NAME)/$APP_NAME/g" \
        -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/13.0/g" \
        "$PROJECT_DIR/Sources/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"
    
    echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
    
    VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Sources/Info.plist" | grep string | sed 's/.*>\(.*\)<.*/\1/')
    BUILD_NUM=$(grep -A1 "CFBundleVersion" "$PROJECT_DIR/Sources/Info.plist" | grep integer | sed 's/.*>\(.*\)<.*/\1/' 2>/dev/null || grep -A1 "CFBundleVersion" "$PROJECT_DIR/Sources/Info.plist" | grep string | sed 's/.*>\(.*\)<.*/\1/')
    
    log_info "App bundle created: $APP_BUNDLE (v$VERSION build $BUILD_NUM)"
}

# =============================================================================
# Embed Sparkle Framework
# =============================================================================

embed_sparkle_framework() {
    local sparkle_framework="$BUILD_DIR/Sparkle.framework"
    
    if [[ -d "$sparkle_framework" ]]; then
        log_info "Embedding Sparkle framework..."
        
        # Copy Sparkle framework to Frameworks directory
        cp -R "$sparkle_framework" "$APP_BUNDLE/Contents/Frameworks/"
        
        # Sign the embedded framework (required for notarization)
        # Must sign with the same identity as the app
        if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
            # Remove any existing signature to avoid Team ID conflicts
            rm -rf "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Contents/_CodeSignature" 2>/dev/null || true
            
            codesign --force --sign "$CODE_SIGN_IDENTITY" \
                --options runtime \
                --timestamp \
                "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
            log_info "Sparkle framework signed"
        fi
        
        log_info "Sparkle framework embedded successfully"
    else
        log_warn "Sparkle framework not found at $sparkle_framework"
        log_warn "App may fail to launch without embedded framework"
    fi
}

# =============================================================================
# Fix Rpath for Embedded Frameworks
# =============================================================================

fix_rpath() {
    log_info "Fixing rpath for embedded frameworks..."
    
    local executable="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    
    # Add rpath pointing to Frameworks directory
    # This allows the app to find embedded frameworks
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$executable" 2>/dev/null || true
    
    log_info "Rpath configured"
}

# =============================================================================
# Code Sign
# =============================================================================

sign_app() {
    log_info "Code signing app..."
    
    ENTITLEMENTS="$OUTPUT_DIR/$APP_NAME.entitlements"
    SOURCE_ENTITLEMENTS="$PROJECT_DIR/Sources/Zest.entitlements"
    
    # Use project's entitlements if available, otherwise create default
    if [[ -f "$SOURCE_ENTITLEMENTS" ]]; then
        cp "$SOURCE_ENTITLEMENTS" "$ENTITLEMENTS"
        log_info "Using entitlements from Sources/Zest.entitlements"
    else
        # Create entitlements with common permissions for a launcher app
        cat > "$ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF
        log_info "Using default entitlements"
    fi
    
    codesign --force --deep --sign "$CODE_SIGN_IDENTITY" \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --timestamp \
        "$APP_BUNDLE"
    
    codesign --verify --verbose=2 "$APP_BUNDLE"
    
    log_info "Code signing complete"
}

# =============================================================================
# Create DMG
# =============================================================================

create_dmg() {
    log_info "Creating DMG with Applications link..."
    
    rm -f "$OUTPUT_DIR/$APP_NAME.dmg"
    
    # Create a temporary folder for DMG contents
    DMG_TEMP="$OUTPUT_DIR/dmg_temp"
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"
    
    # Copy the app bundle
    cp -R "$APP_BUNDLE" "$DMG_TEMP/"
    
    # Create symlink to Applications folder
    ln -s /Applications "$DMG_TEMP/Applications"
    
    # Create DMG from the temp folder
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov \
        -format UDZO \
        "$OUTPUT_DIR/$APP_NAME.dmg"
    
    # Clean up temp folder
    rm -rf "$DMG_TEMP"
    
    log_info "DMG created: $OUTPUT_DIR/$APP_NAME.dmg"
    log_info "  (includes Applications folder link for drag-and-drop install)"
}

# =============================================================================
# Notarize
# =============================================================================

notarize_dmg() {
    if [[ "$SKIP_NOTARIZE" == "true" ]]; then
        log_warn "Skipping notarization (--skip-notarize flag)"
        return 0
    fi
    
    log_info "Notarizing DMG (this may take a few minutes)..."
    
    # Skip notarization if API key not properly configured
    if [[ ! -f "${APPLE_API_KEY_PATH:-}" ]] || [[ -z "${APPLE_API_KEY:-}" ]] || [[ -z "${APPLE_API_ISSUER:-}" ]]; then
        log_warn "Skipping notarization - API keys not configured"
        return 0
    fi
    
    # Submit for notarization using App Store Connect API Key
    # --key: path to .p8 file
    # --key-id: the API key ID (e.g., "2X9R7B3D4E")
    # --issuer: the API issuer UUID
    xcrun notarytool submit "$OUTPUT_DIR/$APP_NAME.dmg" \
        --key "$APPLE_API_KEY_PATH" \
        --key-id "$APPLE_API_KEY" \
        --issuer "$APPLE_API_ISSUER" \
        --wait
    
    # Staple notarization to app
    xcrun stapler staple "$APP_BUNDLE"
    
    # Verify stapling
    xcrun stapler validate "$APP_BUNDLE"
    
    log_info "Notarization complete"
}

# =============================================================================
# Generate Sparkle Appcast
# =============================================================================

generate_sparkle_appcast() {
    if [[ "$SKIP_SPARKLE" == "true" ]]; then
        log_warn "Skipping Sparkle appcast generation (--skip-sparkle flag)"
        return 0
    fi
    
    # Check for Sparkle tools
    if ! command -v generate_appcast &> /dev/null; then
        log_warn "Sparkle generate_appcast not found. Install Sparkle or skip with --skip-sparkle"
        return 0
    fi
    
    log_info "Generating Sparkle appcast..."
    
    # Get version info
    VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Sources/Info.plist" | grep string | sed 's/.*>\(.*\)<.*/\1/')
    
    # Create a releases directory for appcast
    RELEASES_DIR="$OUTPUT_DIR/releases"
    mkdir -p "$RELEASES_DIR"
    
    # Copy DMG to releases
    if [[ -f "$OUTPUT_DIR/$APP_NAME.dmg" ]]; then
        cp "$OUTPUT_DIR/$APP_NAME.dmg" "$RELEASES_DIR/"
        
        # Generate appcast
        generate_appcast "$RELEASES_DIR"
        
        log_info "Sparkle appcast generated in $RELEASES_DIR"
    else
        log_warn "No DMG found, skipping appcast generation"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "Starting release process for $APP_NAME..."
    log_info "Output directory: $OUTPUT_DIR"
    
    # Show flags
    if [[ "$SKIP_NOTARIZE" == "true" ]]; then
        log_info "Mode: Skipping notarization"
    fi
    if [[ "$SKIP_DMG" == "true" ]]; then
        log_info "Mode: Skipping DMG creation"
    fi
    if [[ "$SKIP_SPARKLE" == "true" ]]; then
        log_info "Mode: Skipping Sparkle appcast"
    fi
    
    # Validate environment
    validate_environment
    
    # Build
    build_app
    
    # Create bundle
    create_app_bundle
    
    # Fix rpath for embedded frameworks
    fix_rpath
    
    # Sign
    sign_app
    
    # Create DMG
    if [[ "$SKIP_DMG" != "true" ]]; then
        create_dmg
        
        # Notarize
        notarize_dmg
        
        # Generate Sparkle appcast
        generate_sparkle_appcast
    fi
    
    # Get version for display
    VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Sources/Info.plist" | grep string | sed 's/.*>\(.*\)<.*/\1/')
    
    log_info "=========================================="
    log_info "Release complete!"
    log_info "  App:     $OUTPUT_DIR/$APP_NAME.app"
    if [[ "$SKIP_DMG" != "true" ]]; then
        log_info "  DMG:     $OUTPUT_DIR/$APP_NAME.dmg"
        if [[ "$SKIP_SPARKLE" != "true" ]] && [[ -f "$OUTPUT_DIR/releases/appcast.xml" ]]; then
            log_info "  Appcast: $OUTPUT_DIR/releases/appcast.xml"
        fi
    fi
    log_info "  Version: $VERSION"
    log_info "=========================================="

    ls -la "$OUTPUT_DIR"
}

main "$@"
