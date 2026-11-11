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

---

## Round 2 Phase 0: Width Model & Indicator Sizing Diagnosis

### Skills Re-Pick Log

| Phase | Trigger | Skills Activated | Rationale |
|---|---|---|---|
| **Phase 0 & 1** | Collapsed notch pill rendering far too wide with "Wed" and time on opposite poles sticking out past hardware notch; hit testing blocking menu items; mascot ledge collision | `swiftui-expert-skill`, `axiom-macos`, `apple-design`, `axiom-design`, `swiftui-pro`, `axiom-accessibility`, `axiom-testing`, `ponytail`, `gravitas`, `graphify` | `ponytail` for the simplest pure-function layout model; `axiom-macos` for AppKit window geometry, `hitTest(_:)`, and pass-through clicks; `apple-design` & `axiom-design` for clean bezel integration without clumsy arbitrary wing widths; `gravitas` for evidence-backed verification with exact file:line citations; `axiom-testing` for headless unit tests. |

---

### 1. Table of Collapsed Window Width and Height (Phase 0.1)

All formulas cited from **CONFIRMED-BY-READING** `Sources/Notch/NotchWindow.swift:183-203`:

| CompactIndicatorStyle | Display With Physical Notch: Formula & File:Line | Display Without Notch: Formula & File:Line | Settings Feeding Value | Typical Sizing (14" / 16" MBP) |
|---|---|---|---|---|
| **`.minimal`** | `width = geometry.physicalNotchWidth`<br>`height = max(geometry.physicalNotchHeight, store.hoverTriggerHeight)`<br>(`Sources/Notch/NotchWindow.swift:186, 198`) | `width = store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : 210.0`<br>`height = store.hoverTriggerHeight > 0 ? store.hoverTriggerHeight : 32.0`<br>(`Sources/Notch/NotchWindow.swift:200-201`) | `hoverTriggerHeight` (default 34.0 pt) | Notch: ~210 x 34 pt<br>No-notch: 210 x 32 pt |
| **`.threeZoneStatusBar`** | `width = max(store.hoverTriggerWidth, geometry.physicalNotchWidth + 180.0)`<br>`height = max(geometry.physicalNotchHeight, store.hoverTriggerHeight)`<br>(`Sources/Notch/NotchWindow.swift:188, 198`) | `width = store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : 210.0`<br>`height = store.hoverTriggerHeight > 0 ? store.hoverTriggerHeight : 32.0`<br>(`Sources/Notch/NotchWindow.swift:200-201`) | `hoverTriggerWidth` (default 210 pt), fixed `+ 180.0` term | Notch: **390 x 34 pt** (+90 pt wing per side)<br>No-notch: 210 x 32 pt |
| **`.media`** | `width = max(store.hoverTriggerWidth, geometry.physicalNotchWidth + 160.0)`<br>`height = max(geometry.physicalNotchHeight, store.hoverTriggerHeight)`<br>(`Sources/Notch/NotchWindow.swift:190, 198`) | `width = store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : 210.0`<br>`height = store.hoverTriggerHeight > 0 ? store.hoverTriggerHeight : 32.0`<br>(`Sources/Notch/NotchWindow.swift:200-201`) | `hoverTriggerWidth`, fixed `+ 160.0` term | Notch: **370 x 34 pt** (+80 pt wing per side)<br>No-notch: 210 x 32 pt |
| **`.battery`** | `width = max(store.hoverTriggerWidth, geometry.physicalNotchWidth + 140.0)`<br>`height = max(geometry.physicalNotchHeight, store.hoverTriggerHeight)`<br>(`Sources/Notch/NotchWindow.swift:192, 198`) | `width = store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : 210.0`<br>`height = store.hoverTriggerHeight > 0 ? store.hoverTriggerHeight : 32.0`<br>(`Sources/Notch/NotchWindow.swift:200-201`) | `hoverTriggerWidth`, fixed `+ 140.0` term | Notch: **350 x 34 pt** (+70 pt wing per side)<br>No-notch: 210 x 32 pt |
| **`.dateTime`** | `width = max(store.hoverTriggerWidth, geometry.physicalNotchWidth + 160.0)`<br>`height = max(geometry.physicalNotchHeight, store.hoverTriggerHeight)`<br>(`Sources/Notch/NotchWindow.swift:194, 198`) | `width = store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : 210.0`<br>`height = store.hoverTriggerHeight > 0 ? store.hoverTriggerHeight : 32.0`<br>(`Sources/Notch/NotchWindow.swift:200-201`) | `hoverTriggerWidth`, fixed `+ 160.0` term | Notch: **370 x 34 pt** (+80 pt wing per side)<br>No-notch: 210 x 32 pt |
| **`.circadian`** | `width = max(store.hoverTriggerWidth, geometry.physicalNotchWidth + 160.0)`<br>`height = max(geometry.physicalNotchHeight, store.hoverTriggerHeight)`<br>(`Sources/Notch/NotchWindow.swift:196, 198`) | `width = store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : 210.0`<br>`height = store.hoverTriggerHeight > 0 ? store.hoverTriggerHeight : 32.0`<br>(`Sources/Notch/NotchWindow.swift:200-201`) | `hoverTriggerWidth`, fixed `+ 160.0` term | Notch: **370 x 34 pt** (+80 pt wing per side)<br>No-notch: 210 x 32 pt |

