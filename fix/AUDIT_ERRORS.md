# Audit Errors & Misleading Findings Catalog

This document details every finding, claim, path, or line citation from `AUDIT_REPORT.md`, `review/BETTER_WAY.md`, and the review generator scripts that was found to be **WRONG**, **EXAGGERATED**, or **BASED ON HALLUCINATED PATHS** upon reading the actual production code.

---

## 1. Path & Line Citation Errors in `review/BETTER_WAY.md`

| Item in BETTER_WAY.md | Cited Location | Reality in Codebase | Verdict & Error Detail |
|---|---|---|---|
| **Hotspot 6: Media File Streaming** | `Sources/Telegram/DirectMessenger.swift:240-280` | File `DirectMessenger.swift` DOES NOT EXIST. | **WRONG PATH**: `DirectMessenger` is a struct declared inside `Sources/Modules/Telegram/TelegramModule.swift` (line 37). Line range 240-280 in `TelegramModule.swift` is inside `TelegramMessageCell`, not `DirectMessenger`. |
| **Hotspot 7: QuickNotes Parser** | `Sources/Notes/NotesView.swift:70-110` | File `NotesView.swift` DOES NOT EXIST. | **WRONG PATH**: The notes view is named `Sources/Modules/Notes/NotesWidgetView.swift`. |
| **Hotspot 7: Text Re-indexing** | `Sources/Notes/NoteStorageManager.swift:150-185` | `NoteStorageManager.swift` is only 104 lines long! | **WRONG LINE RANGE**: Lines 150-185 do not exist. `NoteStorageManager` has 104 lines total. Text tokenization is in `NotesWidgetView.swift`. |
| **Hotspot 5: Process Cleanup** | `Sources/Thock/ThockModule.swift` | Folder `Sources/Thock/` does not exist. | **WRONG FOLDER**: The actual folder is `Sources/Modules/Thock/ThockModule.swift`. |

---

## 2. Erroneous / Exaggerated Claims in `AUDIT_REPORT.md`

| Finding ID | Audit Claim | Code Reality | Verdict & Correction |
|---|---|---|---|
| **P1-PERM-1** | *"Dangerous Attempted Symlink Deletion in System `/Applications` on Every Launch"* | In `PermissionsHelper.swift:56-60`, `removeItem` is ONLY called if `destinationOfSymbolicLink` succeeds and the destination is stale. It will NEVER remove a directory or regular file. Moreover, `run_notch.sh` already creates `/Applications/NotchApp.app`. | **SEVERELY EXAGGERATED**: Not a destructive vulnerability. It only updates stale symlinks. However, to prevent root permission errors, it should be made silent or restricted to `~/Applications`. |
| **P1-DASH-1** | *"120-Line `DottedDividerView` Completely Unused in View Hierarchy (Dead Code to delete)"* | Audit recommends deleting `DottedDividerView` or adding draggable dividers to the live notch. | **WRONG & CONFLICTS WITH C6**: User complaint C6 explicitly states: *"Slot widths must be adjustable ONLY in Settings -> Dashboard Slots Canvas (dotted draggable dividers between filled slots), NOT in the live notch."* Deleting `DottedDividerView` destroys the required Settings canvas divider! |
| **Zero Warnings Claim** | *"0 compiler warnings across all targets"* | `swift build` produces search path warnings for Command Line Tools. | **PARTLY WRONG**: Build succeeds, but linker warnings and deprecation warnings (`IOObjectRelease`) exist. |
| **Lag Cause Attribution**| *"Shelf PDF work is responsible for general app lag (C1)"* | Shelf PDF compression only runs when a user drops a PDF and clicks compress. It has zero CPU impact during general notch usage or idle states. | **WRONG ROOT CAUSE**: General lag (C1) is caused by: (1) Monolithic `SettingsStore` 50-property `@Published` fan-out; (2) 120Hz `TimelineView` ticking on dormant mascot; (3) Sub-pixel `.onContinuousHover` event stream; (4) Synchronous Keychain IPC on keypress. |

---

## 3. Templated / Hardcoded Finding Text in Review Generator Scripts

The following generator scripts in `review/scratch/` were found to contain hardcoded finding text embedded directly as string literals rather than parsed dynamically from code:

1. **`review/scratch/build_connections.py`**:
   - Lines 9-35: 40 lines of pre-authored defect claims hardcoded into strings (e.g. `sweepOrphanProcesses runs synchronous POSIX syscalls`, `NotchPanel floats permanently ABOVE Settings window`).
2. **`review/scratch/build_global.py`**:
   - Lines 26, 34, 41, 204: Hardcoded text describing cross-module defects (`AppDelegate.performCleanShutdown never calls ModuleRegistry.stopAll()`, `setpgid post-spawn fails with EACCES`).
3. **`review/scratch/build_better_way.py`**:
   - Lines 147-165: Hardcoded problem descriptions and proposed alternatives written directly into python strings.
4. **`review/scratch/build_master_report.py`**:
   - Lines 140-230: Top 15 risks authored as embedded multiline strings.

*Conclusion: Output from generator scripts must never be accepted blindly without verifying against the actual Swift source files.*
