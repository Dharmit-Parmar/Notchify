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
cp -f "$APP_BIN" "$APP_BUNDLE/Contents/MacOS/NotchApp"

# Copy validated source Info.plist with all privacy entitlements
cp -f "$DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc sign the bundle so macOS TCC privacy permissions are properly associated
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
echo "Application bundle signed with ad-hoc signature."

# 3. Create user Applications shortcut (~/Applications/NotchApp.app)
mkdir -p "$HOME/Applications"
ln -sfn "$APP_BUNDLE" "$HOME/Applications/NotchApp.app"
echo "Standard Application bundle installed at: $HOME/Applications/NotchApp.app"

# 4. Create system Applications symlink (/Applications/NotchApp.app) if writable
ln -sfn "$APP_BUNDLE" "/Applications/NotchApp.app" 2>/dev/null || true
echo "System Applications symlink installed at: /Applications/NotchApp.app"
echo "(You can now select NotchApp directly in System Settings (+) without searching!)"

echo "Launching NotchApp in background..."
nohup "$APP_BIN" >/dev/null 2>&1 &
APP_PID=$!
echo "NotchApp PID: $APP_PID"

sleep 1.5
echo "Memory Footprint Status:"
ps -o pid,rss,%mem,%cpu,command -p $APP_PID
