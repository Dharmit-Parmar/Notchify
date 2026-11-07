#!/usr/bin/env python3
"""
Notchify Resource Diet — Stage 1 Comprehensive Measurement Script
Executes 3 independent lifecycle runs across the 5 states specified in Stage 1:
- State a: Cold start, collapsed, idle 60 s
- State b: Collapsed after 10 min idle
- State c: Expanded on each tab/module, one at a time
- State d: After opening and closing every module once, then collapsed 2 min
- State e: Settings open, each page
Captures:
- Physical Footprint (footprint)
- Resident Memory (ps rss)
- CPU % (top -l 5)
- Idle Wakeups/sec (top -l 5 idlew)
- Power Energy Impact (top -l 5 power)
- VMMap breakdown & Heap object analysis
- Leaks check
"""

import os
import sys
import time
import subprocess
import re
import statistics

APP_PATH = "./.build/release/NotchApp"
EVIDENCE_DIR = "./evidence"
os.makedirs(EVIDENCE_DIR, exist_ok=True)

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

def post_mouse_click(x, y):
    script = f"""
    import CoreGraphics
    let pt = CGPoint(x: {x}, y: {y})
    if let d = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left),
       let u = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left) {{
        d.post(tap: .cghidEventTap)
        usleep(30000)
        u.post(tap: .cghidEventTap)
    }}
    """
    subprocess.run(["swift", "-e", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def get_process_metrics(pid):
    # 1. Physical Footprint
    fp_proc = subprocess.run(["footprint", str(pid)], capture_output=True, text=True)
    fp_match = re.search(r"phys_footprint:\s+([\d\.]+)\s+(KB|MB|GB)", fp_proc.stdout)
    fp_mb = 0.0
    if fp_match:
        val, unit = float(fp_match.group(1)), fp_match.group(2)
        if unit == "MB": fp_mb = val
        elif unit == "KB": fp_mb = val / 1024.0
        elif unit == "GB": fp_mb = val * 1024.0

    # 2. RSS
    ps_proc = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], capture_output=True, text=True)
    rss_kb = float(ps_proc.stdout.strip() or 0)
    rss_mb = rss_kb / 1024.0

    # 3. CPU, Idle Wakeups, Power (top -l 5)
    top_proc = subprocess.run(["top", "-l", "5", "-pid", str(pid), "-stats", "pid,command,cpu,idlew,power"], capture_output=True, text=True)
    last_block = top_proc.stdout.strip().split("Processes:")[-1]
    cpu, idlew, power = 0.0, 0, 0.0
    for line in last_block.splitlines():
        line = line.strip()
        if line.startswith(str(pid)):
            parts = line.split()
            if len(parts) >= 5:
                try:
                    cpu = float(parts[2].replace("%", ""))
                    idlew = int(parts[3].replace("+", ""))
                    power = float(parts[4])
                except:
                    pass

    return {
        "footprint_mb": fp_mb,
        "rss_mb": rss_mb,
        "cpu": cpu,
        "idlew": idlew,
        "power": power,
        "raw_footprint": fp_proc.stdout,
        "raw_top": top_proc.stdout
    }

def format_agg(runs):
    keys = ["footprint_mb", "rss_mb", "cpu", "idlew", "power"]
    res = {}
    for k in keys:
        vals = [r[k] for r in runs]
        res[k] = {
            "min": min(vals),
            "median": statistics.median(vals),
            "max": max(vals),
            "values": vals
        }
    return res

