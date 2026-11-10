# Batch B3 Manual Verification Steps

These tests verify the correctness fixes applied in Batch B3 (addressing user complaints C1, C8, C9).

---

### Check 1: Settings Module Visibility & Toggle Responsiveness (P1-REG-1, P1-SET-1)
- **Goal:** Verify that disabling a module does not cause it to vanish from the Settings window, and clicking a toggle switch flips state exactly once without double-toggling.
- **Steps:**
  1. Open Notchify Settings -> General -> "Enabled Header Modules & Tab Order".
  2. Click directly on the green/blue toggle switch thumb of any module (e.g. "Notes").
  3. Verify the toggle turns off immediately without flashing or reverting back to on.
  4. Verify the "Notes" row remains in the Settings list with its toggle in the OFF state.
  5. Click the toggle switch again; verify it turns back ON and re-appears in the live notch dock.
- **Pass Criteria:** Module row never disappears from Settings when disabled; clicking the toggle thumb flips state smoothly in a single click.

---

### Check 2: Esc Key Dismissal (P1-WIN-1, C8)
- **Goal:** Verify pressing the Escape key dismisses the expanded notch when `closeOnEsc` is enabled.
- **Steps:**
  1. In Settings -> General -> Behavior, ensure "Dismiss Notch on Esc Key" is toggled ON.
  2. Hover the cursor over the hardware notch to expand it.
  3. Press the `Esc` key on your keyboard.
- **Pass Criteria:** The notch smoothly collapses back into the hardware bezel immediately upon pressing Esc.

---

### Check 3: Notes & Ask AI Keyboard Focus & Auto-Collapse Inhibition (C8)
- **Goal:** Verify that typing in Notes or Ask AI acquires keyboard focus and prevents the notch from collapsing even when the mouse cursor leaves the notch panel.
- **Steps:**
  1. Hover over the notch to expand it.
  2. Click into the Quick Notes text editor area, or click into the "Ask AI" input field.
  3. Type several words.
  4. Move your mouse cursor away from the notch down into the middle of the desktop screen.
  5. Continue typing on the keyboard.
- **Pass Criteria:** The notch remains fully open while typing and does not collapse under your hands. Once you click outside onto the desktop, the notch collapses smoothly.

---

### Check 4: Thock Process Lifecycle & Rapid Toggle Race (P1-THOCK-1, C9)
- **Goal:** Verify that Thock engine sound simulation stays active across the system, and rapid start/stop toggling does not corrupt engine status.
- **Steps:**
  1. Navigate to the Thock tab in the notch.
  2. Click "Start Engine".
  3. Rapidly click "Stop" and "Start" 3 times in quick succession.
  4. Collapse the notch and type on the keyboard in another app (e.g. Safari, Terminal, Notes).
- **Pass Criteria:** Mechanical switch sounds continue playing while typing across the system when Thock is active. The engine status in the Thock tab displays "Active · PID <number>" without becoming stuck in "Engine Stopped".
