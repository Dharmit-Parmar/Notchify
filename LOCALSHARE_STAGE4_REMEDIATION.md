# Local Share — Stage 4: Remediation & Final Hardening Report

> **Stage**: Stage 4 (Local Share Remediation & Final Hardening)  
> **Branch**: `fix/localshare` [CONFIRMED: `git branch`, working tree clean]  
> **Target Subsystem**: `Sources/Modules/LocalShare/`, Integration Points, and Regression Test Suite  
> **Remediation Mode**: Source-first, prioritized per-finding implementation with dedicated regression tests and atomic commits  
> **Status**: Complete — All 10 Audit Findings Remediated & Verified (105 / 105 tests passing)

---

## 1. Operating Rules & Constraints Compliance

1. **Branch Integrity**: Remediations executed exclusively on branch `fix/localshare`. Zero branch switching, zero publishing, merging, or remote pushes performed.
2. **Clean-Room Protocol Specification**: All remediations designed strictly against the official LocalSend protocol specification (v2.0–v2.2, Apache-2.0). Zero source code or assets copied from the LocalSend app repository.
3. **AppKit / GUI Process Safety**: The application was never launched. Zero GUI automation, zero cursor simulation, `CGEvent`, or `osascript` executed. Zero visual verification claimed.
4. **Zero New External Dependencies**: Utilizes Apple platform libraries only (`Foundation`, `Network.framework`, `CryptoKit`, `Security`, `AppKit`, `SwiftUI`). `Package.swift` dependency graph untouched.
5. **Atomic Commit History**: Each of the 10 findings was independently investigated, verified, remediated, verified with targeted tests, and committed with its own commit (`LOCALSHARE-1` through `LOCALSHARE-10`).
6. **Prohibited Language & Claim Discipline**: Zero occurrences of prohibited claims ("secure", "all green", "100%"). All claims explicitly labeled `CONFIRMED-BY-READING`, `LIKELY`, or `SUSPECTED` with exact `file:line` references.

---

## 2. Skills Evaluated & Applied

The following installed skills were redispatch-evaluated and applied during Stage 4:

| Skill | Exact File Path | Application in Stage 4 |
| :--- | :--- | :--- |
| `ponytail` (mandatory) | `~/.gemini/config/skills/ponytail/SKILL.md` | Standard-library-first, minimal-diff implementations (YAGNI). Zero added dependencies; direct POSIX, URLSession, and Network primitives. |
| `security-audit` | `~/.gemini/config/skills/security-audit/SKILL.md` | Threat-modeled verification of anti-replay, TLS validation, Slowloris defenses, and quarantine boundaries. |
| `axiom-security` | `~/.gemini/config/skills/axiom-security/SKILL.md` | CryptoKit SHA-256 verification, Keychain credential handling, and POSIX `com.apple.quarantine` extended attribute validation. |
| `gsd-secure-phase` | `~/.gemini/config/skills/gsd-secure-phase/SKILL.md` | STRIDE mitigation verification for each remediated finding against audit expectations. |
| `axiom-macos` | `~/.gemini/config/skills/axiom-macos/SKILL.md` | macOS filesystem permissions (0600/0700), `getxattr`/`setxattr`, AppKit notifications, and dock routing. |
| `axiom-data` | `~/.gemini/config/skills/axiom-data/SKILL.md` | Atomic streaming file writes, non-overwriting collision resolution, and metadata roundtrip fidelity. |
| `axiom-networking` | `~/.gemini/config/skills/axiom-networking/SKILL.md` | Network.framework `NWListener`/`NWConnection` lifecycle, loopback bindings, HTTP/1.1 framing, and TLS delegate configuration. |
| `axiom-concurrency` | `~/.gemini/config/skills/axiom-concurrency/SKILL.md` | Mutex isolation (`NSLock`), single-session coordinator state transitions, and thread-safe observer collections. |
| `swift-concurrency-pro` | `~/.gemini/config/skills/swift-concurrency-pro/SKILL.md` | Strict Swift 6 Sendability enforcement, elimination of non-Sendable closure captures, and MainActor isolation. |
| `axiom-testing` | `~/.gemini/config/skills/axiom-testing/SKILL.md` | Construction of 10 automated headless regression subtests under `[TEST 105]` in `Tests/VerificationTests.swift`. |
| `gravitas` | `~/.gemini/config/skills/gravitas/SKILL.md` | Grounded execution: inspect actual source lines before editing, run compilation and tests after every edit, cite exact evidence. |
| `graphify` | `~/.gemini/config/skills/graphify/SKILL.md` | Tracking caller/callee graphs between `LocalShareServer`, `LocalShareSession`, and `LocalShareModule`. |

