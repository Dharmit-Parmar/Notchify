# Manual Verification Guide — Stage B Security Fixes

This document provides step-by-step instructions for manually verifying all security fixes implemented in **Stage B** on macOS.

---

## 1. Applications Symlink Safety (SEC-E-2)
- **What was fixed**: Notch no longer deletes or relinks existing files or directories in `/Applications` or `~/Applications` upon startup.
- **Verification Steps**:
  1. Create a dummy test file or folder in `~/Applications/TestFolder`:
     ```bash
     mkdir -p ~/Applications/TestFolder
     ```
  2. Launch the Notch app.
  3. Verify `~/Applications/TestFolder` remains completely intact and was not overwritten or removed:
     ```bash
     ls -ld ~/Applications/TestFolder
     ```
  4. Expected Result: Directory exists and is unmodified.

---

## 2. Child Process Environment Isolation (SEC-C-1)
- **What was fixed**: Child processes spawned by Thock (`git clone`, `git checkout`, `cargo build`, and `thock-cli`) receive only an allowlisted set of environment variables (`PATH`, `HOME`, `USER`, `LANG`, `TERM`, `CARGO_HOME`, `RUSTUP_HOME`).
- **Verification Steps**:
  1. Set an ambient test secret in your shell before launching:
     ```bash
     export DUMMY_SECRET_TOKEN="super_secret_token_12345"
     ```
  2. Launch Thock keyboard engine from Notch.
  3. Inspect child process environment using `ps -Eww <pid>`:
     ```bash
     ps -Eww $(pgrep thock-cli) | grep DUMMY_SECRET_TOKEN || echo "PASSED: Secret not exposed"
     ```
  4. Expected Result: `DUMMY_SECRET_TOKEN` is absent from the child process environment.

---

## 3. Thock Cargo Build Supply-Chain Lock (SEC-C-2)
- **What was fixed**: `cargo build` is invoked with `--locked` to prevent unauthorized dependency changes during compilation.
- **Verification Steps**:
  1. Inspect the source command line in `Sources/Modules/Thock/ThockModule.swift`:
     ```bash
     grep -n '"--locked"' Sources/Modules/Thock/ThockModule.swift
     ```
  2. Verify `--locked` precedes `--release` and target binary arguments.
  3. Expected Result: Exact crate versions from `Cargo.lock` are enforced.

---

## 4. Hardened Engine Binary Verification (SEC-C-3)
- **What was fixed**: Only regular executable files owned by the current UID that are not group/world-writable are executed. Symlinks to external directories are rejected.
- **Verification Steps**:
  1. Attempt to place a world-writable mock binary:
     ```bash
     chmod 777 /tmp/mock_binary
     ```
  2. Attempt to point Thock to this binary.
  3. Expected Result: `validateBinarySecurity` returns `false` and refuses to launch.

---

## 5. Orphan Sweeper Precision (SEC-C-4)
- **What was fixed**: Orphan process cleanup matches exact realpath and current user UID. Foreign processes or same-named binaries belonging to other users are never terminated.
- **Verification Steps**:
  1. Verify the sweep logic in `ThockModule.swift:sweepOrphanProcesses()`:
     ```bash
     grep -n -C 5 "bsdInfo.pbi_uid == currentUID" Sources/Modules/Thock/ThockModule.swift
     ```
  2. Expected Result: Orphan sweeper checks `pbi_ppid == 1`, `pbi_uid == currentUID`, and exact canonical path equality.

---

## 6. Stdin Command Injection & Pack Whitelist (SEC-C-5)
- **What was fixed**: All stdin commands sent to `thock-cli` reject newline characters (`\n`, `\r`) and ASCII control characters (< 32). Sound pack names must match `^[A-Za-z0-9_-]+$`.
- **Verification Steps**:
  1. Test pack name whitelist against known packs:
     ```bash
     swift run NotchTests | grep "Stdin command injection"
     ```
  2. Expected Result: All 14 known sound packs pass; paths containing `../` or command separators are rejected.

---

