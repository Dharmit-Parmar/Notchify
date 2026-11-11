# Notchify Behavior & Invariant Contract (Stage A)

- **Target Repository**: Notchify (`/Users/dharmitparmar/Doc/Notch`)
- **Active Branch**: `fix/security-round1`
- **Baseline Commit**: `TEST: baseline`
- **Status**: LOCKED (86/86 automated headless verification tests passing)
- **Prime Directive**: UI (layout, sizes, colors, typography, animations, hit areas) and runtime behavior (speed, features, settings, saved data) remain identical across all security patches.

---

## 1. Finding-to-Contract Mapping Matrix

Every finding from `security/VERIFIED_FINDINGS.md` is mapped to its immutable behavior contract and the automated test that proves compliance.

| Finding ID | Security Defect | Required Invariant (What Must Stay Identical) | Proving Test |
|---|---|---|---|
| **SEC-E-2** | Destructive symlink removal in `/Applications` at launch | Application launching, status item creation, and panel presentation must never fail. No existing files, user installations, or external symlinks in `/Applications` or `~/Applications` are ever deleted. | `Test 1`, `Test 8`, `Test 86.4` |
| **SEC-C-1** | Full ambient environment leaked to child processes | Child processes (`git clone`, `git checkout`, `cargo build`, `thock-cli`) receive all necessary variables (`PATH`, `HOME`, `USER`, `LANG`, `TERM`, `CARGO_HOME`, `RUSTUP_HOME`) to operate reliably, but ambient secrets (e.g. AWS tokens, GitHub tokens) are never forwarded. | `Test 23`, `Test 86.3`, `Test 86.4` |
| **SEC-C-2** | Unlocked runtime `cargo build` | When building Thock, `--locked` enforces exact dependency resolution from `Cargo.lock` (verified present in commit `264ef80…`). Build output and binary execution remain identical. | `Test 35`, `Test 86.2` |
| **SEC-C-3** | Untrusted search path hierarchy in user folders | Current working Thock engine on user's machine (`/Users/dharmitparmar/Doc/KeySound/target/release/thock-cli`) MUST continue working without prompting, failing, or triggering a rebuild. New installations default strictly to Application Support. Binary validation ensures regular file, user ownership, and restricted permissions. | `Test 35`, `Test 42`, `Test 86.4` |
| **SEC-C-4** | Overbroad orphan cleanup (`hasSuffix("/thock-cli")`) | Stale background `thock-cli` processes spawned by Notch are cleanly swept on restart/quit, while unrelated processes belonging to other users or tools are never touched. | `Test 8`, `Test 23`, `Test 86.3` |
| **SEC-C-5** | Stdin command injection via newlines in pack names | Commands sent to `thock-cli` (`"vol N"`, `"pack X"`, `"asmr …"`) produce exact newline-terminated strings. All 14 known sound packs (`banana_split_lubed`, `alpacas`, `cherry_mx_blue`, `creams`, `gateron_black_ink`, etc.) load, sort, and switch identically. | `Test 24`, `Test 26`, `Test 86.1`, `Test 86.3` |
| **SEC-E-1** | Path traversal in `exportURL(for doc:)` | Standard filenames (`"My Doc" -> "My Doc.pdf"`, `"a.pdf" -> "a.pdf"`, `"" -> "Resultant_Document.pdf"`) export with identical filenames and locations. Traversal sequences (`../`, `/etc/passwd`) are stripped safely without breaking normal names. | `Test 16`, `Test 86.7` |
| **SEC-A-3** | Silent clipboard exfiltration on Siri trigger | Triggering Siri via Ask AI opens `/System/Applications/Siri.app` or dispatches via NSWorkspace identically. Note context is no longer silently broadcast to `NSPasteboard.general`. User-initiated copy buttons remain unchanged. | `Test 69`, `Test 72`, `Test 86.8` |
| **SEC-B-1** | Telegram Bot token in URL path and error messages | Telegram bot messages are dispatched reliably via HTTP POST. Network error strings shown in `lastDispatchStatus` inform the user of delivery status without exposing raw bot tokens or request URLs. | `Test 3`, `Test 86.8` |
| **SEC-B-2** | Unbounded prompt injection via note context | Notes context forwarded to Gemini or OpenAI is clearly demarcated with data delimiters and capped at 2,000 characters. Responses continue to be parsed and displayed identically in Notes and Ask AI widgets. | `Test 69`, `Test 86.8` |
| **SEC-A-1** | Unencrypted plaintext storage of `notes.txt` | Notes maintain debounced autosave, immediate save on collapse, POSIX 0600 permissions, instant load on launch, and undo/redo support. Migration from existing plaintext `notes.txt` is seamless and lossless. | `Test 38`, `Test 74`, `Test 86.5` |
| **SEC-A-2** | Unencrypted plaintext storage of `contacts.json` | Pinned contacts, conversation history, and chat messages load and persist with identical schema and performance. Migration from existing plaintext `contacts.json` is seamless. | `Test 3`, `Test 86.6` |
| **SEC-A-4** | Keychain access controls & lifecycle | Keychain secrets (`gemini_api_key`, `openai_api_key`, `telegram_bot_token`) are stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Secrets are deleted upon explicit signout or clearing text fields. | `Test 65`, `Test 86.9` |
| **SEC-F-2** | Outdated security audit script | `scripts/security-audit.sh` checks are strictly additive: verifying file permissions of encrypted stores and Info.plist usage descriptions. No existing audit gates are weakened. | `Test 67` |

---

## 2. Baseline Test Suite Verification Record

- **Test Target**: `NotchTests` (`Tests/VerificationTests.swift`)
- **Compilation**: Clean (`0` errors, `0` warnings)
- **Total Test Suites**: 86 passing tests:
  - Tests 1–85: Original regression & feature suite (Window geometry, wallpaper extraction, direct messaging, AirDrop, MediaRemote bridge, camera preview, calendar grid, single instance, PDF merge/compress/enhance, jog wheel, dock navigation, tray reordering, collapse state machine, sound persistence, dashboard bento layout, OKLab color engine, motion physics, energy governor, battery widget).
  - Test 86: Baseline characterization test suite covering all 9 contract domains (Subtests 86.1 through 86.9).
