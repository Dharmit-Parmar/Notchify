# Phase 1 Manual Verification Guide: Responsive Notch Island (200 pt – 420 pt)

## Overview of Phase 1 Implementation
- **Shared Responsive Container**: `ResponsiveTabContent` (`Sources/Notch/ResponsiveContainer.swift`) measures real `GeometryReader` container height (`notchContentHeight`) and publishes `@Environment(\.notchCompact)` (`< 240 pt`) and `@Environment(\.notchTight)` (`< 170 pt`).
- **Scroll Nesting Guard**: Modules with internal native scroll views (`Notes` with `NSTextView`, `Ask AI`, `Telegram`, `Notifications`) opt out of outer scroll wrapping, eliminating nested scroll fight and collapse-to-zero bugs.
- **Graceful Degradation Order**: All 11 modules adapt dynamically, hiding descriptive subtitles before hiding controls, keeping every control accessible.
- **Single Source of Truth**: `NotchGeometry.expandedLayout` is the sole source for window sizing; `SettingsStore.notchHeight` is clamped to `200...420 pt` on `didSet` and defaults load.

---

## Verification Test Matrix

### 1. Height Sizing Sweep (Preferences > Geometry > Expanded Notch Height)

| Expanded Height Setting | Expected Usable Content Height (Hardware Notch) | Expected Visual Behavior | Bug Indicators |
| :--- | :--- | :--- | :--- |
| **200 pt** (Minimum) | ~145 pt available (~110 pt inside module card) | `notchTight = true`. Week strip in Calendar; 95 pt wheel in Shelf; 80 pt preview in Mirror; 46 pt gauge in Battery; 48 pt chat in Telegram; compact switch carousel in Thock. | Content cut off at bottom bezel; overlapping header dock; text overlapping borders. |
| **240 pt** | ~185 pt available (~150 pt inside module card) | `notchCompact = true`, `notchTight = false`. Secondary rows adapt; medium artwork in NowPlaying; standard wheel in Shelf; full month fits or week strip fallback. | Double scroll indicators; jittering height during spring animation. |
| **280 pt** | ~225 pt available (~190 pt inside module card) | Standard comfortable mode. Full month calendar grid fits unclipped; full switch profiles in Thock. | Any clipped button or missing control. |
| **330 pt** (Default) | ~275 pt available (~240 pt inside module card) | Standard spacious layout. Bento 2x2 grid has full breathing room; AirDrop radar at full 140x140 pt. | Inconsistent margins or unbalanced card heights. |
| **420 pt** (Maximum) | ~365 pt available (~330 pt inside module card) | Maximum vertical room. Notes, chat history, and Bento widgets expand smoothly to fill container. | Empty awkward gaps or broken background clipping. |

---

### 2. Per-Module Verification Checklist at Height = 200 pt

#### A. Dashboard Home (`ModularDashboardView`)
1. **Horizontal Strip Layout**:
   - Set height slider to 200 pt. Open Notch Island.
   - **Correct**: Widgets sit side-by-side inside the 145 pt content area. Clock shows digital readout and compact dial; NowPlaying shows compact artwork and controls; Calendar shows mini glance; Notes shows title and quick note lines.
   - **Bug**: Widgets overflowing outside the bottom rounded bezel.
2. **2×2 Bento Quad Layout**:
   - Switch layout to Bento Quad.
   - **Correct**: Slots divide available height into ~68 pt cells. Single-column widgets scale to span 1 compact tiles without clipping.
   - **Bug**: Bottom row widgets cut off or hidden behind screen bottom.

#### B. Thock Module (`ThockExpandedView`)
1. Navigate to **Thock** tab with notch height at 200 pt.
2. **Correct**:
   - Sub-navigation dock pills (Key Sound · Ambient ASMR) render with compact 3 pt vertical padding.
   - Controls bar: Engine power button, Audition Tap, and volume slider are fully visible. "Volume" text label is hidden to give slider full width.
   - Switch pack carousel renders with compact 105 pt cards and 1-line labels; active switch checkmark is clearly visible.
   - If permissions banner is triggered, content scrolls vertically with fluid momentum and zero clipping.
3. **Bug**: Audition or volume slider pushing offscreen without scroll capability.

#### C. Shelf & File Studio (`ShelfModuleExpandedView`)
1. Navigate to **Shelf** tab at 200 pt.
2. **Correct**:
   - Header shows tool name (e.g. `Merge PDF`) in 11 pt bold font with breadcrumb chevron. "File Studio" text is hidden when tight to conserve space.
   - Studio jog wheel scales to 95x95 pt, keeping all 5 tool icons clickable and responsive.
   - Action trigger button ("Merge Documents", "AirDrop All") is prominent.
   - Staged files tray renders at bottom; file chips or drop placeholder are clearly accessible.
3. **Bug**: Wheel overflowing bottom card border; file chips unclickable.

