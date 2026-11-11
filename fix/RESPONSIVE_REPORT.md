# Responsive Notch Tabs (200 pt) & Event-Driven Battery Widget Report

This report documents the architectural fixes, multi-tier responsive degradation, and new event-driven Battery Status widget implemented for Notch.

---

## 1. Root Causes of 200 pt Clipping (Pre-Fix Analysis)

Prior to this fix, when `SettingsStore.notchHeight` was lowered from the previous default minimum of 310 pt down to 200 pt, every tab and widget experienced severe vertical clipping or layout overflow:

1. **Fixed-Size Outer Shell Assumptions (`Sources/Notch/NotchRootView.swift:233-255`)**:
   - `[CONFIRMED-BY-READING Sources/Notch/NotchRootView.swift:233-255]` The expanded content area assumed a vertical stage of at least 310 pt. It lacked environment awareness of container boundaries and provided no fallback scrolling mechanism for tab modules that exceeded the reduced height.
2. **Fixed Large Intrinsic Sizes in Tab Modules**:
   - `[CONFIRMED-BY-READING Sources/Modules/Thock/ThockModule.swift:145]` Thock carousel diameter was hardcoded to `150.0 pt` with `40 pt` padding. In a 200 pt window (where only ~111-145 pt is available below chrome), the carousel exceeded the entire container.
   - `[CONFIRMED-BY-READING Sources/Modules/Shelf/ShelfModule.swift:186]` Shelf radial jog wheel dial was hardcoded to `150 pt` diameter, clipping outer tools and action buttons.
   - `[CONFIRMED-BY-READING Sources/Modules/AirDrop/AirDropModule.swift:156]` Radar beacon circle was hardcoded to `140 pt`, pushing drop zones outside window bounds.
   - `[CONFIRMED-BY-READING Sources/Modules/Mirror/MirrorModule.swift:150]` Camera live view was hardcoded to `120 pt` height with fixed padding, clipping camera selector buttons.
   - `[CONFIRMED-BY-READING Sources/Modules/Calendar/CalendarModule.swift:170-220]` The 35/42-cell monthly calendar grid required `218 pt` intrinsic height. Below 240 pt, the bottom week row and event indicators were completely sliced off.
3. **Hardcoded Height Offsets in Modular Dashboard (`Sources/Notch/ModularDashboardView.swift:257`)**:
   - `[CONFIRMED-BY-READING Sources/Notch/ModularDashboardView.swift:257]` Dashboard used a hardcoded fallback subtraction `max(100.0, targetExpanded.contentRect.height - 96.0)` instead of measuring actual GeometryReader available height (`geo.size.height`).
4. **Settings Clamping Inconsistency (`Sources/Core/NotchModule.swift:184-188`)**:
   - `[CONFIRMED-BY-READING Sources/Core/NotchModule.swift:184-188]` While `SettingsView.swift` slider was updated to 200 pt, `SettingsStore.notchHeight` lacked defensive clamps on `didSet` and on disk load, risking saved values below 200 or out-of-sync presets.

---

## 2. Exact File Changes & Line Counts

### Phase 1: Shared Responsive Container & Tab Adaptation (Commit `59f49d0`)
- **`Sources/Notch/ResponsiveContainer.swift`** (+82 lines, new file):
  - Created `ResponsiveTabContent` wrapping tab content in a GeometryReader.
  - Injected custom `@Environment(\.notchCompact)` (`< 240 pt`), `@Environment(\.notchTight)` (`< 170 pt`), and `@Environment(\.notchContentHeight)`.
  - Added optional graceful `ScrollView` fallback with hidden scroll indicators for modules without native scroll views.
- **`Sources/Notch/NotchRootView.swift`** (+30, -11 lines):
  - Wrapped active tab view body in `ResponsiveTabContent(enablesVerticalScrollFallback: !moduleHasInternalVerticalScroll)`.
  - Added `moduleHasInternalVerticalScroll` to prevent nested vertical scroll views on `Notes` (`NSTextView`), `Telegram` (`ScrollView`), `Ask AI` (`ScrollView`), and `Notifications` (`ScrollView`).
- **`Sources/Core/NotchModule.swift`** (+17, -2 lines):
  - Enforced `min(420.0, max(200.0, notchHeight))` clamp on `didSet` and initialization in `SettingsStore`.
- **`Sources/Notch/ModularDashboardView.swift`** (+2, -2 lines):
  - Replaced hardcoded subtraction with dynamic `geo.size.height` allocation.
