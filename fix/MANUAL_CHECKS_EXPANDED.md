# Manual Verification Steps: Expanded Notch Layout & Geometry Synchronization

These manual checks verify the expanded notch sizing, camera clear zone insets, first-hover vs second-hover consistency, and non-clipping behavior across all tabs, sizes, and display types.

---

### Check 1: First Hover vs Second Hover Layout Parity
- **Goal:** Verify that expanding the notch on the very first cursor hover renders at the exact final size and layout immediately, with zero difference in height, width, widget span, or layout compared to subsequent hovers.
- **Steps:**
  1. Launch the app fresh (`swift run NotchApp` or launch compiled binary). Do not click or interact with settings beforehand.
  2. Move the cursor smoothly into the collapsed notch to trigger expansion.
  3. Carefully observe:
     - The window expansion animation: does it animate smoothly to the full configured size?
     - The dashboard content: does `Calendar` render in full 2-span card mode immediately on the first hover?
     - The bottom edge: is the bottom-most row of the calendar visible without clipping?
  4. Move the cursor away to let the notch collapse.
  5. Move the cursor back into the notch to trigger the second expansion.
  6. Compare the second expansion to the first expansion.
- **Pass Criteria:**
  - The first hover and second hover expand to the exact same pixel dimensions.
  - No widgets flicker or swap spans (e.g. mini glance switching to home card) mid-animation.
  - The calendar, media widget, tabs, and dividers are laid out at identical positions on both first and second hover.
- **Failure Condition:** The first hover opens at a smaller or clipped size (e.g. 225 pt) and only reaches the proper size on the second hover, or widgets change layout after opening.

---

### Check 2: Top Bezel & Camera Cutout Clear Zone (No Top Clipping)
- **Goal:** Verify that the camera clear zone padding properly clears the physical MacBook notch without wasting space or clipping header elements.
- **Steps:**
  1. Hover to expand the notch on a MacBook with a hardware notch.
  2. Inspect the top area of the expanded window directly beneath the black camera bezel:
     - Observe the "Dashboard" home tab and module tabs dock.
  3. Verify the vertical position of the tabs:
     - They must sit completely below the physical notch cutout (minimum 38–44 pt clear zone).
     - No tab text, icons, or borders may be hidden behind or overlapping the camera plastic.
  4. Inspect the top corners of the expanded notch:
     - Verify squircle continuous curves blend neatly without visual seams or awkward gaps against the screen bezel.
- **Pass Criteria:** The camera clear zone keeps all interactive tabs fully visible below the physical notch. No content renders behind the black cutout.
- **Failure Condition:** Tab headers sit partially or fully behind the hardware notch cutout, or top padding is so excessively large that content is pushed off the bottom.

---

### Check 3: Calendar Widget Full 6-Row Visibility (No Bottom Clipping)
- **Goal:** Verify that the calendar widget displays all days of the month, including the 5th and 6th week rows and the bottom event glance, without clipping.
- **Steps:**
  1. Hover to expand the notch to view the Home Dashboard.
  2. Navigate the calendar to a month requiring 6 rows (e.g., a 31-day month starting on a Friday or Saturday, such as May 2026 or August 2026):
     - Click the month stepper chevrons to navigate months.
  3. Inspect the bottom-most row of date cells:
     - Verify the date numbers (e.g. 30, 31) are completely visible with their circular selection/today rings.
  4. Inspect the "Selected Day Event Glance" bar at the very bottom of the card:
     - Verify the event title, dot, and time string (or "No events scheduled") are fully visible and readable with proper padding above the bottom card border.
- **Pass Criteria:** All 6 rows of dates and the bottom event glance are 100% visible with comfortable breathing room above the card border. No dates or text are cut off by the window frame.
- **Failure Condition:** The last row of dates is cut in half or hidden below the window edge.

---

### Check 4: Settings Width & Height Extremes Follow-Through
- **Goal:** Verify that the expanded window strictly adheres to user-configured width and height settings without arbitrary code-level clamps (e.g. hardcoded 225 pt limits).
- **Steps:**
  1. Open Settings -> Appearance & Sizing.
  2. Test Minimum Bounds:
     - Set Expanded Notch Width to minimum (480 pt).
     - Set Expanded Notch Height to minimum (310 pt).
     - Hover over the notch to expand it: verify the window respects 480 x 310 pt, adjusting widget columns responsively without text overflowing horizontally or vertically.
  3. Test Maximum Bounds:
     - Set Expanded Notch Width to maximum (800 pt).
     - Set Expanded Notch Height to maximum (420 pt).
     - Hover over the notch to expand it: verify the window expands to the full 800 x 420 pt, giving ample space to dashboard cards and slots.
  4. Test Intermediate Values:
     - Set Width to 640 pt, Height to 360 pt: verify frame math matches exactly.
- **Pass Criteria:** The expanded window frame matches the exact values configured in Settings (+/- notch inset where applicable). Changing settings immediately reflects in the next expansion without requiring an app restart.
- **Failure Condition:** The expanded window height remains stuck at 225 pt regardless of what height is selected in Settings.

---

### Check 5: Secondary Module Tabs (Shelf, Notes, AirDrop, Battery, Notifications)
- **Goal:** Verify each secondary module tab lays out properly within the expanded container without clipping or overflow.
- **Steps:**
  1. Hover to expand the notch.
  2. Click or dwell-hover across each tab in the navigation dock:
     - **Shelf**: Verify staged drag items, drop target, and preview tray are fully visible.
     - **Notes**: Verify scratchpad text editor, font controls, and AI action buttons render within bounds.
     - **AirDrop**: Verify radar beacon, device list, and batch tray are visible.
     - **Battery**: Verify battery percentage, health metrics, and charging glyph render cleanly.
     - **Notifications**: Verify notification list and clear buttons fit within window bounds.
  3. Click back to the **Dashboard** home tab:
     - Verify smooth transition back to the dashboard layout.
- **Pass Criteria:** Every module tab renders cleanly within the window boundaries with proper internal scrolling where appropriate.
- **Failure Condition:** Switching to any tab causes the window to collapse, clip content, or freeze.

---

### Check 6: Display Without a Hardware Notch (External Monitor / iMac)
- **Goal:** Verify expanded layout behavior on displays lacking a physical notch cutout.
- **Steps:**
  1. Connect or move the app to an external display without a notch.
  2. Hover to expand the notch.
  3. Observe the top edge of the expanded notch:
     - Verify top padding is NOT wasting 38–44 pt of camera cutout space.
     - Verify the top corners are rounded (`cornerStyle.topRadius`), neatly framing the window.
  4. Inspect the dashboard and calendar:
     - Verify content occupies the allocated window height comfortably without bottom clipping.
- **Pass Criteria:** On non-notch displays, the expanded window adapts its top padding and corner radii appropriately, giving maximum vertical space to content.
- **Failure Condition:** A large 40 pt empty gap appears at the top of the window on a screen with no physical notch, causing bottom content to clip.