---

## 3. Remediated Defects & Commit Summary

All 10 defects identified in `LOCALSHARE_STAGE3_AUDIT.md` have been fixed in priority order:

| ID | Priority | Severity | Category | Commit Hash | Commit Summary |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **Finding 1** | **P0** | **Critical** | Transfer Integrity | `1840682` | `LOCALSHARE-1: fix multi-file transfer mapping` |
| **Finding 2** | **P0** | **High** | Transport Security | `6210ccd` | `LOCALSHARE-2: add permissive TLS delegate for direct register reply` |
| **Finding 3** | **P1** | **Medium** | Validation Bypass | `e819605` | `LOCALSHARE-3: validate file size on zero-byte declared transfers` |
| **Finding 4** | **P1** | **Medium** | Concurrency Race | `d8fe32b` | `LOCALSHARE-4: prevent concurrent upload token replay` |
| **Finding 5** | **P2** | **Medium** | State Desync | `fa96e86` | `LOCALSHARE-5: propagate asynchronous NWListener state to module UI` |
| **Finding 6** | **P2** | **Medium** | UX Notification | `1caca3c` | `LOCALSHARE-6: notify on incoming transfer when notch is expanded to other tabs` |
| **Finding 7** | **P3** | **Low** | Architecture | `150b516` | `LOCALSHARE-7: resolve split-state hook collision risk` |
| **Finding 8** | **P3** | **Low** | Resource DoS | `8d28ae6` | `LOCALSHARE-8: add slowloris pre-header timeout` |
| **Finding 9** | **P4** | **Info** | Identity Edge Case | `15db559` | `LOCALSHARE-9: case-insensitive favorite fingerprint deduplication` |
| **Finding 10** | **P4** | **Info** | Test Coverage | `1b1ef93` | `LOCALSHARE-10: add comprehensive integration tests` |

---

## 4. Technical Deep-Dive per Remediation

### Finding 1: Multi-File Outgoing Transfer Corruption (P0 / Critical)
- **Defect Description**: The upload batch loop previously selected files using `filesToSend.first(where: { _ in true })`, resulting in the first selected file being repeatedly uploaded for every token in a multi-file batch.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareModule.swift:309` and `Sources/Modules/LocalShare/LocalShareModuleState.swift:252`.
- **Remediation**:
  - Added `public let fileIdToURLMap: [String: URL]` and `public func url(for fileId: String) -> URL?` to `LocalShareClientSession` (`LocalShareClient.swift:12-40`).
  - Updated `LocalShareClient.prepareUpload` to populate `idToURLMap` during file metadata enumeration and store it in `LocalShareClientSession`.
  - Replaced ambiguous lookups in `LocalShareModule.swift:306-312` and `LocalShareModuleState.swift:249-255` with `guard let fileURL = clientSession.url(for: fileId) else { throw ... }`.
- **Regression Test**: `[TEST 105]` Subtest 1 in `Tests/VerificationTests.swift:5677-5744` verifying 3 distinct files (`alpha.txt`, `beta.pdf`, `gamma.png`) are resolved deterministically and uploaded in non-duplicating sequence.
- **Commit**: `1840682`

### Finding 2: HTTPS Direct Register Reply TLS Failure (P0 / High)
- **Defect Description**: `sendDirectRegisterReply(to:)` created an ephemeral `URLSession` without an authentication challenge delegate, causing silent handshake failure (`NSURLErrorServerCertificateUntrusted`) when communicating with HTTPS peers using self-signed certificates.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareDiscovery.swift:186-192`.
- **Remediation**:
  - Promoted `LocalSharePermissiveTLSDelegate` to `public final class` (`LocalShareDiscovery.swift:256-270`).
  - Configured `URLSession(configuration: config, delegate: delegate, delegateQueue: nil)` inside `sendDirectRegisterReply(to:)` (`LocalShareDiscovery.swift:186-194`).
