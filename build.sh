#!/bin/zsh
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Reolink LogGuard.app"
MACOS="$APP/Contents/MacOS"
mkdir -p "$MACOS"
rm -f "$MACOS/ReolinkLogGuard"
SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun swiftc -O -sdk "$SDK" -target "$(uname -m)-apple-macos13.0" -framework SwiftUI -framework AppKit "$ROOT"/ReolinkLogGuard/*.swift -o "$MACOS/ReolinkLogGuard"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Reolink LogGuard</string>
<key>CFBundleDisplayName</key><string>Reolink LogGuard</string>
<key>CFBundleIdentifier</key><string>com.tasumin.reolinklogguard</string>
<key>CFBundleExecutable</key><string>ReolinkLogGuard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
