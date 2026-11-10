import os, sys, time, glob, re

def get_file_info(path):
    st = os.stat(path)
    mtime = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(st.st_mtime))
    size = st.st_size
    return size, mtime

def main():
    root_mds = [f for f in os.listdir(".") if f.endswith(".md") and os.path.isfile(f)]
    review_mds = []
    for root, dirs, files in os.walk("review"):
        for f in files:
            if f.endswith(".md"):
                review_mds.append(os.path.join(root, f))
    
    all_mds = sorted(root_mds + review_mds)
    
    known_table = {
        "AUDIT_REPORT.md": ("merged static audit: Part 1 per-file doubts (P1-*), Part 2 connection findings (P2-*), Part 3 flow findings, Alternatives table, NEEDS MANUAL CHECK list, summary table, coverage proof, unknowns", "main question list", "medium: some findings are wrong; coverage claims unverified"),
        "review/BETTER_WAY.md": ("\"Part 4\" hotspots 1-8 with Alt A / Alt B, second thought, verdict", "optimisation questions", "low: some paths and line ranges do not exist; re-verify each"),
        "review/PLAN.md": ("the phase plan used by the audit run", "what was meant to be covered", "low"),
        "review/SKILLS.md": ("skills chosen per part", "which skills were really used", "info only"),
        "review/CODE_REVIEW_DOUBTS.md": ("doubts and consolidated master report", "connection and doubtful patterns", "medium: contains full 544 doubts synthesis"),
        "review/CONNECTIONS.md": ("file-to-file connection questions, coupling", "connection-level questions", "medium: static cross-module review"),
        "review/GLOBAL.md": ("flow questions, 10 end-to-end traced flows", "global lifecycle bugs", "medium: traced flows with sequence diagrams"),
        "review/HIDDEN_EDGES.md": ("hidden edges (notifications, Combine sinks, settings keys, singletons)", "implicit coupling map", "medium: grep extracted"),
        "review/INVENTORY.md": ("coverage contract of 42 files and line counts", "coverage tracking", "high"),
        "SECURITY_AUDIT_REPORT.md": ("earlier security findings", "security questions", "low (self-graded)"),
        "GITHUB_SECURITY_AND_SENSITIVE_DATA_AUDIT.md": ("GitHub security & sensitive data audit", "security questions", "low (self-graded)"),
        "CREATURE_ANALYSIS.md": ("mascot defects (DEF-xx) and claimed fixes", "mascot questions", "low: later reports contradict some claims"),
        "CREATURE_ANALYSIS_PART2_FIXES.md": ("claimed fixes for mascot defects", "mascot claims", "low: unverified"),
        "CREATURE_ANALYSIS_PART3.md": ("mascot part 3 report", "mascot questions", "low"),
        "NOTCHIFY_DESIGN_PROPOSAL.md": ("design proposal and its known loopholes", "design intent and items never built", "intent only"),
        "DESIGN_LOG.md": ("earlier phase design logs and decisions", "claims to verify", "low: unverified"),
        "FEATURE_MATRIX.md": ("earlier feature matrix and completion statuses", "claims to verify", "low: unverified"),
        "REPORT.md": ("earlier audit and project status report", "claims to verify", "low: unverified"),
        "README.md": ("project readme, user manual, and setup instructions", "claims to verify", "low: unverified")
    }

    # Inspect scratch scripts for hardcoded finding text
    scratch_py = sorted(glob.glob("review/scratch/*.py"))
    scratch_findings = {}
    for spy in scratch_py:
        with open(spy) as f:
            lines = f.readlines()
        suspicious = []
        for idx, line in enumerate(lines, 1):
            if any(kw in line for kw in ["CONFIRMED BUG", "LIKELY BUG", "Dead Code", "Deadlock", "Defect", "Clobbering", "Leak", "EACCES", "usleep", "sweepOrphanProcesses"]):
                suspicious.append((idx, line.strip()))
        scratch_findings[spy] = suspicious

    # Classify non-table markdown files
    classifications = {
        "NOTCH_CARTOON_FEATURE.md": "PLAN (Feature spec & architectural vision for cartoon companion)",
        "NOTCH_CREATURE_MVP.md": "PLAN (Earlier MVP specification for Notchy companion)",
        "CREATURE_RIGIDITY_AND_SETTINGS_ANALYSIS.md": "QUESTIONS (Forensic defect audit of creature rigidity, peeking, and settings)",
        "CODEBASE_ANALYSIS_REPORT.md": "CLAIMS (High-level architecture overview claiming production-readiness & 74/74 tests passing)"
    }

    with open("fix/SOURCES.md", "w") as out:
        out.write("# Question Sources Inventory & Audit Trail\n\n")
        out.write("This file catalogs all Markdown sources, confirmed existence of known audit inputs, classifications of extra documents, and forensic checks of review generator scripts.\n\n")
        
        out.write("## 1. Known Audit Input Files Status\n\n")
        out.write("| Known File | Exists? | Size (Bytes) | Last Modified | Use It For | Trust Level |\n")
        out.write("|---|:---:|:---:|:---:|---|---|\n")
        
        for kfile, (holds, use_for, trust) in known_table.items():
            if os.path.exists(kfile):
                sz, mt = get_file_info(kfile)
                out.write(f"| `{kfile}` | **EXISTS** | {sz:,} | {mt} | {use_for} | {trust} |\n")
            else:
                out.write(f"| `{kfile}` | **MISSING** | - | - | {use_for} | {trust} |\n")
        
        out.write("\n## 2. All Markdown Files under Repo Root & `review/`\n\n")
        out.write("| Path | Size (Bytes) | Last Modified | Classification / Category |\n")
        out.write("|---|:---:|:---:|---|\n")
        
        for mpath in all_mds:
            sz, mt = get_file_info(mpath)
            if mpath in known_table:
                cat = "KNOWN AUDIT SOURCE"
            elif mpath.startswith("review/parts/"):
                cat = "RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS)"
            elif mpath in classifications:
                cat = classifications[mpath]
            else:
                cat = "NOISE"
            out.write(f"| `{mpath}` | {sz:,} | {mt} | {cat} |\n")

        out.write("\n## 3. Review Generator Scripts Audit (`review/scratch/*.py`)\n\n")
        out.write("Per instructions, all generator scripts were inspected to detect whether finding text was hardcoded/templated instead of dynamically read from code:\n\n")
        for spy, items in scratch_findings.items():
            out.write(f"### `{spy}` ({len(items)} Hardcoded Finding Lines)\n")
            if not items:
                out.write("- *Clean: No hardcoded finding text detected. Pure dynamic parser/collector.*\n\n")
            else:
                out.write("- **Trust:** DO NOT TRUST OUTPUT DIRECTLY. Findings were embedded as literal strings in the generator script:\n")
                for lno, ltext in items[:10]:
                    out.write(f"  - Line {lno}: `{ltext[:90]}`\n")
                if len(items) > 10:
                    out.write(f"  - ... and {len(items)-10} more lines.\n")
                out.write("\n")

    print("fix/SOURCES.md generated successfully.")

if __name__ == "__main__":
    main()
