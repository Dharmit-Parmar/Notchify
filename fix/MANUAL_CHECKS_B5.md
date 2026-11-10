# Batch B5 Manual Verification Steps

These tests verify the interaction fixes applied in Batch B5 (addressing user complaints C6 and C7).

---

### Check 1: Slot Width Adjustment in Settings Canvas ONLY (C6)
- **Goal:** Verify that draggable slot dividers exist ONLY in Settings -> Dashboard Slots Canvas, and NOT as interactive drag dividers in the live notch.
- **Steps:**
  1. Open Settings -> Dashboard Grid -> "DASHBOARD SLOTS CANVAS".
  2. With two adjacent columns filled (e.g. Bento Quad or Focus Dominant), move your mouse over the vertical dotted divider between the cards.
  3. Notice the cursor changes to a horizontal resize cursor (`<->`) and the grab pill highlights.
  4. Drag the divider to the left and right: verify the columns resize in real time, snapping cleanly at 1/3, 1/2, and 2/3 ratios.
  5. Double-click the divider: verify it resets immediately to 50/50.
  6. Now open the live notch.
  7. Move your mouse over the divider between the widgets in the live notch.
- **Pass Criteria:** In Settings Canvas, the dotted divider is fully draggable and resizes the columns. In the live notch, the divider is clean and static, reflecting the ratio selected in Settings without presenting interactive drag handles.

---

### Check 2: Direct Dock Tab Drag-to-Reorder in Live Notch (C7)
- **Goal:** Verify dock tabs can be directly dragged and dropped to reorder them in the live notch dock.
- **Steps:**
  1. Hover over the hardware notch to expand it.
  2. Click and hold down on any dock tab chip (e.g. "Notes").
  3. Drag it horizontally over another tab chip (e.g. "Calendar" or "Thock").
  4. Release the mouse.
- **Pass Criteria:** The dragged tab swaps places with the target tab with a smooth spring animation and drop haptic/click sound. The new tab order persists across app restarts and reflects in Settings.

---

### Check 3: File Drops & Spring-Loaded Hover Preservation
- **Goal:** Verify that making dock tabs draggable did not break file drops or spring-loaded tab hover.
- **Steps:**
  1. Drag an image or PDF file from Finder over the notch.
  2. Hover the dragged file over the "AirDrop" or "Shelf" tab without releasing.
  3. Verify the tab springs open after ~0.4s dwell time.
  4. Drop the file onto the tab: verify the file is accepted and processed cleanly.
- **Pass Criteria:** File drops and spring-loaded hover continue functioning perfectly without collision with tab reorder drags.
