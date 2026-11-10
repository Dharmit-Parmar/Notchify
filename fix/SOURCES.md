# Question Sources Inventory & Audit Trail

This file catalogs all Markdown sources, confirmed existence of known audit inputs, classifications of extra documents, and forensic checks of review generator scripts.

## 1. Known Audit Input Files Status

| Known File | Exists? | Size (Bytes) | Last Modified | Use It For | Trust Level |
|---|:---:|:---:|:---:|---|---|
| `AUDIT_REPORT.md` | **EXISTS** | 50,667 | 2026-11-10 00:27:56 | main question list | medium: some findings are wrong; coverage claims unverified |
| `review/BETTER_WAY.md` | **EXISTS** | 20,364 | 2026-11-10 00:39:44 | optimisation questions | low: some paths and line ranges do not exist; re-verify each |
| `review/PLAN.md` | **EXISTS** | 4,243 | 2026-11-10 00:20:03 | what was meant to be covered | low |
| `review/SKILLS.md` | **EXISTS** | 8,763 | 2026-11-10 00:24:08 | which skills were really used | info only |
| `review/CODE_REVIEW_DOUBTS.md` | **EXISTS** | 34,254 | 2026-11-10 00:44:56 | connection and doubtful patterns | medium: contains full 544 doubts synthesis |
| `review/CONNECTIONS.md` | **EXISTS** | 17,796 | 2026-11-10 00:36:03 | connection-level questions | medium: static cross-module review |
| `review/GLOBAL.md` | **EXISTS** | 17,309 | 2026-11-10 00:37:50 | global lifecycle bugs | medium: traced flows with sequence diagrams |
| `review/HIDDEN_EDGES.md` | **EXISTS** | 40,176 | 2026-11-10 00:19:06 | implicit coupling map | medium: grep extracted |
| `review/INVENTORY.md` | **EXISTS** | 7,523 | 2026-11-10 00:19:40 | coverage tracking | high |
| `SECURITY_AUDIT_REPORT.md` | **MISSING** | - | - | security questions | low (self-graded) |
| `GITHUB_SECURITY_AND_SENSITIVE_DATA_AUDIT.md` | **EXISTS** | 9,161 | 2026-11-06 16:00:18 | security questions | low (self-graded) |
| `CREATURE_ANALYSIS.md` | **EXISTS** | 42,064 | 2026-11-04 01:22:12 | mascot questions | low: later reports contradict some claims |
| `CREATURE_ANALYSIS_PART2_FIXES.md` | **EXISTS** | 5,433 | 2026-11-04 01:53:17 | mascot claims | low: unverified |
| `CREATURE_ANALYSIS_PART3.md` | **MISSING** | - | - | mascot questions | low |
| `NOTCHIFY_DESIGN_PROPOSAL.md` | **MISSING** | - | - | design intent and items never built | intent only |
| `DESIGN_LOG.md` | **EXISTS** | 52,732 | 2026-11-07 22:57:31 | claims to verify | low: unverified |
| `FEATURE_MATRIX.md` | **EXISTS** | 8,924 | 2026-11-07 21:11:00 | claims to verify | low: unverified |
| `REPORT.md` | **EXISTS** | 16,074 | 2026-11-07 21:11:00 | claims to verify | low: unverified |
| `README.md` | **EXISTS** | 13,818 | 2026-11-07 22:57:11 | claims to verify | low: unverified |

## 2. All Markdown Files under Repo Root & `review/`

