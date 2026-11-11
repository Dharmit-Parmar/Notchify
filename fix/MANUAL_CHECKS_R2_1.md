# Manual Human Checks - Round 2 (Batches 1 & 2)

**Generated:** 2026-11-11  
**Target Branch:** `fix/from-audit`  
**Scope:** Batch 1 (Window Hierarchy, Level Architecture & Non-Overlap) and Batch 2 (Lag, Concurrency, Shelf Background I/O & Keychain Debounce)

---

## 1. Summary of Structural Changes Implemented

| Area / File | Change Details | Verification Reason |
|---|---|---|
| **Window Levels & Collections**<br>`Sources/Notch/NotchWindow.swift` | `NotchPanel.level = .popUpMenu` (101); `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`; `constrainFrameRect` overridden to return unmodified frame rect. | Guarantees notch stays above menu bar and renders over full-screen apps without AppKit pushing it below the menu bar. |
| **Settings Window Behavior**<br>`Sources/App/AppDelegate.swift` | Level `.normal` (0), styleMask `[.titled, .closable, .miniaturizable, .resizable]`. Window collapses notch on focus via `windowDidBecomeKey`. | Preserves standard Mac dock minimization and eliminates notch overlap without lowering the notch island level. |
| **Live Preview Gating**<br>`Sources/Notch/NotchShellCoordinator.swift:117-121` | Added check in `triggerAppearancePropagationPreview()` to block opening the notch when Settings is open (`P1-SHELL-1`). | Prevents unexpected appearance preview expansions while tweaking settings. |
| **Module Draft Preservation**<br>`Sources/Core/ModuleRegistry.swift:417-422` | In `LazyNotchModule.unload()`, stopped discarding `_instance = nil`; now calls `_instance?.stop()` (`P1-APP-1`). | Preserves module drafts, form states, and scroll positions across notch collapses. |
| **Shelf Background I/O & Cancellation**<br>`Sources/Modules/Shelf/ShelfModule.swift:320-726` | Converted `mergeDocuments`, `compressPDF`, `convertToPDF`, and `enhanceDocument` to run off the main actor via `Task.detached` with `AsyncStream` progress reporting and cooperative cancellation (`P1-SHELF-1`). | Offloads 100% of PDF downsampling, image filtering, and file I/O off the main thread; prevents UI freeze during heavy multi-page processing. |
| **Keychain Write Debouncing**<br>`Sources/Core/KeychainHelper.swift:34-47` | Added `pendingSaveTasks: [String: Task<Void, Never>]` to `saveSecretAsync` with 0.50s cancelable Task sleep. | Eliminates synchronous main-thread IPC storms to `securityd` while typing API keys. |
| **Zero-Allocation Dimming Overlay**<br>`Sources/Notch/NotchRootView.swift:80-87` | Replaced whole-view container `.opacity(...)` with composited `Color.black.opacity(0.12)` overlay. | Eliminates offscreen CoreAnimation group render passes over large expanded views. |
| **Settings Redundant Focusables**<br>`Sources/Settings/SettingsView.swift` | Removed duplicate `.focusable()` modifiers from native buttons. | Restores standard macOS keyboard tab navigation and reduces hit-testing overhead. |

---

## 2. Human Verification Test Plan (NEEDS HUMAN CHECK)

Since automated tests cannot interact with the macOS window server or synthetic hardware inputs under the testing contract, follow these step-by-step human verification instructions:

### Test Case 1: Notch Over Menu Bar & Full-Screen Spaces (Batch 1)
- **Goal:** Verify notch stays anchored at the very top bezel without being forced down by AppKit or hidden behind full-screen windows.
- **Steps:**
  1. Build and run the app: `swift run NotchApp`.
  2. Open Safari or another app and toggle Full Screen mode (green window button).
  3. Look at the top center of the display where the hardware notch or camera bezel resides.
  4. Move the mouse to the hardware notch to trigger hover expansion.
- **Expected Outcome:** The collapsed pill sits flush against the top edge of the display bezel. When hovering, it smoothly expands *over* the full-screen Safari title/tab bar without being obscured.
- **What Result Means a Bug:** If the pill renders with a gap below the top bezel or gets hidden behind the full-screen application.

### Test Case 2: Settings Window Minimization & Non-Overlap (Batch 1)
- **Goal:** Verify Settings is a normal standard window that minimizes to the Dock and never collides with the expanded notch.
- **Steps:**
  1. Expand the notch, click the Settings gear icon (or press `Cmd+,`).
  2. Observe the notch: it should smoothly collapse as the Settings window receives focus.
  3. Try hovering over the top notch while the Settings window has focus.
  4. Click the yellow minimize button on the Settings window title bar.
- **Expected Outcome:** The Settings window minimizes smoothly into the macOS Dock. The notch does not expand while Settings is key, preventing visual overlap.
- **What Result Means a Bug:** If the Settings window cannot be minimized to the Dock, or if the notch expands on top of the Settings window while Settings is active.

### Test Case 3: Keychain Asynchronous Debounce (Batch 2)
- **Goal:** Verify typing API keys in Settings does not stutter or hang the UI.
- **Steps:**
  1. In Settings, navigate to the **AI** category.
  2. Focus the API Key text field.
  3. Type rapidly (e.g. 20-30 characters quickly) or paste a long token.
  4. Observe keystroke responsiveness.
- **Expected Outcome:** Every character renders smoothly without lag or beachball cursor. Only one delayed save operation occurs after you stop typing for 0.5s.
- **What Result Means a Bug:** If typing feels sluggish, characters drop, or beachball spinning appears.

### Test Case 4: Shelf Background Compression & Cancellation (Batch 2)
- **Goal:** Verify heavy PDF processing runs asynchronously off the main thread with live progress and cancelability.
- **Steps:**
  1. Hover-expand the notch and navigate to the **Shelf** module.
  2. Drag and drop a multi-page PDF into the staging tray.
  3. Click **Compress PDF** (or rotate the jog wheel to compress).
  4. Immediately observe the notch UI while compression is in progress:
     - The circular or horizontal progress bar smoothly increments from 0% to 100%.
     - You can hover over other items or click the **Cancel** button.
- **Expected Outcome:** UI remains completely fluid at 60/120 fps. If Cancel is clicked, processing halts immediately without crashing or freezing.
- **What Result Means a Bug:** If the notch freezes, mouse hover halts, or progress jumps straight from 0% to 100% without intermediate updates.

### Test Case 5: Module Draft State Retention (Batch 2)
- **Goal:** Verify closing the notch does not wipe uncommitted text in Notes or Shelf staging tray.
- **Steps:**
  1. Expand the notch and navigate to **Notes** or **Shelf**.
  2. Type some text in Notes (or stage a few files in Shelf).
  3. Move the mouse away to allow the notch to auto-collapse.
  4. Move the mouse back to re-expand the notch.
- **Expected Outcome:** All typed text in Notes and all staged files in Shelf remain exactly as left.
- **What Result Means a Bug:** If the module reinitializes to an empty/blank state upon re-expansion.

---

## 3. Metric Claims & Status

- Compilation status: `NotchApp` and `NotchTests` compiled with **0 errors**.
- Headless test suite: **83/83 passed**.
- Claims label: `CONFIRMED-BY-READING` (cites exact source files and line ranges); performance estimates labeled `reasoned, unmeasured`.
