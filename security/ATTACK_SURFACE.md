# Attack Surface & System Architecture Map

- **Target**: Notchify (Notch) macOS Application
- **Git Commit**: `d3f4b11d1101271e61beaff0e2d1cf78d924f197`
- **Knowledge Graph**: 1,894 nodes, 4,242 edges, 114 semantic communities (Build time: 0.62s)
- **Binary Status**: Mach-O 64-bit thin (arm64), Ad-hoc signed (`flags=0x2`), Unsandboxed, No Hardened Runtime

---

## 1. Secrets & Credentials Inventory

| Credential / Secret | Storage Mechanism | In-Memory Reference | Scope & Accessibility |
| :--- | :--- | :--- | :--- |
| **Google Gemini API Key** | macOS Keychain (`kSecClassGenericPassword`, account: `"gemini_api_key"`) via `KeychainHelper` | `SettingsStore.shared.geminiApiKey` | Used for outbound HTTPS requests to Google Generative Language API. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| **OpenAI API Key** | macOS Keychain (`kSecClassGenericPassword`, account: `"openai_api_key"`) via `KeychainHelper` | `SettingsStore.shared.openAIApiKey` | Used for outbound HTTPS requests to OpenAI Chat Completions API. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |
| **Telegram Bot Token** | macOS Keychain (`kSecClassGenericPassword`, account: `"telegram_bot_token"`) via `KeychainHelper` | `TelegramModule.shared.botToken` | Used for outbound Telegram Bot API requests. Migrated from legacy plaintext `UserDefaults` key `"NotchApp_TelegramBotToken"`. |
| **Google Account OAuth Token** | macOS Keychain (`kSecClassGenericPassword`, account: `"google_oauth_token"`) via `KeychainHelper` | Loaded on-demand in `AskAIService` | Bearer token for Gemini queries via Google account. |
| **Connected Google Email** | `SettingsStore.shared.connectedGoogleEmail` + Keychain account `"google_account_email"` | `SettingsStore.shared.connectedGoogleEmail` | User email address displayed in UI badge. |
| **Ambient Environment Variables** | Inherited process environment (`ProcessInfo.processInfo.environment`) | Process table | Passed verbatim to child processes `cargo` and `thock-cli`, leaking user environment. |
| **Legacy AES Encryption Seed** | Hardcoded static salt string + `IOPlatformUUID` + `NSUserName()` | `KeychainHelper.swift:141` | Deterministic machine-wide seed previously used to encrypt `vault.enc`. Discarded after Keychain migration. |

---

## 2. Data at Rest

| Asset / File | Absolute / Relative Path | Format & Protection | Threat & Access Boundary |
| :--- | :--- | :--- | :--- |
| **User Quick Notes** | `~/Library/Application Support/NotchApp/notes.txt` | Unencrypted UTF-8 text; POSIX `0600` permissions (`-rw-------`) | POSIX 0600 prevents access by *other OS user accounts*, but NOT other applications running under the *same user UID*. Unencrypted at rest. Exposed to local malware, scripts, and Time Machine backups. |
| **Contacts & Chat History** | `~/Library/Application Support/NotchApp/contacts.json` | Unencrypted JSON; POSIX `0600` permissions (`-rw-------`) | Contains names, phone numbers, Telegram handles, and message text. Readable by any un-sandboxed local process running under the user's account. |
| **Application Preferences** | `~/Library/Preferences/com.notch.NotchApp.plist` | Standard macOS binary/XML property list (`UserDefaults`) | Stores UI settings, layout presets, default providers, and connected Google email. |
| **Thock Audio Engine Assets & Settings** | `~/Library/Application Support/Notch/KeySound/` (or `~/Doc/KeySound`) | JSON settings (`.settings.json`, `.favorites.json`) and WAV audio files | User-writable directory. If symlinked to `~/Doc/KeySound`, files can be swapped by any local process. |
| **Temporary PDF & Document Cache** | `NSTemporaryDirectory()/NotchifyStudio/` | Merged/compressed PDF files, image thumbnails | Created with default directory permissions; pruned every 15 minutes by `cleanStaleTempFiles()`. |
| **Exported Files** | User-selected destination via `NSSavePanel` | PDF documents | Written directly to user filesystem. |

