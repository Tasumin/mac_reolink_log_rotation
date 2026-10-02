#!/bin/zsh
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Reolink LogGuard.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
ICON_SOURCE="$ROOT/ReolinkLogGuard.png"
ICONSET="$BUILD/ReolinkLogGuard.iconset"
ICON_FILE="$RESOURCES/ReolinkLogGuard.icns"

rm -rf "$APP" "$ICONSET"
mkdir -p "$MACOS" "$RESOURCES" "$ICONSET"

SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun swiftc -O -sdk "$SDK" -target "$(uname -m)-apple-macos13.0" -framework SwiftUI -framework AppKit "$ROOT"/ReolinkLogGuard/*.swift -o "$MACOS/ReolinkLogGuard"

if [[ -f "$ICON_SOURCE" ]]; then
  echo "Building application icon..."
  sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$ICON_FILE"
else
  echo "WARNING: $ICON_SOURCE not found; building without custom icon."
fi

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
<key>CFBundleShortVersionString</key><string>1.0.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

rm -rf "$ICONSET"
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
