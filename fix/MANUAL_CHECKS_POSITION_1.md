# Phase 1 Manual Verification Steps: Notch Position & Flush Bezel Integration

These verification checks confirm the root-cause fixes applied in Phase 1 for the notch position, window level, and bezel merging.

---

### Check 1: Collapsed Notch Flush Top Alignment (Desktop)
- **Goal:** Verify the collapsed notch pill sits flush against the very top edge of the display, merging directly into the physical notch bezel instead of floating below the menu bar.
- **Steps:**
  1. Launch the app (`swift run NotchApp` or launch compiled binary).
  2. With the desktop visible (or any standard windowed app open), observe the collapsed notch pill.
  3. Inspect the top edge of the pill where it meets the black bezel.
- **Pass Criteria:** The top edge of the notch panel sits exactly at `screen.frame.maxY` (0pt gap from top screen bezel). There is no gap between the notch and the bezel.
- **Failure Condition:** The pill renders below the menu bar with visible desktop wallpaper or menu bar space above it.

---

### Check 2: Full-Screen Safari & Full-Screen Spaces
- **Goal:** Verify the notch pill does not drop down over the Safari address bar or toolbar in native macOS full-screen mode.
- **Steps:**
  1. Open Safari and click the green maximize button to enter native full-screen mode.
  2. Look at the top center of the screen, specifically the Safari address bar and tab bar.
  3. Move the mouse to reveal and hide the full-screen menu bar.
- **Pass Criteria:** The collapsed notch remains docked flush at the very top of the physical bezel (`.popUpMenu` level with `.fullScreenAuxiliary`). It does NOT drop down onto or obscure the Safari address bar.
- **Failure Condition:** The notch pill renders floating over the Safari URL/search bar or website header.

---

### Check 3: Bezel Merger, Zero-Pixel Cutout Zone & Wings
- **Goal:** Verify that collapsed notch width matches the cutout when Minimal, and content sits strictly on the left/right wings without pixels hidden behind the hardware notch.
- **Steps:**
  1. Open Settings -> Appearance / Compact Indicator.
  2. Set Compact Indicator to **"Minimal"**:
     - Observe the collapsed notch: it matches the physical notch cutout width and disappears seamlessly into the black bezel.
  3. Set Compact Indicator to **"Media"**, **"Battery"**, or **"3-Zone Status Bar"**:
     - Observe the layout of indicators: content sits in the left wing (beside the notch) and right wing (beside the notch).
- **Pass Criteria:** In Minimal mode, the pill disappears into the physical notch cutout. In wing modes, all text, numbers, and icons are 100% visible on the left and right sides of the notch; no text or icon is drawn inside or occluded by the physical camera cutout.
- **Failure Condition:** Text or icons render in the center dead-zone behind the physical camera plastic.

---

### Check 4: Settings Window Decoupling, Minimization & Focus Non-Overlap
- **Goal:** Verify Settings is a standard window (`.normal` level) that minimizes to the Dock and never gets occluded by the notch when focused.
- **Steps:**
  1. Open Settings (via menu bar or expanding notch and clicking gear).
  2. Click the yellow minimize button on the Settings window.
  3. Check the macOS Dock: verify Notchify has a Dock tile with the minimized window.
  4. Click the Dock tile: verify the Settings window restores cleanly.
  5. Drag the Settings window near the top center of the screen directly beneath the notch.
  6. Click inside the Settings window to focus it.
- **Pass Criteria:** When Settings has key focus, the notch collapses immediately into the physical notch cutout, eliminating any overlap. Settings can be minimized and restored without trapping or clipping.
- **Failure Condition:** Expanded notch blocks Settings controls while Settings has focus, or Settings fails to minimize to the Dock.

---

### Check 5: Non-Notch Display (External Monitor)
- **Goal:** Verify behavior on a display without a hardware notch (e.g., external monitor or iMac).
- **Steps:**
  1. Connect or switch to an external monitor without a notch.
  2. Observe the collapsed notch.
- **Pass Criteria:** The notch renders as a centered top pill with rounded top and bottom corners (`topRadius: 10, bottomRadius: 14`), neatly centered horizontally at `screen.frame.midX`.
- **Failure Condition:** Pill renders square top corners on a non-notch screen or is horizontally misaligned.