---

### 2. Root Cause of the Wide Pill with Opposing Poles (Phase 0.2)

- **Style Identified**: `CompactIndicatorStyle.dateTime` ("Clock") (**CONFIRMED-BY-READING** `Sources/Notch/NotchRootView.swift:984-1020` on notch displays and `Sources/Notch/NotchRootView.swift:776-791` on non-notch displays).
- **Why It Sticks Out**:
  - In `NotchWindow.swift:194`, `targetWidth = max(store.hoverTriggerWidth, geometry.physicalNotchWidth + 160.0)`.
  - On standard Apple Silicon notch displays where `physicalNotchWidth` is ~210 pt, this forces `targetWidth` to 370 pt (extending 80 pt past the physical notch on both left and right).
- **Why the Middle Is Empty**:
  - In `CompactWingDateTimeIndicator` (`Sources/Notch/NotchRootView.swift:989-1016`):
    - Left Wing (`:991-1000`): Uses `HStack` with `.frame(maxWidth: .infinity, alignment: .leading)`, pinning `calendar` icon and formatted time (`11:24 AM`) to the extreme left edge (`padding(.leading, 8)`).
    - Center Cutout (`:1003-1005`): `Spacer().frame(width: max(20.0, notchWidth)).allowsHitTesting(false)` inserts an unpainted ~210 pt void corresponding to the camera bezel.
    - Right Wing (`:1008-1015`): Uses `HStack` with `Spacer()` and `.frame(maxWidth: .infinity, alignment: .trailing)`, pinning `Text("Wed")` to the extreme right edge (`padding(.trailing, 8)`).
  - On non-notch displays (`Sources/Notch/NotchRootView.swift:776-791`), `dateTimeIndicator` uses a free `Spacer()` between the time and weekday inside a 210 pt pill, pushing time to the far left and "Wed" to the far right with dead space between them.

---

### 3. Window Sizing, Hit-Testing, Menu Bar Blocking & Mascot Collision (Phase 0.3)

