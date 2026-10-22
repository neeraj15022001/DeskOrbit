#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🛑 Stopping any running instances of DeskOrbit..."
killall DeskOrbit 2>/dev/null || true
pkill -f "DeskOrbit.app/Contents/MacOS/DeskOrbit" 2>/dev/null || true
sleep 0.5

echo "🔨 Building DeskOrbit (Release)..."
CONST_VALS_DIR="/tmp/deskorbit_const_vals"
mkdir -p "$CONST_VALS_DIR"
swift build -c release \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$DIR/Info.plist" \
    -Xswiftc -emit-const-values-path -Xswiftc "$CONST_VALS_DIR/DeskOrbit.swiftconstvalues" \
    --disable-sandbox --cache-path "/tmp/swiftpm_cache"

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

echo "🧠 Extracting App Intents metadata for Siri AI & Shortcuts..."
python3 - << 'PYEOF'
import os, subprocess, glob

sources = [os.path.abspath(f) for f in glob.glob("Sources/**/*.swift", recursive=True)]
with open("/tmp/deskorbit_sources.txt", "w") as f:
    f.write("\n".join(sources))

const_file = "/tmp/deskorbit_const_vals/DeskOrbit.swiftconstvalues"
if not os.path.exists(const_file):
    candidates = glob.glob(".build/**/DeskOrbit*.swiftconstvalues", recursive=True)
    if candidates:
        const_file = os.path.abspath(candidates[0])

with open("/tmp/deskorbit_consts.txt", "w") as f:
    f.write(const_file)

sdk = subprocess.check_output(["xcrun", "--show-sdk-path"]).decode().strip()
xcode_dev = subprocess.check_output(["xcode-select", "-p"]).decode().strip()
toolchain = os.path.join(xcode_dev, "Toolchains/XcodeDefault.xctoolchain")
if not os.path.exists(toolchain):
    toolchain = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
out_dir = os.path.abspath("DeskOrbit.app/Contents/Resources")

cmd = [
    "xcrun", "appintentsmetadataprocessor",
    "--output", out_dir,
    "--toolchain-dir", toolchain,
    "--module-name", "DeskOrbit",
    "--sdk-root", sdk,
    "--xcode-version", "16.0",
    "--platform-family", "macOS",
    "--deployment-target", "14.0",
    "--target-triple", "arm64-apple-macos14.0",
    "--source-file-list", "/tmp/deskorbit_sources.txt",
    "--swift-const-vals-list", "/tmp/deskorbit_consts.txt"
]
subprocess.run(cmd, check=False)
PYEOF

if [ -f "$DIR/Info.plist" ]; then
    cp "$DIR/Info.plist" "$CONTENTS/Info.plist"
    if [ -n "$APP_VERSION" ]; then
        plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true
    fi
    if [ -n "$BUILD_NUMBER" ]; then
        plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS/Info.plist" 2>/dev/null || true
    fi
fi

# Ensure AppIcon.icns is present
if [ ! -f "$DIR/AppIcon.icns" ] && [ -f "$DIR/AppIcon_1024.png" ]; then
    echo "🎨 Generating AppIcon.icns from AppIcon_1024.png..."
    ICONSET="/tmp/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    sips -z 16 16     "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "$DIR/AppIcon_1024.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null 2>&1
    iconutil -c icns "$ICONSET" -o "$DIR/AppIcon.icns"
    rm -rf "$ICONSET"
fi

if [ -f "$DIR/AppIcon.icns" ]; then
    cp "$DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"
    echo "🖼️ Bundled AppIcon.icns into Contents/Resources/"
fi

if [ ! -f "$RESOURCES/AppIcon.icns" ]; then
    echo "⚠️ Warning: Contents/Resources/AppIcon.icns was not created!"
fi

# Apply icon to bundle metadata
if [ -f "$DIR/AppIcon_1024.png" ]; then
    swift -e '
    import AppKit
    let img = NSImage(contentsOfFile: "'"$DIR"'/AppIcon_1024.png")
    if let img = img {
        NSWorkspace.shared.setIcon(img, forFile: "'"$APP_BUNDLE"'", options: [])
    }
    ' 2>/dev/null || true
fi

# Clean resource forks/detritus and sign bundle so macOS TCC respects Info.plist entitlements/privacy strings
dot_clean "$APP_BUNDLE"
find "$APP_BUNDLE" -exec xattr -c {} + 2>/dev/null || true
echo "🔏 Signing bundle with ad-hoc identity..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Successfully built and packaged DeskOrbit.app!"
echo "📍 Location: $APP_BUNDLE"
