# Phase 1 Execution Plan: Root-Cause Batching & Interference Matrix

**Architecture Contract:** Model-agnostic reliability, ponytail minimalism, keep-and-guard, strict zero-regression enforcement.  
**Execution Strategy:** Phase 0 & 1 execute without pause. Then execute **Batch B1** and **Batch B2** and **STOP** for manual user verification.

---

## 1. Lag Analysis from Code (Addressing C1 & C10)

By analyzing the static code paths without executing the app, we identified the exact mechanisms producing lag, beachballs, and high idle CPU:

| Mechanism | Code Location | What Runs at Runtime | Frequency / Cost | Reasoned Impact |
|---|---|---|---|---|
| **Monolithic Store Invalidation** | `NotchModule.swift:349-550` | Modifying any `@Published` property triggers `objectWillChange` across all subscribers. | Up to 120Hz during slider drag / hover | Full SwiftUI tree re-diffing across `NotchRootView`, `SettingsView`, and `NotchWindow`. |
| **Continuous Rig Ticking** | `CreatureRigView.swift:20-120` | `TimelineView(.animation)` ticks continuously computing IK joints, eye blinks, and breathing curves even when creature is sleeping or notch is collapsed. | 60–120 fps continuous | Burns CPU/GPU cycles and prevents CPU cores from entering deep C-states. |
| **Sub-Pixel Continuous Hover** | `NotchRootView.swift:180-195` | `.onContinuousHover` executes coordinate checks and resets watchdog timers on every sub-pixel pointer motion. | Unthrottled mouse motion | Dispatches main-actor run loop tasks repeatedly during cursor movement. |
| **Main-Thread Keychain IPC** | `KeychainHelper.swift:30`, `NotchModule.swift:198` | Keystroke in `SecureField` calls synchronous `SecItemDelete` and `SecItemAdd` via Mach messaging to `securityd`. | Per keystroke (40+ times per key entry) | 2ms–50ms main-thread freezes per character typed. |
| **Launch Process Table Sweep** | `AppDelegate.swift:38`, `ThockModule.swift:738` | `sweepOrphanProcesses()` iterates PIDs 1 to 2048 calling `proc_pidinfo` and `usleep(20_000)` on `@MainActor`. | Launch & Quit | Stalls app startup and shutdown run loops. |

---

## 2. Interference Matrix (Batch x File x Shared State x Singleton)

| Batch | Target Files | Shared State / Singletons Touched | Potential Collisions with Other Batches | Isolation / Mitigation Rule |
|---|---|---|---|---|
| **B1** | `VerificationTests.swift`, `KeychainHelper.swift`, `MediaRemoteBridge.swift`, `CompanionWindow.swift`, `NotchModule.swift` | `UserDefaults.standard`, `KeychainHelper.shared`, `MediaRemoteBridge.shared`, `CompanionPanel` | B2 touches `SettingsStore`; B6 touches `VerificationTests.swift`. | Isolate Keychain & Tests in B1. Do not touch UI views in B1. |
| **B2** | `NotchModule.swift`, `CreatureRigView.swift`, `NotchRootView.swift`, `ThockModule.swift` | `SettingsStore.shared`, `KinematicEngine.shared`, `NotchShellCoordinator.shared` | B3 touches `ThockModule` lifecycle; B4 touches `NotchRootView` colors. | Split high-frequency state from `SettingsStore`. Gate TimelineView when sleeping. |
| **B3** | `ModuleRegistry.swift`, `SettingsView.swift`, `NotesWidgetView.swift`, `AskAIWidgetView.swift`, `ThockModule.swift` | `ModuleRegistry.shared`, `ThockModule.shared`, `@FocusState` | B4 touches `SettingsView` layout; B5 touches `ModuleRegistry` reordering. | Introduce `allOrderedModules` and reusable `SettingsToggleRow`. Guard Thock generation. |
| **B4** | `DesignSystem.swift`, `NotchWindow.swift`, `SettingsView.swift`, `AppDelegate.swift`, `EnvironmentState.swift` | `DesignSystem`, `NotchPanel.level`, `SettingsWindow.level`, `NSApp.activationPolicy` | B5 touches `SettingsView` dashboard canvas. | Update semantic color tokens and window levels. Dynamic regular/accessory policy. |
| **B5** | `ModularDashboardView.swift`, `DashboardSettingsView.swift`, `NotchRootView.swift` | `DottedDividerView`, `UniversalTabDropDelegate`, `DraggableTabChip` | B2 touched `NotchRootView` hover; B3 touched tab ordering. | Restrict draggable dividers exclusively to Settings Canvas; tab drag-to-reorder in dock. |
| **B6** | `PermissionsHelper.swift`, `VerificationTests.swift`, `ShelfModule.swift` | `FileManager`, `ModuleRegistry.shared.stopAll()` | Clean closeout of all remaining long-tail items. | Final dead code elimination and integration tests. |

