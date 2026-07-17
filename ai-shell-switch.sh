#!/bin/zsh

set -u

readonly PMSET=/usr/bin/pmset
readonly OSASCRIPT=/usr/bin/osascript

power_source() {
  "$PMSET" -g ps | /usr/bin/sed -n "s/^Now drawing from '\([^']*\)'.*/\1/p"
}

sleep_disabled() {
  [[ $("$PMSET" -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2; exit }') == "1" ]]
}

notify() {
  local message=$1
  "$OSASCRIPT" -e "display notification \"${message}\" with title \"AIクラムシェル運転\"" >/dev/null 2>&1 || true
}

set_sleep_disabled() {
  local value=$1

  if /usr/bin/sudo -n "$PMSET" -a disablesleep "$value" >/dev/null 2>&1; then
    return 0
  fi

  "$OSASCRIPT" -e "do shell script \"/usr/bin/pmset -a disablesleep ${value}\" with administrator privileges" >/dev/null
}

status() {
  local source
  source=$(power_source)

  if sleep_disabled; then
    print "AIクラムシェル運転: ON"
    print "電源: ${source:-不明}"
    print "蓋を閉じてもMacのスリープを禁止しています。"
    [[ $source == "AC Power" ]] || print "警告: バッテリー駆動中です。電源アダプタを接続してください。"
    return 0
  fi

  print "AIクラムシェル運転: OFF"
  print "電源: ${source:-不明}"
  print "通常のmacOSスリープ動作です。"
}

turn_on() {
  local source
  source=$(power_source)

  if sleep_disabled; then
    print "すでにONです。"
    status
    return 0
  fi

  if [[ $source != "AC Power" ]]; then
    print -u2 "安全のため、電源アダプタ接続中だけONにできます。"
    print -u2 "接続後にもう一度 ai-on を実行してください。"
    return 2
  fi

  set_sleep_disabled 1

  if ! sleep_disabled; then
    print -u2 "ONへの切り替えを確認できませんでした。"
    return 1
  fi

  notify "ON：蓋を閉じてもAI処理を継続します"
  print "ONにしました。作業後は ai-off で必ず解除してください。"
  status
}

turn_off() {
  if sleep_disabled; then
    set_sleep_disabled 0
  fi

  if sleep_disabled; then
    print -u2 "OFFへの切り替えを確認できませんでした。"
    return 1
  fi

  notify "OFF：通常のスリープ動作に戻しました"
  print "OFFにしました。通常のmacOSスリープ動作に戻っています。"
  status
}

usage() {
  print "使い方: ${0:t} on|off|status"
}

case ${1:-status} in
  on) turn_on ;;
  off) turn_off ;;
  status) status ;;
  *) usage; exit 64 ;;
esac
