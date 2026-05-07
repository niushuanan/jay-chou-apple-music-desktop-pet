#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXECUTABLE_NAME="JayPetApp"
APP_NAME="JayPetTopBubble"
BUNDLE_ID="com.zhk.jaypet.topbubble"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
EXECUTABLE="$ROOT_DIR/.build/debug/$EXECUTABLE_NAME"

cd "$ROOT_DIR"

for process_name in "$APP_NAME" "$EXECUTABLE_NAME"; do
  if pgrep -x "$process_name" >/dev/null 2>&1; then
    pkill -x "$process_name" || true
  fi
done
for _ in {1..30}; do
  if ! pgrep -x "$APP_NAME" >/dev/null 2>&1 && ! pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -9 -x "$APP_NAME" || true
fi
if pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
  pkill -9 -x "$EXECUTABLE_NAME" || true
fi

rm -rf "$DIST_DIR/JayPetApp.app"
rm -rf "$DIST_DIR/JayPetTopBubble.app"
rm -rf "$HOME/Applications/JayPet.app"
rm -rf "$HOME/Applications/JayPetTopBubble.app"

swift build
RESOURCE_BUNDLE="$(find "$ROOT_DIR/.build" -type d -name "JayPetApp_JayPetApp.bundle" | head -n 1)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"
if [[ -n "$RESOURCE_BUNDLE" && -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/open "$APP_DIR"

if [[ "${1:-}" == "--verify" ]]; then
  sleep 1
  count="$(pgrep -x "$APP_NAME" | wc -l | tr -d ' ')"
  if [[ "$count" != "1" ]]; then
    echo "Expected exactly one $APP_NAME process, found $count" >&2
    exit 1
  fi
  echo "$APP_NAME is running"
fi