---

## 3. Detailed Batch Breakdown

### Batch B1: Data and Crash Safety
- **Aim**: Ensure tests never corrupt real user data, eliminate synchronous Keychain freezes, eliminate data races in MediaRemote caching, and prevent `EXC_BAD_ACCESS` in companion window deallocation.
- **Root Causes**:
  - `VerificationTests.swift:1242`: Test 44 writes directly to production `UserDefaults.standard` key `NotchApp_QuickNotesText`.
  - `KeychainHelper.swift:30` & `NotchModule.swift:198-203`: Synchronous `SecItem` calls in `@Published` property observers.
  - `MediaRemoteBridge.swift:36`: Mutable `artworkCache` and `appIconCache` accessed without synchronization in `@unchecked Sendable` class.
  - `CompanionWindow.swift:90`: Forceful `self.contentView = nil` in `CompanionPanel.teardown()` triggers AppKit memory faults (proven by commit `5682c6b`).
- **Complaints Addressed**: C10, C1.
- **Smallest Fix**:
  1. Sandbox Test 44 to use `UserDefaults(suiteName: "NotchifyTests")`.
  2. In `KeychainHelper.swift`, ensure async non-blocking execution or debounced saving. In `SettingsStore`, update local memory state immediately and persist to Keychain asynchronously. Remove deprecated `IOObjectRelease`.
  3. In `MediaRemoteBridge.swift`, guard dictionary cache reads/writes with an internal lock (`os_unfair_lock`).
  4. In `CompanionWindow.swift:90`, remove `self.contentView = nil` from `teardown()`.
- **Second Thoughts**:
  - *Keychain async write*: If app terminates immediately after key entry, ensure in-memory state is flushed or saved on field commit.
  - *CompanionPanel*: Removing `contentView = nil` leaves deallocation to ARC, which is the standard AppKit design pattern.

### Batch B2: Lag & Responsiveness (C1, C10)
- **Aim**: Eliminate app-wide view invalidation fan-out, stop background mascot render loops while dormant, and throttle high-frequency hover tracking.
- **Root Causes**:
  - `SettingsStore`: 50+ `@Published` properties invalidating entire window hierarchies on any slider or toggle update.
  - `CreatureRigView`: Continuous 120Hz `TimelineView` ticking when creature is in `.sleeping` state or notch is collapsed.
  - `NotchRootView`: Sub-pixel `.onContinuousHover` event stream resetting collapse watchdogs at 120Hz.
  - `ThockModule`: 2048-PID synchronous scan during app launch.
- **Complaints Addressed**: C1, C10.
- **Smallest Fix**:
  1. Exploit macOS 14.0+ deployment target: Decompose or decouple high-frequency interaction flags from `SettingsStore`. Keep `SettingsStore.shared` API surface intact to avoid breaking callers, but isolate live interaction state.
  2. In `CreatureRigView.swift`, pause or gate `TimelineView` updates to 1Hz when `companionState == .sleeping` or when notch is collapsed.
  3. In `NotchRootView.swift`, debounce `.onContinuousHover` coordinate checks.
  4. In `ThockModule.swift`, replace 2048 PID iteration with targeted PID lockfile check.
- **Second Thoughts**:
  - *Mascot wake-up*: Transitioning from 1Hz sleep to 120Hz active must be instantaneous on hover. Gate wake event to state transition.

### Batch B3: Correctness (C8, C9)
- **Aim**: Ensure disabled modules remain visible and re-enableable in Settings, prevent toggle double-flips, guarantee keyboard focus for Notes and Ask AI, and ensure Thock child process cleanly manages lifecycle.
- **Root Causes**:
  - `ModuleRegistry.swift:81`: `orderedModules` filters out `!isEnabled`, causing disabled modules to disappear from Settings.
  - `SettingsView.swift:1143`: `Button` wrapping `Toggle` causes double-flip event cancellation.
  - `NotesWidgetView.swift` & `AskAIWidgetView.swift`: Plain SwiftUI editors fail to become AppKit key window first responders; mouse movement triggers notch collapse.
  - `ThockModule.swift:722`: Stale termination handler from previous process run races and overwrites newly spawned engine state; child process not suspended on collapse.
