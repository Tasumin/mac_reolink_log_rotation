#!/bin/zsh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/reolink-logguard"
BIN_DIR="$HOME/.local/bin"
PLIST="$HOME/Library/LaunchAgents/com.reolink.logguard.plist"
BUILD_DIR="$SCRIPT_DIR/build"
APP_DEST="/Applications/Reolink LogGuard.app"
BUILD_APP="$BUILD_DIR/Reolink LogGuard.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cleanup_build() {
  # Never leave a valid .app in the source tree. Spotlight/LaunchServices would
  # otherwise discover it as a second copy of Reolink LogGuard.
  if [[ -d "$BUILD_APP" && -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -u "$BUILD_APP" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf "$BUILD_DIR"
}

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$HOME/Library/LaunchAgents"
/bin/cp -f "$SCRIPT_DIR/logguard.sh" "$INSTALL_DIR/logguard.sh"
/bin/chmod +x "$INSTALL_DIR/logguard.sh"
[[ -f "$INSTALL_DIR/config.conf" ]] || /bin/cp "$SCRIPT_DIR/config.conf" "$INSTALL_DIR/config.conf"
source "$INSTALL_DIR/config.conf"
INTERVAL="${CHECK_INTERVAL:-3600}"

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

# Remove any stale staging app before building.
cleanup_build

echo "Building Reolink LogGuard.app..."
/bin/chmod +x "$SCRIPT_DIR/build.sh"
"$SCRIPT_DIR/build.sh"
[[ -d "$BUILD_APP" ]] || { echo "ERROR: App bundle not found: $BUILD_APP" >&2; exit 1; }

/usr/bin/pkill -x "ReolinkLogGuard" 2>/dev/null || true
sleep 1

if [[ -e "$APP_DEST" ]]; then
  echo "Removing previous application..."
  /bin/rm -rf "$APP_DEST" 2>/dev/null || sudo /bin/rm -rf "$APP_DEST"
fi
[[ ! -e "$APP_DEST" ]] || { echo "ERROR: Could not remove previous application." >&2; exit 1; }

echo "Installing fresh application bundle..."
/bin/cp -R "$BUILD_APP" "$APP_DEST" 2>/dev/null || sudo /bin/cp -R "$BUILD_APP" "$APP_DEST"
[[ -x "$APP_DEST/Contents/MacOS/ReolinkLogGuard" ]] || { echo "ERROR: Installed app is missing its executable." >&2; exit 1; }
/usr/bin/codesign --verify --deep --strict "$APP_DEST" >/dev/null 2>&1 || { echo "ERROR: Installed app failed code-signature verification." >&2; exit 1; }

# The staging bundle must disappear before macOS indexes applications.
cleanup_build

echo "Registering application with macOS..."
/usr/bin/touch "$APP_DEST"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_DEST" >/dev/null 2>&1 || true
fi
/usr/bin/mdimport -i "$APP_DEST" >/dev/null 2>&1 || true
/usr/bin/killall Dock >/dev/null 2>&1 || true

sleep 2
if /usr/bin/open -Ra "Reolink LogGuard" >/dev/null 2>&1; then
  echo "LaunchServices registration verified: Reolink LogGuard"
else
  echo "WARNING: macOS has not resolved the app by name yet; exact-path launch will still work."
fi

echo "Installed fresh app: $APP_DEST"
echo "Background cleanup interval: $INTERVAL seconds"

if ! /usr/bin/open "$APP_DEST"; then
  echo "Install succeeded, but macOS did not launch the app automatically."
  echo "Try: open \"$APP_DEST\""
fi
