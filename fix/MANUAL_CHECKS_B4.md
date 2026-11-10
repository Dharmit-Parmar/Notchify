# Batch B4 Manual Verification Steps

These tests verify the look, layout, contrast, and window leveling fixes applied in Batch B4 (addressing user complaints C2, C3, C4, C5).

---

### Check 1: Panel Boundary Containment & Adaptive Content Height (C2)
- **Goal:** Verify elements do not bleed past the rounded notch corners, and the bottom of the notch has no giant empty space.
- **Steps:**
  1. Hover over the notch to expand it.
  2. Switch between Dashboard (e.g. Horizontal Strip or single-row Bento), Battery, and AirDrop.
  3. Look at the bottom border and corners of the notch panel.
- **Pass Criteria:** The expanded notch height adjusts cleanly to fit content without a dead 100pt black void at the bottom. No card, text, or button bleeds outside the rounded squircle boundary.

---

### Check 2: Sakura and Birch Light Themes Readability (C3)
- **Goal:** Verify all text, badges, active theme labels, and buttons are crisp and legible in Sakura and Birch light themes.
- **Steps:**
  1. Open Settings -> Appearance & Themes -> Studio Color Presets.
  2. Select "Sakura Blossom" and then "Birch Studio".
  3. Look at the "Active" badge on the theme card, the footer chip "ACTIVE THEME", and the "Done" button at the bottom right.
- **Pass Criteria:** "Active" text, theme titles, and the "Done" button have strong dark contrast (> 10:1 ratio against light background) and are effortless to read.

---

### Check 3: Visually Distinct Glass Styles (C4)
- **Goal:** Verify that switching between Frosted, Deep OLED, Luminous, and Crystal produces clearly distinct visual appearances.
- **Steps:**
  1. In Settings -> Appearance & Themes -> Glass Material Style:
  2. Click "Frosted Glass" -> Notice the soft satin diffuse blur.
  3. Click "Deep OLED" -> Notice the deep ink-black backing with true zero-bleed contrast.
  4. Click "Luminous Glow" -> Notice the vibrant accent gradient inner illumination.
  5. Click "Crystal Clear" -> Notice the liquid diamond high-transparency specular look.
- **Pass Criteria:** Each glass style has its own unique, recognizable visual signature.

---

### Check 4: Settings Window Minimization & Notch Leveling (C5)
- **Goal:** Verify that Settings window can be minimized and restored from the Dock, and the expanded notch never floats over the Settings window.
- **Steps:**
  1. Open Settings from the notch or menu bar.
  2. Click the yellow minimize button on the Settings window title bar.
  3. Look at the macOS Dock: verify Notchify has a Dock tile with the minimized window.
  4. Click the Dock tile: verify Settings window unminimizes smoothly.
  5. Move the Settings window near the top center of the screen under the notch.
  6. Hover over the notch to expand it.
- **Pass Criteria:** Settings window can be minimized and de-miniaturized without getting lost or trapped. When expanded, the notch stays behind or under the Settings window (`level = .floating`), never covering the Settings window (`level = .floating + 1`).
