# Threat Model & STRIDE Analysis (gsd-secure-phase)

- **Target**: Notchify (Notch) macOS Application
- **Date**: 2026-11-11
- **Methodology**: Microsoft STRIDE Threat Modeling & GSD Secure Phase Verification
- **Trust Boundaries Evaluated**:
  1. *Host OS / Kernel Boundary*: TCC Permissions (Accessibility, Input Monitoring, Camera, AppleEvents).
  2. *Inter-Process Boundary*: Local processes under same macOS user UID vs un-sandboxed NotchApp.
  3. *Child Process Boundary*: NotchApp vs child processes (`git`, `cargo`, `thock-cli`).
  4. *Network Egress Boundary*: App memory vs external cloud endpoints (Google Gemini, OpenAI, Telegram).
  5. *Storage Boundary*: App memory vs local disk (`notes.txt`, `contacts.json`, Keychain).

---

## 1. Feature Area Threat Registers (STRIDE)

### Area 1: Notes (`NoteStorageManager.swift`)
- **Assets**: User notes, personal scratchpad, drafts, clipboard contents.
- **Entry Points**: `NotesWidgetView` text view, AI insertion, disk file load.
- **Trust Boundaries**: App memory vs local filesystem; un-sandboxed app vs other local apps.
- **Threat Actors**: Other local processes under same user UID, Time Machine / cloud backups, shoulder-surfers.
- **STRIDE Analysis**:
  - *Information Disclosure*: `notes.txt` stored in plaintext at `~/Library/Application Support/NotchApp/notes.txt`. POSIX `0600` permissions protect against other OS users, but provide ZERO protection against other applications running under the same user account.
  - *Information Disclosure (Clipboard)*: Triggering Siri via `AskAIService.triggerSiri` silently copies the entire note context to `NSPasteboard.general` without user awareness.
  - *Tampering*: Any un-sandboxed local process can modify `notes.txt` directly without detection.
- **Existing Mitigations**:
  - `NoteStorageManager.swift:93-94`: `try? data.write(to: target, options: .atomic)` with `try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)`.
- **Gaps**: No encryption at rest (CryptoKit AES-GCM or `NSFileProtectionComplete`); silent clipboard population leaks private text.

---

### Area 2: Ask AI (`AskAIService.swift`)
- **Assets**: Gemini API key, OpenAI API key, Google OAuth token, user prompts, system prompts, AI responses.
- **Entry Points**: AI widget text field, note context passed via action shortcuts, remote API responses.
- **Trust Boundaries**: Local app vs third-party LLM cloud servers; user prompt vs system prompt.
- **Threat Actors**: Network observers, remote MITM, prompt injectors, local processes inspecting Keychain/memory.
- **STRIDE Analysis**:
  - *Information Disclosure*: Unredacted note context sent across network to Google and OpenAI servers.
  - *Tampering / Prompt Injection*: Indirect prompt injection via malicious note content or clipboard text can override `SettingsStore.shared.aiSystemPrompt` instructions.
  - *Denial of Service*: Unbounded response parsing or network timeouts blocking UI.
- **Existing Mitigations**:
  - Keys stored in Keychain via `KeychainHelper` (`AskAIService.swift:145, 162, 171`).
  - TLS enforced on all REST endpoints (`https://...`).
  - Auth tokens passed in HTTP request headers (`x-goog-api-key`, `Authorization: Bearer`), avoiding URL query strings (`AskAIService.swift:325, 427, 486`).
  - `messages` history capped at 40 items (`AskAIService.swift:190, 250`).
- **Gaps**: Un-sandboxed app lacks Keychain Access Groups; prompt injection mitigations (spotlighting, delimiter guards) are absent when forwarding note context.

---

### Area 3: Telegram & Direct Messaging (`TelegramModule.swift`)
- **Assets**: Telegram Bot token, recipient chat IDs / phone numbers, outgoing message text.
- **Entry Points**: Bot token field, contact input, send button, Telegram Bot API response.
- **Trust Boundaries**: App memory vs Telegram API servers; app memory vs URL access logs.
- **Threat Actors**: Web proxies, network packet loggers, local processes.
- **STRIDE Analysis**:
  - *Information Disclosure (CRITICAL)*: Telegram Bot token is embedded in the URL path: `https://api.telegram.org/bot\(token)/sendMessage` (`TelegramModule.swift:179`). URLs are logged in plain text by network monitoring tools, proxies, and web servers.
  - *Elevation of Privilege / Account Takeover*: Anyone obtaining the bot token gains complete control over the bot, including reading incoming messages and impersonating the bot.
- **Existing Mitigations**:
  - Token migrated from legacy UserDefaults to Keychain (`TelegramModule.swift:376`).
  - Timeout enforced on URLRequest (8.0s) (`TelegramModule.swift:200`).
- **Gaps**: Telegram Bot API protocol mandates token in URL path for simple HTTP clients; local proxy logging exposes token. Legacy plaintext token migration leaves residue if UserDefaults was backed up.

