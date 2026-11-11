# Phase 1 Manual Verification Steps: Collapsed Notch Width Model & Event-Driven Wings

These manual verification steps confirm the width model, event-driven wings, and hit-testing pass-through implemented in Phase 1.

---

### Check 1: Default "Hide Behind Notch" Mode (Zero Visible Pixels Outside Cutout)
- **Goal:** Verify that in the default mode, the collapsed notch pill is completely contained within the physical hardware cutout.
- **Steps:**
  1. Launch the app (`swift run NotchApp` or launch compiled binary).
  2. Ensure Settings -> Position & Size -> Collapsed Mode is set to **"Hide behind notch"** (default).
  3. Observe the collapsed notch at the top bezel.
- **Pass Criteria:**
  - The notch pill width matches the physical hardware notch (+ 2 pt overlap per side to prevent visual hairline seams).
  - Absolutely **zero pixels** (text, background glass, icons) are rendered outside or to the sides of the physical hardware notch.
  - The top edge of the pill is flush against the top bezel.
- **Failure Condition:** The pill extends past the physical notch edges into the menu bar, or renders text/clock icons beside the notch.

---

### Check 2: Pass-Through Hit-Testing (Menu Bar Items Beside Notch Are Fully Clickable)
- **Goal:** Verify that `NotchHostingView.hitTest(_:)` allows clicks to pass through to menu bar items and status icons located beside the notch.
- **Steps:**
  1. Open several menu bar applications or ensure status items (e.g. Wi-Fi, battery, clock, Control Center) are located near the notch.
  2. With the notch collapsed, click on menu bar icons positioned immediately adjacent to the notch (20 pt to 80 pt to the left and right).
  3. Click on the Apple menu or app menus on the left side of the notch.
- **Pass Criteria:**
  - Clicking any menu bar icon immediately opens its menu or status popover.
  - Clicks are NOT intercepted, swallowed, or blocked by the notch panel.
- **Failure Condition:** Clicking near the notch fails to open menu bar items or requires moving the mouse far away from the center.

---

### Check 3: "Wings on Events" Dynamic Slide-Out and Retraction
- **Goal:** Verify that wings slide out only while active events occur and retract immediately when events stop.
- **Steps:**
  1. Set Collapsed Mode to **"Wings on events"**.
  2. While no music is playing and the laptop is on battery:
     - Observe the notch: it remains hidden behind the physical cutout (0 pt wings).
  3. Start playing music in Apple Music or Spotify:
     - Observe the notch: left wing slides out displaying artwork/title, and right wing slides out displaying animated equalizer bars.
  4. Pause music playback:
     - Observe the notch: wings smoothly slide back behind the physical notch cutout.
  5. Plug in the MagSafe / USB-C charger:
     - Observe the notch: battery charging wing slides out showing the charging bolt and battery percentage.
  6. Unplug the charger:
     - Observe the notch: wing retracts behind the notch.
  7. Enable macOS System Settings -> Accessibility -> Display -> **Reduce Motion**:
     - Repeat steps 3–6. Verify transitions are immediate without spring animation.
- **Pass Criteria:** Wings only appear during active events and cleanly retract when events end. Transitions are smooth and respect Reduce Motion.
- **Failure Condition:** Wings remain permanently visible when no events are active, or fail to retract after media is paused.

---

### Check 4: "Always Show Wings" & Elimination of Opposing-Pole Empty Void
- **Goal:** Verify that in wing-enabled modes, indicators render comfortably snug against the notch without wide 370 pt balloons or empty center voids.
- **Steps:**
  1. Set Collapsed Mode to **"Always show wings"**.
  2. Set Compact Indicator Style to **"Clock" (`.dateTime`)**:
     - Observe the left and right wings.
  3. Compare with prior buggy behavior:
     - Prior behavior: 370 pt wide pill with the clock at the extreme left (x: 8 pt) and "Wed" at the extreme right (x: 362 pt) with a gaping 210 pt empty void in the middle.
     - New behavior: Left wing displays calendar icon + time within a compact 56 pt wing; right wing displays weekday within a compact 56 pt wing, anchored directly against the sides of the hardware notch.
  4. Cycle through all 6 compact styles:
     - **Minimal**: No wings.
     - **Media**: Art + Title left (56 pt), Equalizer right (56 pt).
     - **Battery**: Time left (56 pt), Battery % right (56 pt).
     - **Clock**: Time left (56 pt), Day right (56 pt).
     - **Circadian**: Sun icon left (56 pt), Time right (56 pt).
     - **3-Zone Status Bar**: Media left, status center, clock right.
- **Pass Criteria:** All 6 styles render content within the configured wing width (default 56 pt). Content is legible, compact, and snug against the notch without awkward pole separation.
- **Failure Condition:** Time and weekday are separated by a giant empty void, or wings extend 80–100 pt across the menu bar.

---

### Check 5: Display Without a Hardware Notch (External Display / iMac)
- **Goal:** Verify collapsed notch behavior on screens without a physical notch cutout.
- **Steps:**
  1. Move the app window or connect an external display without a notch.
  2. Observe the collapsed pill.
- **Pass Criteria:**
  - Renders as a centered top pill (`width: 180 pt + wing factor`, `height: 32 pt`).
  - Top and bottom corners are rounded (`topRadius: 10, bottomRadius: 14`).
  - In Clock mode, time and weekday are rendered in a compact, bullet-separated pill (`"11:24 AM • Wed"`) rather than pushed to opposite edges with a large empty spacer.
- **Failure Condition:** Pill renders square top corners or large empty void on non-notch screens.
