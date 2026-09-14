#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🔨 Building DeskOrbit (Release)..."
swift build -c release --disable-sandbox --cache-path "/tmp/swiftpm_cache"

BINARY_PATH=$(find "$DIR/.build" -name "DeskOrbit" -type f -perm +111 | grep -i "release" | head -n 1)

if [ -z "$BINARY_PATH" ]; then
    BINARY_PATH=$(find "$DIR/.build" -name "DeskOrbit" -type f -perm +111 | head -n 1)
fi

APP_BUNDLE="$DIR/DeskOrbit.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "📦 Creating .app bundle at '$APP_BUNDLE'..."
rm -rf "$APP_BUNDLE" "$DIR/Devices Control.app"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BINARY_PATH" "$MACOS/DeskOrbit"
chmod +x "$MACOS/DeskOrbit"

if [ -f "$DIR/Info.plist" ]; then
    cp "$DIR/Info.plist" "$CONTENTS/Info.plist"
fi

if [ -f "$DIR/AppIcon.icns" ]; then
    cp "$DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# Apply icon to bundle
if [ -f "$DIR/AppIcon_1024.png" ]; then
    swift -e '
    import AppKit
    let img = NSImage(contentsOfFile: "'"$DIR"'/AppIcon_1024.png")
    if let img = img {
        NSWorkspace.shared.setIcon(img, forFile: "'"$APP_BUNDLE"'", options: [])
    }
    ' 2>/dev/null || true
fi

echo "✅ Successfully built and packaged DeskOrbit.app!"
echo "📍 Location: $APP_BUNDLE"