1. **Window Size vs Visible Content**:
   - **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:15-26, 214-234`): The window frame matches `targetWidth` (370 pt) exactly.
   - **CONFIRMED-BY-READING** (`Sources/Notch/NotchRootView.swift:38-42`): `NotchGlassBackground` spans the full window bounds (`ZStack`), rendering a continuous 370 pt glass capsule across the top bezel instead of hiding behind the physical notch.
2. **Hit-Testing & Click Blocking on Menu Bar Items**:
   - **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:30, 40`): `NotchPanel.level = .popUpMenu` (level 101, above `.mainMenu` level 24 and `.statusBar` level 25) and `self.ignoresMouseEvents = false`.
   - **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:238-272`): `NotchHostingView` does NOT override `hitTest(_:)`.
   - **Defect Impact**: Any click on menu bar items or status extras located within 80–90 pt of the notch (e.g. Wi-Fi, battery, clock, Control Center, or app menus) is intercepted by `NotchPanel`.
3. **Mascot Ledge Collision**:
   - **CONFIRMED-BY-READING** (`Sources/Modules/Companion/KinematicEngine.swift:110-115`): `notchLeft` and `notchRight` are computed strictly from the physical cutout (`tl.maxX` and `tr.minX`).
   - The mascot's crawl boundaries (`notchLeft - 42.0`, `notchRight + 42.0`) and hang points (`notchLeft + 14.0`, `notchRight - 14.0`) assume the physical notch boundaries.
   - When the wide pill extends to `notchLeft - 80.0` and `notchRight + 80.0`, the mascot crawls, hangs, and dangles right over and through the wing content.

---

### 4. Inventory of All Consumers of the Collapsed Rect (Phase 0.4)

1. **`NotchPanel` Frame Math**: `Sources/Notch/NotchWindow.swift:15-26, 136-234`
2. **`NotchHostingView` Tracking Area**: `Sources/Notch/NotchWindow.swift:246-253`
3. **`NotchShellCoordinator` Transitions & Frame Sync**: `Sources/Notch/NotchShellCoordinator.swift:150-180, 265-267, 383-385, 427-447`
4. **`NotchShellCoordinator` Hover Detection**: `Sources/Notch/NotchShellCoordinator.swift:258-340` (`onMouseEnter()`, `onMouseExit()`)
5. **`NotchRootView` Compact Container Sizing**: `Sources/Notch/NotchRootView.swift:45-47, 720-764`
6. **Wing Indicators**: `CompactWingMediaIndicator`, `CompactWingBatteryIndicator`, `CompactWingDateTimeIndicator`, `CompactWingCircadianIndicator`, `CompactThreeZoneStatusBarIndicator` (`Sources/Notch/NotchRootView.swift:880-1160`)
7. **Drag & Drop Drop Targets**: `Sources/Notch/NotchRootView.swift:85-120`
8. **Companion Mascot Engine**: `Sources/Modules/Companion/KinematicEngine.swift:36-41, 109-127, 157-185, 408-456, 640-641, 1003-1004`
9. **Companion Den & Spawning**: `Sources/Modules/Companion/CompanionCoordinator.swift:110-145`
10. **Settings Window Preview**: `Sources/Settings/SettingsView.swift:1020-1045, 1315-1350`

---

## Round 2 Phase 1: One Collapsed-Layout Model Implementation

### Skills Re-Pick Log

| Phase | Trigger | Skills Activated | Rationale |
|---|---|---|---|
| **Phase 1 Execution** | Implementing unified pure collapsed layout function, removing hardcoded wing expansion (+180/160/140), event-driven wings, and hit-test pass-through | `swiftui-expert-skill`, `axiom-macos`, `apple-design`, `axiom-design`, `swiftui-pro`, `axiom-accessibility`, `axiom-testing`, `ponytail`, `gravitas`, `graphify` | `ponytail` for a single clean pure function `collapsedLayout` replacing ad-hoc geometry sprawl; `axiom-macos` for `NSView.hitTest(_:)` outside `contentRect` to permit menu bar clicks; `apple-design` & `axiom-design` for fluid event-driven wings and bezel aesthetics; `gravitas` for evidence-backed verification. |

### 1. Pure Function: `NotchGeometry.collapsedLayout`
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchGeometry.swift:80-205`):
  - Pure function signature:
    ```swift
    public static func collapsedLayout(
        geometry: NotchGeometry,
        style: CompactIndicatorStyle,
        mode: CollapsedNotchMode,
        attachment: NotchPositionAttachment,
        wingWidth: CGFloat = 56.0,
        collapsedHeight: CGFloat = 34.0,
        horizontalOffset: CGFloat = 0.0,
        verticalOffset: CGFloat = 0.0,
        activeEvents: ActiveNotchEvents = ActiveNotchEvents()
    ) -> CollapsedLayout
    ```
  - Output struct `CollapsedLayout`:
    - `windowRect`: Frame allocated to the `NotchPanel` NSWindow.
    - `contentRect`: Visual painted boundary of the notch pill and visible wings.
    - `leftWingRect`: Bounding box of the left wing.
    - `centerCutoutRect`: Screen region occupied by the hardware notch cutout (clear zone).
    - `rightWingRect`: Bounding box of the right wing.
    - `hoverTriggerRect`: Expanded interactive hit region for cursor expansion.
    - `effectiveWingWidth`: Calculated wing dimension (0 when wings are hidden).
    - `isWingsVisible`: Boolean indicating whether wings are rendered.

