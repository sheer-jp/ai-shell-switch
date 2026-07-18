#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(/usr/bin/dirname "$0")" && /bin/pwd -P)
readonly ROOT
readonly SWITCH="$ROOT/ai-shell-switch.sh"
readonly FIXTURES="$ROOT/tests/fixtures"
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
/usr/bin/swiftc -typecheck -module-cache-path "$temp_dir/module-cache" -framework AppKit -framework Carbon "$ROOT/Sources/main.swift"
/usr/bin/plutil -lint "$ROOT/Info.plist" >/dev/null
"$JQ_BIN" -e . "$ROOT/done-criteria.json" >/dev/null

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
  *"1.2.0"*) ;;
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
  "通常スリープに戻す（OFF）" \
  "AI稼働モードにする（ON）" \
  "ショートカット: ⌃⌥A" \
  "NOPASSWD:" \
  "/usr/bin/pmset -a disablesleep 0" \
  "/usr/bin/pmset -a disablesleep 1"; do
  if ! /usr/bin/grep -q "$contract_text" "$ROOT/Sources/main.swift"; then
    printf 'menu contract missing: %s\n' "$contract_text" >&2
    exit 1
  fi
done

rule_command_count=$(/usr/bin/grep -Ec '^[[:space:]]*"/usr/bin/pmset -a disablesleep [01]"' "$ROOT/Sources/main.swift")
if [ "$rule_command_count" -ne 2 ]; then
  printf 'sudoers contract must contain exactly two pmset commands\n' >&2
  exit 1
fi

if /usr/bin/grep -Eq 'NOPASSWD:[[:space:]]*(ALL|/bin/|/usr/bin/[^p])' "$ROOT/Sources/main.swift"; then
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

printf 'PASS: shell lint, mocked transitions, menu app, plist, and CLI contracts\n'
