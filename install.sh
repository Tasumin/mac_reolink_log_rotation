#!/bin/zsh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/reolink-logguard"
BIN_DIR="$HOME/.local/bin"
PLIST="$HOME/Library/LaunchAgents/com.reolink.logguard.plist"
APP_DEST="/Applications/Reolink LogGuard.app"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$HOME/Library/LaunchAgents"
cp "$SCRIPT_DIR/logguard.sh" "$INSTALL_DIR/logguard.sh"
chmod +x "$INSTALL_DIR/logguard.sh"
[[ -f "$INSTALL_DIR/config.conf" ]] || cp "$SCRIPT_DIR/config.conf" "$INSTALL_DIR/config.conf"
source "$INSTALL_DIR/config.conf"
INTERVAL="${CHECK_INTERVAL:-3600}"
cat > "$BIN_DIR/logguard" <<EOF
#!/bin/zsh
INSTALL_DIR="$INSTALL_DIR"
case "\${1:-status}" in
 run) "\$INSTALL_DIR/logguard.sh" ;;
 dry-run) "\$INSTALL_DIR/logguard.sh" --dry-run ;;
 status) launchctl print gui/\$(id -u)/com.reolink.logguard 2>/dev/null | grep -E "state =|runs =|last exit code =" || echo "LaunchAgent is not loaded"; du -sh "\$HOME/Library/Logs/reolink" 2>/dev/null || true ;;
 config) open -a "Reolink LogGuard" ;;
 logs) tail -100 "\$HOME/Library/Logs/reolink-logguard.log" ;;
 *) echo "Usage: logguard {status|run|dry-run|config|logs}"; exit 1 ;;
esac
EOF
chmod +x "$BIN_DIR/logguard"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.reolink.logguard</string>
<key>ProgramArguments</key><array><string>$INSTALL_DIR/logguard.sh</string></array>
<key>StartInterval</key><integer>$INTERVAL</integer>
<key>RunAtLoad</key><true/>
</dict></plist>
EOF
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"

echo "Building Reolink LogGuard.app..."
chmod +x "$SCRIPT_DIR/build.sh"
"$SCRIPT_DIR/build.sh"
rm -rf "$APP_DEST" 2>/dev/null || true
if cp -R "$SCRIPT_DIR/build/Reolink LogGuard.app" "$APP_DEST" 2>/dev/null; then
  echo "Installed app: $APP_DEST"
else
  echo "Installing to /Applications requires administrator permission."
  sudo rm -rf "$APP_DEST"
  sudo cp -R "$SCRIPT_DIR/build/Reolink LogGuard.app" "$APP_DEST"
fi
/usr/bin/touch "$APP_DEST"
echo "Reolink LogGuard installed. Find it in Applications, Launchpad, or Spotlight."
echo "Background cleanup interval: $INTERVAL seconds"
open -a "Reolink LogGuard"
