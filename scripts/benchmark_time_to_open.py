#!/usr/bin/env python3
import time
import subprocess
import re

APP_PATH = "./.build/release/NotchApp"

def stop_notch():
    subprocess.run(["pkill", "-9", "-f", "NotchApp"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.0)

def start_notch():
    stop_notch()
    p = subprocess.Popen([APP_PATH], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2.0)
    return p.pid

def post_mouse_move(x, y):
    script = f"""
    import CoreGraphics
    if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: {x}, y: {y}), mouseButton: .left) {{
        event.post(tap: .cghidEventTap)
    }}
    """
    subprocess.run(["swift", "-e", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def get_window_height():
    ascript = '''
    tell application "System Events"
        tell process "NotchApp"
            if exists (window 1) then
                set sz to size of window 1
                return item 2 of sz
            end if
        end tell
    end tell
    return 0
    '''
    res = subprocess.run(["osascript", "-e", ascript], capture_output=True, text=True)
    try:
        return float(res.stdout.strip())
    except:
        return 0.0

def measure_open():
    pid = start_notch()
    # Move mouse away first
    post_mouse_move(100, 500)
    time.sleep(1.0)
    
    t0 = time.time()
    # Move into notch
    post_mouse_move(735, 12)
    
    # Poll for window height expanding beyond collapsed (~24-35pt)
    expanded = False
    duration = 0.0
    while time.time() - t0 < 2.0:
        h = get_window_height()
        if h > 80.0:
            duration = (time.time() - t0) * 1000.0
            expanded = True
            break
        time.sleep(0.005)
    
    stop_notch()
    return duration if expanded else None

results = []
for i in range(5):
    d = measure_open()
    if d is not None:
        results.append(d)
        print(f"Run {i+1}: {d:.1f} ms")

if results:
    avg_d = sum(results) / len(results)
    min_d = min(results)
    max_d = max(results)
    out_str = f"Time-to-open: Min {min_d:.1f} ms | Avg {avg_d:.1f} ms | Max {max_d:.1f} ms\nRuns: {results}\n"
    print(out_str)
    with open("evidence/baseline_time_to_open.txt", "w") as f:
        f.write(out_str)