### 2. Collapsed Notch Modes Supported
- **CONFIRMED-BY-READING** (`Sources/UI/DesignSystem.swift:352-374` & `Sources/Notch/NotchGeometry.swift:108-144`):
  1. **"Hide behind notch" (`.hideBehindNotch`, default)**:
     - On notch screens: `effectiveWingWidth = 0`.
     - `contentRect.width = physicalNotchWidth + 4.0` (2 pt overlap per side to prevent visual hairline seams against the bezel).
     - `windowRect.width = contentRect.width`.
     - Zero pixels rendered outside the physical notch cutout.
  2. **"Wings on events" (`.wingsOnEvents`)**:
     - Wings slide out only while active events occur (`activeEvents.isMediaPlaying`, `activeEvents.isCharging`, `activeEvents.hasActiveTimer`, `activeEvents.hasNotification`).
     - When active, `effectiveWingWidth = clampedWingWidth` (default 56 pt); when inactive, `effectiveWingWidth = 0`.
     - Smooth spring animation, instantaneous under `accessibilityReduceMotion`.
  3. **"Always show wings" (`.alwaysShowWings`)**:
     - Wings remain visible with width configured in settings (`0` to `160` pt, default `56` pt).
  4. **Display without a notch**:
     - Centered top pill with width `180.0 + (effectiveWingWidth * 0.8)` and height `32.0`.
     - Snug formatting without empty void spaces.

### 3. Keep-and-Guard All 6 Compact Styles
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchRootView.swift:880-1160`):
  - All 6 styles preserved and adapted to receive `CollapsedLayout`:
    - `.minimal`: Always hides wings, matching physical cutout.
    - `.media`: `CompactWingMediaIndicator` receives `layout.effectiveWingWidth` (56 pt) and renders art/title in left wing, equalizer in right wing.
    - `.battery`: `CompactWingBatteryIndicator` renders time in left wing, battery level + charging glyph in right wing.
    - `.dateTime`: `CompactWingDateTimeIndicator` renders calendar/time in left wing, weekday in right wing, strictly constrained to `effectiveWingWidth` (56 pt). Fixed the opposing-pole defect.
    - `.circadian`: `CompactWingCircadianIndicator` renders circadian sun in left wing, time in right wing.
    - `.threeZoneStatusBar`: `CompactThreeZoneStatusBarIndicator` with media left, status center-wings, clock right.
  - When `layout.isWingsVisible == false`, `CompactNotchIndicator` renders `EmptyView()`, leaving the physical notch cutout completely bare and undisturbed.

### 4. Zero Click-Blocking Hit Testing
- **CONFIRMED-BY-READING** (`Sources/Notch/NotchWindow.swift:259-271`):
  - `NotchHostingView.hitTest(_:)` overridden:
    ```swift
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let coordinator = NotchShellCoordinator.shared
        if coordinator.state == .collapsed {
            let layout = coordinator.currentCollapsedLayout
            let localContentRect = convert(layout.contentRect, from: nil)
            guard localContentRect.contains(point) else {
                return nil
            }
        }
        return super.hitTest(point)
    }
    ```
  - When the window frame is wider than its visible content (or when wings retract), points outside `contentRect` return `nil`, passing clicks through to underlying menu bar items, status icons, and desktop elements.

### 5. Verification Status
- Built with `swift build --target NotchApp`: Clean build, 0 errors.
- Built and ran `.build/debug/NotchTests`: 83/83 verification tests passed.


