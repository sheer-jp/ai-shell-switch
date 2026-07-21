#!/bin/bash

set -euo pipefail

readonly APP_NAME="AI Shell Switch"
readonly CLI_VERSION="1.3.0"
readonly PMSET="${AI_SHELL_SWITCH_PMSET:-/usr/bin/pmset}"
readonly SUDO="${AI_SHELL_SWITCH_SUDO:-/usr/bin/sudo}"
readonly OSASCRIPT="${AI_SHELL_SWITCH_OSASCRIPT:-/usr/bin/osascript}"
readonly INSTALLED_APP="${AI_SHELL_SWITCH_INSTALLED_APP:-$HOME/Applications/$APP_NAME.app}"
readonly APP_EXECUTABLE_OVERRIDE="${AI_SHELL_SWITCH_APP_EXECUTABLE:-}"
readonly NOTIFICATIONS_ENABLED="${AI_SHELL_SWITCH_NOTIFICATIONS:-1}"

resolve_script_path() {
  local path=$1
  local link

  while [ -L "$path" ]; do
    link=$(/usr/bin/readlink "$path")
    case "$link" in
      /*) path=$link ;;
      *) path=$(/usr/bin/dirname "$path")/$link ;;
    esac
  done

  local directory
  directory=$(/usr/bin/dirname "$path")
  printf '%s/%s\n' "$(cd "$directory" && /bin/pwd -P)" "$(/usr/bin/basename "$path")"
}

SCRIPT_PATH=$(resolve_script_path "$0")
readonly SCRIPT_PATH
SCRIPT_DIR=$(/usr/bin/dirname "$SCRIPT_PATH")
readonly SCRIPT_DIR
CONTENTS_DIR=$(cd "$SCRIPT_DIR/.." && /bin/pwd -P)
readonly CONTENTS_DIR

error() {
  printf 'エラー: %s\n' "$*" >&2
}

power_source() {
  local output
  output=$("$PMSET" -g ps 2>/dev/null) || return 1
  printf '%s\n' "$output" | /usr/bin/sed -n "s/^Now drawing from '\([^']*\)'.*/\1/p"
}

sleep_disabled_value() {
  local output
  local value

  output=$("$PMSET" -g 2>/dev/null) || return 1
  value=$(printf '%s\n' "$output" | /usr/bin/awk '$1 == "SleepDisabled" { print $2; exit }')
  case "$value" in
    0 | 1) printf '%s\n' "$value" ;;
    *) return 1 ;;
  esac
}

notify() {
  local message=$1
  local escaped

  [ "$NOTIFICATIONS_ENABLED" = "1" ] || return 0
  escaped=${message//\\/\\\\}
  escaped=${escaped//\"/\\\"}
  "$OSASCRIPT" -e "display notification \"${escaped}\" with title \"AIクラムシェル運転\"" >/dev/null 2>&1 || true
}

set_sleep_disabled() {
  local value=$1

  case "$value" in
    0 | 1) ;;
    *)
      error "内部値が不正です。"
      return 64
      ;;
  esac

  if "$SUDO" -n "$PMSET" -a disablesleep "$value" >/dev/null 2>&1; then
    return 0
  fi

  if [ "$PMSET" != "/usr/bin/pmset" ]; then
    error "テスト用pmsetでは管理者確認へフォールバックできません。"
    return 77
  fi

  "$OSASCRIPT" -e "do shell script \"/usr/bin/pmset -a disablesleep ${value}\" with administrator privileges" >/dev/null
}

status() {
  local source
  local value

  source=$(power_source) || source="不明"
  value=$(sleep_disabled_value) || {
    error "macOSのSleepDisabled状態を取得できませんでした。"
    return 1
  }

  if [ "$value" = "1" ]; then
    printf 'AIクラムシェル運転: ON\n'
    printf '電源: %s\n' "${source:-不明}"
    printf '蓋を閉じてもMacのスリープを禁止しています。\n'
    if [ "$source" != "AC Power" ]; then
      printf '警告: バッテリー駆動中です。電源アダプタを接続するか、ai-offを実行してください。\n'
    fi
    return 0
  fi

  printf 'AIクラムシェル運転: OFF\n'
  printf '電源: %s\n' "${source:-不明}"
  printf '通常のmacOSスリープ動作です。\n'
}