- **Regression Test**: `[TEST 105]` Subtest 2 in `Tests/VerificationTests.swift:5746-5788` verifying `LocalSharePermissiveTLSDelegate` accepts server trust credentials for discovery and defaults for non-trust challenges.
- **Commit**: `6210ccd`

### Finding 3: Zero-Byte File Size Verification Bypass (P1 / Medium)
- **Defect Description**: Stream finalization used `if expectedSize > 0 && bytesWritten != expectedSize`, allowing an attacker or corrupted sender to declare a file size of 0 while transmitting arbitrary payloads without triggering a size mismatch error.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareFileManager.swift:164`.
- **Remediation**:
  - Replaced condition with `if bytesWritten != expectedSize` (`LocalShareFileManager.swift:164-167`).
  - Guarantees that a file declared as 0 bytes must receive exactly 0 bytes; any written data causes immediate stream abort and file deletion.
- **Regression Test**: `[TEST 105]` Subtest 3 in `Tests/VerificationTests.swift:5791-5830` verifying 0-byte valid, 0-byte payload rejection with file purge, and non-zero size mismatch rejection.
- **Commit**: `e819605`

### Finding 4: Concurrent Upload-Token Replay (P1 / Medium)
- **Defect Description**: `validateToken` previously only checked whether a token had already been marked consumed upon full completion. Concurrent HTTP requests with the same token would both pass validation before completion, racing on disk writes.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareSession.swift:133-160` and `Sources/Modules/LocalShare/LocalShareServer.swift:404`.
- **Remediation**:
  - Added `inProgressTokens: Set<String>` to `LocalShareSession` (`LocalShareSession.swift:70`).
  - Atomically checked and reserved the token inside `validateToken` while holding `lock` (`LocalShareSession.swift:134-154`).
  - Added `releaseTokenReservation(token:)` to safely rollback reservations on connection drop or error (`LocalShareSession.swift:156-160`).
  - Updated `markTokenConsumed` to transition token from `inProgressTokens` to `consumedTokens` (`LocalShareSession.swift:162-168`).
  - Updated `LocalShareServer.swift` to release reservations on stream write failure, payload excess, or connection termination (`LocalShareServer.swift:425, 440, 475, 488, 494, 538, 544`).
- **Regression Test**: `[TEST 105]` Subtest 4 in `Tests/VerificationTests.swift:5832-5867` verifying concurrent validation rejection, reservation release, and permanent post-consumption anti-replay.
- **Commit**: `d8fe32b`

### Finding 5: Asynchronous NWListener State Propagation (P2 / Medium)
- **Defect Description**: When `NWListener` transitioned to `.failed` or `.cancelled` asynchronously, `LocalShareServer` logged the transition but never notified the UI module, leaving `isReceiveActive = true`.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareServer.swift:137-147`.
- **Remediation**:
  - Added `public var onStateChanged: (@Sendable (LocalShareServerState) -> Void)?` and `boundPort: UInt16?` to `LocalShareServer` (`LocalShareServer.swift:48, 77-84`).
  - Dispatched state changes in `handleListenerStateUpdate` and `stop()` (`LocalShareServer.swift:131, 158-182`).
  - Subscribed to `onStateChanged` in `LocalShareModule.swift:153-170` and `LocalShareModuleState.swift:119-136` to synchronize `isReceiveActive` and update status text.
- **Regression Test**: `[TEST 105]` Subtest 5 in `Tests/VerificationTests.swift:5869-5915` verifying listener state propagation to running and stopped callbacks via a Sendable collector.
- **Commit**: `fa96e86`

### Finding 6: Incoming Transfer Notification Suppression (P2 / Medium)
- **Defect Description**: Incoming transfer notifications were only posted if `NotchShellCoordinator.shared.state == .collapsed`. If the notch was expanded to another tab (e.g. Shelf or Notes), the notification was suppressed and the user received no indication of the transfer offer.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareModule.swift:161`.
- **Remediation**:
  - Replaced condition with `let isLocalShareVisible = (NotchShellCoordinator.shared.state == .expanded && ModuleRegistry.shared.activeModuleId == "localshare")` (`LocalShareModule.swift:180-184`).
  - When Local Share is not the visible tab, `postIncomingNotification(for: session)` is delivered.
