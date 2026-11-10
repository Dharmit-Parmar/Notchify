# Manual Verification Guide: Batch B1 (Data & Crash Safety)

Follow these numbered steps to manually test the changes introduced in Batch B1:

---

### Check 1: User QuickNotes Preservation During Test Runs
- **What to do:**
  1. Open Terminal and run: `defaults read com.notch.NotchApp NotchApp_QuickNotesText` (or note your current notes text).
  2. Run the test suite: `.build/debug/NotchTests`.
  3. Run again: `defaults read com.notch.NotchApp NotchApp_QuickNotesText`.
- **What to look at:**
  Compare the output of step 1 and step 3.
- **Fixed Result:**
  Your original notes text is completely unchanged.
- **Still Broken Result:**
  The output shows `"Architecture Note: Thermal optimization active."` (meaning Test 44 clobbered your personal notes).
- **One-line command:**
  ```bash
  defaults read com.notch.NotchApp NotchApp_QuickNotesText 2>/dev/null || echo "(No note set, safe)"
  ```

---

### Check 2: Zero Keystroke Freezes on AI Key / Bot Token Entry
- **What to do:**
  1. Open Settings -> AI Assistant tab (or Telegram tab).
  2. Click into the Gemini API Key, OpenAI API Key, or Telegram Bot Token `SecureField`.
  3. Rapidly type a 40-character random string.
- **What to look at:**
  Look at text entry responsiveness and cursor blinking.
- **Fixed Result:**
  Typing is instantaneous and fluid at 120Hz with zero lag or beachball.
- **Still Broken Result:**
  The cursor freezes or skips characters on every keystroke due to synchronous `securityd` Mach IPC.

---

### Check 3: Companion Panel Teardown Without AppKit Crash
- **What to do:**
  1. Enable Companion Mascot in Settings.
  2. Open and collapse the notch multiple times rapidly.
  3. In Settings, toggle Companion OFF.
- **What to look at:**
  Monitor console output or CrashReporter for `EXC_BAD_ACCESS`.
- **Fixed Result:**
  The companion panel disappears cleanly without crashing the app.
- **Still Broken Result:**
  Crash with `SIGSEGV` or `EXC_BAD_ACCESS` in `NSHostingView` / `dealloc`.
