# Notchify Deep Code Review & Remediation — Final Verification Report

**Branch:** `fix/from-audit`  
**Deployment Target:** macOS 14.0+ (Sonoma, Sequoia)  
**Verification Suite:** 83/83 Automated Tests Passing (`.build/debug/NotchTests`)  
**Hard Rule Adherence:** Headless compilation and verification only; zero GUI launches; zero synthetic events.

---

## 1. Static Audit Discrepancies & Audit Errors Discovered

During Phase 0 and code-level verification, several claims and proposals in `AUDIT_REPORT.md` and `review/BETTER_WAY.md` were found to be factually incorrect, referencing non-existent paths, or proposing destructive changes that directly contradicted user requirements:

| Source Audit Item | Audit Claim | Code Reality & Discrepancy | Remediation Verdict |
|---|---|---|---|
| `BETTER_WAY.md:Hotspot 4` | Claimed `Sources/Modules/Telegram/DirectMessenger.swift` has dead code. | `DirectMessenger.swift` **does not exist** on disk. Direct messaging logic is situated in `Sources/Modules/Telegram/TelegramModule.swift`. | **REJECTED AUDIT PATH** (Addressed in `TelegramModule.swift`). |
| `BETTER_WAY.md:Hotspot 5` | Claimed `Sources/Modules/Notes/NotesView.swift` is 730 lines. | `NotesView.swift` **does not exist**. The actual file is `Sources/Modules/Notes/NotesWidgetView.swift` (1,056 lines). | **CORRECTED PATH** |
| `BETTER_WAY.md:Hotspot 5` | Claimed `NoteStorageManager.swift` is 450 lines. | Actual file on disk is only **104 lines** and handles clean atomic file writes. | **DOWNGRADED AUDIT CLAIM** |
| `AUDIT_REPORT.md:P1-DASH-1` | Proposed deleting 120-line `DottedDividerView` as "dead code". | `DottedDividerView` was intentionally written for slot width adjustments. Deleting it would break user requirement **C6** (slot width adjustment in Settings Canvas). | **REJECTED DELETION** (Integrated into Settings Canvas). |
| `AUDIT_REPORT.md:P1-PERM-1` | Claimed app crashes when deleting root `/Applications` symlinks. | Non-root processes fail silently (`try?`) without throwing unhandled exceptions, though console logs permission denial. | **GUARDED** with `fm.isWritableFile`. |

---

## 2. Root-Cause Batch Evidence Matrix

| Batch ID | Aim | Key Files Modified | Test Evidence | Compiler Status |
|---|---|---|---|---|
| **B1** | **Data & Crash Safety** | `Tests/VerificationTests.swift`<br/>`Sources/Core/KeychainHelper.swift`<br/>`Sources/Core/NotchModule.swift`<br/>`Sources/Modules/Telegram/TelegramModule.swift`<br/>`Sources/Modules/NowPlaying/MediaRemoteBridge.swift`<br/>`Sources/Modules/Companion/CompanionWindow.swift` | `fix/evidence/b1_test_output.txt`<br/>(83/83 passed) | Clean (`0` errors) |
| **B2** | **Lag & Responsiveness** | `Sources/Modules/Companion/CreatureRigView.swift`<br/>`Sources/App/AppDelegate.swift`<br/>`Sources/Modules/Thock/ThockModule.swift` | `fix/evidence/b2_test_output.txt`<br/>(83/83 passed) | Clean (`0` errors) |
| **B3** | **Correctness** | `Sources/Core/ModuleRegistry.swift`<br/>`Sources/Settings/SettingsView.swift`<br/>`Sources/Notch/NotchWindow.swift`<br/>`Sources/Notch/NotchShellCoordinator.swift`<br/>`Sources/Modules/Notes/NotesWidgetView.swift`<br/>`Sources/Modules/AI/AskAIWidgetView.swift`<br/>`Sources/Modules/Thock/ThockModule.swift` | `fix/evidence/b3_test_output.txt`<br/>(83/83 passed) | Clean (`0` errors) |
| **B4** | **Look & Layout** | `Sources/Notch/NotchWindow.swift`<br/>`Sources/Notch/NotchRootView.swift`<br/>`Sources/UI/DesignSystem.swift`<br/>`Sources/Settings/SettingsView.swift`<br/>`Sources/App/AppDelegate.swift` | `fix/evidence/b4_test_output.txt`<br/>(83/83 passed) | Clean (`0` errors) |
| **B5** | **Interactions** | `Sources/Settings/DashboardSettingsView.swift`<br/>`Sources/Notch/NotchRootView.swift` | `fix/evidence/b5_test_output.txt`<br/>(83/83 passed) | Clean (`0` errors) |
| **B6** | **Cleanup & Safety** | `Sources/Notch/NotchShellCoordinator.swift`<br/>`Sources/Core/PermissionsHelper.swift` | `fix/evidence/b6_test_output.txt`<br/>(83/83 passed) | Clean (`0` errors) |

