#!/bin/zsh

set -euo pipefail

readonly ROOT=${0:A:h}
readonly SWITCH="$ROOT/ai-shell-switch.sh"

zsh -n "$SWITCH"
zsh -n "$ROOT/build.sh"
zsh -n "$ROOT/install.sh"
/usr/bin/swiftc -typecheck -framework AppKit "$ROOT/Sources/main.swift"
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

for contract_text in "AI ON" "AI OFF" "通常スリープに戻す（OFF）" "AI稼働モードにする（ON）"; do
  if ! /usr/bin/grep -q "$contract_text" "$ROOT/Sources/main.swift"; then
    print -u2 "menu contract missing: $contract_text"
    exit 1
  fi
done

print "PASS: shell, menu app, plist, and status contracts"