| Path | Size (Bytes) | Last Modified | Classification / Category |
|---|:---:|:---:|---|
| `AUDIT_REPORT.md` | 50,667 | 2026-11-10 00:27:56 | KNOWN AUDIT SOURCE |
| `CODEBASE_ANALYSIS_REPORT.md` | 14,458 | 2026-11-06 15:59:48 | CLAIMS (High-level architecture overview claiming production-readiness & 74/74 tests passing) |
| `CREATURE_ANALYSIS.md` | 42,064 | 2026-11-04 01:22:12 | KNOWN AUDIT SOURCE |
| `CREATURE_ANALYSIS_PART2_FIXES.md` | 5,433 | 2026-11-04 01:53:17 | KNOWN AUDIT SOURCE |
| `CREATURE_RIGIDITY_AND_SETTINGS_ANALYSIS.md` | 42,624 | 2026-11-04 03:50:01 | QUESTIONS (Forensic defect audit of creature rigidity, peeking, and settings) |
| `DESIGN_LOG.md` | 52,732 | 2026-11-07 22:57:31 | KNOWN AUDIT SOURCE |
| `FEATURE_MATRIX.md` | 8,924 | 2026-11-07 21:11:00 | KNOWN AUDIT SOURCE |
| `GITHUB_SECURITY_AND_SENSITIVE_DATA_AUDIT.md` | 9,161 | 2026-11-06 16:00:18 | KNOWN AUDIT SOURCE |
| `NOTCH_CARTOON_FEATURE.md` | 9,724 | 2026-11-01 22:27:19 | PLAN (Feature spec & architectural vision for cartoon companion) |
| `NOTCH_CREATURE_MVP.md` | 12,419 | 2026-11-01 18:56:20 | PLAN (Earlier MVP specification for Notchy companion) |
| `README.md` | 13,818 | 2026-11-07 22:57:11 | KNOWN AUDIT SOURCE |
| `REPORT.md` | 16,074 | 2026-11-07 21:11:00 | KNOWN AUDIT SOURCE |
| `review/BETTER_WAY.md` | 20,364 | 2026-11-10 00:39:44 | KNOWN AUDIT SOURCE |
| `review/CODE_REVIEW_DOUBTS.md` | 34,254 | 2026-11-10 00:44:56 | KNOWN AUDIT SOURCE |
| `review/CONNECTIONS.md` | 17,796 | 2026-11-10 00:36:03 | KNOWN AUDIT SOURCE |
| `review/GLOBAL.md` | 17,309 | 2026-11-10 00:37:50 | KNOWN AUDIT SOURCE |
| `review/HIDDEN_EDGES.md` | 40,176 | 2026-11-10 00:19:06 | KNOWN AUDIT SOURCE |
| `review/INVENTORY.md` | 7,523 | 2026-11-10 00:19:40 | KNOWN AUDIT SOURCE |
| `review/PLAN.md` | 4,243 | 2026-11-10 00:20:03 | KNOWN AUDIT SOURCE |
| `review/SKILLS.md` | 8,763 | 2026-11-10 00:24:08 | KNOWN AUDIT SOURCE |
| `review/parts/ai-service.md` | 33,866 | 2026-11-10 00:31:07 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/ai-widget-part1.md` | 22,810 | 2026-11-10 00:28:45 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/ai-widget-part2.md` | 37,086 | 2026-11-10 00:30:48 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/app-coresecurity.md` | 44,070 | 2026-11-10 00:33:25 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/calendar-clock.md` | 25,516 | 2026-11-10 00:30:46 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/companion-coordinator.md` | 37,227 | 2026-11-10 00:29:11 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/companion-engine-part1.md` | 15,148 | 2026-11-10 00:31:13 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/companion-engine-part2.md` | 30,416 | 2026-11-10 00:32:25 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/companion-rig-part1.md` | 27,250 | 2026-11-10 00:30:52 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/companion-rig-part2.md` | 37,740 | 2026-11-10 00:31:46 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/companion-window-types.md` | 37,190 | 2026-11-10 00:32:04 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/core-moduleregistry.md` | 17,411 | 2026-11-10 00:30:23 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/core-settingsstore.md` | 33,692 | 2026-11-10 00:28:47 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/dashboardsettings-part1.md` | 33,102 | 2026-11-10 00:30:57 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/dashboardsettings-part2.md` | 34,213 | 2026-11-10 00:30:02 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/designsystem-part1.md` | 30,399 | 2026-11-10 00:30:12 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/designsystem-part2.md` | 33,707 | 2026-11-10 00:31:46 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/mirror.md` | 27,476 | 2026-11-10 00:31:12 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/notch-window-dashboard.md` | 28,802 | 2026-11-10 00:31:22 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/notchrootview-part1.md` | 24,308 | 2026-11-10 00:29:58 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/notchrootview-part2.md` | 38,065 | 2026-11-11 00:51:52 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/notchshellcoordinator.md` | 34,217 | 2026-11-10 00:30:07 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/notes-part1.md` | 32,163 | 2026-11-10 00:31:20 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/notes-part2.md` | 33,988 | 2026-11-10 00:29:50 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/nowplaying.md` | 38,766 | 2026-11-10 00:31:47 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/peripheral-modules.md` | 37,888 | 2026-11-10 00:32:03 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/settingsview-part1.md` | 33,447 | 2026-11-10 00:30:22 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/settingsview-part2.md` | 30,536 | 2026-11-10 00:30:50 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/settingsview-part3.md` | 29,618 | 2026-11-10 00:34:16 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/shelf-part1.md` | 31,775 | 2026-11-10 00:30:53 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/shelf-part2.md` | 42,217 | 2026-11-10 00:30:53 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/telegram-part1.md` | 34,875 | 2026-11-10 00:30:34 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/telegram-part2.md` | 29,650 | 2026-11-10 00:29:48 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/tests-coverage.md` | 34,901 | 2026-11-10 00:30:26 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/thock-part1.md` | 24,113 | 2026-11-10 00:29:54 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |
| `review/parts/thock-part2.md` | 33,021 | 2026-11-10 00:30:49 | RAW SUB-AGENT AUDIT PART (LONG-TAIL QUESTIONS) |

