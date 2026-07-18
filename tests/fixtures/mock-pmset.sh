#!/bin/bash

set -euo pipefail

readonly STATE_FILE=${AI_SHELL_SWITCH_TEST_STATE:?AI_SHELL_SWITCH_TEST_STATE is required}
readonly POWER_SOURCE=${AI_SHELL_SWITCH_TEST_POWER:-AC Power}

if [ "${1:-}" = "-g" ] && [ "${2:-}" = "ps" ]; then
  printf "Now drawing from '%s'\n" "$POWER_SOURCE"
  exit 0
fi

if [ "${1:-}" = "-g" ] && [ "$#" -eq 1 ]; then
  printf 'System-wide power settings:\n'
  printf ' SleepDisabled\t\t%s\n' "$(/bin/cat "$STATE_FILE")"
  exit 0
fi

if [ "${1:-}" = "-a" ] && [ "${2:-}" = "disablesleep" ]; then
  case "${3:-}" in
    0 | 1)
      printf '%s\n' "$3" >"$STATE_FILE"
      exit 0
      ;;
  esac
fi

printf 'unsupported mock pmset invocation\n' >&2
exit 64
