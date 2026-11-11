# Manual Check Guide: Battery Status Widget & Dashboard Layouts

This manual verification protocol details testing steps for the event-driven **Battery Status Widget** in Dashboard slots across all widget spans, layout flows, hardware states, and display themes.

---

## 1. Widget Span Verification (1, 2, and 4 Spaces)

### Span 1 (Compact Tile)
1. In Settings > Dashboard, drag the **Battery** widget into an active slot with Span 1.
2. Expand the Notch (or press the global toggle shortcut).
3. **Verify:**
   - Circular battery ring with progress trim corresponding to the current battery level.
   - Percentage numeral displayed inside the ring.
   - Charging bolt icon visible if plugged into MagSafe or USB-C power.
   - Status text displayed below the ring: *"Charging"*, *"On Battery"*, *"Fully Charged"*, or *"Low Power Mode"*.
   - When height is reduced to tight mode (`< 170 pt`), secondary status text collapses cleanly while the percentage ring remains visible and legible.
   - The entire card is clickable (`.contentShape(Rectangle())`).

### Span 2 (Half-Stage Card)
1. In Settings > Dashboard, configure the Battery widget to Span 2.
2. Expand the Notch.
3. **Verify:**
   - Header shows a colored indicator dot matching battery state, "Power & Battery" title, and power source pill (e.g., *"AC Power"* / *"Battery Power"*).
   - Horizontal divider with subtle theme border.
   - Larger ring gauge on the left with percentage numeral and charging bolt.
   - Status details on the right: main status line (*"Charging"* / *"On Battery"*), estimated time remaining or time to full charge (e.g., *"1h 45m remaining"* / *"42m to full"*).
   - Low Power Mode or battery health status indicator.
   - In tight mode, text metrics scale down gracefully with no overlapping labels.

### Span 4 (Full-Stage Dashboard)
1. In Settings > Dashboard, set the Battery widget to Span 4 (dominant stage).
2. Expand the Notch.
3. **Verify:**
   - Expanded title "Power & Energy Dashboard" with power source status badge.
   - High-resolution ring gauge with spring animation on capacity changes.
   - Left-to-right metrics layout: status description, time estimate, Low Power Mode status icon, and Battery Health indicator.
   - Architecture indicator noting event-driven zero-timer monitoring (`IOPSNotificationCreateRunLoopSource` with 0% idle CPU draw).
   - Architectural note explaining that historical graph polling is omitted to strictly enforce Notch's zero-timer performance invariant.

---

## 2. Layout Flow & Preset Integration

### Quick Layout Preset: "Power Dashboard"
1. Open Settings > Dashboard.
2. Scroll to **QUICK LAYOUT PRESETS**.
3. Click the **Power Dashboard** preset button (*"Battery + Clock + Cal + Notes"*).
4. **Verify:**
   - Dashboard layout switches to Horizontal Strip.
   - Slots are populated in order: `[Battery, Clock, Calendar, Notes]`.
   - Spans are configured to 1 space each.
   - In the Notch expanded view, all four widgets render side-by-side with equal spacing and no clipping at 200 pt window height.

### Layout Flow Modes
Verify the Battery widget renders correctly across all four layout flows:
- **Horizontal Strip:** Renders smoothly as a column card.
- **Bento Quad (2x2):** Fits into 1-space quadrant or 2-space span without overflowing adjacent cells.
- **Adaptive Auto:** Adapts to available width and height dynamically.
- **Focus Dominant:** Battery expands to full width when placed in the primary focus position.

---

## 3. Hardware States & Desktop Mac Fallback

### Desktop Mac Test (Mac mini, Mac Studio, Mac Pro, iMac)
- On hardware without an internal battery, verify that IOKit returns an empty battery list.
- **Expected Display:**
  - SF Symbol `desktopcomputer` is displayed instead of a zero percent battery icon.
  - Title shows *"Desktop Mac"*.
  - Subtitle displays *"Connected to Power"* / *"Continuous AC Power"*.
  - No fake `100%`, `0%`, or `NaN%` is ever shown.
  - VoiceOver announces: *"Battery Status: Desktop Mac, connected to power, no battery detected"*.

### MacBook Charger Connect / Disconnect Test
- Unplug the power adapter:
  - System immediately triggers `IOPSNotificationCreateRunLoopSource`.
  - Battery ring color updates (green/orange/red depending on level).
  - Status text updates from *"Charging"* to *"On Battery"*.
  - Bolt icon disappears.
- Plug in the power adapter:
  - System immediately triggers notification.
  - Ring transitions with spring animation.
  - Yellow charging bolt appears.
  - Status text updates to *"Charging"*.
  - Time-to-full estimate appears once IOKit calculates charge rate.

### Low Power Mode Test
- Enable Low Power Mode in macOS System Settings > Battery.
- Verify widget updates to reflect *"Low Power Mode"* with yellow theme accent.

---

## 4. Accessibility & Theme Compliance

### VoiceOver
- Enable VoiceOver (`Cmd + F5`).
- Navigate focus to the Battery widget.
- **Verify:** VoiceOver reads the combined single-sentence label, e.g.:
  - *"Battery 85 percent, Charging, 38m to full"*
  - Or on desktop: *"Battery Status: Desktop Mac, connected to power, no battery detected"*.

### Theme Readability
- Switch theme to **Birch** (light wood/parchment tone).
  - Verify battery text uses `DesignSystem.primaryText` (dark ink) and is completely readable.
  - Verify card background uses `DesignSystem.cardFill` and borders use `DesignSystem.cardBorder`.
- Switch theme to **Sakura** (light pastel pink tone).
  - Verify dark plum ink contrast is maintained. No washed-out white text.
- Switch theme to **Midnight** or **Obsidian** (dark themes).
  - Verify crisp white ink text and glowing accent rings.