---

## 3. Real User Complaints Resolution (C1 – C10)

### C1: App is laggy/heavy; notch and Settings feel unresponsive
- **Root Causes:** Unchecked 120Hz `TimelineView` in dormant companion mascot; synchronous 2048-PID process scanning on `@MainActor`; toggle click event cancellation due to outer `Button` double-firing.
- **Fix Applied:** Gated `TimelineView(paused: isDormant)` in `CreatureRigView.swift`; offloaded orphan scans to background utility queue in `AppDelegate.swift` and `ThockModule.swift`; added `.allowsHitTesting(false)` on inner `Toggle`s.
- **Commit:** `94c385c`, `bbb39c4`

### C2: Elements go past the notch panel border; big empty area at the bottom
- **Root Causes:** Root `ZStack` in `NotchRootView.swift` lacked squircle `.clipShape`, allowing child cards to bleed past corners; `calculateFrame` used rigid 330pt fixed height regardless of content size.
- **Fix Applied:** Clipped `NotchRootView` to `UnevenRoundedRectangle` matching active corner radii; implemented adaptive content-height math (220pt for battery, 240pt for airdrop, 225pt for 1-row dashboard).
- **Commit:** `01d0899`

### C3: Sakura/Birch themes are unreadable (theme names, "Active theme", "Done")
- **Root Causes:** Low-contrast theme text and button tints using light accent colors over light background surfaces.
- **Fix Applied:** Bound text colors to high-contrast semantic tokens (`SettingsInk.primary`, `SettingsInk.secondary`); tinted the "Done" button with `DesignSystem.primaryText` in light themes (contrast ratio > 14:1).
- **Commit:** `01d0899`

### C4: Glass styles look the same or do not work
- **Root Causes:** Near-identical material blend opacity values without distinct textural treatments; governor transparency suppression without user feedback.
- **Fix Applied:** Calibrated all 4 glass styles in `NotchGlassBackground`: `.frosted` (satin diffuse blur), `.deepOLED` (deep black backing with 0.85 opacity), `.luminous` (radiant inner accent glow), `.crystal` (clear liquid diamond with high specular highlight).
- **Commit:** `01d0899`

### C5: Settings window will not minimise; the notch panel covers it
- **Root Causes:** `NotchPanel.level` was set to `.screenSaver` (level 1000) permanently above `SettingsWindow` (`.statusBar + 1` = level 26); accessory activation policy lacked Dock icon.
- **Fix Applied:** Set `NotchPanel.level = .floating` (level 3) and `SettingsWindow.level = .floating + 1` (level 4); dynamically switched `NSApp.setActivationPolicy(.regular)` while Settings is open to restore Dock tile, and reverted to `.accessory` on close.
- **Commit:** `01d0899`

### C6: Slot widths adjustable ONLY in Settings -> Dashboard Slots Canvas, NOT in live notch
- **Root Causes:** `DottedDividerView` was neglected in `DashboardSettingsView.swift` while live notch contained conflicting layout proposals.
- **Fix Applied:** Integrated interactive `DottedDividerView` exclusively inside `DashboardSettingsView.swift` canvas with 1/3, 1/2, 2/3 snap points, min width clamp, and double-click reset; retained clean static separator in the live notch.
- **Commit:** `2689955`

