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

echo "Launching NotchApp in background..."
"$APP_BIN" &
APP_PID=$!
echo "NotchApp PID: $APP_PID"

sleep 1.5
echo "Memory Footprint Status:"
ps -o pid,rss,%mem,%cpu,command -p $APP_PID