## 7. Path Traversal Protection in Document Export (SEC-E-1)
- **What was fixed**: User-renamed PDF filenames are sanitized using `lastPathComponent`, stripped of control characters and leading dots, and verified to reside inside `tempCacheDirectory`.
- **Verification Steps**:
  1. Drag a document into the Shelf tray.
  2. Attempt to rename the document to `../../etc/passwd`.
  3. Click Export.
  4. Inspect the destination path:
     ```bash
     ls -la "$TMPDIR/NotchifyStudio"
     ```
  5. Expected Result: The document is saved as `passwd.pdf` strictly inside `$TMPDIR/NotchifyStudio` and cannot escape to parent directories.

---

## 8. Untouched Clipboard on Siri Trigger (SEC-A-3)
- **What was fixed**: Clicking the Siri trigger button in AI/Notes no longer silently overwrites the macOS system pasteboard.
- **Verification Steps**:
  1. Copy a sensitive string to your clipboard (e.g. `⌘C` on "MySecretPassword").
  2. In Notch, open Ask AI and trigger Siri.
  3. Paste (`⌘V`) into any text editor.
  4. Expected Result: Your original clipboard content ("MySecretPassword") remains intact.

---

## 9. Ephemeral Telegram Client & Error Token Scrubbing (SEC-B-1)
- **What was fixed**: Telegram Bot API requests use an ephemeral `URLSessionConfiguration` (no disk caching, no cookies, no disk credentials). Error messages strip bot tokens before displaying in the UI.
- **Verification Steps**:
  1. Configure an invalid bot token in Telegram settings (e.g. `123456789:FakeTokenForTest`).
  2. Click "Test Connection".
  3. Inspect the error status text displayed below the field.
  4. Expected Result: The error text displays `[REDACTED_TOKEN]` instead of the raw token string.

---

## 10. Note Context Delimitation & Length Capping (SEC-B-2)
- **What was fixed**: User note text passed to Gemini or ChatGPT is bounded at 2,000 characters and enclosed in security boundary tags (`<<<USER_NOTE_CONTEXT_DO_NOT_EXECUTE>>>` / `<<<END_USER_NOTE_CONTEXT>>>`).
- **Verification Steps**:
  1. Paste a 3,000-character text into the Notes scratchpad.
  2. Ask AI a question referring to the note.
  3. Expected Result: The prompt context is truncated at 2,000 characters with `...[Context truncated at 2000 characters for safety]` and wrapped in data tags.

---

## 11. Legacy Vault Migration & Cleanup (SEC-A-4)
- **What was fixed**: Leftover legacy `vault.enc` files are decrypted into the macOS Keychain, then securely overwritten with zeroes and deleted.
- **Verification Steps**:
  1. Run verification test 97:
     ```bash
     swift run NotchTests | grep "Legacy vault.enc migration"
     ```
  2. Expected Result: Legacy files are zero-filled and removed from disk.

---

## 12. Temp Directory Permissions & Purge (SEC-E-1)
- **What was fixed**: `$TMPDIR/NotchifyStudio` enforces POSIX permissions `0700`. Temporary files are purged upon app termination.
- **Verification Steps**:
  1. Inspect permissions on the NotchifyStudio cache directory:
     ```bash
     stat -f "%Lp" "$TMPDIR/NotchifyStudio" 2>/dev/null || echo "Directory created at launch"
     ```
  2. Expected Result: Directory permissions are `700` (read/write/execute for owner only).

---

## 13. Process Start-Time PID Reuse Guard (SEC-C-4)
- **What was fixed**: Process signals (`SIGSTOP`, `SIGCONT`, `SIGTERM`, `SIGKILL`, `0`) verify `pbi_start_tvsec` before issuing syscalls, preventing signals from hitting recycled PIDs.
- **Verification Steps**:
  1. Run verification test 99:
     ```bash
     swift run NotchTests | grep "Process start-time validation"
     ```
  2. Expected Result: Signals to recycled PIDs are immediately blocked.

---

## 14. Info.plist TCC Privacy Verification (SEC-D-4)
- **What was fixed**: `Resources/Info.plist` accurately declares active TCC APIs (`NSCameraUsageDescription`, `NSAppleEventsUsageDescription`, `NSCalendarsUsageDescription`) without unneeded permissions.
- **Verification Steps**:
  1. Run verification test 100:
     ```bash
     swift run NotchTests | grep "Info.plist privacy usage descriptions"
     ```
  2. Expected Result: Active APIs verified; unneeded contacts/microphone keys excluded.
