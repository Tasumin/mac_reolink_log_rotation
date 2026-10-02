#!/bin/zsh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/reolink-logguard"
BIN_DIR="$HOME/.local/bin"
PLIST="$HOME/Library/LaunchAgents/com.reolink.logguard.plist"
APP_DEST="/Applications/Reolink LogGuard.app"
BUILD_APP="$SCRIPT_DIR/build/Reolink LogGuard.app"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$HOME/Library/LaunchAgents"

# Always replace installed program files. Preserve only the user's installed config.
/bin/cp -f "$SCRIPT_DIR/logguard.sh" "$INSTALL_DIR/logguard.sh"
/bin/chmod +x "$INSTALL_DIR/logguard.sh"
if [[ ! -f "$INSTALL_DIR/config.conf" ]]; then
  /bin/cp "$SCRIPT_DIR/config.conf" "$INSTALL_DIR/config.conf"
fi

source "$INSTALL_DIR/config.conf"
INTERVAL="${CHECK_INTERVAL:-3600}"

# Always rewrite the CLI helper.
/bin/cat > "$BIN_DIR/logguard" <<EOF
#!/bin/zsh
INSTALL_DIR="$INSTALL_DIR"
case "\${1:-status}" in
 run) "\$INSTALL_DIR/logguard.sh" ;;
 dry-run) "\$INSTALL_DIR/logguard.sh" --dry-run ;;
 status) launchctl print gui/\$(id -u)/com.reolink.logguard 2>/dev/null | grep -E "state =|runs =|last exit code =" || echo "LaunchAgent is not loaded"; du -sh "\$HOME/Library/Logs/reolink" 2>/dev/null || true ;;
 config) /usr/bin/open "/Applications/Reolink LogGuard.app" ;;
 logs) tail -100 "\$HOME/Library/Logs/reolink-logguard.log" ;;
 *) echo "Usage: logguard {status|run|dry-run|config|logs}"; exit 1 ;;
esac
EOF
/bin/chmod +x "$BIN_DIR/logguard"

# Always rewrite and reload the LaunchAgent.
/bin/cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.reolink.logguard</string>
<key>ProgramArguments</key><array><string>$INSTALL_DIR/logguard.sh</string></array>
<key>StartInterval</key><integer>$INTERVAL</integer>
<key>RunAtLoad</key><true/>
</dict></plist>
EOF
/bin/launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
/bin/launchctl bootstrap gui/$(id -u) "$PLIST"

echo "Building Reolink LogGuard.app..."
/bin/chmod +x "$SCRIPT_DIR/build.sh"
"$SCRIPT_DIR/build.sh"

if [[ ! -d "$BUILD_APP" ]]; then
  echo "ERROR: Build completed but app bundle was not found: $BUILD_APP" >&2
  exit 1
fi

# A reinstall is a true replacement: close the old app, remove the entire old bundle,
# then copy the newly built bundle. Never merge files into an existing .app.
/usr/bin/pkill -x "ReolinkLogGuard" 2>/dev/null || true
sleep 1

if [[ -e "$APP_DEST" ]]; then
  echo "Removing previous application..."
  if ! /bin/rm -rf "$APP_DEST" 2>/dev/null; then
    sudo /bin/rm -rf "$APP_DEST"
  fi
fi

if [[ -e "$APP_DEST" ]]; then
  echo "ERROR: Could not remove previous application: $APP_DEST" >&2
  exit 1
fi

echo "Installing fresh application bundle..."
if ! /bin/cp -R "$BUILD_APP" "$APP_DEST" 2>/dev/null; then
  sudo /bin/cp -R "$BUILD_APP" "$APP_DEST"
fi

# Verify that the newly installed bundle contains the expected executable.
if [[ ! -x "$APP_DEST/Contents/MacOS/ReolinkLogGuard" ]]; then
  echo "ERROR: Installed app is missing its executable." >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict "$APP_DEST" >/dev/null 2>&1 || {
  echo "ERROR: Installed application failed code-signature verification." >&2
  exit 1
}

/usr/bin/touch "$APP_DEST"
/usr/bin/mdimport "$APP_DEST" >/dev/null 2>&1 || true

echo "Installed fresh app: $APP_DEST"
echo "Background cleanup interval: $INTERVAL seconds"

# Launch by exact bundle path rather than relying on LaunchServices name indexing.
if ! /usr/bin/open "$APP_DEST"; then
  echo "Install succeeded, but macOS did not launch the app automatically."
  echo "Try: open \"$APP_DEST\""
fi