---

### Area 4: Thock Audio Engine (`ThockModule.swift`)
- **Assets**: Child process execution integrity, host environment variables, system stability.
- **Entry Points**: Git clone repository (`https://github.com/Dharmit-Parmar/KeySound.git`), local dev paths (`~/Doc/KeySound`), cargo compilation, stdin pipe commands.
- **Trust Boundaries**: Notch application vs third-party source repository; Notch vs child process `thock-cli`.
- **Threat Actors**: Malicious repository commit, compromised Rust dependency/proc-macro, local unprivileged process tampering with dev directory.
- **STRIDE Analysis**:
  - *Remote / Local Code Execution*: `cargo build --release --bin thock-cli` runs during setup without `--locked`, executing untrusted `build.rs` and macro code on the host machine.
  - *Information Disclosure (HIGH)*: Notch passes the entire ambient environment (`ProcessInfo.processInfo.environment`), including API keys, tokens, and credentials, to both `cargo` and `thock-cli` (`ThockModule.swift:636, 693`).
  - *Denial of Service / Process Injection*: `sweepOrphanProcesses()` terminates any process with `ppid == 1` whose executable path ends in `/thock-cli` (`ThockModule.swift:274`). Stale PID reuse when sending `kill(pid, SIGSTOP)` / `SIGCONT`.
  - *Command Injection*: Stdin commands constructed via string interpolation (`"pack \(pack.name)"` in `ThockModule.swift:794`).
- **Existing Mitigations**:
  - Git checkout pinned to commit SHA `264ef80f73c38b1d45a6c3e69fa127775b7a5e49` (`ThockModule.swift:56, 601`).
- **Gaps**: Ambient environment leakage; untrusted binary resolution order (`~/Doc/KeySound` before App Support); arbitrary process killing in `sweepOrphanProcesses`.

---

### Area 5: Mirror Camera (`MirrorModule.swift`)
- **Assets**: Live video stream, camera hardware LED status.
- **Entry Points**: `AVCaptureSession` video frames.
- **Trust Boundaries**: Camera sensor vs UI view; active foreground state vs background collapse.
- **Threat Actors**: Shoulder surfer, malicious dylib injecting into un-sandboxed process.
- **STRIDE Analysis**:
  - *Information Disclosure*: Background video capture if camera fails to shut down on collapse.
- **Existing Mitigations**:
  - Camera stops running when Notch collapses (`NotchShellCoordinator.swift:20`).
  - Camera stops running on app termination (`AppDelegate.swift:299-300`).
  - Hardware green LED illuminates while camera is powered.
- **Gaps**: Un-sandboxed process without hardened runtime is vulnerable to code injection.

---

### Area 6: DirectMessenger Automation (`TelegramModule.swift`)
- **Assets**: macOS Accessibility privileges, user chat window focus.
- **Entry Points**: Send button click.
- **Trust Boundaries**: Notch app vs macOS Accessibility / System Events.
- **Threat Actors**: Local malicious process, concurrent user window interactions.
- **STRIDE Analysis**:
  - *Tampering / Accidental Dispatch*: Uses AppleScript to send `key code 36` (Return) 450ms after opening URL (`asyncAfter(deadline: .now() + 0.45)` in `TelegramModule.swift:86, 143`). If window focus changes or lag occurs, Return key is pressed in the wrong application.
- **Existing Mitigations**:
  - Checks `AXIsProcessTrusted()` before executing AppleScript (`TelegramModule.swift:85, 142`).
- **Gaps**: Blind, unverified keystroke synthesis without confirming target window focus.

---

### Area 7: Shelf, File Studio & AirDrop (`ShelfModule.swift`)
- **Assets**: User files on disk, temporary cache directory.
- **Entry Points**: External drag-and-drop of files, file export panel.
- **Trust Boundaries**: Untrusted file inputs vs internal PDF/image parsers.
- **Threat Actors**: Malicious dropped file (crafted PDF exploit), directory traversal.
- **STRIDE Analysis**:
  - *Tampering / Path Traversal*: `exportURL(for doc:)` uses `doc.fileName` without path sanitization (`ShelfModule.swift:295, 299`), allowing directory traversal if a file name contains `../`.
  - *Denial of Service*: Processing oversized PDF files in memory without size limits.
- **Existing Mitigations**:
  - Detached asynchronous Tasks for processing (`ShelfModule.swift:414`).
  - `cleanStaleTempFiles()` purges temporary files older than 15 minutes (`ShelfModule.swift:209`).
- **Gaps**: Lack of path sanitization against `../` in `exportURL`; absence of file size bounds on imported documents.

---

### Area 8: Companion Typing Mimic (`CompanionCoordinator.swift`)
- **Assets**: Keystroke privacy.
- **Entry Points**: `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`.
- **Trust Boundaries**: macOS global event stream vs app memory.
- **Threat Actors**: Malware sniffing keystrokes.
- **STRIDE Analysis**:
  - *Information Disclosure (Keylogging)*: Risk of intercepting and recording keystrokes globally.