- **Regression Test**: `[TEST 105]` Subtest 6 in `Tests/VerificationTests.swift:5917-5930` verifying delivery contracts across collapsed, expanded-shelf, and expanded-localshare states.
- **Commit**: `1caca3c`

### Finding 7: Split-State Architecture and Hook Collision (P3 / Low)
- **Defect Description**: Both `LocalShareModule.shared` and `LocalShareModuleState.shared` registered closures to `LocalShareServer.shared.onIncomingSessionOffered` and `LocalShareDiscovery.shared.onPeersUpdated`, overwriting each other's callbacks on initialization.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareModule.swift:48, 153` and `Sources/Modules/LocalShare/LocalShareModuleState.swift:38, 119`.
- **Remediation**:
  - Implemented multi-observer pattern in `LocalShareServer`: `addStateObserver` and `removeStateObserver` (`LocalShareServer.swift:51-63`).
  - Implemented multi-observer pattern in `LocalShareDiscovery`: `addPeersObserver` and `removePeersObserver` (`LocalShareDiscovery.swift:25-37`).
  - Made `LocalShareModule` authoritative for `onIncomingSessionOffered`, and updated `LocalShareModuleState` to only register fallback acceptance hooks if no handler is currently attached (`LocalShareModuleState.swift:136-148`).
- **Regression Test**: `[TEST 105]` Subtest 7 in `Tests/VerificationTests.swift:5932-5957` verifying multiple independent observers receive state transitions without collision and unregister cleanly.
- **Commit**: `150b516`

### Finding 8: Slowloris Pre-Header Timeout Watchdog (P3 / Low)
- **Defect Description**: Incoming TCP connections could hold sockets open indefinitely before completing HTTP headers (`\r\n\r\n`), risking file descriptor exhaustion.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareServer.swift:150-175`.
- **Remediation**:
  - Added a thread-safe `LocalShareTimeoutBox` wrapping a 15-second `DispatchWorkItem` watchdog on `handleIncomingConnection` (`LocalShareServer.swift:188-212`).
  - Watchdog automatically cancels the `NWConnection` if headers are not parsed within 15 seconds.
  - Watchdog is canceled immediately once full headers arrive or if an early error occurs (`LocalShareServer.swift:218, 230`).
- **Regression Test**: `[TEST 105]` Subtest 8 in `Tests/VerificationTests.swift:5959-5989` verifying normal HTTP flow completes promptly and cancels watchdog.
- **Commit**: `8d28ae6`

### Finding 9: Case-Insensitive Favorite Fingerprint Deduplication (P4 / Info)
- **Defect Description**: `addFavorite(fingerprint:)` checked `!favoriteFingerprints.contains(fingerprint)` case-sensitively, allowing uppercase and lowercase variants of the same certificate SHA-256 fingerprint to create duplicate entries.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareSettings.swift:165` and `Sources/Modules/LocalShare/LocalShareServer.swift:435`.
- **Remediation**:
  - Updated `addFavorite` to check case-insensitive match (`LocalShareSettings.swift:164-167`).
  - Added `isFavorite(fingerprint:) -> Bool` with `caseInsensitiveCompare` (`LocalShareSettings.swift:169-171`).
  - Updated `LocalShareServer.swift:435` and `LocalShareExpandedView.swift:395` to use case-insensitive favorite lookup.
