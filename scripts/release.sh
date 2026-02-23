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
# =============================================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
OUTPUT_DIR="$PROJECT_DIR/dist"

# Default values
APP_NAME="${APP_NAME:-Zest}"
BUNDLE_ID="${BUNDLE_ID:-com.zest.app}"

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
# Create App Bundle
# =============================================================================

create_app_bundle() {
    log_info "Creating app bundle..."
    
    mkdir -p "$OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR/$APP_NAME.app"
    
    APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    
    cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
    
    # Copy app icon
    if [[ -d "$PROJECT_DIR/AppIcon.appiconset" ]]; then
        cp -r "$PROJECT_DIR/AppIcon.appiconset" "$APP_BUNDLE/Contents/Resources/"
        log_info "App icon included"
    else
        log_warn "App iconset not found at $PROJECT_DIR/AppIcon.appiconset"
    fi
    
    # Resolve placeholder variables in Info.plist
    sed -e "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" \
        -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.zest.app/g" \
        -e "s/\$(PRODUCT_NAME)/$APP_NAME/g" \
        -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/13.0/g" \
        "$PROJECT_DIR/Sources/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"
    
    echo -n "APPL????"> "$APP_BUNDLE/Contents/PkgInfo"
    
    VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Sources/Info.plist" | grep string | sed 's/.*>\(.*\)<.*/\1/')
    BUILD_NUM=$(grep -A1 "CFBundleVersion" "$PROJECT_DIR/Sources/Info.plist" | grep integer | sed 's/.*>\(.*\)<.*/\1/')
    
    log_info "App bundle created: $APP_BUNDLE (v$VERSION ($BUILD_NUM))"
}

# =============================================================================
# Code Sign
# =============================================================================

sign_app() {
    log_info "Code signing app..."
    
    ENTITLEMENTS="$OUTPUT_DIR/$APP_NAME.entitlements"
    
    cat > "$ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF
    
    codesign --force --deep --sign "$CODE_SIGN_IDENTITY" \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        "$APP_BUNDLE"
    
    codesign --verify --verbose=2 "$APP_BUNDLE"
    
    log_info "Code signing complete"
}

# =============================================================================
# Create DMG
# =============================================================================

create_dmg() {
    log_info "Creating DMG..."
    
    rm -f "$OUTPUT_DIR/$APP_NAME.dmg"
    
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$APP_BUNDLE" \
        -ov \
        -format UDZO \
        "$OUTPUT_DIR/$APP_NAME.dmg"
    
    log_info "DMG created: $OUTPUT_DIR/$APP_NAME.dmg"
}

# =============================================================================
# Notarize
# =============================================================================

notarize_dmg() {
    log_info "Notarizing DMG (this may take a few minutes)..."
    
    # Skip notarization if API key not properly configured
    if [[ ! -f "$APPLE_API_KEY_PATH" ]] || [[ -z "$APPLE_API_KEY" ]] || [[ -z "$APPLE_API_ISSUER" ]]; then
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
# Main
# =============================================================================

main() {
    log_info "Starting release process for $APP_NAME..."
    log_info "Output directory: $OUTPUT_DIR"
    
    # Validate environment
    validate_environment
    
    # Build
    build_app
    
    # Create bundle
    create_app_bundle
    
    # Sign
    sign_app
    
    # Create DMG
    create_dmg
    
    # Notarize
    notarize_dmg
    
    log_info "=========================================="
    log_info "Release complete!"
    log_info "  App:    $OUTPUT_DIR/$APP_NAME.app"
    log_info "  DMG:    $OUTPUT_DIR/$APP_NAME.dmg"
    log_info "=========================================="

    ls -la "$OUTPUT_DIR"
}

main "$@"