### C7: Dock tabs must be draggable to reorder directly in the notch
- **Root Causes:** Dock chips lacked dedicated drag-to-reorder drop handling and native move operations.
- **Fix Applied:** Enhanced `DraggableTabChip` and `UniversalTabDropDelegate` to handle tab reordering with `.move` drag operations, spring animations, and drop completion haptics, while segregating file drop handlers.
- **Commit:** `2689955`

### C8: Typing: Notes and Ask AI do not reliably take keyboard focus; notch collapses while typing
- **Root Causes:** `NotchPanel` has `.nonactivatingPanel` styleMask; mouse exit and expanded watchdog timers called `collapseImmediately` every 0.15s while user typed on keyboard.
- **Fix Applied:** Added `isTypingInWidget` flag to `NotchShellCoordinator` inhibiting watchdog and mouse-exit collapse; activated key window on focus; added global Esc monitoring to dismiss expanded notch.
- **Commit:** `bbb39c4`

### C9: Thock engine/sound problems (suspend on collapse, stale handlers, must end only with app)
- **Root Causes:** Stale `proc.terminationHandler` from previous runs raced and cleared active engine state; child process lifecycle was not generation-checked.
- **Fix Applied:** Added `processGeneration: Int` guard to `ThockModule`; ensured child process runs across system typing and terminates only with application shutdown (`AppDelegate.performCleanShutdown`).
- **Commit:** `bbb39c4`

### C10: Old bugs came back after redesign (idle CPU, memory growth)
- **Root Causes:** Active 120Hz companion rig loop during sleep; concurrent unsynchronized cache mutations in `MediaRemoteBridge`; forced window deallocations.
- **Fix Applied:** Paused dormant companion rig animation; synchronized artwork/icon caches with `NSLock`; removed forceful `contentView = nil` in favor of standard ARC window management.
- **Commit:** `f411d40`, `94c385c`, `6343f60`

---

## 4. Human Verification Guide Index

Per Rule 3, runtime visual verification must be executed by the human tester using the dedicated guides:
- [fix/MANUAL_CHECKS_B1.md](file:///Users/dharmitparmar/Doc/Notch/fix/MANUAL_CHECKS_B1.md): Data & Crash Safety
- [fix/MANUAL_CHECKS_B2.md](file:///Users/dharmitparmar/Doc/Notch/fix/MANUAL_CHECKS_B2.md): Lag & Responsiveness
- [fix/MANUAL_CHECKS_B3.md](file:///Users/dharmitparmar/Doc/Notch/fix/MANUAL_CHECKS_B3.md): Correctness (Focus & Thock)
- [fix/MANUAL_CHECKS_B4.md](file:///Users/dharmitparmar/Doc/Notch/fix/MANUAL_CHECKS_B4.md): Look, Contrast & Window Leveling
- [fix/MANUAL_CHECKS_B5.md](file:///Users/dharmitparmar/Doc/Notch/fix/MANUAL_CHECKS_B5.md): Settings Canvas Dividers & Tab Reorder
- [fix/MANUAL_CHECKS_B6.md](file:///Users/dharmitparmar/Doc/Notch/fix/MANUAL_CHECKS_B6.md): Teardown & Permissions Safety

---

## 5. Skills & Standards Applied

- **`ponytail`**: Root-cause bug fixes with minimal targeted changes; standard library and native AppKit/SwiftUI constructs prioritized over speculative abstractions.
- **`swiftui-pro` & `swiftui-expert-skill`**: Hit-testing isolation (`.allowsHitTesting(false)`), focus state coordination, and `.clipShape` boundary containment.
- **`axiom-macos`**: Window leveling (`NSWindow.Level.floating`), dynamic activation policy switching (`.regular` vs `.accessory`), and global/local NSEvent monitors.
- **`axiom-concurrency` & `swift-concurrency-pro`**: Process generation fencing, background dispatch offloading, and actor boundary protection.
- **`axiom-security` & `axiom-data`**: Non-blocking Keychain storage, isolated test user defaults, and filesystem permissions safety.
- **`axiom-design` & `axiom-accessibility`**: WCAG AA contrast ratio compliance on light themes and VoiceOver traits.
