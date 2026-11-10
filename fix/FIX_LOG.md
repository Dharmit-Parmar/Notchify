# Notchify Fix Execution Log

This log documents every batch change, pre-mortem analysis, skill activation, evidence collection, and regression sweep.

---

## Skills Re-Pick Log

| Timestamp | Phase / Batch | Trigger | Skills Added | Skills Retained / Dropped |
|---|---|---|---|---|
| 2026-11-11 00:50 | Phase 0 & 1 Setup | Initial audit & question bank ingestion | `ponytail`, `gravitas`, `graphify`, `swiftui-pro`, `swiftui-expert-skill`, `swift-concurrency-pro`, `axiom-performance`, `axiom-security`, `axiom-data` | Retained all foundational skills |
| 2026-11-11 01:00 | Batch B1 Execution | Data and crash safety (Keychain, Tests, MediaRemote, CompanionPanel) | `axiom-security`, `axiom-data`, `axiom-concurrency`, `axiom-testing` | Dropped UI-specific styling skills for B1 |
| 2026-11-11 01:15 | Batch B2 Execution | Lag and responsiveness (SettingsStore fan-out, TimelineView, hover) | `axiom-performance`, `axiom-swiftui`, `apple-design`, `emilkowalski-motion` | Retained concurrency & performance |
| 2026-11-11 01:30 | Batch B3 Execution | Correctness (ModuleRegistry, Toggle double-flip, keyboard focus, Thock generation guard) | `axiom-macos`, `axiom-concurrency`, `swift-concurrency-pro`, `swiftui-pro`, `axiom-swiftui` | Retained all previous skills |
| 2026-11-11 01:45 | Batch B4 Execution | Look and layout (Panel clipping, adaptive height, light theme contrast, distinct glass, window leveling) | `axiom-design`, `axiom-accessibility`, `apple-design`, `axiom-macos` | Retained design & macOS windowing |
| 2026-11-11 02:00 | Batch B5 Execution | Interactions (Slot dividers restricted to Settings canvas, direct dock tab reordering) | `apple-design`, `emilkowalski-motion`, `axiom-swiftui`, `swiftui-pro` | Retained UI gesture & animation skills |
| 2026-11-11 02:15 | Batch B6 Execution | Cleanup & proposals (Redundant teardown removal, permissions symlink safety) | `ponytail`, `axiom-performance`, `axiom-security`, `axiom-testing` | Retained all testing & safety skills |

---

## Batch B1 Entry: Data & Crash Safety
- **Batch ID:** B1
- **Files Modified:**
  - `Tests/VerificationTests.swift:1240-1249` (Sandboxed Test 44 to isolated `UserDefaults` suite)
  - `Sources/Core/KeychainHelper.swift:28-40` (Added non-blocking `saveSecretAsync`)
  - `Sources/Core/NotchModule.swift:198-206` (Async keychain saving for Gemini, OpenAI, Google Account keys)
  - `Sources/Modules/Telegram/TelegramModule.swift:362` (Async keychain saving for Telegram bot token)
  - `Sources/Modules/NowPlaying/MediaRemoteBridge.swift:36-50, 140-150, 200-210, 260-275` (Added `cacheLock` synchronization)
  - `Sources/Modules/Companion/CompanionWindow.swift:89-91, 154-158` (Removed forceful `self.contentView = nil`)
- **Why:** Prevent test runs from deleting developer notes, prevent keystroke freezes on main thread, prevent data races on concurrent artwork caches, prevent EXC_BAD_ACCESS in AppKit window deallocation.
- **Pre-Mortem Result:** Verified that removing `contentView = nil` safely delegates deallocation to ARC (matching commit `5682c6b`). Verified async keychain write does not lose in-memory credentials.
- **Complaints Addressed:** C10, C1.
- **Evidence File:** `fix/evidence/b1_test_output.txt` (83/83 verification tests passed).

## Batch B2 Entry: Lag & Responsiveness
- **Batch ID:** B2
- **Files Modified:**
  - `Sources/Modules/Companion/CreatureRigView.swift:57-73` (Gated `TimelineView` so dormant mascot in den or sleeping while collapsed does not run at 120Hz)
  - `Sources/App/AppDelegate.swift:37-41` (Offloaded 2048-PID `ThockModule.sweepOrphanProcesses()` to background utility queue)
  - `Sources/Modules/Thock/ThockModule.swift:675-679` (Offloaded `sweepOrphanProcesses()` in `startEngine()` to background utility queue)
- **Why:** Eliminate idle CPU burn and high energy usage while the companion is dormant; prevent launch and engine startup from blocking `@MainActor` with synchronous PID iterations.
- **Pre-Mortem Result:** Verified that wake-up on expand or behavior change restores `.animation` mode without delay. Verified that background orphan sweep cleanly cleans up stale processes without thread contention.
- **Complaints Addressed:** C1 (lag/heavy), C10 (old idle CPU bugs).
- **Evidence File:** `fix/evidence/b2_test_output.txt` (83/83 verification tests passed, 0 compiler errors).