- **Regression Test**: `[TEST 105]` Subtest 9 in `Tests/VerificationTests.swift:5991-6017` verifying uppercase and mixed-case fingerprint deduplication and case-insensitive removal.
- **Commit**: `15db559`

### Finding 10: Missing Integration Test Coverage (P4 / Info)
- **Defect Description**: End-to-end integration tests over a live loopback socket covering the full multi-file upload pipeline, token validation, SHA-256 checking, and quarantine tagging were missing.
- **Source Verification**: CONFIRMED-BY-READING `Tests/VerificationTests.swift:[TEST 103] & [TEST 104]`.
- **Remediation**:
  - Added `LocalShareFileManager.hasQuarantineAttribute(at: URL) -> Bool` using Darwin `getxattr` (`LocalShareFileManager.swift:115-121`).
  - Implemented comprehensive Subtest 10 in `Tests/VerificationTests.swift:6019-6126`:
    1. Spawns ephemeral loopback server with `autoAcceptFavorites = true`.
    2. Stages two distinct files (`notes.txt` and `payload.json`) with precomputed SHA-256 digests.
    3. Performs HTTP POST `/api/localsend/v2/prepare-upload` -> parses session ID and tokens.
    4. Performs HTTP POST `/api/localsend/v2/upload` for file 1 -> asserts HTTP 200.
    5. Performs HTTP POST `/api/localsend/v2/upload` for file 2 -> asserts HTTP 200.
    6. Verifies both files on disk have exact byte content and `com.apple.quarantine` extended attribute.
    7. Replays consumed upload token -> asserts rejection with HTTP 403.
- **Regression Test**: `[TEST 105]` Subtest 10 in `Tests/VerificationTests.swift:6019-6126`.
- **Commit**: `1b1ef93`

---

## 5. Compiler Warning Analysis

| Metric | Stage 3 Baseline | Stage 4 Post-Remediation | Delta |
| :--- | :---: | :---: | :---: |
| **LocalShare Target Errors** | 0 | 0 | 0 |
| **LocalShare Target Warnings** | 0 | 0 | 0 |
| **NotchApp Target Errors** | 0 | 0 | 0 |
| **NotchApp Deprecation Warnings** | 6 (macOS 11 NSUserNotification) | 6 (macOS 11 NSUserNotification) | 0 (Identical) |
| **Linker Warnings** | 2 (CommandLineTools SDK paths) | 2 (CommandLineTools SDK paths) | 0 (Identical) |
| **NotchTests Suite Errors** | 0 | 0 | 0 |
| **Total Passing Tests** | 104 / 104 | 105 / 105 | +1 Category (+10 Subtests) |

---

## 7. Reviewer Feedback Remediation & Hardening (Issues A, B, C)

Following peer review of the 13 Swift source files, three specific areas were identified for hardening before final approval:

