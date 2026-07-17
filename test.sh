#!/bin/zsh

set -euo pipefail

readonly ROOT=${0:A:h}
readonly SWITCH="$ROOT/ai-shell-switch.sh"

zsh -n "$SWITCH"
zsh -n "$ROOT/build.sh"
zsh -n "$ROOT/install.sh"
/usr/bin/swiftc -typecheck -framework AppKit -framework Carbon "$ROOT/Sources/main.swift"
/usr/bin/plutil -lint "$ROOT/Info.plist" >/dev/null

status_output=$("$SWITCH" status)
if [[ $status_output != *"AIクラムシェル運転: "* ]]; then
  print -u2 "status output does not contain the mode label"
  exit 1
fi

if [[ $status_output != *"電源: "* ]]; then
  print -u2 "status output does not contain the power source"
  exit 1
fi

for contract_text in "AI ON" "AI OFF" "通常スリープに戻す（OFF）" "AI稼働モードにする（ON）" "ショートカット: ⌃⌥A" "NOPASSWD:" "/usr/bin/pmset -a disablesleep 0" "/usr/bin/pmset -a disablesleep 1"; do
  if ! /usr/bin/grep -q "$contract_text" "$ROOT/Sources/main.swift"; then
    print -u2 "menu contract missing: $contract_text"
    exit 1
  fi
done

rule_command_count=$(/usr/bin/grep -Ec '^[[:space:]]*"/usr/bin/pmset -a disablesleep [01]"' "$ROOT/Sources/main.swift")
if [[ $rule_command_count != 2 ]]; then
  print -u2 "sudoers contract must contain exactly two pmset commands"
  exit 1
fi

if /usr/bin/grep -Eq 'NOPASSWD:[[:space:]]*(ALL|/bin/|/usr/bin/[^p])' "$ROOT/Sources/main.swift"; then
  print -u2 "sudoers contract is broader than the two pmset commands"
  exit 1
fi

print "PASS: shell, menu app, plist, and status contracts"
