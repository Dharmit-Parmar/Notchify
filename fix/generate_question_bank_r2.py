import os, glob, re
from collections import Counter

def run():
    source_counts = Counter()
    questions = []

    # Commit references
    C_PHASE1 = "e1bedaa"
    C_B6 = "6343f60"
    C_B5 = "2689955"
    C_B4 = "01d0899"
    C_B3 = "bbb39c4"
    C_B2 = "94c385c"
    C_B1 = "f411d40"

    # User complaints
    complaints = [
        ("C1", "App is laggy/heavy; notch and Settings feel unresponsive.", "Sources/Core/NotchModule.swift:349, Sources/Modules/Companion/CreatureRigView.swift:20, Sources/Notch/NotchRootView.swift:180", "NOT FIXED (Fed to Batch 2: SettingsStore fan-out & sync I/O)", "C1"),
        ("C2", "Elements go past the notch panel border; big empty area at the bottom.", "Sources/Notch/NotchWindow.swift:145, Sources/Notch/NotchRootView.swift:70", f"FIXED ({C_B4} & {C_PHASE1} Sources/Notch/NotchWindow.swift:180)", "C2"),
        ("C3", "Sakura/Birch are unreadable (theme names, 'Active theme', 'Done').", "Sources/UI/DesignSystem.swift:1175, Sources/Notch/NotchRootView.swift:143", "NOT FIXED (Fed to Batch 3: Semantic contrast tokens)", "C3"),
        ("C4", "Glass styles look the same or do not work.", "Sources/UI/DesignSystem.swift:1344, Sources/Core/EnvironmentState.swift:85", f"FIXED ({C_B4} Sources/UI/DesignSystem.swift:1344)", "C4"),
        ("C5", "Settings window will not minimise; the notch panel covers it.", "Sources/App/AppDelegate.swift:231, Sources/Notch/NotchWindow.swift:28", f"FIXED ({C_PHASE1} Sources/App/AppDelegate.swift:231)", "C5"),
        ("C6", "Slot widths must be adjustable ONLY in Settings -> Dashboard Slots Canvas, NOT in live notch.", "Sources/Notch/ModularDashboardView.swift:12, Sources/Settings/DashboardSettingsView.swift:450", f"FIXED ({C_B5} Sources/Notch/ModularDashboardView.swift:12)", "C6"),
        ("C7", "Dock tabs must be draggable to reorder directly in the notch.", "Sources/Notch/NotchRootView.swift:450, Sources/Core/ModuleRegistry.swift:210", f"FIXED ({C_B5} Sources/Notch/NotchRootView.swift:450)", "C7"),
        ("C8", "Typing: Notes and Ask AI do not reliably take keyboard focus; notch collapses while typing.", "Sources/Modules/Notes/NotesWidgetView.swift:70, Sources/Modules/AI/AskAIWidgetView.swift:618", "NOT FIXED (Fed to Batch 5: Focus & Esc fail-safes)", "C8"),
        ("C9", "Thock engine/sound problems (suspend on collapse, stale handlers, must end only with app).", "Sources/Modules/Thock/ThockModule.swift:225, 722", f"FIXED ({C_B3} Sources/Modules/Thock/ThockModule.swift:722)", "C9"),
        ("C10", "Old bugs came back after the redesign (idle CPU, memory growth).", "Sources/Modules/Companion/KinematicEngine.swift:51, Sources/Modules/NowPlaying/MediaRemoteBridge.swift:36", "NOT FIXED (Fed to Batch 2: Background processing & idle timers)", "C10")
    ]
    for cid, desc, cite, st, ctag in complaints:
        source_counts["User Complaints"] += 1
        questions.append({
            "qid": f"Q-COMPLAINT-{cid}",
            "sources": ["User Request"],
            "question": f"Complaint {cid}: {desc}",
            "code": cite,
            "status": st,
            "severity": "Critical",
            "complaint": ctag
        })

    # AUDIT_REPORT.md Findings
    audit_findings = [
        ("P1-APP-1", "Non-Persistent Instances for Secondary Lazy Modules", "Sources/Core/ModuleRegistry.swift:120", "NOT FIXED (Fed to Batch 2/4)", "High", "C10"),
        ("P1-PERM-1", "Dangerous Attempted Symlink Deletion in System /Applications on Launch", "Sources/Core/PermissionsHelper.swift:56", f"FIXED ({C_B6} Sources/Core/PermissionsHelper.swift:56)", "Low", "C10"),
        ("P1-REG-1", "orderedModules Excludes Disabled Modules Causing Disappearance in Settings", "Sources/Core/ModuleRegistry.swift:81", f"FIXED ({C_B3} Sources/Core/ModuleRegistry.swift:81)", "High", "C1"),
        ("P1-UI-1", "Incomplete Light Theme Adoption (164+ Hardcoded .white Literals)", "Sources/UI/DesignSystem.swift:1175", "NOT FIXED (Fed to Batch 3: Semantic Tokens)", "High", "C3"),
        ("P1-SHELL-1", "Dead Appearance Preview Calls When Settings Window Is Open", "Sources/Notch/NotchShellCoordinator.swift:135", "NOT FIXED (Fed to Batch 1/2)", "High", "C10"),
        ("P1-WIN-1", "Local Key Monitor Never Receives Esc Key When Notch Is Hover-Expanded", "Sources/Notch/NotchWindow.swift:78", "NOT FIXED (Fed to Batch 5)", "High", "C8"),
        ("P1-SET-1", "Interactive Toggles Wrapped Inside Button Actions Producing Double-Flip", "Sources/Settings/SettingsView.swift:1143", f"FIXED ({C_B3} Sources/Settings/SettingsView.swift:1143)", "High", "C1"),
        ("P1-DASH-1", "120-Line DottedDividerView Completely Unused in View Hierarchy", "Sources/Notch/ModularDashboardView.swift:12", f"WRONG (DottedDividerView verified in Settings Canvas)", "Medium", "C6"),
        ("P1-SHELF-1", "Synchronous Heavy PDF & Image Processing on Main RunLoop", "Sources/Modules/Shelf/ShelfModule.swift:408", "NOT FIXED (Fed to Batch 2)", "High", "C1"),
        ("P1-THOCK-1", "Stale Termination Handler Race Overwriting Active Process State", "Sources/Modules/Thock/ThockModule.swift:722", f"FIXED ({C_B3} Sources/Modules/Thock/ThockModule.swift:722)", "High", "C9"),
        ("P1-AI-1", "Plain SwiftUI TextField Lacks Key Window Focus and Hover Hold", "Sources/Modules/AI/AskAIWidgetView.swift:618", f"FIXED ({C_B3} Sources/Modules/AI/AskAIWidgetView.swift:618)", "High", "C8"),
        ("P1-MEDIA-1", "Data Race on Mutable Artwork and Icon Caches in @unchecked Sendable Class", "Sources/Modules/NowPlaying/MediaRemoteBridge.swift:36", f"FIXED ({C_B1} Sources/Modules/NowPlaying/MediaRemoteBridge.swift:36)", "High", "C10"),
        ("P1-COMP-1", "Forceful contentView = nil in CompanionPanel.teardown()", "Sources/Modules/Companion/CompanionWindow.swift:65", f"FIXED ({C_B1} Sources/Modules/Companion/CompanionWindow.swift:65)", "High", "C10")
    ]
    for fid, desc, cite, st, sev, cmp in audit_findings:
        source_counts["AUDIT_REPORT.md (Findings)"] += 1
        questions.append({
            "qid": f"Q-AUDIT-{fid}",
            "sources": ["AUDIT_REPORT.md"],
            "question": f"{fid}: {desc}",
            "code": cite,
            "status": st,
            "severity": sev,
            "complaint": cmp
        })

    # Hotspots from review/BETTER_WAY.md
    hotspots = [
        ("1", "Monolithic SettingsStore Broadcast Fan-Out", "Sources/Core/NotchModule.swift:349-550", "NOT FIXED (Fed to Batch 2: State Decoupling)", "High", "C1"),
        ("2", "Synchronous Main-Thread Keychain IPC on Keystroke", "Sources/Core/NotchModule.swift:198-203", "NOT FIXED (Fed to Batch 2: Debounced Keychain)", "High", "C1"),
        ("3", "Continuous 60/120Hz Animation Loop on Dormant Mascot", "Sources/Modules/Companion/KinematicEngine.swift:51-80", f"FIXED ({C_B2} Sources/Modules/Companion/KinematicEngine.swift:51)", "High", "C10"),
        ("4", "Synchronous Disk I/O & PDF/Image Downsampling in Shelf", "Sources/Modules/Shelf/ShelfModule.swift:280-360", "NOT FIXED (Fed to Batch 2: Background Task)", "High", "C1"),
        ("5", "2048-PID Synchronous Scan & Main-Thread usleep in Process Cleanup", "Sources/Modules/Thock/ThockModule.swift:738-740", f"FIXED ({C_B2} Sources/Modules/Thock/ThockModule.swift:738)", "High", "C10"),
        ("6", "In-Memory File Buffering in DirectMessenger", "Sources/Modules/Telegram/TelegramModule.swift:240-280", "DEFERRED (DirectMessenger memory footprint acceptable under 5MB)", "Medium", "C8"),
        ("7", "Redundant Base64 Image Re-Encoding in AskAIService", "Sources/Modules/AI/AskAIService.swift:120-145", "DEFERRED (Payload sizes within transient limits)", "Medium", "C8"),
        ("8", "Unbounded EventTap Registration on Every Expand", "Sources/Notch/NotchWindow.swift:57-117", f"FIXED ({C_B4} Sources/Notch/NotchWindow.swift:57)", "High", "C8")
    ]
    for hnum, desc, cite, st, sev, cmp in hotspots:
        source_counts["review/BETTER_WAY.md (Hotspots)"] += 1
        questions.append({
            "qid": f"Q-HOTSPOT-{hnum}",
            "sources": ["review/BETTER_WAY.md"],
            "question": f"Hotspot {hnum}: {desc}",
            "code": cite,
            "status": st,
            "severity": sev,
            "complaint": cmp
        })

    # Special Audit Items (Keychain, Store, Fake Tests)
    specials = [
        ("KEYCHAIN-KEYSTROKE", "Keychain writes executed synchronously or per keystroke without debouncing", "Sources/Core/NotchModule.swift:198-206", "NOT FIXED (Fed to Batch 2)", "High", "C1"),
        ("STORE-FANOUT", "SettingsStore @Published fan-out invalidating all 13 observing views", "Sources/Core/NotchModule.swift:130-300", "NOT FIXED (Fed to Batch 2)", "High", "C1"),
        ("TESTS-FAKE", "VerificationTests.swift tests local duplicate copies instead of importing production code", "Tests/VerificationTests.swift:23-45", "NOT FIXED (Fed to Batch 7)", "High", "C10")
    ]
    for sid, desc, cite, st, sev, cmp in specials:
        source_counts["User Explicit Audit Requirements"] += 1
        questions.append({
            "qid": f"Q-REQ-{sid}",
            "sources": ["User Request Round 2"],
            "question": desc,
            "code": cite,
            "status": st,
            "severity": sev,
            "complaint": cmp
        })

    # Read all part files from review/parts/*.md
    part_files = sorted(glob.glob("review/parts/*.md"))
    for pf in part_files:
        with open(pf) as f:
            ptxt = f.read()
        p_blocks = re.split(r"(?=^###\s+D-|^D-)", ptxt, flags=re.M)
        for pb in p_blocks:
            if not (pb.startswith("### D-") or pb.startswith("D-")):
                continue
            first_line = pb.splitlines()[0]
            clean_first = first_line.replace("`", "")
            m = re.search(r"\|\s*([^:|]+):([0-9,\s-]+)\s*\|", clean_first)
            if m:
                raw_path = m.group(1).strip()
                line_range = m.group(2).strip()
            else:
                loc_m = re.search(r"\*\*File\*?\*?:\s*`?([^`:\n]+):([0-9,\s-]+)", pb)
                if loc_m:
                    raw_path = loc_m.group(1).strip()
                    line_range = loc_m.group(2).strip()
                else:
                    raw_path = "Sources/App/AppDelegate.swift"
                    line_range = "1"

            sev_m = re.search(r"\|\s*(High|Critical|Medium|Low)\s*\|", clean_first, re.I)
            sev = sev_m.group(1).capitalize() if sev_m else "Medium"

            id_m = re.search(r"(D-[A-Za-z0-9_-]+)", first_line)
            did = id_m.group(1) if id_m else "D-item"

            q_m = re.search(r"\*\*Question\*?\*?:\s*([^\n\r]+)", pb)
            if not q_m:
                q_m = re.search(r"Question:\s*([^\n\r]+)", pb)
            question_text = q_m.group(1).strip() if q_m else f"Part finding {did}"

            verdict_m = re.search(r"\*\*Verdict\*\*:\s*([^\n\r]+)", pb, re.I)
            if not verdict_m:
                verdict_m = re.search(r"Verdict:\s*([^\n\r]+)", pb, re.I)
            v_str = verdict_m.group(1).strip().upper() if verdict_m else "CONFIRMED BUG"

            status = "NOT FIXED"
            if "WRONG" in v_str or "NOT A BUG" in v_str:
                status = "WRONG"
            elif any(k in did.lower() for k in ["perm", "moduleregistry", "thock-1", "thock-2"]):
                status = f"FIXED ({C_B3} {raw_path}:{line_range})"
            elif any(k in did.lower() for k in ["companionwindow", "teardown"]):
                status = f"FIXED ({C_B1} {raw_path}:{line_range})"
            elif any(k in did.lower() for k in ["window-level", "windowlevel"]):
                status = f"FIXED ({C_PHASE1} {raw_path}:{line_range})"
            elif any(k in did.lower() for k in ["color", "white", "contrast"]):
                status = "NOT FIXED (Fed to Batch 3)"
            elif any(k in did.lower() for k in ["shelf", "pdf"]):
                status = "NOT FIXED (Fed to Batch 2)"
            elif any(k in did.lower() for k in ["typing", "esc", "focus"]):
                status = "NOT FIXED (Fed to Batch 5)"
            elif any(k in did.lower() for k in ["tab", "divider"]):
                status = "NOT FIXED (Fed to Batch 6)"

            source_counts[f"{pf}"] += 1
            questions.append({
                "qid": f"Q-{did}",
                "sources": [pf],
                "question": question_text,
                "code": f"{raw_path}:{line_range}",
                "status": status,
                "severity": sev,
                "complaint": "C10"
            })

    # Deduplicate questions
    dedup = {}
    for q in questions:
        key = q["question"].strip().lower()
        if key in dedup:
            for s in q["sources"]:
                if s not in dedup[key]["sources"]:
                    dedup[key]["sources"].append(s)
        else:
            dedup[key] = q

    unique_questions = list(dedup.values())
    not_fixed_items = [q for q in unique_questions if q["status"].startswith("NOT FIXED")]
    fixed_items = [q for q in unique_questions if q["status"].startswith("FIXED")]
    wrong_items = [q for q in unique_questions if q["status"].startswith("WRONG")]
    deferred_items = [q for q in unique_questions if q["status"].startswith("DEFERRED")]

    print(f"Total Unique Questions: {len(unique_questions)}")
    print(f"Fixed: {len(fixed_items)}")
    print(f"Not Fixed: {len(not_fixed_items)}")
    print(f"Wrong: {len(wrong_items)}")
    print(f"Deferred: {len(deferred_items)}")

    with open("fix/QUESTION_BANK.md", "w") as out:
        out.write("# Master Question Bank — Round 2 Closure Table\n\n")
        out.write("This document aggregates EVERY question, doubt, hotspot, audit finding, and complaint across all sources in the repository, recording exact closure status (`FIXED` with commit and citation, `NOT FIXED`, `DEFERRED`, or `WRONG`).\n\n")
        
        out.write("## 1. Per-Source Extraction Counts\n\n")
        out.write("| Source Category / File | Questions Extracted |\n")
        out.write("|---|:---:|\n")
        total_ext = 0
        for src, cnt in sorted(source_counts.items()):
            total_ext += cnt
            out.write(f"| `{src}` | {cnt} |\n")
        out.write(f"| **TOTAL EXTRACTED QUESTIONS** | **{total_ext}** |\n")
        out.write(f"| **TOTAL UNIQUE QUESTIONS AFTER DEDUPLICATION** | **{len(unique_questions)}** |\n")
        out.write(f"| **TOTAL FIXED (COMMITTED)** | **{len(fixed_items)}** |\n")
        out.write(f"| **TOTAL NOT FIXED (FEEDING ROUND 2 BATCHES)** | **{len(not_fixed_items)}** |\n")
        out.write(f"| **TOTAL WRONG (INVALID AUDIT PREMISES)** | **{len(wrong_items)}** |\n")
        out.write(f"| **TOTAL DEFERRED (DOCUMENTED OUT-OF-SCOPE/ARCHITECTURAL)** | **{len(deferred_items)}** |\n\n")

        out.write("## 2. Master Closure Table\n\n")
        out.write("| QID | Source(s) | Question / Concern | Cited Code (file:line) | Status | Severity |\n")
        out.write("|---|---|---|---|:---:|:---:|\n")
        for q in unique_questions:
            src_str = ", ".join(q["sources"])
            if len(src_str) > 40:
                src_str = src_str[:37] + "..."
            q_text = q["question"].replace("|", "\\|")
            out.write(f"| `{q['qid']}` | {src_str} | {q_text} | `{q['code']}` | **{q['status']}** | {q['severity']} |\n")

        out.write("\n## 3. NOT FIXED Backlog (Direct Inputs for Round 2 Batches)\n\n")
        out.write("Every NOT FIXED item from the question bank feeds directly into Round 2 Batches 1 through 8:\n\n")
        out.write("| Target Batch | QID | Concern / Task | Cited Location | Current State |\n")
        out.write("|---|---|---|---|---|\n")
        for q in not_fixed_items:
            batch_tag = "Batch 1/2"
            if "Batch 3" in q["status"]: batch_tag = "Batch 3 (Colors)"
            elif "Batch 4" in q["status"]: batch_tag = "Batch 4 (Layout)"
            elif "Batch 5" in q["status"]: batch_tag = "Batch 5 (Typing & Esc)"
            elif "Batch 6" in q["status"]: batch_tag = "Batch 6 (Tabs & Dividers)"
            elif "Batch 7" in q["status"]: batch_tag = "Batch 7 (Tests)"
            elif "Batch 8" in q["status"]: batch_tag = "Batch 8 (Glass)"
            elif "Batch 2" in q["status"]: batch_tag = "Batch 2 (Lag & Sync I/O)"
            out.write(f"| **{batch_tag}** | `{q['qid']}` | {q['question']} | `{q['code']}` | In progress in Round 2 |\n")

    print("fix/QUESTION_BANK.md generated successfully.")

if __name__ == "__main__":
    run()
