#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(/usr/bin/dirname "$0")" && /bin/pwd -P)
readonly ROOT
readonly APP_NAME="AI Shell Switch"
readonly BUILD_DIR="${AI_SHELL_SWITCH_BUILD_DIR:-$ROOT/.build}"
readonly SOURCE_APP="$BUILD_DIR/$APP_NAME.app"
readonly INSTALL_DIR="${AI_SHELL_SWITCH_INSTALL_DIR:-$HOME/Applications}"
readonly INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"
readonly CLI_DIR="${AI_SHELL_SWITCH_CLI_DIR:-$HOME/.local/bin}"
readonly INSTALLED_CLI="$INSTALLED_APP/Contents/Resources/ai-shell-switch"
readonly INSTALLED_EXECUTABLE="$INSTALLED_APP/Contents/MacOS/$APP_NAME"
STAGING_APP="$INSTALL_DIR/.$APP_NAME.installing.$$.app"

cleanup() {
  if [ -n "${STAGING_APP:-}" ] && [ -e "$STAGING_APP" ]; then
    /bin/rm -rf "$STAGING_APP"
  fi
}
trap cleanup EXIT

"$ROOT/build.sh"
/bin/mkdir -p "$INSTALL_DIR" "$CLI_DIR"
/bin/rm -rf "$STAGING_APP"
/usr/bin/ditto "$SOURCE_APP" "$STAGING_APP"
/usr/bin/codesign --verify --deep --strict "$STAGING_APP"

/usr/bin/pkill -f -x "$INSTALLED_EXECUTABLE" >/dev/null 2>&1 || true
attempt=0
while /usr/bin/pgrep -f -x "$INSTALLED_EXECUTABLE" >/dev/null 2>&1 && [ "$attempt" -lt 20 ]; do
  /bin/sleep 0.1
  attempt=$((attempt + 1))
done
if /usr/bin/pgrep -f -x "$INSTALLED_EXECUTABLE" >/dev/null 2>&1; then
  printf '既存の%sを終了できませんでした。メニューから終了して再実行してください。\n' "$APP_NAME" >&2
  exit 1
fi
/bin/rm -rf "$INSTALLED_APP"
/bin/mv "$STAGING_APP" "$INSTALLED_APP"
STAGING_APP=""

for command_name in ai-shell-switch ai-on ai-off ai-toggle ai-status ai-setup ai-unsetup ai-doctor; do
  /bin/ln -sfn "$INSTALLED_CLI" "$CLI_DIR/$command_name"
done

if [ "${AI_SHELL_SWITCH_KEEP_BUILD:-0}" != "1" ]; then
  /bin/rm -rf "$SOURCE_APP"
fi

if [ "${AI_SHELL_SWITCH_SKIP_OPEN:-0}" != "1" ]; then
  /usr/bin/open "$INSTALLED_APP"
fi

printf 'Installed: %s\n' "$INSTALLED_APP"
printf 'Commands: ai-on, ai-off, ai-toggle, ai-status, ai-setup, ai-doctor\n'
case ":$PATH:" in
  *":$CLI_DIR:"*) ;;
  *) printf 'PATHへ追加してください: export PATH="%s:$%s"\n' "$CLI_DIR" "PATH" ;;
esac
