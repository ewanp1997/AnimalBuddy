#!/bin/bash
set -e

echo "🔨 Building Animal Buddy (Release)..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/AnimalBuddy"

APP_NAME="Animal Buddy.app"
PRIMARY_APP="/Applications/$APP_NAME"
USER_APP="/Users/ewanpotter/Applications/$APP_NAME"
BUILD_APP="$(pwd)/.build/AnimalBuddy.app"

package_app() {
    local target="$1"
    echo "📦 Packaging $target..."
    rm -rf "$target"
    mkdir -p "$target/Contents/MacOS"
    mkdir -p "$target/Contents/Resources"

    cp "$BIN_PATH" "$target/Contents/MacOS/AnimalBuddy"
    chmod +x "$target/Contents/MacOS/AnimalBuddy"
    cp App/Info.plist "$target/Contents/Info.plist"
    cp App/AnimalBuddy.icns "$target/Contents/Resources/AnimalBuddy.icns"
    cp App/AnimalBuddyIcon.png "$target/Contents/Resources/AnimalBuddyIcon.png"

    if command -v codesign &> /dev/null; then
        codesign --force --deep --sign - "$target" 2>/dev/null || true
    fi
}

# Package to the primary /Applications location (the exact Dock location)
package_app "$PRIMARY_APP"

# Also sync to user Applications and local .build directory for complete consistency
package_app "$USER_APP"
package_app "$BUILD_APP"

# Register with macOS LaunchServices so the Dock and Finder refresh metadata immediately
if [ -f "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PRIMARY_APP" 2>/dev/null || true
fi

# Package zip for GitHub release
ZIP_NAME="AnimalBuddy-a0.43.zip"
echo "🗜️ Creating release archive $ZIP_NAME..."
rm -f "$ZIP_NAME" ".build/$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$PRIMARY_APP" "$ZIP_NAME"
cp "$ZIP_NAME" ".build/$ZIP_NAME"

echo "✅ App bundle synced across all locations and packaged: $ZIP_NAME"
