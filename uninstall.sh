#!/bin/zsh
set -e
INSTALL_DIR="$HOME/.local/share/reolink-logguard"
PLIST="$HOME/Library/LaunchAgents/com.reolink.logguard.plist"
COMMAND="$HOME/.local/bin/logguard"
APP="/Applications/Reolink LogGuard.app"
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
rm -f "$PLIST" "$COMMAND"
rm -rf "$INSTALL_DIR"
if [[ -d "$APP" ]]; then
  rm -rf "$APP" 2>/dev/null || sudo rm -rf "$APP"
fi
echo "Reolink LogGuard removed. Existing Reolink logs were not deleted."