## 3. Review Generator Scripts Audit (`review/scratch/*.py`)

Per instructions, all generator scripts were inspected to detect whether finding text was hardcoded/templated instead of dynamically read from code:

### `review/scratch/build_better_way.py` (3 Hardcoded Finding Lines)
- **Trust:** DO NOT TRUST OUTPUT DIRECTLY. Findings were embedded as literal strings in the generator script:
  - Line 147: `## Hotspot 5: 2048-PID Synchronous Scan & Main-Thread usleep in Process Cleanup`
  - Line 151: `- **Problem**: `sweepOrphanProcesses()` executes a sequential loop from PID 1 to 2048 call`
  - Line 162: `Delete the entire 2048 PID iteration loop and the `usleep` calls.`

### `review/scratch/build_connections.py` (41 Hardcoded Finding Lines)
- **Trust:** DO NOT TRUST OUTPUT DIRECTLY. Findings were embedded as literal strings in the generator script:
  - Line 9: `"TelegramModule() and NotificationModule() use fresh instances `factory: { TelegramModule(`
  - Line 11: `("AppDelegate -> ThockModule", "Direct calls `.sweepOrphanProcesses()` and `.terminateProc`
  - Line 13: `"`sweepOrphanProcesses()` runs synchronous POSIX syscalls on @MainActor during launch; if `
  - Line 17: `"Changing dimensions while notch is collapsed updates panel frame with animated:false but `
  - Line 21: `"NotchPanel floats permanently ABOVE the Settings window; expanded notch occludes preferen`
  - Line 25: `"Timing function mismatch: NotchShellCoordinator uses SwiftUI `.spring()`, but NotchWindow`
  - Line 29: `"50 @Published properties on SettingsStore trigger coordinator evaluations and re-renders `
  - Line 33: `"Duplicate teardown: coordinator calls stop in `state.didSet` AND repeats the exact same 4`
  - Line 37: `"Performs synchronous POSIX file write on the main thread during high-frequency collapse a`
  - Line 41: `"`resumeIfViewed()` is inert dead code because `release()` on collapse always sets viewers`
  - ... and 31 more lines.

### `review/scratch/build_global.py` (5 Hardcoded Finding Lines)
- **Trust:** DO NOT TRUST OUTPUT DIRECTLY. Findings were embedded as literal strings in the generator script:
  - Line 26: `- Line 38: Calls `ThockModule.sweepOrphanProcesses()`. This scans all 2048 system PIDs on `
  - Line 34: `- `ThockModule.shared.terminateProcess()`: Line 286 runs synchronous `usleep(5_000)` busy-`
  - Line 41: `- **Cross-Module Defect**: `AppDelegate.performCleanShutdown()` never calls `ModuleRegistr`
  - Line 60: `AppDel->>Thock: sweepOrphanProcesses() (MainActor PID scan)`
  - Line 204: `- Line 739: `setpgid(childPid, childPid)` called after `proc.run()` always fails with `EAC`

### `review/scratch/build_hidden_edges.py` (0 Hardcoded Finding Lines)
- *Clean: No hardcoded finding text detected. Pure dynamic parser/collector.*

### `review/scratch/build_inventory.py` (0 Hardcoded Finding Lines)
- *Clean: No hardcoded finding text detected. Pure dynamic parser/collector.*

### `review/scratch/build_master_report.py` (16 Hardcoded Finding Lines)
- **Trust:** DO NOT TRUST OUTPUT DIRECTLY. Findings were embedded as literal strings in the generator script:
  - Line 67: `v_str = verdict_m.group(1).strip() if verdict_m else "CONFIRMED BUG"`
  - Line 143: `2. **Synchronous Main-Thread IPC & Disk I/O**: The main run loop is repeatedly stalled by `
  - Line 145: `4. **Hardware & Subprocess Leaks**: The camera preview layer lacks `dismantleNSView` and i`
  - Line 195: `### 1. Window Level & Layering Deadlock`
  - Line 217: `- **Root Cause**: `posix_spawn` is invoked without setting `posix_spawnattr_setpgroup`. Li`
  - Line 218: `- **Blast Radius**: `thock-cli` fails to detach into an independent process group. Further`
  - Line 220: `### 6. Camera Session Hardware LED Leak & User Intent Wipe`
  - Line 235: `### 9. Appearance Propagation Preview Dead Code`
  - Line 240: `### 10. Destructive Test Suite Clobbering Production User Data`
  - Line 255: `### 13. Incomplete Application Shutdown Leaking Secondary Modules`
  - ... and 6 more lines.

### `review/scratch/extract_hidden_edges.py` (0 Hardcoded Finding Lines)
- *Clean: No hardcoded finding text detected. Pure dynamic parser/collector.*

