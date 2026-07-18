#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(/usr/bin/dirname "$0")" && /bin/pwd -P)
readonly ROOT
readonly APP_NAME="AI Shell Switch"
readonly BUILD_DIR="${AI_SHELL_SWITCH_BUILD_DIR:-$ROOT/.build}"
readonly APP_DIR="$BUILD_DIR/$APP_NAME.app"
readonly CONTENTS_DIR="$APP_DIR/Contents"
readonly MACOS_DIR="$CONTENTS_DIR/MacOS"
readonly RESOURCES_DIR="$CONTENTS_DIR/Resources"
readonly MODULE_CACHE_DIR="$BUILD_DIR/ModuleCache"

/bin/rm -rf "$APP_DIR"
/bin/mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"
/usr/bin/swiftc \
  -O \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework Carbon \
  -o "$MACOS_DIR/$APP_NAME" \
  "$ROOT/Sources/main.swift"
/bin/cp -f "$ROOT/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/install -m 0755 "$ROOT/ai-shell-switch.sh" "$RESOURCES_DIR/ai-shell-switch"
/usr/bin/plutil -lint "$CONTENTS_DIR/Info.plist"
/usr/bin/xattr -cr "$APP_DIR"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"

printf 'Built: %s\n' "$APP_DIR"