---

## 3. Data Leaving the Device (Egress Network & IPC)

| Destination / Endpoint | Protocol & Method | Data Transmitted | Authentication & Parameters |
| :--- | :--- | :--- | :--- |
| `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` | HTTPS POST via `URLSession.shared` | User prompt text + full note content (when note context is attached) + AI system prompt | Header `x-goog-api-key: {apiKey}` or `Authorization: Bearer {oauthToken}`. TLS enforced. |
| `https://api.openai.com/v1/chat/completions` | HTTPS POST via `URLSession.shared` | User prompt text + full note content + AI system prompt | Header `Authorization: Bearer {apiKey}`. TLS enforced. |
| `https://api.telegram.org/bot{token}/sendMessage` | HTTPS POST via `URLSession.shared` | Message text and recipient `chat_id` | **CRITICAL**: Bot token is transmitted as part of the URL path (`/bot{token}/...`), exposing it to web proxies, local proxies, and network access logs. |
| `https://api.telegram.org/bot{token}/getMe` | HTTPS GET via `URLSession.shared` | None | Bot token exposed in URL path. |
| `https://github.com/Dharmit-Parmar/KeySound.git` | HTTPS Git clone via `/usr/bin/git` | None (inbound download of code repo) | Public repository URL. |
| `whatsapp://send?phone={digits}&text={encoded}` | Custom URL scheme via `NSWorkspace.shared.open` | Phone number and message text | Query string parameters; opened in WhatsApp desktop app. |
| `tg://resolve?domain={user}&text={encoded}` | Custom URL scheme via `NSWorkspace.shared.open` | Username/phone and message text | Query string parameters; opened in Telegram desktop app. |
| External URLs via `NSWorkspace.shared.open` | HTTPS GET in default browser | None | Navigation to `aistudio.google.com`, `platform.openai.com`, and `gemini.google.com`. |

---

## 4. Child Processes & Execution Table

