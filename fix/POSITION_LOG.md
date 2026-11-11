# Notchify Position & Bezel Integration Execution Log

## Skills Re-Pick Log

| Phase | Trigger | Skills Activated | Rationale |
|---|---|---|---|
| **Phase 0 & 1** | Collapsed notch pill rendering below screen top over Safari address bar; window levels and frame constraints diagnosis | `swiftui-expert-skill`, `axiom-macos`, `apple-design`, `swiftui-pro`, `ponytail`, `gravitas`, `axiom-testing`, `axiom-accessibility`, `axiom-design` | `axiom-macos` for `NSWindow.Level`, `constrainFrameRect`, `collectionBehavior`, and screen geometry; `apple-design` & `axiom-design` for bezel integration, notch inverted corners, and HIG; `ponytail` for minimal surgical fixes; `gravitas` for evidence-backed verification without hallucinated lines; `axiom-testing` for headless frame math test suites. |

---

## Phase 0: Diagnosis Notes

### 1. Window Inventory & B4 Git Diff
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:5-43`): `NotchPanel`
  - `styleMask`: `[.nonactivatingPanel, .borderless]`
  - `collectionBehavior`: `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
  - `level`: `.floating` (level 3) prior to Phase 1.
  - `constrainFrameRect`: NOT overridden prior to Phase 1 (inherited default `NSWindow.constrainFrameRect`).
- **CONFIRMED-BY-READING** (`Sources/Modules/Companion/CompanionWindow.swift:6-35`): `CompanionPanel`
  - `styleMask`: `[.nonactivatingPanel, .borderless]`
  - `collectionBehavior`: `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
  - `level`: `.screenSaver` (level 1000)
  - `constrainFrameRect`: Not overridden.
- **CONFIRMED-BY-READING** (`Sources/Modules/Companion/CompanionWindow.swift:100-116`): `CompanionClickPanel`
  - Same as `CompanionPanel`.
- **CONFIRMED-BY-READING** (`Sources/App/AppDelegate.swift:207-233`): `settingsWindow`
  - `styleMask`: `[.titled, .closable, .miniaturizable, .resizable]`
  - `level`: `.floating + 1` (level 4) prior to Phase 1.
- **B4 Commit Diff (`01d0899`)**:
  - `NotchPanel`: `self.level` was lowered from `.screenSaver` (1000) to `.floating` (3).
  - `SettingsWindow`: `window.level` was lowered from `.statusBar + 1` (26) to `.floating + 1` (4).
  - Purpose was to solve C5 ("Settings window minimization & Notch leveling") so Settings wouldn't be occluded by expanded notch.

### 2. Frame Math Tracing
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchGeometry.swift:14-41`):
  - Physical cutout detection: `let hasNotch = screen.safeAreaInsets.top > 0`.
  - Cutout width: `screen.auxiliaryTopRightArea.origin.x - (tl.origin.x + tl.width)` (fallback 185.0).
  - Cutout center prior to Phase 1: `frame.origin.x + (frame.width / 2.0)` (did not use auxiliary areas).
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:130-194`):
  - Prior math: `y = screenFrame.origin.y + screenFrame.height - targetHeight` (`screenFrame.maxY - targetHeight`).
  - Top edge intended: `y + targetHeight = screenFrame.maxY`.
  - Prior collapsed target width: `store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : baseWidth` (default 210pt).

### 3. Hypothesis Confirmation & Root Cause
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:29`):
  - **Hypothesis CONFIRMED**: When `NotchPanel.level` was changed to `.floating` (level 3, below `.mainMenu` level 24), AppKit's default `NSWindow.constrainFrameRect(_:to:)` treats it as a standard desktop window and constrains its frame so that `frame.origin.y + frame.size.height <= visibleFrame.maxY`.
  - On a MacBook with a hardware notch, `screen.frame.maxY` is at the very top bezel, while `screen.visibleFrame.maxY` is below the menu bar (`screen.frame.maxY - screen.safeAreaInsets.top`, ~34pt lower).
  - Because `constrainFrameRect` was not overridden, AppKit pushed the window down by ~34pt, placing it directly over the top of the Safari window / address bar.
  - Furthermore, at `.floating` level, the window could not reliably sit above the menu bar or over full-screen auxiliary surfaces.

### 4. Consumers of Notch Position
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:55-70, 165`): Outside click detection and hover tracking.
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:222-257`): `NotchHostingView` mouse entered/exited tracking area.
- **CONFIRMED-BY-READING** (`Sources/Modules/Companion/KinematicEngine.swift:36-41, 109-116`): Companion mascot kinematic routes (`notchLeft`, `notchRight`, `ledgeY`).
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchRootView.swift:699-932`): Compact wing indicators (`CompactThreeZoneStatusBarIndicator`, `CompactMediaIndicator`, etc.).
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchRootView.swift:85-120`): Drag-and-drop hit testing target (`onDrop`).
- **CONFIRMED-BY-READING** (`Sources/Settings/DashboardSettingsView.swift`): Live preview triggers.

