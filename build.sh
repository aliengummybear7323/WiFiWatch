#!/bin/bash
# Builds WiFiWatch.app from WiFiWatch.swift. Needs Xcode Command Line Tools:
#   xcode-select --install
set -e
cd "$(dirname "$0")"

APP="WiFiWatch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O WiFiWatch.swift -o "$APP/Contents/MacOS/WiFiWatch"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>WiFiWatch</string>
    <key>CFBundleDisplayName</key><string>WiFiWatch</string>
    <key>CFBundleIdentifier</key><string>com.local.wifiwatch</string>
    <key>CFBundleExecutable</key><string>WiFiWatch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# Optional app icon: drop an AppIcon.icns next to this script and rebuild
if [ -f AppIcon.icns ]; then
    mkdir -p "$APP/Contents/Resources"
    cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
    echo "Bundled AppIcon.icns"
fi

# Ad-hoc sign so notifications and login-item registration work
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open $APP"
echo "Optional: drag it into /Applications"
