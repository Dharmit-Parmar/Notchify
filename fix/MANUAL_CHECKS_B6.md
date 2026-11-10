# Batch B6 Manual Verification Steps

These tests verify cleanup, redundant teardown elimination, and filesystem permissions safety in Batch B6.

---

### Check 1: Smooth Single Teardown on Notch Collapse
- **Goal:** Verify that expanding and collapsing the notch repeatedly does not trigger duplicate teardowns or stutter.
- **Steps:**
  1. Expand the notch by hovering.
  2. Move the mouse away to collapse the notch.
  3. Expand and collapse 5 times in succession.
  4. Observe the console / logs if attached.
- **Pass Criteria:** Teardown executes exactly once per collapse transition via `state.didSet`, eliminating redundant duplicate calls to `stopAll()`, `unloadInactiveModules()`, `evictArtworkOnCollapse()`, and `saveImmediately()`.

---

### Check 2: Clean Launch Without Permissions Errors
- **Goal:** Verify NotchApp launches without logging root permission errors when attempting to access `/Applications`.
- **Steps:**
  1. Open NotchApp.
  2. Open Console.app and filter for `Notch`.
- **Pass Criteria:** No sandbox or filesystem permission denied errors are thrown when checking for application symlinks.