## Batch B3 Entry: Correctness
- **Batch ID:** B3
- **Files Modified:**
  - `Sources/Core/ModuleRegistry.swift:81-105` (Added `allOrderedModules` so disabled modules remain visible in Settings)
  - `Sources/Settings/SettingsView.swift:1156-1216, 1338-1406` (Added `.allowsHitTesting(false)` on inner toggles to prevent double-flip event cancellation; switched module management to `allOrderedModules`)
  - `Sources/Notch/NotchWindow.swift:6-9, 44-98` (Added global Esc monitor so pressing Esc collapses expanded notch reliably)
  - `Sources/Notch/NotchShellCoordinator.swift:33, 125, 194-215, 345-375` (Added `isTypingInWidget` flag inhibiting expanded watchdog and mouse-exit auto-collapse while typing; unblocked appearance preview)
  - `Sources/Modules/Notes/NotesWidgetView.swift:962-985, 1050-1065` (Hooked `isTypingInWidget` to `FocusTextView` and editor coordinator)
  - `Sources/Modules/AI/AskAIWidgetView.swift:18, 30-38, 255, 631, 829, 935` (Hooked `isTypingInWidget` and key window activation to Ask AI text fields)
  - `Sources/Modules/Thock/ThockModule.swift:183, 287, 672-740` (Added `processGeneration` guard so stale process termination handlers cannot overwrite new engine state)
- **Why:** Resolve module vanishing bug in Settings, prevent toggle double-click bugs, guarantee keyboard focus and prevent auto-collapse during text entry, and eliminate Thock process lifecycle races.
- **Pre-Mortem Result:** Verified that `allOrderedModules` does not expose disabled modules to the live dock bar (which still consumes `orderedModules`), verified that global Esc monitoring does not trigger while Settings window is active, and verified that Thock processes terminate cleanly on app shutdown.
- **Complaints Addressed:** C1, C8, C9.
- **Evidence File:** `fix/evidence/b3_test_output.txt` (83/83 verification tests passed, 0 compiler errors).

## Batch B4 Entry: Look & Layout
- **Batch ID:** B4
- **Files Modified:**
  - `Sources/Notch/NotchWindow.swift:28, 137-165` (Lowered `NotchPanel.level` to `.floating`, added adaptive content-height calculation for secondary modules and 1-row dashboards)
  - `Sources/Notch/NotchRootView.swift:70-80` (Added continuous squircle `.clipShape` matching active corner style, preventing any child element overflow)
  - `Sources/UI/DesignSystem.swift:1349-1395` (Calibrated 4 distinct glass styles in `NotchGlassBackground`)
  - `Sources/Settings/SettingsView.swift:420, 531, 618, 2317` (High-contrast theme labels, active badges, and Done button tint for Sakura/Birch)
  - `Sources/App/AppDelegate.swift:195, 229, 243, 260` (Set `SettingsWindow.level = .floating + 1`, dynamically switched activation policy to `.regular` while Settings is open and `.accessory` when closed)
- **Why:** Prevent elements from bleeding outside the notch panel squircle, eliminate giant empty bottom space on compact content, ensure Sakura and Birch light themes are readable, make glass styles visually distinct, and allow Settings window to minimize to the Dock without occlusion.
- **Pre-Mortem Result:** Verified that `.floating + 1` permanently keeps Settings above the notch panel, and switching activation policy restores native Dock minimization behavior while cleanly returning to accessory mode on close.
- **Complaints Addressed:** C2, C3, C4, C5.
- **Evidence File:** `fix/evidence/b4_test_output.txt` (83/83 verification tests passed, 0 compiler errors).

## Batch B5 Entry: Interactions & Dividers
- **Batch ID:** B5
- **Files Modified:**
  - `Sources/Settings/DashboardSettingsView.swift:65-150` (Integrated interactive `DottedDividerView` between adjacent filled slots in Settings Canvas with drag resizing and snap points)
  - `Sources/Notch/NotchRootView.swift:571-665` (Implemented direct tab drag-to-reorder in dock chips with native drag operations, spring animations, and drop completion)
- **Why:** Restrict interactive slot dividers exclusively to Settings -> Dashboard Slots Canvas (C6) while keeping live notch clean and static; enable direct drag-and-drop tab reordering in the live notch dock (C7).
- **Pre-Mortem Result:** Verified that tab reorder drag operations do not intercept or conflict with external file drop operations (UTType.fileURL), and verified that live notch cleanly respects the ratio saved via Settings canvas without exposing drag gestures.
- **Complaints Addressed:** C6, C7.
- **Evidence File:** `fix/evidence/b5_test_output.txt` (83/83 verification tests passed, 0 compiler errors).

## Batch B6 Entry: Cleanup & Verification
- **Batch ID:** B6
- **Files Modified:**
  - `Sources/Notch/NotchShellCoordinator.swift:378-381, 426-429, 448-450` (Removed redundant duplicate teardown calls, establishing `state.didSet` as single source of truth)
  - `Sources/Core/PermissionsHelper.swift:49-65` (Guarded `/Applications` system symlink operations with `fm.isWritableFile` check)
- **Why:** Eliminate double teardown churn on every notch collapse and prevent root-permission filesystem errors.
- **Pre-Mortem Result:** Verified that all module teardown tasks execute exactly once in `state.didSet`, and verified that permissions checks run cleanly without console errors.
- **Complaints Addressed:** C1, C10.
- **Evidence File:** `fix/evidence/b6_test_output.txt` (83/83 verification tests passed, 0 compiler errors).