#### D. AirDrop Module (`AirDropExpandedView`)
1. Navigate to **AirDrop** tab at 200 pt.
2. **Correct**:
   - Radar animation beacon scales to 85x85 pt on the left.
   - Drop stage box sits on the right with dashed accent border and "Drag & Drop Files Here" prompt.
   - Dragging a file over the notch highlights the radar and drop box instantly.
3. **Bug**: Radar fixed at 140 pt pushing drop stage out of view.

#### E. Messages / Telegram (`TelegramModuleExpandedView`)
1. Navigate to **Messages** tab at 200 pt.
2. **Correct**:
   - Top pinned contacts bar scrolls horizontally.
   - Conversation chat scroll area sizes to 48 pt height, scrolling smoothly through messages.
   - Bottom message input textfield is fully visible and clickable; pressing Enter sends immediately.
   - Opening "Direct Bot Setup" or "Add Contact" reveals the card with verbose descriptions collapsed.
3. **Bug**: Text input field pushed below window bottom; keyboard focus trapped.

#### F. Camera Mirror (`MirrorContainerView`)
1. Navigate to **Mirror** tab at 200 pt.
2. **Correct**:
   - Live camera preview scales to 80 pt height with continuous squircle corners.
   - Header shows "Camera Mirror" and green "Live Preview" status dot.
   - Camera frame never spills past bottom squircle radius.
3. **Bug**: Hardcoded 140 pt preview clipping bottom edge of the panel.

#### G. NowPlaying (`NowPlayingHomeCardView`)
1. Play audio in Music or Spotify; open Dashboard at 200 pt.
2. **Correct**:
   - Album art renders at compact 38x38 pt squircle.
   - Track title and artist are legible.
   - Scrubber progress capsule bar is visible; secondary time readout text is hidden to save vertical space.
   - Transport controls (Play/Pause, Previous, Next) are 100% accessible.
3. **Bug**: Equalizer bars or play button clipping outside bottom border.

#### H. Calendar (`CalendarHomeCardView`)
1. In Dashboard, view Calendar widget at 200 pt (`notchTight = true`).
2. **Correct**:
   - Displays a sleek **single-week strip** showing 7 days of the active week.
   - Today's date numeral is ringed in accent color; selected date has filled accent circle.
   - Month name and "Today" pill allow instant snapping and month flipping.
   - If user needs full month, scrolling vertically inside the card smoothly reveals the full 6-row month grid.
3. **Bug**: 6-week rows cramming together or the last 2 weeks getting cut off at the bottom.

#### I. Quick Notes (`NotesWidgetView`)
1. Click into **Notes** widget at 200 pt.
2. **Correct**:
   - Header shows Notes icon and title.
   - AppKit native `NSTextView` fills the remaining height with a 45 pt minimum guarantee.
   - Typing is fluid; long multi-paragraph notes scroll internally via AppKit `NSScrollView` with zero outer container jitter.
3. **Bug**: Notes collapsing to 0 height inside container; nested scroll bars fighting each other.

#### J. Ask AI (`AskAIWidgetView`)
1. View **Ask AI** widget at 200 pt.
2. **Correct**:
   - Input prompt bar is visible with provider badge.
   - AI response text renders in vertical scroll view.
   - Focus state properly notifies `NotchShellCoordinator.isTypingInWidget`.
3. **Bug**: AI response pushing input bar out of window.

#### K. Battery Module Expanded View (`BatteryExpandedView`)
1. Navigate to **Battery** tab at 200 pt.
2. **Correct**:
   - Battery gauge circle scales to 46x46 pt with 5 pt stroke width and bold percentage.
   - Status header indicates "Connected to Power" or "On Battery".
   - "Apple Silicon Health" text is visible; tertiary longevity text is hidden when tight.
3. **Bug**: Circle gauge cut off at 70 pt.

---

### 3. First Hover vs Second Hover Verification
1. Move cursor away so Notch collapses completely.
2. Move cursor to notch top center to expand on the **FIRST** hover.
   - **Correct**: Window frame animates directly to the target height (e.g. 200 pt); content renders at the exact final size immediately with no intermediate jump or layout reflow.
   - **Bug**: Notch first opens at 330 pt and suddenly snaps to 200 pt.
3. Move cursor away and hover a second time.
   - **Correct**: Dimensions, layout, and animations are byte-for-byte identical to the first hover.

---

### 4. Theme & Appearance Verification
- **Sakura Theme (Light)**:
  - Text colors must remain dark/high-contrast against light card background.
  - No white text on light gray background.
- **Birch Theme (Muted Warm Light)**:
  - Contrast on switch buttons and chips must remain crisp and readable.
- **Dark Theme (Obsidian / Neon)**:
  - Specular divider and card borders subtle and sharp.

---

### 5. Needs Manual Check (Hardware / OS Dependent)
- `[NEEDS MANUAL CHECK]`: Verification on physical 14" M1/M2/M3 MacBook Pro hardware notch vs external 4K 16:9 monitor without notch.
- `[NEEDS MANUAL CHECK]`: Live typing sound playback when Thock engine is running at 200 pt height.
- `[NEEDS MANUAL CHECK]`: VoiceOver cursor reading order on week strip vs full month calendar.
