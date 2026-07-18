#!/bin/bash

set -euo pipefail

if [ "${1:-}" = "-n" ]; then
  shift
fi

if [ "${1:-}" = "-l" ]; then
  [ "${AI_SHELL_SWITCH_TEST_PASSWORDLESS:-0}" = "1" ]
  exit
fi

if [ "${AI_SHELL_SWITCH_TEST_PASSWORDLESS:-0}" != "1" ]; then
  exit 1
fi

exec "$@"
