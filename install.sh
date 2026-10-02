#!/bin/zsh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/reolink-logguard"
BIN_DIR="$HOME/.local/bin"
PLIST="$HOME/Library/LaunchAgents/com.reolink.logguard.plist"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$HOME/Library/LaunchAgents"
cp "$SCRIPT_DIR/logguard.sh" "$INSTALL_DIR/logguard.sh"
chmod +x "$INSTALL_DIR/logguard.sh"
if [[ ! -f "$INSTALL_DIR/config.conf" ]]; then cp "$SCRIPT_DIR/config.conf" "$INSTALL_DIR/config.conf"; fi
source "$INSTALL_DIR/config.conf"
INTERVAL="${CHECK_INTERVAL:-3600}"
cat > "$BIN_DIR/logguard" <<EOF
#!/bin/zsh
INSTALL_DIR="$INSTALL_DIR"
case "\${1:-status}" in
 run) "\$INSTALL_DIR/logguard.sh" ;;
 dry-run) "\$INSTALL_DIR/logguard.sh" --dry-run ;;
 status) echo "Reolink LogGuard"; launchctl print gui/\$(id -u)/com.reolink.logguard 2>/dev/null | grep -E "state =|runs =|last exit code =" || echo "LaunchAgent is not loaded"; echo; du -sh "\$HOME/Library/Logs/reolink" 2>/dev/null || true ;;
 config) open -e "\$INSTALL_DIR/config.conf" ;;
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
echo "Reolink LogGuard installed."
echo "Config: $INSTALL_DIR/config.conf"
echo "Command: $BIN_DIR/logguard"
echo 'If needed, add ~/.local/bin to PATH: export PATH="$HOME/.local/bin:$PATH"'
