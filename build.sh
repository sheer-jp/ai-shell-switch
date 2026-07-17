#!/bin/zsh

set -euo pipefail

readonly ROOT=${0:A:h}
readonly APP_NAME="AI Shell Switch"
readonly APP_DIR="$ROOT/dist/$APP_NAME.app"
readonly CONTENTS_DIR="$APP_DIR/Contents"
readonly MACOS_DIR="$CONTENTS_DIR/MacOS"

/bin/mkdir -p "$MACOS_DIR"
/usr/bin/swiftc \
  -O \
  -framework AppKit \
  -o "$MACOS_DIR/$APP_NAME" \
  "$ROOT/Sources/main.swift"
/bin/cp -f "$ROOT/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/plutil -lint "$CONTENTS_DIR/Info.plist"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"

print "Built: $APP_DIR"