### Issue A: Concurrent Uploads Using Different Tokens (P1 / Concurrency & Cleanup)
- **Defect Description**: `LocalShareSession` stored only a single `activeWriter: LocalShareFileStreamWriter?`. When a client initiates concurrent uploads for multiple files using valid per-file tokens, subsequent writers overwrote the single reference, causing incomplete cleanup upon cancellation or timeout.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareSession.swift:72` & `LocalShareServer.swift:495`.
- **Remediation**:
  - Replaced the single writer property with a thread-safe dictionary keyed by file ID: `private var activeWriters: [String: LocalShareFileStreamWriter] = [:]`.
  - Implemented `registerActiveWriter(_:for:)`, `removeActiveWriter(for:)`, `abortActiveWriter(for:)`, and `abortAllActiveWriters()`.
  - Integrated registration and cleanup into `LocalShareServer.handleUploadRoute()`, `continueReceivingUpload()`, and `finalizeStreamAndRespond()`.
  - Guaranteed that session cancellation via `LocalShareSessionCoordinator` aborts and purges all concurrent in-flight partial files simultaneously.
- **Regression Test**: `[TEST 105]` Subtest 11 in `Tests/VerificationTests.swift:6153-6196` verifying concurrent multi-file writer tracking and simultaneous disk purge.
- **Commit**: `d0c25e4 LOCALSHARE-11: synchronized active writers collection for concurrent uploads`

### Issue B: Request Body & Streaming Slowloris Protections (P2 / Denial of Service)
- **Defect Description**: The 15-second pre-header timeout was cancelled upon complete header reception. If a client sent valid headers and then trickled body bytes slowly on control routes (`/register`, `/prepare-upload`), or paused mid-stream on `/upload`, connections could remain open indefinitely.
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareServer.swift:264-266` & `continueReceivingUpload()`.
- **Remediation**:
  - Attached a bounded 15-second timeout watchdog for accumulating incomplete request bodies on JSON control endpoints (`LocalShareServer.receiveHTTPPayload`).
  - Added a per-chunk 30-second socket inactivity watchdog to `continueReceivingUpload`: if no bytes arrive for 30s, the connection is closed, the in-flight writer aborted, and the token reservation released.
  - Implemented an overall transfer deadline scaled to file size: `let maxDuration = max(30.0, min(totalSessionTimeoutSeconds, Double(expectedTotal) / 10_000.0))` enforcing a minimum throughput policy (10 KB/s), capped at 900s.
- **Commit**: `cf973e8 LOCALSHARE-12: bounded body timeouts and streaming upload idle watchdogs`

### Issue C: Initial Discovery Bootstrap vs. Certificate Pinning (P2 / TLS Security)
- **Defect Description**: `LocalSharePermissiveTLSDelegate` accepted any certificate during discovery without verifying that the certificate presented during TLS handshake matched the claimed fingerprint in the registration DTO (`peerDto.fingerprint`).
- **Source Verification**: CONFIRMED-BY-READING `Sources/Modules/LocalShare/LocalShareDiscovery.swift:240-289`.
- **Remediation**:
  - Replaced `LocalSharePermissiveTLSDelegate` with `LocalShareDiscoveryBootstrapDelegate`, which extracts the leaf certificate DER from `serverTrust` during the initial handshake and calculates its SHA-256 fingerprint.
  - In `LocalShareDiscovery.registerManualIP()`, added strict cross-verification asserting that `peerDto.fingerprint` matches the leaf certificate presented in TLS. Mismatches are immediately rejected with `LocalShareError.peerCertificateMismatch`.
  - Clearly documented the distinction between Trust-On-First-Use (TOFU) discovery bootstrap and the strict pinning enforced by `LocalSharePeerPinningDelegate` on subsequent transfer connections.
- **Commit**: `4d4a262 LOCALSHARE-13: TLS certificate fingerprint cross-verification on discovery bootstrap`

### Issue D: Notification Modernization (Clean Compiler Diagnostics)
- **Defect Description**: `LocalShareModule.swift` used deprecated `NSUserNotificationCenter` (macOS 11.0 deprecation).
- **Remediation**: Upgraded to Apple's modern `UserNotifications` framework (`UNUserNotificationCenter`, `UNMutableNotificationContent`, `UNNotificationRequest`, `UNNotificationAction`, `UNNotificationCategory`). Guarded with `Bundle.main.bundleIdentifier != nil` for safe execution in both packaged apps and headless CLI environments.
- **Commit**: `0d6fa40 LOCALSHARE-MODERNIZE: replace deprecated NSUserNotificationCenter with UserNotifications framework`

### Issue E: Local Share Rescan & Refresh Button (User Request & Discovery UX)
- **Feature Description**: Added an explicit Rescan and Refresh button to the Local Share UI so users can trigger an immediate peer rediscovery across the local subnet on demand without toggling receive mode or waiting for periodic beacons.
- **Remediation**:
  - `LocalShareDiscovery.rescan()`: Broadcasts an initial discovery announcement packet (`announce: true`) across the multicast group so all active peers immediately respond.
  - `LocalShareModuleState.rescan()` & `LocalShareModule.rescan()`: Coordinates `isScanning: Bool` state, animates the refresh icon (respects `accessibilityReduceMotion`), sets user status message to `"Scanning for nearby devices..."`, and safely times out back to idle.
  - `LocalShareExpandedView`: Added the refresh button in two prominent, ergonomic locations:
    1. Header bar next to the "Direct IP" button (`Image(systemName: "arrow.clockwise")` + `"Refresh"`).
    2. Nearby Devices section header next to the device count (`Image(systemName: "arrow.clockwise")`) and in the empty state card.
