#!/bin/zsh
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Reolink LogGuard.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
ICON_SOURCE="$ROOT/ReolinkLogGuard.png"
NODEVYU_SOURCE="$ROOT/homepage-platform.png"
ICONSET="$BUILD/ReolinkLogGuard.iconset"
ICON_FILE="$RESOURCES/ReolinkLogGuard.icns"

rm -rf "$APP" "$ICONSET"
mkdir -p "$MACOS" "$RESOURCES" "$ICONSET"

SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun swiftc -O -sdk "$SDK" -target "$(uname -m)-apple-macos13.0" -framework SwiftUI -framework AppKit "$ROOT"/ReolinkLogGuard/*.swift -o "$MACOS/ReolinkLogGuard"

# Bundle everything required for a first-run installation. A DMG user does not
# need Git, the source repository, Homebrew, or a separate installer script.
/bin/cp -f "$ROOT/logguard.sh" "$RESOURCES/logguard.sh"
/bin/chmod +x "$RESOURCES/logguard.sh"
/bin/cp -f "$ROOT/config.conf" "$RESOURCES/config.conf"

if [[ -f "$ICON_SOURCE" ]]; then
  echo "Building application icon..."
  sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$ICON_FILE"
fi

if [[ -f "$NODEVYU_SOURCE" ]]; then /bin/cp -f "$NODEVYU_SOURCE" "$RESOURCES/homepage-platform.png"; fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Reolink LogGuard</string>
<key>CFBundleDisplayName</key><string>Reolink LogGuard</string>
<key>CFBundleIdentifier</key><string>com.tasumin.reolinklogguard</string>
<key>CFBundleExecutable</key><string>ReolinkLogGuard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>ReolinkLogGuard.icns</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>4</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

rm -rf "$ICONSET"
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
