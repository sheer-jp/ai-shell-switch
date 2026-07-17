#!/bin/zsh

set -euo pipefail

readonly ROOT=${0:A:h}
readonly APP_NAME="AI Shell Switch"
readonly SOURCE_APP="$ROOT/dist/$APP_NAME.app"
readonly INSTALL_DIR="$HOME/Applications"
readonly INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

"$ROOT/build.sh"
/bin/mkdir -p "$INSTALL_DIR"
/usr/bin/ditto "$SOURCE_APP" "$INSTALLED_APP"
/usr/bin/open "$INSTALLED_APP"

print "Installed and opened: $INSTALLED_APP"