- **Complaints Addressed**: C8, C9, C1.
- **Smallest Fix**:
  1. Add `public var allOrderedModules: [any NotchModule]` in `ModuleRegistry.swift` for Settings.
  2. Implement reusable `SettingsToggleRow` that handles clicking cleanly without double-toggling.
  3. Implement keyboard focus helper and register active text input state in `NotchShellCoordinator` to inhibit auto-collapse while typing.
  4. Add `processGeneration: Int` guard to Thock termination handler; hook `suspendChildProcess()` and `resumeChildProcess()` into notch collapse and expand.
- **Second Thoughts**:
  - *Settings module list*: Keep `orderedModules` for Dock tabs so disabled modules remain hidden from the live dock, while `allOrderedModules` is consumed by Settings.

### Batch B4: Look & Layout (C2–C5)
- **Aim**: Make Sakura/Birch light themes completely readable, eliminate bottom empty space in notch, create visibly distinct glass styles, and make Settings window minimisable without occlusion.
- **Root Causes**:
  - 126+ hardcoded `.foregroundColor(.white)` literals unreadable over light backgrounds.
  - Fixed minimum widths and rigid panel frames in `NotchWindow.swift` causing bottom empty space and border overflows.
  - Glass styles use near-identical `VisualEffectBlur` materials; governor flips glass off silently.
  - `NotchPanel.level = .screenSaver` (1000) permanently floats over `SettingsWindow.level = .statusBar + 1` (26). `.accessory` activation policy traps minimized windows.
- **Complaints Addressed**: C2, C3, C4, C5.
- **Smallest Fix**:
  1. Migrate text/label colors to semantic tokens (`DesignSystem.primaryText`, `secondaryText`, `onAccent`).
  2. Adaptive frame calculation in `NotchWindow.swift` fitting content dynamic height.
  3. Calibrate glass materials with distinct blur/saturation values and show visual indicator if governor reduces effects.
  4. Lower `NotchPanel.level` to `.floating` (level 3); set `SettingsWindow.level = .floating + 1`. Dynamically switch `NSApp.setActivationPolicy(.regular)` while Settings is open to restore Dock icon and enable un-minimizing.
- **Second Thoughts**:
  - *Activation policy*: Switching to `.regular` gives Notchify a Dock icon while Settings is open, allowing users to un-minimize from the Dock. When Settings closes, reverting to `.accessory` returns Notchify to a clean menu bar / island utility.

### Batch B5: Interactions & Dividers (C6, C7)
- **Aim**: Support draggable slot dividers ONLY in Settings Dashboard Canvas (C6); enable direct drag-to-reorder for dock chips in live notch (C7).
- **Root Causes**:
  - `ModularDashboardView.swift`: Live notch currently either lacks dividers or has conflicting audit proposals. `DottedDividerView` was neglected in the Settings canvas.
  - `NotchRootView.swift:450-515`: Dock chips lack native drag-to-reorder handlers with a dedicated UTI.
- **Complaints Addressed**: C6, C7.
- **Smallest Fix**:
  1. C6: Integrate `DottedDividerView` exclusively inside `DashboardSettingsView.swift` canvas with 1/3, 1/2, 2/3 snap points, min width clamp, and double-click reset. Remove draggable dividers from live notch while applying the saved ratio.
  2. C7: Add custom drag payload (`com.notchify.docktab`) to `DraggableTabChip` with `.onDrag` and `.onDrop`, keeping file drops and spring-loaded hover intact.
- **Second Thoughts**:
  - *Drag collisions*: Tab reorder uses UTI `com.notchify.docktab`; file drops check `UTType.fileURL`. Clear UTI segregation prevents file drop handlers from intercepting tab reorders.

### Batch B6: Cleanup and Verification
- **Aim**: Remove remaining dead code, redundant double teardown calls in `NotchShellCoordinator`, safe `/Applications` symlink handling, and unit test coverage against production modules.
- **Smallest Fix**: Clean up redundant calls in `onMouseExit` and `collapseImmediately`; verify clean headless build.

---

## 4. Execution Sequence Checkpoint
Per instructions:
1. Complete Phase 0 and Phase 1.
2. Execute **Batch B1** (Data & Crash Safety).
3. Execute **Batch B2** (Lag & Responsiveness).
4. Run compiler verification and headless tests.
5. Create local git commits on `fix/from-audit`.
6. Write `fix/MANUAL_CHECKS_B1.md` and `fix/MANUAL_CHECKS_B2.md`.
7. **STOP and present manual verification steps to the user.**
