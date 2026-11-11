# Verified Security Findings Table (Stage 0 Re-Verification)

- **Target Repository**: Notchify (`/Users/dharmitparmar/Doc/Notch`)
- **Active Branch**: `fix/security-round1` (forked from `fix/from-audit`)
- **Reviewed Git Commit**: `d3f4b11d1101271e61beaff0e2d1cf78d924f197`
- **Re-Verification Date**: 2026-11-11
- **Mode**: Source-First Static Inspection (Zero Source Edits in Stage 0)

---

## 1. Findings Verification Matrix

| ID | Severity | Verdict | Exact Source Evidence (`file:line` & Quote Status) | Other Occurrences (Pattern Search) | Fix Size | Proposed Fix & Safety Scope |
|---|---|---|---|---|---|---|
| **SEC-C-1** | High | **REAL** | `Sources/Modules/Thock/ThockModule.swift:636-639, 693-695`. Quoted code matches exact lines. Passes ambient `ProcessInfo.processInfo.environment`. | `ThockModule.swift:590, 600` (`cloneProc`, `checkoutProc`) inherit ambient environment by default. | **S** | Create `SafeEnvironment.make()` allowlist (`PATH`, `HOME`, `USER`, `LANG`, `TERM`, `CARGO_HOME`, `RUSTUP_HOME`) used for all child processes. |
| **SEC-C-2** | High | **REAL** | `Sources/Modules/Thock/ThockModule.swift:633`. Quoted code matches exact line. Invokes `cargo build` without `--locked`. Verified `Cargo.lock` exists in pinned commit `264ef80f73c38b1d45a6c3e69fa127775b7a5e49`. | None in app source. | **S** | Add `--locked` argument to `cargoProc`. Checkout failure already aborts build; clone is over HTTPS. |
| **SEC-C-3** | High | **REAL** | `Sources/Modules/Thock/ThockModule.swift:70-79`. Quoted code matches exact lines. Searches `~/Doc/KeySound` and `~/Documents/KeySound`. Line 581 creates symlink to `~/Doc/KeySound`. | `ThockModule.swift:574` (`devSource` resolution). | **S** | Restrict default search strictly to `~/Library/Application Support/Notch/KeySound`. Remove automatic symlink creation. Verify binary is regular file, owned by current UID, non-writable by group/world. |
| **SEC-B-1** | High | **REAL** | `Sources/Modules/Telegram/TelegramModule.swift:179`. Quoted code matches exact line. Passes raw token in URL path. Lines 214-220 use `URLSession.shared` and forward raw `err.localizedDescription` to `lastDispatchStatus` which renders on UI in `TelegramModule.swift:967`. | None. | **M** | Introduce dedicated `TelegramClient` with ephemeral `URLSessionConfiguration` (no cache, no cookies, no credentials). Scrub token and endpoint URLs from error descriptions. Add documentation note on Telegram API path requirement. |
| **SEC-D-1** | High | **NEEDS A DECISION** | `NotchApp.app`. Static verification (`codesign -d --entitlements :-`) confirms 0 embedded entitlements. | None. | **L** | **Stage 4 Decision**: App Sandbox breaks Thock child processes, global Input Monitoring, MediaRemote private framework `dlopen`, AppleScript key injection, and arbitrary drag-and-drop filesystem paths in Shelf. Recommendation: Do not sandbox; adopt Hardened Runtime instead. |
| **SEC-D-2** | High | **REAL** | `run_notch.sh:32`, `codesign -dvvv ./NotchApp.app`. Quoted code matches exact line. Ad-hoc signing (`codesign --sign -`) lacks `--options runtime` and library validation. | None. | **M** | **Stage 4 Decision**: Adopt Hardened Runtime. Requires decision between persistent local self-signed root vs Developer ID Application certificate to prevent TCC prompt churn. |
| **SEC-A-1** | Medium | **REAL** | `Sources/Modules/Notes/NoteStorageManager.swift:93-94`. Quoted code matches exact lines. Writes cleartext `notes.txt` with POSIX 0600. | None for notes. | **M** | **Stage 2 Fix**: Encrypt notes at rest using CryptoKit AES-GCM with a 256-bit Keychain-stored key. Safe atomic migration from plaintext. |
| **SEC-A-2** | Medium | **REAL** | `Sources/Modules/Telegram/TelegramModule.swift:474-478`. Quoted code matches exact lines. Writes cleartext `contacts.json` with POSIX 0600. | None for contacts. | **M** | **Stage 2 Fix**: Encrypt `contacts.json` at rest using shared `EncryptedFileStore` with CryptoKit AES-GCM and Keychain key. |
| **SEC-A-3** | Medium | **REAL** | `Sources/Modules/AI/AskAIService.swift:365-368`. Quoted code matches exact lines. Silently overwrites `NSPasteboard.general` on Siri trigger. | `PermissionsHelper.swift:157`, `NotesWidgetView.swift:523, 950`, `AskAIWidgetView.swift:954` (all are explicit user button clicks). | **S** | Remove silent copy to general pasteboard; if copy retained, mark transient/concealed (`org.nspasteboard.TransientType`, `org.nspasteboard.ConcealedType`), auto-expire after 60s, and add visible UI notice. |
| **SEC-D-3** | Medium | **NEEDS A DECISION** | `Sources/Modules/Telegram/TelegramModule.swift:86-103, 143-160`. Quoted code matches exact lines. Synthesizes `key code 36` via `System Events` after 450ms sleep. | None. | **M** | **Stage 4 Decision**: Propose "Auto-send" preference toggle (default OFF), frontmost app & window verification before dispatch, and user cancellation path. |
| **SEC-D-4** | Medium | **NOT REAL** *(Downgraded)* | `Resources/Info.plist:1-28`. Lacks `NSContactsUsageDescription` and `NSMicrophoneUsageDescription`. | Grep confirms `CNContactStore` and Contacts framework are **never imported or used** anywhere in Sources. Microphone audio recording is never used (`MirrorModule` uses video only). | **S** | Downgraded from Medium to Not Real / Informational. No process crash occurs on macOS 14+ because Contacts/Microphone APIs are not called. Documented in Info.plist. |
| **SEC-E-1** | Medium | **REAL** | `Sources/Modules/Shelf/ShelfModule.swift:294-304`. Quoted code matches exact lines. Concatenates unvalidated `doc.fileName` to `tempCacheDirectory`. | `ThockModule.swift:529` (`packName` in `packsDir.appendingPathComponent(packName)`). | **S** | Sanitize all user/external filenames with `(name as NSString).lastPathComponent`, strip leading dots and control chars, and assert standardized path prefix. |
| **SEC-E-2** | Medium | **REAL** | `Sources/Core/PermissionsHelper.swift:57-65, 81-89`. Quoted code matches exact lines. Runs on every launch from `AppDelegate.swift:96`. Silently wipes and replaces existing symlinks in `/Applications` and `~/Applications`. | `run_notch.sh:37, 41`. | **S** | Stop calling `ensureApplicationsSymlink()` on startup in `AppDelegate.swift:96`. Never delete files/symlinks not created by this run. Relocate to an explicit, safe Settings button. |
| **SEC-F-1** | Medium | **REAL** | `run_notch.sh:32`. Ad-hoc signature causes ephemeral designated requirement, causing macOS TCC permissions to reset on rebuild. | Same as SEC-D-2. | **M** | Grouped with SEC-D-2 for Stage 4 decisions. |
| **SEC-A-4** | Low | **PARTLY REAL** | `Sources/Core/KeychainHelper.swift:56-68`. Quoted code matches exact lines. Sets `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and deletes on empty, but lacks App Group ACL. | None. | **S** | Ensure strictest accessibility class and explicit signout deletion. |
| **SEC-B-2** | Low | **REAL** | `Sources/Modules/AI/AskAIService.swift:304, 403, 466`. Quoted code matches exact lines. Concatenates raw note context without boundary delimiters or size limits. | None. | **S** | Delimit note context with `<<<USER_NOTE_CONTEXT_DO_NOT_EXECUTE>>>`, cap length to 2,000 characters, and instruct LLM to treat context purely as passive data. |
| **SEC-C-4** | Low | **REAL** | `Sources/Modules/Thock/ThockModule.swift:274-279`. Quoted code matches exact lines. Matches `execPath.hasSuffix("/thock-cli")` without verifying process owner UID. | None. | **S** | Strictly match `execPath == binaryPath` (via `realpath`) and enforce `bsdInfo.pbi_uid == geteuid()`. |
| **SEC-C-5** | Low | **REAL** | `Sources/Modules/Thock/ThockModule.swift:794-796`. Quoted code matches exact lines. Writes raw command with `\n` to stdin pipe. Lines 761, 868 interpolate user pack names. | None. | **S** | Validate `cmd` contains no `\n`, `\r`, or control chars. Restrict `packName` strictly to `^[A-Za-z0-9_-]+$`. |
| **SEC-F-2** | Low | **REAL** | `scripts/security-audit.sh:63, 75`. Quoted code matches exact lines. Omitted checks for `NSCalendarsUsageDescription`, file permissions/encryption of `notes.txt` / `contacts.json`. | None. | **S** | Extend audit script checks without loosening any existing gates. |

---

## 2. Specific Check Results

### Check 1: SEC-D-4 (Contacts & Microphone)
- **Code Audit**: Grep across `Sources/` for `CNContactStore`, `CNContact`, `import Contacts`, and audio input recording APIs (`AVAudioRecorder`, `AVCaptureDeviceInput` for audio).
- **Result**: Zero occurrences found. `TelegramModule` uses a local `ChatContact` model saved to `contacts.json`. `MirrorModule` explicitly requests video only (`.video`).
- **Conclusion**: Missing `NSContactsUsageDescription` will **not** trigger `SIGABRT` or crash on macOS 14+. The finding is downgraded from Medium to **NOT REAL**.

### Check 2: SEC-B-1 (Telegram Bot Token Exposure)
- **Path Analysis**: Telegram Bot API mandates `/bot<token>/sendMessage` in the URL path.
- **Exposure Vectors Found**:
  1. `URLSession.shared.dataTask` error callback returns `err.localizedDescription`. On network failure (DNS, timeout), `URLError` embeds the full URL containing the bot token.
  2. `DirectMessenger.dispatch` forwards this error to `lastDispatchStatus`.
  3. `TelegramModule.swift:967` renders `lastDispatchStatus` directly into the Notch UI.
  4. `URLSession.shared` participates in default HTTP caching and credential storage.
- **Remediation**: Dedicated `TelegramClient` using ephemeral `URLSessionConfiguration`, stripping URLs/tokens from error strings prior to UI display.

### Check 3: SEC-D-1 (App Sandbox Breakage Inventory)
Adopting `com.apple.security.app-sandbox` would break the following core features:
1. **Thock Engine**: Spawning child processes (`cargo`, `thock-cli`) from Application Support or running background compilers is blocked in standard sandboxes.
2. **Global Input Monitoring**: Listening to system-wide keystrokes (`CGEvent.tapCreate`, `IOHIDManager`) across other applications is blocked without Apple-restricted temporary exception entitlements.
3. **Private Framework Interop**: `MediaRemoteBridge.swift` dynamically `dlopen`s `/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote`, which is denied by dyld sandbox boundaries.
4. **AppleScript Process Automation**: Automating `System Events` to dispatch keys into third-party apps is blocked.
5. **Shelf / File Studio**: Drag-and-drop of arbitrary user files from `~/Doc`, `~/Desktop`, or network shares fails without security-scoped bookmarks.
- **Verdict**: **NEEDS A DECISION**. Recommendation: Keep NotchApp un-sandboxed; harden via Hardened Runtime, library validation, and minimized attack surface.

### Check 4: SEC-E-2 (Destructive Applications Symlinking)
- **Trigger**: Runs unconditionally on every launch via `AppDelegate.swift:96` (`PermissionsHelper.ensureApplicationsSymlink()`).
- **Mechanism**: Reads `/Applications/Notch.app` and `~/Applications/Notch.app`. If either is a symlink whose destination != `bundleURL.path`, it calls `try? fm.removeItem(atPath:)` and re-symlinks to the developer build path.
- **Risk**: Deletes user-created symlinks, clobbers external installations, and pollutes `/Applications` during development.
- **Remediation**: Remove `ensureApplicationsSymlink()` call from `AppDelegate.swift:96`.

### Check 5: Git History Diff & Secret Scan
- **Range Scanned**: `main..fix/notchify-deep-audit-performance` (27 commits).
- **Search Scope**: `git log -p` and `git grep` across all commits scanning for Google Gemini (`AIza`), OpenAI (`sk-`), GitHub (`ghp_`), Telegram bot tokens, and private keys.
- **Result**:
  - **Zero production secrets committed**.
  - One synthetic unit test mock found: `Tests/VerificationTests.swift:17` (`testKeychainSecret = "test_keychain_secret_value_123"`, redacted: `test…`).
  - All other matches were in documentation (`GITHUB_SECURITY_AND_SENSITIVE_DATA_AUDIT.md`), placeholder labels in `SecureField`, or regexes in `scripts/security-audit.sh`.