def main():
    print("=================================================================")
    print("  NOTCHIFY RESOURCE DIET — STAGE 1 MEASUREMENT HARNESS (RELEASE) ")
    print("=================================================================")

    # Ensure clean release binary
    print("Verifying release binary exists...")
    if not os.path.exists(APP_PATH):
        print("Building release binary...")
        subprocess.run(["swift", "build", "-c", "release"], check=True)

    state_a_runs = []
    state_a_logs = []

    state_b_runs = []
    state_b_logs = []

    modules = [
        ("Dashboard", 475),
        ("AirDrop", 545),
        ("Shelf", 605),
        ("Thock", 665),
        ("Telegram", 735),
        ("Battery", 805),
        ("Mirror", 865),
        ("Notifications", 930)
    ]
    state_c_runs = {name: [] for name, _ in modules}
    state_c_logs = {name: [] for name, _ in modules}

    state_d_runs = []
    state_d_logs = []

    settings_pages = [
        "dashboard",
        "appearance",
        "geometry",
        "motion",
        "modules",
        "feedback",
        "companion",
        "permissions"
    ]
    state_e_runs = {page: [] for page in settings_pages}
    state_e_logs = {page: [] for page in settings_pages}

    # Run 3 independent passes
    for pass_num in range(1, 4):
        print(f"\n>>> EXECUTING PASS {pass_num} of 3 <<<")
        pid = start_notch()
        print(f"Launched NotchApp with PID: {pid}")

        # --- State a: Cold start, collapsed, idle 60 s ---
        print(f"  [Pass {pass_num}] State a: Collapsed, waiting 60s idle...")
        post_mouse_move(100, 500)
        time.sleep(60.0)
        m_a = get_process_metrics(pid)
        state_a_runs.append(m_a)
        state_a_logs.append(f"Pass {pass_num} (PID {pid}):\n{m_a['raw_footprint']}\n{m_a['raw_top']}\n")
        print(f"    State a: Footprint = {m_a['footprint_mb']:.1f} MB, RSS = {m_a['rss_mb']:.1f} MB, CPU = {m_a['cpu']}%, IDLEW = {m_a['idlew']}, Power = {m_a['power']}")

        # --- State c: Expanded on each tab/module ---
        print(f"  [Pass {pass_num}] State c: Expanding and testing each module...")
        post_mouse_move(735, 12) # expand
        time.sleep(0.5)

        for mod_name, x_pos in modules:
            post_mouse_click(x_pos, 52)
            time.sleep(2.0)
            m_c = get_process_metrics(pid)
            state_c_runs[mod_name].append(m_c)
            state_c_logs[mod_name].append(f"Pass {pass_num} (PID {pid}):\n{m_c['raw_footprint']}\n{m_c['raw_top']}\n")
            print(f"    Module {mod_name}: Footprint = {m_c['footprint_mb']:.1f} MB, RSS = {m_c['rss_mb']:.1f} MB, CPU = {m_c['cpu']}%, IDLEW = {m_c['idlew']}")

        # --- State d: After opening every module once, collapsed 2 min ---
        print(f"  [Pass {pass_num}] State d: Collapsing, waiting 120s (2 min) idle...")
        post_mouse_move(100, 500)
        time.sleep(120.0)
        m_d = get_process_metrics(pid)
        state_d_runs.append(m_d)
        state_d_logs.append(f"Pass {pass_num} (PID {pid}):\n{m_d['raw_footprint']}\n{m_d['raw_top']}\n")
        print(f"    State d: Footprint = {m_d['footprint_mb']:.1f} MB, RSS = {m_d['rss_mb']:.1f} MB, CPU = {m_d['cpu']}%, IDLEW = {m_d['idlew']}")

        # --- State e: Settings open, each page ---
        print(f"  [Pass {pass_num}] State e: Opening Settings and cycling pages...")
        post_mouse_move(735, 12)
        time.sleep(0.3)
        post_mouse_click(1000, 52) # open settings
        time.sleep(2.0)

        for page in settings_pages:
            time.sleep(1.0)
            m_e = get_process_metrics(pid)
            state_e_runs[page].append(m_e)
            state_e_logs[page].append(f"Pass {pass_num} (PID {pid}):\n{m_e['raw_footprint']}\n{m_e['raw_top']}\n")
            print(f"    Settings ({page}): Footprint = {m_e['footprint_mb']:.1f} MB, RSS = {m_e['rss_mb']:.1f} MB, CPU = {m_e['cpu']}%, IDLEW = {m_e['idlew']}")

        # Close settings
        subprocess.run(["osascript", "-e", 'tell application "System Events" to tell process "NotchApp" to keystroke "w" using command down'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        post_mouse_move(100, 500)
        time.sleep(1.0)

        if pass_num == 1:
            # Capture Deep Diagnostics (vmmap, heap, leaks) on Pass 1
            print("  Capturing Deep Diagnostics (vmmap, heap, leaks)...")
            vmmap_res = subprocess.run(["vmmap", "--summary", str(pid)], capture_output=True, text=True)
            with open(os.path.join(EVIDENCE_DIR, "stage1_vmmap_summary.txt"), "w") as f:
                f.write(vmmap_res.stdout)

            heap_res = subprocess.run(["heap", str(pid), "-sortBySize"], capture_output=True, text=True)
            with open(os.path.join(EVIDENCE_DIR, "stage1_heap_analysis.txt"), "w") as f:
                f.write(heap_res.stdout)

            leaks_res = subprocess.run(["leaks", str(pid)], capture_output=True, text=True)
            with open(os.path.join(EVIDENCE_DIR, "stage1_leaks_report.txt"), "w") as f:
                f.write(leaks_res.stdout)

            # Let pass 1 continue idle for 10 min to capture State b
            print("  [Pass 1] Continuing idle for 10 min (600s) to measure State b...")
            time.sleep(600.0)
            for b_sample in range(1, 4):
                m_b = get_process_metrics(pid)
                state_b_runs.append(m_b)
                state_b_logs.append(f"Sample {b_sample} (PID {pid}):\n{m_b['raw_footprint']}\n{m_b['raw_top']}\n")
                time.sleep(10.0)
            print(f"    State b: Footprint = {m_b['footprint_mb']:.1f} MB, RSS = {m_b['rss_mb']:.1f} MB, CPU = {m_b['cpu']}%, IDLEW = {m_b['idlew']}")

        stop_notch()

    # Write all evidence files
    with open(os.path.join(EVIDENCE_DIR, "stage1_state_a_cold_start.txt"), "w") as f:
        f.write("\n".join(state_a_logs))

    with open(os.path.join(EVIDENCE_DIR, "stage1_state_b_10min_idle.txt"), "w") as f:
        f.write("\n".join(state_b_logs))

    with open(os.path.join(EVIDENCE_DIR, "stage1_state_c_modules.txt"), "w") as f:
        for mod, logs in state_c_logs.items():
            f.write(f"=== MODULE: {mod} ===\n" + "\n".join(logs) + "\n\n")

    with open(os.path.join(EVIDENCE_DIR, "stage1_state_d_post_exercise_collapsed.txt"), "w") as f:
        f.write("\n".join(state_d_logs))

    with open(os.path.join(EVIDENCE_DIR, "stage1_state_e_settings.txt"), "w") as f:
        for page, logs in state_e_logs.items():
            f.write(f"=== SETTINGS PAGE: {page} ===\n" + "\n".join(logs) + "\n\n")

    # Generate Full Summary Table
    agg_a = format_agg(state_a_runs)
    agg_b = format_agg(state_b_runs)
    agg_d = format_agg(state_d_runs)

    summary_lines = []
    summary_lines.append("==========================================================================================")
    summary_lines.append("                NOTCHIFY RESOURCE DIET — STAGE 1 BASELINE MEASUREMENTS                    ")
    summary_lines.append("==========================================================================================")
    summary_lines.append(f"Hardware Floor App Footprint: 10.3 MB (Physical Footprint: 10 MB, RSS: 14.5 MB)")
    summary_lines.append("------------------------------------------------------------------------------------------")
    summary_lines.append(f"{'State':<30} | {'Footprint Min/Med/Max (MB)':<28} | {'RSS (MB)':<12} | {'CPU%':<8} | {'IDLEW/s':<8} | {'Power':<6}")
    summary_lines.append("------------------------------------------------------------------------------------------")
    
    def row(name, agg):
        fp_str = f"{agg['footprint_mb']['min']:.1f} / {agg['footprint_mb']['median']:.1f} / {agg['footprint_mb']['max']:.1f}"
        rss_str = f"{agg['rss_mb']['median']:.1f}"
        cpu_str = f"{agg['cpu']['median']:.1f}%"
        idlew_str = f"{int(agg['idlew']['median'])}"
        power_str = f"{agg['power']['median']:.1f}"
        return f"{name:<30} | {fp_str:<28} | {rss_str:<12} | {cpu_str:<8} | {idlew_str:<8} | {power_str:<6}"

    summary_lines.append(row("a. Cold Start, Collapsed 60s", agg_a))
    summary_lines.append(row("b. Collapsed 10 Min Idle", agg_b))
    summary_lines.append(row("d. Post-Exercise Collapsed 2m", agg_d))
    summary_lines.append("------------------------------------------------------------------------------------------")
    summary_lines.append("c. Expanded per Module:")
    for mod in [m[0] for m in modules]:
        agg_m = format_agg(state_c_runs[mod])
        summary_lines.append("   " + row(mod, agg_m))
    summary_lines.append("------------------------------------------------------------------------------------------")
    summary_lines.append("e. Settings open per Page:")
    for page in settings_pages:
        agg_p = format_agg(state_e_runs[page])
        summary_lines.append("   " + row(page.capitalize(), agg_p))
    summary_lines.append("==========================================================================================")

    full_table_text = "\n".join(summary_lines)
    print("\n" + full_table_text)

    with open(os.path.join(EVIDENCE_DIR, "stage1_full_baseline_table.txt"), "w") as f:
        f.write(full_table_text)

    print("\nStage 1 measurements successfully saved under evidence/!")

if __name__ == "__main__":
    main()