- **Existing Mitigations**:
  - Key event details are discarded (`_ in` in `CompanionCoordinator.swift:172`); only increments a cadence counter `recentKeystrokes += 1`.
- **Gaps**: Code is currently listen-only; must remain strictly verified.

---

### Area 9: Permissions & Symlink Management (`PermissionsHelper.swift`)
- **Assets**: `/Applications` and `~/Applications` directory integrity.
- **Entry Points**: App launch (`AppDelegate.swift:96`).
- **Trust Boundaries**: Git repository directory vs System and User Applications directories.
- **Threat Actors**: Local symlink manipulation.
- **STRIDE Analysis**:
  - *Tampering / Data Loss*: `ensureApplicationsSymlink()` calls `removeItem(atPath:)` on existing `/Applications/Notch.app` and `~/Applications/Notch.app` and replaces them with symlinks to `projectDir` (`PermissionsHelper.swift:59, 83`).
- **Existing Mitigations**:
  - Checks `isWritableFile(atPath: "/Applications")`.
- **Gaps**: Destructive deletion and replacement of application bundles.

---

### Area 10: Contacts & Calendar (`TelegramModule.swift`, `CalendarModule.swift`)
- **Assets**: User contact book, phone numbers, chat logs.
- **Entry Points**: Contact creation form, `contacts.json` on disk.
- **Trust Boundaries**: App memory vs disk storage.
- **Threat Actors**: Other local processes under same user UID.
- **STRIDE Analysis**:
  - *Information Disclosure*: `contacts.json` stores all contact names, phone numbers, and chat message histories in cleartext.
- **Existing Mitigations**:
  - POSIX `0600` permissions on `contacts.json` (`TelegramModule.swift:477`).
- **Gaps**: Unencrypted storage of personal messaging history at rest.

---

### Area 11: Build, Signing & Packaging (`run_notch.sh`)
- **Assets**: Binary cryptographic identity, TCC privacy persistence.
- **Entry Points**: Shell build script.
- **Trust Boundaries**: Local compiler output vs macOS Gatekeeper and TCC.
- **Threat Actors**: Local unprivileged processes.
- **STRIDE Analysis**:
  - *Elevation of Privilege / TCC Degradation*: Ad-hoc signing (`codesign --sign -`) generates random code directory hashes on each compilation, invalidating TCC permissions. Launches raw executable instead of `.app` bundle.
- **Existing Mitigations**:
  - Automated build script.
- **Gaps**: Missing Hardened Runtime (`--options runtime`), missing entitlements file, missing Developer ID code signature.

---

## 2. Verification of Claimed Mitigations (Code vs Claims)

| Claimed Mitigation (in Code / Docs / UI) | Claim Source | Verified Code Reality | Verdict |
| :--- | :--- | :--- | :--- |
| *"Hardware-Bound AES-256-GCM Secure Secret Vault with zero password prompt interruptions"* | `KeychainHelper.swift:6` (legacy comment) | Migrated to native macOS Keychain Services (`kSecClassGenericPassword`). Legacy vault was derived from `IOPlatformUUID` and user name, not Secure Enclave hardware keys. | **OVERSTATED (Migrated)** |
| *"Zero dotfile probing & zero external file snooping"* | `AskAIService.swift:130, 296` | `detectLocalGoogleAccount()` returns `nil` (`AskAIService.swift:131`). Zero dotfiles read. | **VERIFIED CLEAN** |
| *"POSIX 0600 Sandboxed Storage isolates files from other OS user accounts"* | `SECURITY_AUDIT_REPORT.md:14` | Sets `[.posixPermissions: 0o600]` on `notes.txt` and `contacts.json`. Protects against other OS user accounts, but NOT other apps under same user account. | **PARTIALLY TRUE (No Sandbox)** |
| *"100% Background Silent Sending without opening windows"* | `SettingsView.swift:1476` | Uses Telegram Bot API over HTTPS or `whatsapp://` URL scheme followed by AppleScript Return key synthesis. | **VERIFIED (With Timing Caveat)** |
| *"All API tokens and credentials are encrypted using Apple's native Security framework"* | `SECURITY_AUDIT_REPORT.md:12` | Saved via `SecItemAdd` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. | **VERIFIED** |
| *"Camera & AppleEvents privacy descriptions present"* | `scripts/security-audit.sh:64` | `NSCameraUsageDescription` and `NSAppleEventsUsageDescription` are present. `NSContactsUsageDescription` is missing. | **INCOMPLETE DECLARATIONS** |
| *"Immutable pinned Git commit SHA verification"* | `ThockModule.swift:56` | Checks out pinned SHA `264ef80f73...`, but `cargo build` is run without `--locked`. | **PARTIALLY VERIFIED** |
