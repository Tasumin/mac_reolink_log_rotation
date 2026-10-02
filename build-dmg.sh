#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Reolink LogGuard"
APP="$ROOT/build/$APP_NAME.app"
DIST="$ROOT/dist"
STAGE="$ROOT/build/dmg-stage"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
DMG="$DIST/Reolink-LogGuard-$VERSION.dmg"
VOLUME_NAME="Reolink LogGuard $VERSION"

cd "$ROOT"

echo "Building $APP_NAME.app..."
/bin/chmod +x "$ROOT/build.sh"
"$ROOT/build.sh"

[[ -d "$APP" ]] || { echo "ERROR: $APP was not created." >&2; exit 1; }

/bin/rm -rf "$STAGE"
/bin/mkdir -p "$STAGE" "$DIST"

# Copy the application and provide the standard drag-to-Applications shortcut.
/bin/cp -R "$APP" "$STAGE/$APP_NAME.app"
/bin/ln -s /Applications "$STAGE/Applications"

# Include a short first-install note. LogGuard installs its background service
# when the application is first opened.
/bin/cat > "$STAGE/README.txt" <<'EOF'
Reolink LogGuard
================

1. Drag Reolink LogGuard.app to the Applications folder.
2. Open Reolink LogGuard from Applications.
3. Use Configuration to review the default protection settings.

LogGuard protects ~/Library/Logs/reolink by default.

Project:
https://github.com/Tasumin/mac_reolink_log_rotation
EOF

/bin/rm -f "$DMG"

echo "Creating $DMG..."
/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

/bin/rm -rf "$STAGE"

echo
echo "DMG created successfully:"
echo "$DMG"
echo
echo "Before public distribution, sign and notarize the app/DMG with an Apple Developer ID to avoid Gatekeeper warnings."
