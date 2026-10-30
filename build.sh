#!/bin/bash
# Build PortKiller.app (menu bar app, không icon Dock)
set -e
cd "$(dirname "$0")"

swift build -c release

APP="PortKiller.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp $(swift build -c release --show-bin-path)/PortKiller "$APP/Contents/MacOS/PortKiller"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PortKiller</string>
    <key>CFBundleIdentifier</key><string>com.local.portkiller</string>
    <key>CFBundleExecutable</key><string>PortKiller</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Xong: $(pwd)/$APP"
echo "Chạy: open $APP"
