# Manual Verification Guide: Batch B2 (Lag & Responsiveness)

Follow these numbered steps to manually test the changes introduced in Batch B2:

---

### Check 1: Idle CPU & Energy Consumption with Dormant Mascot
- **What to do:**
  1. Launch Notchify.
  2. Ensure the Companion Mascot is enabled in Settings.
  3. Collapse the notch and let the app idle for 30 seconds.
  4. Run `top` or check Activity Monitor.
- **What to look at:**
  CPU % and Energy Impact for `NotchApp`.
- **Fixed Result:**
  CPU % drops to near **0.0% – 0.5%** because the continuous 120Hz `TimelineView` animation loop is paused while the mascot is dormant in den / sleeping while collapsed.
- **Still Broken Result:**
  CPU % remains constantly elevated at **5% – 15%** on idle due to continuous 120Hz Canvas rendering and IK solver ticking.
- **One-line command:**
  ```bash
  top -l 3 -pid $(pgrep -x NotchApp) -stats pid,command,cpu,mem | tail -n 2
  ```

---

### Check 2: App Launch Speed & Zero Startup Hang
- **What to do:**
  1. Quit Notchify if running.
  2. Launch Notchify from terminal or Alfred / Spotlight (`./run_notch.sh` or `.build/release/NotchApp`).
- **What to look at:**
  Time from launch command to menu bar status item / notch appearance.
- **Fixed Result:**
  App launches instantly (< 0.2s) because `sweepOrphanProcesses()` runs asynchronously on a background utility queue rather than synchronously iterating 2048 system PIDs on `@MainActor`.
- **Still Broken Result:**
  Perceptible 100ms–200ms delay during launch while `@MainActor` executes synchronous POSIX `proc_pidinfo` calls.

---

### Check 3: Immediate Companion Wakeup on Notch Expand
- **What to do:**
  1. Hover over the physical notch to expand the notch container.
  2. Observe the cartoon companion mascot.
- **What to look at:**
  Smooth transition from dormant resting state into active behavior.
- **Fixed Result:**
  The mascot wakes up and animates smoothly without stutter or frozen frames.
- **Still Broken Result:**
  The mascot remains frozen or takes multiple seconds to resume animation.