- **`Sources/Modules/Thock/ThockModule.swift`** (+90, -42 lines):
  - Scaled carousel radius (105 pt when tight, 125 pt when compact), condensed bottom dock, hidden volume label in tight mode.
- **`Sources/Modules/Shelf/ShelfModule.swift`** (+78, -36 lines):
  - Scaled jog wheel (95 pt tight, 115 pt compact), hidden descriptions, preserved full touch targets and tool actions.
- **`Sources/Modules/AirDrop/AirDropModule.swift`** (+49, -24 lines):
  - Scaled radar beacon (85 pt tight, 110 pt compact), condensed drop target box.
- **`Sources/Modules/Telegram/TelegramModule.swift`** (+14, -6 lines):
  - Condensed chat rows (48 pt), collapsed setup cards in tight mode.
- **`Sources/Modules/Mirror/MirrorModule.swift`** (+12, -4 lines):
  - Scaled live preview height (80 pt tight, 105 pt compact).
- **`Sources/Modules/NowPlaying/NowPlayingModule.swift`** (+71, -38 lines):
  - Scaled squircle album art (32 pt tight, 38 pt compact), hidden elapsed/remaining times in tight mode, full playback controls preserved.
- **`Sources/Modules/Calendar/CalendarModule.swift`** (+150, -4 lines):
  - Implemented `weekStripContent` with single-week 7-day strip (`weekStripCells`) active when `notchTight` or when container height `< 240 pt`. Full month preserved via `ScrollView` fallback.
- **`Sources/Modules/Notes/NotesWidgetView.swift`** (+20, -14 lines):
  - Added `minHeight: 45 pt` guarantee preventing NSTextView collapse, hidden word count badge when tight.
- **`Sources/Modules/AI/AskAIWidgetView.swift`** (+4, -2 lines):
  - Condensed prompt bar and scroll response area.
- **`Sources/Modules/Battery/BatteryModule.swift`** (+106, -48 lines):
  - Added `BatteryExpandedView` with responsive 46 pt ring gauge and hidden tertiary rows when tight.
- **`fix/MANUAL_CHECKS_RESPONSIVE_1.md`** (+148 lines, new file):
  - Comprehensive manual check protocol across 200, 240, 280, 330, and 420 pt heights.

### Phase 2: Event-Driven Battery Status Widget & Presets (Commit `d6eba95`)
- **`Sources/Core/NotchModule.swift`** (+8, -2 lines):
  - Added `case battery = "battery"` to `DashboardWidgetType` with `title: "Battery"`, `icon: "battery.100.bolt"`, `tintColor: Color.green`, `subtitle: "Power & Battery Status"`, and default `widgetSpans["battery"] = 1`.
- **`Sources/Modules/Battery/BatteryModule.swift`** (+179, -5 lines):
  - Integrated `IOPSNotificationCreateRunLoopSource` + `Notification.Name.NSProcessInfoPowerStateDidChange` for 100% event-driven updates (0% idle CPU, zero timers).
  - Added desktop Mac fallback (`hasBattery = false`) for Mac mini, Mac Studio, Mac Pro, and iMac.
  - Added pure testable `applyPowerSourceData(description:)`, `batteryColor`, `batteryIconName`, and combined `voiceOverLabel`.
  - Replaced hardcoded `.white` with `DesignSystem.primaryText` for theme readability.
- **`Sources/Modules/Battery/BatteryWidgetView.swift`** (+435 lines, new file):
  - Implemented `span == 1` (compact tile with ring/bar, bolt, status line, tight collapse).
  - Implemented `span == 2` (half-stage card with ring, percentage, power source pill, time estimate, health indicator).
  - Implemented `span == 4` (full-stage dual-column energy dashboard).
  - Desktop Mac graceful fallback with `desktopcomputer` icon and continuous AC power readout.
  - Zero-timer note explaining history graph omission to protect performance invariant.
  - Theme tokens only (`DesignSystem`), `.contentShape(Rectangle())`, combined VoiceOver.
- **`Sources/Notch/ModularDashboardView.swift`** (+2 lines):
  - Added `case .battery: BatteryWidgetView(span: span)` to `ModularDashboardView.renderWidget(type:span:)`.
- **`Sources/Settings/DashboardSettingsView.swift`** (+9 lines):
  - Added **"Power Dashboard"** preset (`[.battery, .clock, .calendar, .notes]`) under Quick Layout Presets.
