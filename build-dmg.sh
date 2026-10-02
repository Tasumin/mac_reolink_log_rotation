#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Reolink LogGuard"
APP="$ROOT/build/$APP_NAME.app"
DIST="$ROOT/dist"
STAGE="$ROOT/build/dmg-stage"

cleanup() {
  /bin/rm -rf "$STAGE"
  /bin/rm -rf "$APP"
}
trap cleanup EXIT

cd "$ROOT"
echo "Building $APP_NAME.app..."
/bin/chmod +x "$ROOT/build.sh"
"$ROOT/build.sh"
[[ -d "$APP" ]] || { echo "ERROR: $APP was not created." >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG="$DIST/Reolink-LogGuard-$VERSION.dmg"
VOLUME_NAME="Reolink LogGuard $VERSION"

/bin/rm -rf "$STAGE"
/bin/mkdir -p "$STAGE" "$DIST"
/bin/cp -R "$APP" "$STAGE/$APP_NAME.app"
/bin/ln -s /Applications "$STAGE/Applications"

/bin/cat > "$STAGE/README.txt" <<'EOF'
Reolink LogGuard
================

1. Drag Reolink LogGuard.app to the Applications folder.
2. Open Reolink LogGuard from Applications.
3. LogGuard automatically installs its per-user background cleanup service.
4. Review Configuration if you want to change the defaults.

No Git clone, Terminal setup, or separate installer is required.
LogGuard protects ~/Library/Logs/reolink by default.
Future in-app updates are downloaded from the latest GitHub Release DMG.

Project:
https://github.com/Tasumin/mac_reolink_log_rotation
EOF

/bin/rm -f "$DMG"
echo "Creating $DMG..."
/usr/bin/hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo
echo "DMG created successfully:"
echo "$DMG"
echo "Temporary build app removed so macOS does not discover a second LogGuard application."
echo
echo "Upload this DMG as an asset on the GitHub Release. Update Now will use the DMG attached to the latest release."
echo "For broad public distribution, Developer ID signing and Apple notarization are still recommended."
