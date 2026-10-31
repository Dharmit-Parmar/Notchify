#!/bin/bash
# NotchApp Launcher and Runtime Monitor
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

# Ensure no duplicate instances are running
killall NotchApp 2>/dev/null || true
sleep 0.5

echo "Building NotchApp (Release optimized)..."
swift build -c release

APP_BIN="$DIR/.build/release/NotchApp"
echo "Executable ready at $APP_BIN"
echo "Binary size: $(du -h "$APP_BIN" | cut -f1)"

# 1. Ensure unhidden binary symlink in project directory
ln -sfn "$APP_BIN" "$DIR/NotchApp"
echo "Visible symlink ready at $DIR/NotchApp"

# 2. Create standard macOS Application Bundle structure
APP_BUNDLE="$DIR/NotchApp.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
ln -sfn "$APP_BIN" "$APP_BUNDLE/Contents/MacOS/NotchApp"

cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NotchApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.notch.NotchApp</string>
    <key>CFBundleName</key>
    <string>NotchApp</string>
    <key>CFBundleDisplayName</key>
    <string>NotchApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 3. Create user Applications shortcut (~/Applications/NotchApp.app)
mkdir -p "$HOME/Applications"
ln -sfn "$APP_BUNDLE" "$HOME/Applications/NotchApp.app"
echo "Standard Application bundle installed at: $HOME/Applications/NotchApp.app"
echo "(You can now select NotchApp directly in System Settings (+) without searching!)"

echo "Launching NotchApp in background..."
nohup "$APP_BIN" >/dev/null 2>&1 &
APP_PID=$!
echo "NotchApp PID: $APP_PID"

sleep 1.5
echo "Memory Footprint Status:"
ps -o pid,rss,%mem,%cpu,command -p $APP_PID
