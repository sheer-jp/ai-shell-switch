#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(/usr/bin/dirname "$0")" && /bin/pwd -P)
readonly ROOT
readonly SWITCH="$ROOT/ai-shell-switch.sh"
readonly FIXTURES="$ROOT/tests/fixtures"
SOURCE_FILES=("$ROOT"/Sources/*.swift)
SHELLCHECK_BIN=$(command -v shellcheck || true)
readonly SHELLCHECK_BIN
SHFMT_BIN=$(command -v shfmt || true)
readonly SHFMT_BIN
JQ_BIN=$(command -v jq || true)
readonly JQ_BIN

if [ -z "$SHELLCHECK_BIN" ] || [ -z "$SHFMT_BIN" ] || [ -z "$JQ_BIN" ]; then
  printf 'test tools missing: install shellcheck, shfmt, and jq\n' >&2
  exit 69
fi

temp_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/ai-shell-switch-test.XXXXXX")
cleanup() {
  /bin/rm -rf "$temp_dir"
}
trap cleanup EXIT

scripts=(
  "$SWITCH"
  "$ROOT/build.sh"
  "$ROOT/install.sh"
  "$FIXTURES/mock-pmset.sh"
  "$FIXTURES/mock-sudo.sh"
  "$FIXTURES/mock-osascript.sh"
  "$FIXTURES/mock-app.sh"
)

for script in "${scripts[@]}"; do
  /bin/bash -n "$script"
done

"$SHELLCHECK_BIN" "${scripts[@]}"
"$SHFMT_BIN" -d -i 2 -ci "${scripts[@]}"
/usr/bin/swiftc -typecheck -module-cache-path "$temp_dir/module-cache" -framework AppKit -framework Carbon "${SOURCE_FILES[@]}"
/usr/bin/plutil -lint "$ROOT/Info.plist" >/dev/null
"$JQ_BIN" -e . "$ROOT/done-criteria.json" >/dev/null
"$JQ_BIN" -e . "$ROOT/trust/tech-decision.json" "$ROOT/trust/roadmap.json" >/dev/null

icon_width=$(/usr/bin/sips -g pixelWidth "$ROOT/Assets/AppIcon.png" 2>/dev/null | /usr/bin/awk '$1 == "pixelWidth:" { print $2; exit }')
icon_height=$(/usr/bin/sips -g pixelHeight "$ROOT/Assets/AppIcon.png" 2>/dev/null | /usr/bin/awk '$1 == "pixelHeight:" { print $2; exit }')
icon_alpha=$(/usr/bin/sips -g hasAlpha "$ROOT/Assets/AppIcon.png" 2>/dev/null | /usr/bin/awk '$1 == "hasAlpha:" { print $2; exit }')
if [ "$icon_width" != "1024" ] || [ "$icon_height" != "1024" ] || [ "$icon_alpha" != "yes" ]; then
  printf 'AppIcon source must be a 1024x1024 PNG with alpha\n' >&2
  exit 1
fi

plist_icon=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$ROOT/Info.plist")
if [ "$plist_icon" != "AppIcon.icns" ]; then
  printf 'CFBundleIconFile must point to AppIcon.icns\n' >&2
  exit 1
fi

state_file="$temp_dir/sleep-disabled"
rule_file="$temp_dir/passwordless-rule"
bin_dir="$temp_dir/bin"
/bin/mkdir -p "$bin_dir"
printf '0\n' >"$state_file"
printf '1\n' >"$rule_file"

for alias_name in ai-shell-switch ai-on ai-off ai-toggle ai-status ai-setup ai-unsetup ai-doctor; do
  /bin/ln -s "$SWITCH" "$bin_dir/$alias_name"
done

export AI_SHELL_SWITCH_PMSET="$FIXTURES/mock-pmset.sh"
export AI_SHELL_SWITCH_SUDO="$FIXTURES/mock-sudo.sh"
export AI_SHELL_SWITCH_OSASCRIPT="$FIXTURES/mock-osascript.sh"
export AI_SHELL_SWITCH_APP_EXECUTABLE="$FIXTURES/mock-app.sh"
export AI_SHELL_SWITCH_INSTALLED_APP="$temp_dir/AI Shell Switch.app"
export AI_SHELL_SWITCH_NOTIFICATIONS=0
export AI_SHELL_SWITCH_TEST_PASSWORDLESS=1
export AI_SHELL_SWITCH_TEST_POWER="AC Power"
export AI_SHELL_SWITCH_TEST_RULE_STATE="$rule_file"
export AI_SHELL_SWITCH_TEST_STATE="$state_file"
export PATH="$bin_dir:$PATH"

assert_state() {
  local expected=$1
  local actual
  actual=$(/bin/cat "$state_file")
  if [ "$actual" != "$expected" ]; then
    printf 'expected SleepDisabled=%s, got %s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

status_output=$("$SWITCH" status)
case "$status_output" in
  *"AIクラムシェル運転: OFF"*"電源: AC Power"*) ;;
  *)
    printf 'status output contract failed\n' >&2
    exit 1
    ;;
esac

"$SWITCH" on >/dev/null
assert_state 1
"$SWITCH" toggle >/dev/null
assert_state 0
"$bin_dir/ai-on" >/dev/null
assert_state 1
"$bin_dir/ai-off" >/dev/null
assert_state 0
"$bin_dir/ai-toggle" >/dev/null
assert_state 1
"$bin_dir/ai-toggle" >/dev/null
assert_state 0

if AI_SHELL_SWITCH_TEST_POWER="Battery Power" "$SWITCH" on >"$temp_dir/battery.out" 2>&1; then
  printf 'battery guard unexpectedly allowed ON\n' >&2
  exit 1
else
  battery_exit=$?
fi
if [ "$battery_exit" -ne 2 ]; then
  printf 'battery guard returned %s instead of 2\n' "$battery_exit" >&2
  exit 1
fi
assert_state 0

printf '0\n' >"$rule_file"
"$SWITCH" setup >/dev/null
if [ "$(/bin/cat "$rule_file")" != "1" ]; then
  printf 'setup did not install the mocked rule\n' >&2
  exit 1
fi
"$SWITCH" setup >/dev/null
"$bin_dir/ai-unsetup" >/dev/null
if [ "$(/bin/cat "$rule_file")" != "0" ]; then
  printf 'unsetup did not remove the mocked rule\n' >&2
  exit 1
fi
"$bin_dir/ai-unsetup" >/dev/null
printf '1\n' >"$rule_file"

doctor_output=$("$bin_dir/ai-doctor")
case "$doctor_output" in
  *"診断結果: OK"*) ;;
  *)
    printf 'doctor output contract failed\n' >&2
    exit 1
    ;;
esac

version_output=$("$SWITCH" version)
case "$version_output" in
  *"1.3.0"*) ;;
  *)
    printf 'version output contract failed\n' >&2
    exit 1
    ;;
esac

if "$SWITCH" invalid-command >"$temp_dir/invalid.out" 2>&1; then
  printf 'invalid command unexpectedly succeeded\n' >&2
  exit 1
else
  invalid_exit=$?
fi
if [ "$invalid_exit" -ne 64 ]; then
  printf 'invalid command returned %s instead of 64\n' "$invalid_exit" >&2
  exit 1
fi

for contract_text in \
  "AI ON" \
  "AI OFF" \
  "操作画面を開く…" \
  "通常スリープに戻す（OFF）" \
  "AI稼働モードにする（ON）" \
  "applicationShouldHandleReopen" \
  "showControlWindow" \
  'CommandLine.arguments.contains("--background")' \
  "ショートカット: ⌃⌥A（画面 / 緊急OFF）" \
  "handleGlobalHotKey" \
  "NOPASSWD:" \
  "/usr/bin/pmset -a disablesleep 0" \
  "/usr/bin/pmset -a disablesleep 1"; do
  if ! /usr/bin/grep -q "$contract_text" "${SOURCE_FILES[@]}"; then
    printf 'menu contract missing: %s\n' "$contract_text" >&2
    exit 1
  fi
done

shortcut_handler=$(/usr/bin/sed -n '/private func handleGlobalHotKey()/,/^    }/p' "$ROOT/Sources/AppDelegate.swift")
case "$shortcut_handler" in
  *"case .on:"*"toggleMode()"*"case .off:"*"showControlWindow()"*) ;;
  *)
    printf 'global shortcut must open controls from OFF and may only toggle directly from ON\n' >&2
    exit 1
    ;;
esac

if ! /usr/bin/grep -q '\["/usr/bin/open", "-gj", Bundle.main.bundlePath, "--args", "--background"\]' "${SOURCE_FILES[@]}"; then
  printf 'login launch must stay in the background while manual app launches show controls\n' >&2
  exit 1
fi

rule_command_count=$(/usr/bin/grep -Eh '^[[:space:]]*"/usr/bin/pmset -a disablesleep [01]"' "${SOURCE_FILES[@]}" | /usr/bin/wc -l | /usr/bin/tr -d ' ')
if [ "$rule_command_count" -ne 2 ]; then
  printf 'sudoers contract must contain exactly two pmset commands\n' >&2
  exit 1
fi

if /usr/bin/grep -Eq 'NOPASSWD:[[:space:]]*(ALL|/bin/|/usr/bin/[^p])' "${SOURCE_FILES[@]}"; then
  printf 'sudoers contract is broader than the two pmset commands\n' >&2
  exit 1
fi

if ! /usr/bin/grep -q 'Contents/Resources/ai-shell-switch' "$ROOT/install.sh"; then
  printf 'installer does not expose the bundled CLI\n' >&2
  exit 1
fi

if ! /usr/bin/grep -q '/.build' "$ROOT/build.sh"; then
  printf 'build output is not hidden under .build\n' >&2
  exit 1
fi

test_build_dir="$temp_dir/build"
AI_SHELL_SWITCH_BUILD_DIR="$test_build_dir" "$ROOT/build.sh" >/dev/null
built_app="$test_build_dir/AI Shell Switch.app"
built_icon="$built_app/Contents/Resources/AppIcon.icns"
if [ ! -f "$built_icon" ]; then
  printf 'built app is missing AppIcon.icns\n' >&2
  exit 1
fi
/usr/bin/codesign --verify --deep --strict "$built_app"
/usr/bin/iconutil -c iconset "$built_icon" -o "$temp_dir/verified.iconset"
for icon_file in \
  icon_16x16.png \
  icon_16x16@2x.png \
  icon_32x32.png \
  icon_32x32@2x.png \
  icon_128x128.png \
  icon_128x128@2x.png \
  icon_256x256.png \
  icon_256x256@2x.png \
  icon_512x512.png \
  icon_512x512@2x.png; do
  if [ ! -f "$temp_dir/verified.iconset/$icon_file" ]; then
    printf 'generated icns is missing representation: %s\n' "$icon_file" >&2
    exit 1
  fi
done

printf 'PASS: shell lint, mocked transitions, menu app, icon bundle, plist, and CLI contracts\n'
