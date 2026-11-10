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