---

## Phase 1: Root Cause Fix Implementation

### 1. Window Level & Frame Constraints
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:28-36`):
  - Changed `NotchPanel.level` to `.popUpMenu` (level 101).
  - Justification: `.popUpMenu` sits above `.mainMenu` (24) and `.statusBar` (25), guaranteeing the notch is never clipped or occluded by menu bar extras or full-screen menu bars. It sits below `CompanionPanel` (`.screenSaver` = 1000), allowing the mascot to walk on top of the notch.
  - Kept collection behavior: `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`.
  - Overrode `constrainFrameRect(_:to:)`:
    ```swift
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
    ```
    This strictly prohibits AppKit from clamping the window top down to `visibleFrame.maxY`.

### 2. Settings Window Decoupling & Focus Overlap Prevention
- **CONFIRMED-BY-READING** (`Sources/App/AppDelegate.swift:231`):
  - Changed `settingsWindow.level` to `.normal` (level 0).
  - Settings is now a standard macOS window with native Dock minimization, Spaces support, and tiling.
- **CONFIRMED-BY-READING** (`Sources/App/AppDelegate.swift:273-279`):
  - Implemented `windowDidBecomeKey(_:)`:
    ```swift
    public func windowDidBecomeKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === AppDelegate.settingsWindow {
            if !SettingsStore.shared.keepOpenWhileSettingsActive {
                NotchShellCoordinator.shared.collapseImmediately(force: true)
            }
        }
    }
    ```
  - When Settings window receives focus, the notch immediately collapses into the physical notch cutout, avoiding any overlap without compromising the notch panel's system overlay tier.
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchShellCoordinator.swift:287-290`):
  - In `onMouseEnter()`:
    ```swift
    if AppDelegate.isSettingsOpen && !SettingsStore.shared.keepOpenWhileSettingsActive {
        return
    }
    ```
    Prevents unintended hover-expansion over Settings while Settings is actively open.

### 3. Hardware Notch Centering & Flush Top Math
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchGeometry.swift:30-36`):
  - Precise physical notch center derived directly from AppKit auxiliary menu bar cutouts:
    ```swift
    if hasNotch, let tl = screen.auxiliaryTopLeftArea, let tr = screen.auxiliaryTopRightArea {
        centerX = (tl.origin.x + tl.width + tr.origin.x) / 2.0
    } else {
        centerX = frame.origin.x + (frame.width / 2.0)
    }
    ```
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:184-188`):
  - Centering: `let x = geometry.notchCenterX - (targetWidth / 2.0)`
  - Top edge flush: `let y = screenFrame.origin.y + screenFrame.height - targetHeight` (`screenFrame.maxY - targetHeight`). Top edge sits exactly at `screenFrame.maxY`.

### 4. Bezel Merging Shape & Compact Wings
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchRootView.swift:18-32, 87-97`):
  - Dynamic corner radii:
    ```swift
    private var currentTopRadius: CGFloat {
        if isExpanded { return store.cornerStyle.topRadius }
        return coordinator.geometry.hasPhysicalNotch ? 0 : 10
    }
    private var currentBottomRadius: CGFloat {
        if isExpanded { return store.cornerStyle.bottomRadius }
        return 14
    }
    ```
  - When collapsed on a physical notch screen: `topRadius = 0` creates a flat edge flush against the screen bezel, while `bottomRadius = 14` matches the physical notch's continuous squircle curve.
  - Collapsed width for `.minimal`: matches `geometry.physicalNotchWidth` exactly, disappearing seamlessly into the bezel.
  - Wing indicators on physical notch screens:
    - `CompactWingMediaIndicator`: Left wing (art/title) + Cutout clear zone (`Spacer().frame(width: physicalNotchWidth)`) + Right wing (playing equalizer bars / pause).
    - `CompactWingBatteryIndicator`: Left wing (clock) + Cutout clear zone + Right wing (battery % + charging icon).
    - `CompactWingDateTimeIndicator`: Left wing (calendar + date) + Cutout clear zone + Right wing (weekday).
    - `CompactWingCircadianIndicator`: Left wing (sun + palette) + Cutout clear zone + Right wing (time).
    - ZERO pixels rendered inside the hardware cutout dead zone.
  - Non-notch screens: render as a centered top pill.

### 5. Verification Status
- Built with `swift build --target NotchApp`: Clean build, 0 errors.
- Built and ran `.build/debug/NotchTests`: 83/83 verification tests passed.
