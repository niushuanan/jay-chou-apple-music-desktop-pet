#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="JayPetTopBubble"
APP_PATH="$HOME/Applications/$APP_NAME.app"
BUNDLE_ID="com.zhk.jaypet.topbubble"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/process_album_art.py"
swift build

mkdir -p "$HOME/Applications"
pkill -x "$APP_NAME" 2>/dev/null || true
pkill -x "JayPetApp" 2>/dev/null || true
rm -rf "$HOME/Applications/JayPet.app" "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$ROOT_DIR/.build/arm64-apple-macosx/debug/JayPetApp" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp -R "$ROOT_DIR/.build/arm64-apple-macosx/debug/JayPetApp_JayPetApp.bundle" "$APP_PATH/Contents/Resources/"

printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>' \
'  <key>CFBundleExecutable</key><string>'"$APP_NAME"'</string>' \
'  <key>CFBundleIdentifier</key><string>'"$BUNDLE_ID"'</string>' \
'  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>' \
'  <key>CFBundleName</key><string>'"$APP_NAME"'</string>' \
'  <key>CFBundlePackageType</key><string>APPL</string>' \
'  <key>CFBundleShortVersionString</key><string>0.2.0</string>' \
'  <key>CFBundleVersion</key><string>5</string>' \
'  <key>LSMinimumSystemVersion</key><string>13.0</string>' \
'  <key>NSAppleEventsUsageDescription</key><string>需要控制 Apple Music 进行播放控制与状态读取。</string>' \
'</dict>' \
'</plist>' > "$APP_PATH/Contents/Info.plist"

codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_PATH"

echo "$APP_PATH"