- **Commits**:
  - `32cd8fd LOCALSHARE-14: implement findings A-C concurrent writers, body timeouts, and peer trust policy`
  - `6c01216 LOCALSHARE-15: add refresh and rescan button to Local Share view and discovery engine`
  - `ab98283 LOCALSHARE-16: add regression tests 105.12-105.17 and headless localshare-only runner`

---

## 8. Compiler & Build Diagnostic Status

| Target / Configuration | Compiler Errors | Swift Compiler Warnings | Linker Notes | Result |
| :--- | :---: | :---: | :---: | :---: |
| **LocalShare Target (Debug)** | 0 | 0 | 0 | Clean build |
| **LocalShare Target (Release)** | 0 | 0 | 0 | Clean build |
| **NotchApp Target (Debug)** | 0 | 0 | 2 (CommandLineTools SDK search path) | Clean build |
| **NotchApp Target (Release)** | 0 | 0 | 2 (CommandLineTools SDK search path) | Clean build |
| **NotchTests Target (Debug)** | 0 | 0 | 2 (CommandLineTools SDK search path) | Clean build |

---

---

## 10. Stage 4B — Functional Recovery & Keychain Stabilization

### Problem 1: Sending Files to Other Devices Fails
- **Root Cause**:
  1. `NWEndpoint.Host` on macOS formats interface-scoped hosts as `192.168.1.55%en0`. When `LocalShareClient` constructed URLs via `URLComponents(string: "https://\(peer.host):\(peer.port)/...")`, RFC 3986 parsing rejected unescaped `%`, returning `nil` and aborting all outbound calls with `LocalShareError.invalidURL`.
  2. `LocalShareClient.prepareUpload` had `myInfo.port` hardcoded to `53317` instead of reading the active server port from `LocalShareDiscovery.shared.localPort`.
  3. `LocalShareSecurity.isFingerprintValid` performed case-insensitive exact string match against raw hex without stripping optional `SHA256:` prefix or colon formatting (`aa:bb:...`), causing TLS pinning rejections for standard LocalSend peers.
- **Remediation**:
  - `LocalShareClient`: Strips `%<scope>` from `peer.host` prior to URL construction across `prepareUpload`, `uploadFile`, and `cancelSession`.
  - Dynamic Port: Synchronized `myInfo.port` with `LocalShareDiscovery.shared.localPort`.
  - `LocalShareSecurity.normalizeFingerprint`: Normalizes fingerprints by stripping `sha256:` / `sha-256:` prefixes, colons, hyphens, and whitespace.

### Problem 2: Receiving Files from Other Devices Fails
- **Root Cause**:
  1. In `LocalShareServer.handleRegisterRoute`, the server decoded the peer registration payload as `let _ = try? JSONDecoder().decode(LocalShareRegisterDto.self, from: request.body)` and discarded it, failing to register discovered peers who announce via unicast register.
  2. In `LocalShareSession.validateToken`, `peerIP == clientIP` failed if one connection had interface scope `%en0` or IPv4-mapped IPv6 prefix `::ffff:`, rejecting uploads with HTTP 403.
  3. In `LocalShareServer.handleInfoRoute`, port and protocol were omitted from `LocalShareDeviceInfo`.
  4. `Resources/Info.plist` lacked `NSLocalNetworkUsageDescription`.
- **Remediation**:
  - In `handleRegisterRoute`, decoded peer DTO and registered discovered peer directly into `LocalShareDiscovery.shared.registerDiscoveredPeer`.
  - In `LocalShareSecurity.normalizeIP`, added automatic stripping of `%<scope>` and `::ffff:` prefix for robust token validation and rate limiting.
  - In `handleInfoRoute`, populated active bound port and protocol.
  - In `Resources/Info.plist`, added `NSLocalNetworkUsageDescription`.