turn_on() {
  local source
  local value

  value=$(sleep_disabled_value) || {
    error "現在の状態を確認できないため、ONにしませんでした。"
    return 1
  }
  if [ "$value" = "1" ]; then
    printf 'すでにONです。\n'
    status
    return 0
  fi

  source=$(power_source) || source=""
  if [ "$source" != "AC Power" ]; then
    error "安全のため、電源アダプタ接続中だけONにできます。"
    error "接続後にもう一度 ai-on を実行してください。"
    return 2
  fi

  set_sleep_disabled 1
  value=$(sleep_disabled_value) || value="unknown"
  if [ "$value" != "1" ]; then
    error "ONへの切り替えを確認できませんでした。"
    return 1
  fi

  notify "ON：蓋を閉じてもAI処理を継続します"
  printf 'ONにしました。作業後は ai-off で必ず解除してください。\n'
  status
}

turn_off() {
  local value

  value=$(sleep_disabled_value) || value="unknown"
  if [ "$value" != "0" ]; then
    set_sleep_disabled 0
  fi

  value=$(sleep_disabled_value) || value="unknown"
  if [ "$value" != "0" ]; then
    error "OFFへの切り替えを確認できませんでした。"
    return 1
  fi

  notify "OFF：通常のスリープ動作に戻しました"
  printf 'OFFにしました。通常のmacOSスリープ動作に戻っています。\n'
  status
}

toggle() {
  local value
  value=$(sleep_disabled_value) || {
    error "現在の状態を確認できないため、切り替えませんでした。"
    return 1
  }

  if [ "$value" = "1" ]; then
    turn_off
  else
    turn_on
  fi
}