| Process Binary | Path Source | Arguments | Working Directory | Environment Passed | Invocation Point |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/usr/bin/git` | Fixed system path | `["clone", "https://github.com/Dharmit-Parmar/KeySound.git", targetDir.path]` | Ambient | Default | `ThockModule.swift:591` |
| `/usr/bin/git` | Fixed system path | `["checkout", "264ef80f73c38b1d45a6c3e69fa127775b7a5e49"]` | `targetDir` | Default | `ThockModule.swift:601` |
| `cargo` | Resolved from `~/.cargo/bin/cargo`, `/opt/homebrew/bin/cargo`, `/usr/local/bin/cargo`, `/usr/bin/cargo` | `["build", "--release", "--bin", "thock-cli"]` | `targetDir` (`~/Library/Application Support/Notch/KeySound`) | **Full ambient environment** (`ProcessInfo.processInfo.environment`) with modified `PATH` | `ThockModule.swift:633` |
| `thock-cli` | Resolved from `targetDir/target/release/thock-cli` or `~/Doc/KeySound` or `~/Documents/KeySound` | `[]` | `projectDir` | **Full ambient environment** with `TERM=xterm-256color` | `ThockModule.swift:690` |
| `/usr/bin/open` | Fixed system path | `["-a", "Siri"]` | Ambient | Default | `AskAIService.swift:380` |

---

## 5. Dynamic Code & Framework Loading

| Framework / Binary | API Used | Symbols Loaded | Purpose & Risks |
| :--- | :--- | :--- | :--- |
| `/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote` | `dlopen(..., RTLD_NOW)` | `MRMediaRemoteGetNowPlayingInfo`, `MRMediaRemoteGetNowPlayingClient`, `MRMediaRemoteGetNowPlayingApplicationPID`, `MRMediaRemoteGetNowPlayingApplicationIsPlaying`, `MRMediaRemoteGetNowPlayingArtwork`, `MRMediaRemoteRegisterForNowPlayingNotifications`, `MRMediaRemoteSendCommand` | Private Apple framework loaded via `unsafeBitCast`. Blocks App Store compliance; prone to ABI breakage or crashes across macOS updates. |
| `/System/Library/Frameworks/IOKit.framework/IOKit` | `dlopen(..., RTLD_NOW)` | `IOHIDCheckAccess`, `IOHIDRequestAccess` | Dynamic check for Input Monitoring permission. |
| Rust Crates & Proc-Macros | `cargo build` | Dynamic execution of `build.rs` scripts during compile | Arbitrary code execution during compilation on host machine. |

---

## 6. macOS Permissions & System Hooks

| Permission / Subsystem | API / Mechanism | Purpose | Security Implication |
| :--- | :--- | :--- | :--- |
| **Accessibility (`AXIsProcessTrusted`)** | `AXIsProcessTrusted()`, `AXIsProcessTrustedWithOptions()` | Automating WhatsApp & Telegram UI to synthesize `key code 36` (Return key) via `NSAppleScript` | High-privilege TCC permission. Allows UI scripting, key synthesis, and inspection of other windows. |
| **Input Monitoring (`IOHIDCheckAccess`)** | `IOHIDCheckAccess(1)`, `IOHIDRequestAccess(1)` | Allowing `thock-cli` to intercept hardware keyboard events globally | High-privilege TCC permission. Capability is equivalent to a hardware keylogger if abused. |
| **Camera (`AVCaptureDevice`)** | `AVCaptureSession`, `AVCaptureDevice.DiscoverySession` | Live mirror preview in the Notch island | TCC privacy boundary. Camera hardware LED illuminates; session stops when Notch collapses. |
| **AppleEvents / System Events** | `NSAppleScript.executeAndReturnError()` | Sending keystrokes to `process "WhatsApp"` and `process "Telegram"` | Declared in Info.plist (`NSAppleEventsUsageDescription`). Allows synthetic keyboard input to background applications. |
| **Calendar (`NSCalendarsUsageDescription`)** | Declared in Info.plist | Mock calendar events | Declared in Info.plist, but EventKit queries are not currently executed. |
| **Global Event Monitors** | `NSEvent.addGlobalMonitorForEvents` | 1. Outside-click window collapse<br>2. Escape key detection<br>3. Companion typing cadence animation | Monitors keystrokes globally while active. Code review confirms key codes are discarded without logging content. |
| **System Pasteboard** | `NSPasteboard.general` | 1. **Silent copy of note text + prompt to clipboard on Siri trigger** (`AskAIService.swift:367`)<br>2. Copying app path to clipboard (`PermissionsHelper.swift:157`)<br>3. Copying notes / AI responses on user action | **Information Disclosure**: Silently writing private note content to the global system clipboard exposes data to any background application with pasteboard access. |

---

## 7. File System Impact & Symlink Surface

- **`/Applications/Notch.app` & `/Applications/NotchApp.app`**:
  - `PermissionsHelper.ensureApplicationsSymlink()` checks if `/Applications` is writable and creates or replaces symlinks pointing to the git repository development directory (`projectDir.appendingPathComponent("NotchApp.app")`).
  - Calls `FileManager.default.removeItem(atPath:)` on existing `/Applications/Notch.app` entries.
- **`~/Applications/Notch.app` & `~/Applications/NotchApp.app`**:
  - Automatically created in user home directory; overwrites existing entries.
- **`~/Library/Application Support/Notch/KeySound`**:
  - `ThockModule.swift:580` creates a symlink from `targetDir` to `~/Doc/KeySound` if the local directory exists.
- **`$DIR/NotchApp`**:
  - `run_notch.sh:19` creates a visible symlink to `.build/release/NotchApp`.

---

## 8. Build, Signing, and Hardening Configuration

- **Bundle ID**: `com.notch.NotchApp`
- **Signing Identity**: Ad-hoc (`codesign --sign -`)
- **Hardened Runtime**: **DISABLED** (Flags: `0x2(adhoc)`, missing `runtime` / `0x10000`)
- **Library Validation**: **DISABLED** (Allows arbitrary dylib loading)
- **App Sandbox**: **DISABLED** (Zero entitlements file; full access to user filesystem and system APIs)
- **Info.plist Deficiencies**:
  - Missing `NSContactsUsageDescription` (DirectMessenger queries contact names and handles).
  - Missing `NSMicrophoneUsageDescription`.
  - Missing App Transport Security (`NSAppTransportSecurity`) dictionary.
