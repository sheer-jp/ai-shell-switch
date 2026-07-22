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
readonly ICON_SOURCE="$ROOT/Assets/AppIcon.png"
readonly ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
SOURCE_FILES=("$ROOT"/Sources/*.swift)

icon_source_dimension() {
  local property=$1
  /usr/bin/sips -g "$property" "$ICON_SOURCE" 2>/dev/null | /usr/bin/awk -v key="$property:" '$1 == key { print $2; exit }'
}

generate_icon_png() {
  local size=$1
  local filename=$2
  /usr/bin/sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
}

if [ ! -f "$ICON_SOURCE" ]; then
  printf 'Icon source missing: %s\n' "$ICON_SOURCE" >&2
  exit 66
fi

icon_width=$(icon_source_dimension pixelWidth)
icon_height=$(icon_source_dimension pixelHeight)
if [ "$icon_width" != "1024" ] || [ "$icon_height" != "1024" ]; then
  printf 'Icon source must be 1024x1024, got %sx%s: %s\n' "$icon_width" "$icon_height" "$ICON_SOURCE" >&2
  exit 65
fi

/bin/rm -rf "$APP_DIR"
/bin/rm -rf "$ICONSET_DIR"
/bin/mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"
/bin/mkdir -p "$ICONSET_DIR"
generate_icon_png 16 icon_16x16.png
generate_icon_png 32 icon_16x16@2x.png
generate_icon_png 32 icon_32x32.png
generate_icon_png 64 icon_32x32@2x.png
generate_icon_png 128 icon_128x128.png
generate_icon_png 256 icon_128x128@2x.png
generate_icon_png 256 icon_256x256.png
generate_icon_png 512 icon_256x256@2x.png
generate_icon_png 512 icon_512x512.png
generate_icon_png 1024 icon_512x512@2x.png
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
/bin/rm -rf "$ICONSET_DIR"
/usr/bin/swiftc \
  -O \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework Carbon \
  -o "$MACOS_DIR/$APP_NAME" \
  "${SOURCE_FILES[@]}"
/bin/cp -f "$ROOT/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/install -m 0755 "$ROOT/ai-shell-switch.sh" "$RESOURCES_DIR/ai-shell-switch"
/usr/bin/plutil -lint "$CONTENTS_DIR/Info.plist"
/usr/bin/xattr -cr "$APP_DIR"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"

printf 'Built: %s\n' "$APP_DIR"