- **`fix/MANUAL_CHECKS_RESPONSIVE_2.md`** (+110 lines, new file):
  - Manual check verification guide for all Battery spans, layouts, hardware states, and themes.

### Phase 3: Headless Verification Tests & Knowledge Graph
- **`Tests/VerificationTests.swift`** (+227, -3 lines):
  - Fixed calendar vertical clearance invariant to test single-week strip height (110 pt) at 200 pt.
  - Added **`[TEST 85]`**:
    1. `expandedLayout` contract tests across 200, 240, 330, 420 pt on notch and non-notch displays (positive height, top flush, notch cleared).
    2. `SettingsStore` clamp invariant tests (150 clamps to 200, bounds [200, 420], 310 preserved).
    3. `DashboardWidgetType` JSON serialization, decoding, and backward compatibility with old JSON arrays.
    4. `BatteryModule` pure data ingestion tests: charging, discharging, desktop Mac fallback, Low Power Mode, and combined VoiceOver strings.
- **Knowledge Graph Rebuilt**:
  - Re-extracted 18 modified code files using `graphify . --update --code-only` and re-clustered via `graphify cluster-only .`.
  - Total graph size: 1,894 nodes, 4,242 edges, 114 semantic communities.

---

## 3. Test Evidence

The comprehensive test suite was executed headlessly via `swift run NotchTests`:

```
=====================================================
  RUNNING COMPREHENSIVE NOTCH APP VERIFICATION TESTS 
=====================================================
[TEST 1] Dynamic Window Frame Sizing (Zero Click-Through Blocking)... Passed
...
[Test 84] Expanded Layout Single Source of Truth Contract...
  ✓ Expanded rect top flush, notch inset included, centering, non-notch adaptation, and zero-clipping contracts verified.

[TEST 85] Responsive Expanded Layouts & Event-Driven Battery Widget Tests...
  ✓ Notch display expandedLayout verified across 200, 240, 330, 420 pt: positive height, notch cleared, top flush.
  ✓ Non-notch display expandedLayout verified across 200, 240, 330, 420 pt: positive height, 0pt inset, top flush.
  ✓ SettingsStore clamp verified: 150 clamps to 200, saved 310 preserved, bounds [200, 420].
  ✓ DashboardWidgetType serialization and backward compatibility verified.
  ✓ Mock charging data verified: 85%, 'Charging', '42m to full'.
  ✓ Mock discharging data verified: 45%, 'On Battery', '2h 30m remaining'.
  ✓ Desktop Mac fallback verified: no battery, 'No battery detected', nil estimate, graceful VoiceOver.
  ✓ Low Power Mode verified: isLowPowerMode == true, status == 'Low Power Mode'.

=====================================================
   ALL VERIFICATION TESTS PASSED SUCCESSFULLY (85/85) 
=====================================================
```
- **Execution Timing**: Build complete in 3.26s; test execution completed in under 1 second.
- **Compiler Warnings**: Linker search path warnings for Command Line Tools SDK (`ld: warning: search path ... not found`); zero Swift compiler errors.
- **Total Tests Passed**: 85/85.

---

## 4. Known Compromises & Deliberate Architectural Decisions

1. **Calendar Single-Week Strip Below 240 pt**:
   - A full 6-row (35/42-cell) monthly calendar requires a minimum of ~218 pt vertical clearance. At a 200 pt expanded notch window (where available height below top chrome is ~111-145 pt), rendering all 6 rows without clipping is geometrically impossible.
   - *Design Decision*: Below 240 pt or in `notchTight` mode, the calendar gracefully transforms into a 7-day single-week strip showing today and surrounding days with event indicators. Users can scroll vertically if they wish to inspect earlier or later weeks.
2. **Battery History Strip Omission**:
   - The user specification noted: *"plus a small history strip only if it can be done WITHOUT timers or stored polling data; otherwise omit and say so."*
   - *Design Decision*: Maintaining a historical power graph requires background timer polling or disk logging, which violates Notch's zero-timer, 0% idle CPU performance invariant. Therefore, the history strip was deliberately omitted and documented in the UI and test suites.
3. **Module Scroll Nesting Isolation**:
   - To avoid gesture conflicts between nested scroll views, modules that manage their own internal vertical scrolling (`Notes` with `NSTextView`, `Telegram`, `Ask AI`, `Notifications`) opt out of the outer `ScrollView` wrapper via `moduleHasInternalVerticalScroll = true`.