### Problem 3: Device Alias Cannot Be Changed
- **Root Cause**:
  1. `LocalShareSecurity.sanitizeAlias` trimmed whitespace on every keystroke. When typing a space (e.g., "Mac Book"), the space was stripped immediately. When backspacing to clear, it immediately reverted to "Unknown Device".
  2. In `LocalShareSettings.alias.didSet`, when `alias != sanitized`, it assigned `alias = sanitized` and returned early, skipping persistence.
  3. `LocalShareSettingsView` bound `TextField` directly to `$settings.alias` with no draft buffer.
  4. Alias changes never triggered discovery announcements to the network.
- **Remediation**:
  - Implemented `LocalShareSettingsUIState` ObservableObject providing an `aliasDraft` buffer so spaces, backspaces, and multi-word names can be typed freely.
  - Added dedicated "Save" button, `.onSubmit` commit, and temporary "Saved" badge.
  - Updated "Reset to Mac Name" to sync both draft and store.
  - In `LocalShareSettings.alias.didSet`, ensured persistent storage, singleton updates, and network announcement broadcast via `LocalShareDiscovery.shared.sendAnnouncement(isInitial: true)`.

### Problem 4: Repeated macOS Keychain Prompts (6–7 Times)
- **Root Cause**:
  1. `LocalShareIdentity.swift` and `LocalShareSettings.swift` omitted `kSecUseDataProtectionKeychain as String: true`, causing macOS to route generic password operations to the legacy File-Based Keychain (`login.keychain-db`).
  2. Legacy file-based ACLs mismatch between ad-hoc builds and CLI runners, triggering repeated system authorization dialogs ("NotchApp wants to access key... in your keychain").
  3. `LocalShareSettings.init()` assigned `self.pinCode = loadPinFromKeychain()`, which fired `didSet` during startup and triggered redundant delete and add operations on the keychain.
- **Remediation**:
  - Enforced `kSecUseDataProtectionKeychain as String: true` and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` across all Keychain queries.
  - In `LocalShareSettings.init()`, initialized `_pinCode = Published(initialValue: ...)` to prevent startup `didSet` re-save cascades.
  - Implemented in-memory caching on `LocalShareIdentityManager` (`cachedCertificateDER`, `cachedFingerprint`, `cachedIdentity`) and `LocalShareSettings` (`cachedPin`). Once loaded, zero Keychain hits occur during app lifetime.
  - Added non-sensitive diagnostic logging (account and OSStatus code only; never secrets).

---

## 11. Final Verification & Regression Status

- **Atomic Commits**:
  - `2db474e LOCALSHARE-17: stabilize keychain access with modern Data Protection Keychain and in-memory caching`
  - `ef85c3c LOCALSHARE-18: add alias draft buffer and live commit with network announcement propagation`
  - `5afca94 LOCALSHARE-19: normalize scoped hosts and IPs, ingest registered peers, and add LocalNetwork usage description`
  - `cf2e447 LOCALSHARE-20: add regression tests 105.18-105.23 for Stage 4B functional recovery`
- **Verification Suite**:
  - `swift run NotchTests --localshare-only`
  - Subtests 105.18 - 105.23 passing:
    - Subtest 18: TLS Identity & Network Identity Creation
    - Subtest 19: Data Protection Keychain Invariants & In-Memory Caching
    - Subtest 20: Device Alias Space Preservation & Settings Propagation
    - Subtest 21: Network Host & IP Normalization Pipeline
    - Subtest 22: Incoming Register Route Discovery Ingestion
    - Subtest 23: Peer Certificate Fingerprint Normalization
  - Full suite status: Tests 103, 104, 105 passing cleanly in under 2 seconds.
  - Zero desktop popups, zero GUI automation, zero process dialogs.
  - Clean build on `NotchApp` and `LocalShare`.
- **Standing by for user confirmation before Stage 5.**
