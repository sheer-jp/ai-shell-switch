#!/bin/bash

set -euo pipefail

readonly RULE_STATE=${AI_SHELL_SWITCH_TEST_RULE_STATE:?AI_SHELL_SWITCH_TEST_RULE_STATE is required}

case "${1:-}" in
  --install-passwordless)
    printf '1\n' >"$RULE_STATE"
    printf 'passwordless-rule: installed\n'
    ;;
  --uninstall-passwordless)
    printf '0\n' >"$RULE_STATE"
    printf 'passwordless-rule: removed\n'
    ;;
  --passwordless-status)
    if [ "$(/bin/cat "$RULE_STATE")" = "1" ]; then
      printf 'passwordless-rule: installed\n'
      exit 0
    fi
    printf 'passwordless-rule: not-installed\n'
    exit 1
    ;;
  *)
    printf 'unsupported mock app invocation\n' >&2
    exit 64
    ;;
esac