resolve_app_executable() {
  local candidate

  if [ -n "$APP_EXECUTABLE_OVERRIDE" ] && [ -x "$APP_EXECUTABLE_OVERRIDE" ]; then
    printf '%s\n' "$APP_EXECUTABLE_OVERRIDE"
    return 0
  fi

  for candidate in \
    "$CONTENTS_DIR/MacOS/$APP_NAME" \
    "$INSTALLED_APP/Contents/MacOS/$APP_NAME" \
    "$SCRIPT_DIR/.build/$APP_NAME.app/Contents/MacOS/$APP_NAME"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

passwordless_status() {
  local executable
  executable=$(resolve_app_executable) || return 2
  "$executable" --passwordless-status >/dev/null 2>&1
}

setup_passwordless() {
  local executable
  executable=$(resolve_app_executable) || {
    error "インストール済みアプリが見つかりません。先に ./install.sh を実行してください。"
    return 1
  }

  if passwordless_status; then
    printf 'パスワード省略はすでに設定済みです。\n'
    return 0
  fi

  printf 'macOSの確認画面を表示します。許可するのはpmsetのON/OFF 2コマンドだけです。\n'
  "$executable" --install-passwordless
  if ! passwordless_status; then
    error "パスワード省略設定を確認できませんでした。"
    return 1
  fi
  printf '設定完了: 次回からON/OFF時のパスワード入力は不要です。\n'
}

remove_passwordless() {
  local executable
  executable=$(resolve_app_executable) || {
    error "インストール済みアプリが見つかりません。"
    return 1
  }

  if ! passwordless_status; then
    printf 'パスワード省略はすでに解除されています。\n'
    return 0
  fi

  "$executable" --uninstall-passwordless
  if passwordless_status; then
    error "パスワード省略設定が残っています。"
    return 1
  fi
  printf '解除完了: 次回から切り替え時にmacOSの管理者確認が表示されます。\n'
}

doctor() {
  local failures=0
  local source
  local value
  local executable
  local app_version="不明"
  local cli_command=""

  printf 'AI Shell Switch doctor %s\n' "$CLI_VERSION"
  printf 'CLI実体: %s\n' "$SCRIPT_PATH"

  if [ -x "$PMSET" ]; then
    printf '[OK] pmset: %s\n' "$PMSET"
  else
    printf '[NG] pmsetが実行できません: %s\n' "$PMSET"
    failures=$((failures + 1))
  fi

  source=$(power_source) || source="不明"
  value=$(sleep_disabled_value) || value="unknown"
  printf '[INFO] 電源: %s\n' "${source:-不明}"
  case "$value" in
    1) printf '[INFO] モード: ON\n' ;;
    0) printf '[INFO] モード: OFF\n' ;;
    *)
      printf '[NG] モードを読み取れません\n'
      failures=$((failures + 1))
      ;;
  esac

  if executable=$(resolve_app_executable); then
    printf '[OK] アプリ実行ファイル: %s\n' "$executable"
  else
    printf '[NG] アプリ実行ファイルが見つかりません\n'
    failures=$((failures + 1))
  fi

  if [ -f "$INSTALLED_APP/Contents/Info.plist" ]; then
    app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_APP/Contents/Info.plist" 2>/dev/null || printf '不明')
    printf '[INFO] インストール済みアプリ: %s (%s)\n' "$INSTALLED_APP" "$app_version"
  fi

  if passwordless_status; then
    printf '[OK] パスワード省略: 設定済み\n'
  else
    printf '[WARN] パスワード省略: 未設定または確認不能（ai-setupで設定）\n'
  fi

  cli_command=$(command -v ai-shell-switch 2>/dev/null || true)
  if [ -n "$cli_command" ]; then
    printf '[OK] PATH: %s\n' "$cli_command"
  else
    printf '[WARN] ai-shell-switchがPATH上にありません。./install.shを再実行してください。\n'
  fi

  if [ "$failures" -gt 0 ]; then
    printf '診断結果: NG (%s件)\n' "$failures"
    return 1
  fi

  printf '診断結果: OK\n'
}

usage() {
  cat <<'EOF'
使い方: ai-shell-switch COMMAND

Commands:
  on        AI稼働モードをONにする（AC電源接続時のみ）
  off       通常のmacOSスリープへ戻す
  toggle    ON/OFFを切り替える
  status    現在の状態を表示する
  setup     初回だけ、切り替え時のパスワード省略を設定する
  unsetup   パスワード省略設定を解除する
  doctor    構成を変更せず診断する
  version   バージョンを表示する
  help      このヘルプを表示する

Shortcuts:
  ai-on  ai-off  ai-toggle  ai-status  ai-setup  ai-unsetup  ai-doctor
EOF
}

INVOCATION=$(/usr/bin/basename "$0")
readonly INVOCATION
default_command=status
case "$INVOCATION" in
  ai-on) default_command=on ;;
  ai-off) default_command=off ;;
  ai-toggle) default_command=toggle ;;
  ai-status) default_command=status ;;
  ai-setup) default_command=setup ;;
  ai-unsetup) default_command=unsetup ;;
  ai-doctor) default_command=doctor ;;
esac

command_name=${1:-$default_command}
if [ "$#" -gt 0 ]; then
  shift
fi
if [ "$#" -ne 0 ]; then
  error "余分な引数があります: $*"
  usage >&2
  exit 64
fi

case "$command_name" in
  on) turn_on ;;
  off) turn_off ;;
  toggle) toggle ;;
  status) status ;;
  setup) setup_passwordless ;;
  unsetup) remove_passwordless ;;
  doctor) doctor ;;
  version | -v | --version) printf 'AI Shell Switch CLI %s\n' "$CLI_VERSION" ;;
  help | -h | --help) usage ;;
  *)
    error "不明なコマンドです: $command_name"
    usage >&2
    exit 64
    ;;
esac
