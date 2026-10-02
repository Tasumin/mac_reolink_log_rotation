#!/bin/zsh
set -e
INSTALL_DIR="$HOME/.local/share/reolink-logguard"
PLIST="$HOME/Library/LaunchAgents/com.reolink.logguard.plist"
COMMAND="$HOME/.local/bin/logguard"
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
rm -f "$PLIST" "$COMMAND"
rm -rf "$INSTALL_DIR"
echo "Reolink LogGuard removed. Reolink logs were not deleted."
