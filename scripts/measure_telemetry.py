#!/usr/bin/env python3
import subprocess
import time
import os
import signal
import sys

MEASUREMENTS_DIR = os.path.abspath("measurements")
os.makedirs(MEASUREMENTS_DIR, exist_ok=True)

BASELINE_BIN = "/private/tmp/notch_main_baseline/.build/release/NotchApp"
CURRENT_BIN = os.path.abspath(".build/release/NotchApp")

def cleanup_notch():
    subprocess.run(["pkill", "-9", "-f", "NotchApp"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)

def run_top_sample(pid, output_path):
    print(f"Sampling top for PID {pid} -> {output_path}")
    res = subprocess.run(
        ["top", "-l", "3", "-pid", str(pid), "-stats", "pid,command,cpu,mem"],
        capture_output=True,
        text=True
    )
    with open(output_path, "w") as f:
        f.write(res.stdout)
    
    # Parse the last sample line
    lines = res.stdout.strip().split("\n")
    data_lines = [l for l in lines if l.strip().startswith(str(pid))]
    last_line = data_lines[-1] if data_lines else "unknown"
    return last_line

def measure_scenario(name, binary_path, env_overrides=None, pre_command=None):
    cleanup_notch()
    if pre_command:
        pre_command()
    
    env = os.environ.copy()
    if env_overrides:
        env.update(env_overrides)
        
    print(f"\n--- Measuring {name} with binary: {binary_path} ---")
    proc = subprocess.Popen([binary_path], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pid = proc.pid
    print(f"Started PID: {pid}. Settling for 12 seconds...")
    time.sleep(12)
    
    out_file = os.path.join(MEASUREMENTS_DIR, f"{name}.txt")
    last_sample = run_top_sample(pid, out_file)
    print(f"Result for {name}: {last_sample}")
    
    proc.terminate()
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
    cleanup_notch()
    return last_sample

def main():
    print("==================================================")
    print("  RUNNING REAL HEADLESS TELEMETRY BENCHMARK       ")
    print("==================================================")
    
    # 1. Baseline: Collapsed Idle (default settings)
    def prep_collapsed():
        subprocess.run(["defaults", "write", "com.notch.NotchApp", "NotchApp_IsCompanionEnabled", "-bool", "false"], check=False)
        subprocess.run(["defaults", "write", "NotchApp", "NotchApp_IsCompanionEnabled", "-bool", "false"], check=False)

    baseline_idle = measure_scenario("raw_baseline_collapsed_idle", BASELINE_BIN, pre_command=prep_collapsed)
    current_idle = measure_scenario("raw_current_collapsed_idle", CURRENT_BIN, pre_command=prep_collapsed)
    
    # 2. Companion Enabled
    def prep_companion():
        subprocess.run(["defaults", "write", "com.notch.NotchApp", "NotchApp_IsCompanionEnabled", "-bool", "true"], check=False)
        subprocess.run(["defaults", "write", "NotchApp", "NotchApp_IsCompanionEnabled", "-bool", "true"], check=False)

    baseline_companion = measure_scenario("raw_baseline_companion_enabled", BASELINE_BIN, pre_command=prep_companion)
    current_companion = measure_scenario("raw_current_companion_enabled", CURRENT_BIN, pre_command=prep_companion)

    summary_file = os.path.join(MEASUREMENTS_DIR, "TELEMETRY_SUMMARY.txt")
    with open(summary_file, "w") as f:
        f.write("==================================================\n")
        f.write("      MEASURED HEADLESS TELEMETRY RESULTS         \n")
        f.write("==================================================\n")
        f.write(f"Tool: top -l 3 -pid <PID> -stats pid,command,cpu,mem (sample 3)\n\n")
        f.write(f"1. Collapsed Idle:\n")
        f.write(f"   Baseline (main):             {baseline_idle}\n")
        f.write(f"   Current (fix/notchify-deep): {current_idle}\n\n")
        f.write(f"2. Companion Enabled:\n")
        f.write(f"   Baseline (main):             {baseline_companion}\n")
        f.write(f"   Current (fix/notchify-deep): {current_companion}\n\n")
        f.write("3. Interactive Scenarios (Not measured headlessly):\n")
        f.write("   - Expanded Idle: NOT MEASURED (requires interactive hover/lock state)\n")
        f.write("   - Music Playing Collapsed: NOT MEASURED (requires host system audio playback session)\n")
        f.write("   - Camera Mirror: NOT MEASURED (requires interactive tab selection and camera video stream)\n")
        f.write("   - AirDrop Drag Stage: NOT MEASURED (requires active window dragging session)\n")
    
    print("\nSummary written to:", summary_file)
    with open(summary_file) as f:
        print(f.read())

if __name__ == "__main__":
    main()
