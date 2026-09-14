#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🔨 Ensuring latest release build..."
./bundle_app.sh

DMG_TEMP="$DIR/dmg_staging"
DMG_NAME="DeskOrbit-v1.0.0.dmg"
OUTPUT_DMG="$DIR/$DMG_NAME"

echo "🧹 Preparing DMG staging directory..."
rm -rf "$DMG_TEMP" "$OUTPUT_DMG"
mkdir -p "$DMG_TEMP"

echo "📦 Copying DeskOrbit.app into staging..."
cp -R "$DIR/DeskOrbit.app" "$DMG_TEMP/"

echo "🔗 Creating Applications drag-and-drop symlink..."
ln -s /Applications "$DMG_TEMP/Applications"

echo "💿 Packaging DMG..."
hdiutil create \
    -volname "DeskOrbit" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"

rm -rf "$DMG_TEMP"

echo "✅ Successfully generated: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
