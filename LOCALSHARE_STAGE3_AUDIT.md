# Local Share — Stage 3: Security, Privacy & Energy Audit Report

> **Stage**: Stage 3 (Security, Privacy & Energy Audit)  
> **Branch**: `fix/localshare` [CONFIRMED: `git status`, commit tree clean]  
> **Target Subsystem**: `Sources/Modules/LocalShare/` & Application Integration Points  
> **Audit Mode**: Source-first, static & dynamic analysis, headless verification  
> **Status**: Complete — Audit Only (No production modifications applied)

---

## 1. Executive Summary

A comprehensive source-level and behavioral audit was conducted across the entire Local Share implementation, encompassing network transport, cryptographic identity, HTTP/HTTPS parsing, LocalSend protocol compatibility (v2.0–v2.2), macOS security and sandbox boundaries, power/energy lifecycle, and concurrency invariants.

### Key Audit Highlights:
- **Clean-Room Implementation**: Confirmed strictly independent; zero lines of code or asset resources copied from the LocalSend repository.
- **Transport Security**: Mandatory TLS 1.2/1.3 with P-256 ECDSA identity stored in macOS Keychain (`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). Peer SHA-256 certificate pinning is enforced on client upload.
- **Filesystem Safety**: Automatic POSIX mode 0700 session folder isolation, strict filename sanitization, traversal containment, non-overwriting destination naming, streaming SHA-256 verification, and `com.apple.quarantine` extended attribute tagging.
- **Defects Identified**: The audit discovered **2 High/Critical functional & security defects**, **4 Medium defects**, and **4 Low/Informational findings**:
  1. *[CRITICAL]* Multi-file outgoing transfers repeatedly upload only the first file in the array due to a broken file lookup predicate (`LocalShareModule.swift:309` / `LocalShareModuleState.swift:252`).
  2. *[HIGH]* Direct unicast registration replies over HTTPS fail silently due to an unconfigured TLS delegate in `LocalShareDiscovery.swift:187`.
  3. *[MEDIUM]* Zero-byte declared files bypass size-verification checks upon stream finalization (`LocalShareFileManager.swift:164`).
  4. *[MEDIUM]* Concurrent upload requests with the same token can execute simultaneously due to deferred token consumption (`LocalShareSession.swift:133-160`).
  5. *[MEDIUM]* Asynchronous `NWListener` failures leave the UI in a stale "Receive Active" state (`LocalShareServer.swift:137`).
  6. *[MEDIUM]* Incoming transfers to an expanded notch on another module (e.g. Shelf) suppress user notifications and provide no visual banner, hanging until timeout (`LocalShareModule.swift:161`).

All 104 existing tests in `NotchTests` pass with exit code 0, but the audit revealed significant test gaps (mocked HTTP transports without TLS, lack of multi-file integration tests, and absence of end-to-end HTTPS handshake tests).

---

## 2. Exact Branch & Working-Tree State

- **Active Branch**: `fix/localshare` [CONFIRMED: `git branch`]
- **Working Tree**:
  - `git status` confirms zero commits made ahead of user instruction; all changes are staged/unstaged within `fix/localshare`.
  - No remote pushes, branch switches, or merges performed.
  - Zero external SPM or CocoaPods dependencies added to `Package.swift`.

---

## 3. Skills Evaluated & Applied

| Skill Name | Exact SKILL.md Path | Applied in Audit? | Specific Role in Audit |
| :--- | :--- | :--- | :--- |
| `ponytail` | `/Users/dharmitparmar/.gemini/config/skills/ponytail/SKILL.md` | Yes (Mandatory) | Guided minimal root-cause remediation designs; ensured solutions use native Swift/Darwin stdlib and avoid speculative abstractions. |
| `security-audit` | `/Users/dharmitparmar/.gemini/config/skills/security-audit/SKILL.md` | Yes | Governed STRIDE threat modeling, candidate gate, trust boundary verification, and evidence-backed vulnerability classification. |
| `axiom-security` | `/Users/dharmitparmar/.gemini/config/skills/axiom-security/SKILL.md` | Yes | Audited Keychain accessibility levels (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), P-256 key generation, and certificate pinning. |
| `gsd-secure-phase` | `/Users/dharmitparmar/.gemini/config/skills/gsd-secure-phase/SKILL.md` | Yes | Verified threat mitigations against original STRIDE matrix and checked for security regressions. |
| `axiom-macos` | `/Users/dharmitparmar/.gemini/config/skills/axiom-macos/SKILL.md` | Yes | Evaluated macOS App Sandbox constraints, quarantine tagging (`com.apple.quarantine`), and `NSUserNotificationCenter` behavior. |
| `axiom-data` | `/Users/dharmitparmar/.gemini/config/skills/axiom-data/SKILL.md` | Yes | Audited `UserDefaults` persistence, atomic disk writes, bounded transfer history (10 items), and FIFO eviction. |
| `axiom-networking` | `/Users/dharmitparmar/.gemini/config/skills/axiom-networking/SKILL.md` | Yes | Inspected `NWListener`, `NWConnection`, and `NWConnectionGroup` socket lifecycles, keepalive settings, and framing boundaries. |
| `axiom-concurrency` | `/Users/dharmitparmar/.gemini/config/skills/axiom-concurrency/SKILL.md` | Yes | Audited Swift 6 concurrency, actor isolation boundaries, and `NSLock` isolation on shared mutable state. |
| `swift-concurrency-pro` | `/Users/dharmitparmar/.gemini/config/skills/swift-concurrency-pro/SKILL.md` | Yes | Verified `@MainActor` dispatching, checked for unstructured task leaks, and verified Sendable compliance. |
| `axiom-testing` | `/Users/dharmitparmar/.gemini/config/skills/axiom-testing/SKILL.md` | Yes | Analyzed test suite coverage in `VerificationTests.swift`, identified false positives, and designed missing test plans. |
| `gravitas` | `/Users/dharmitparmar/.gemini/config/skills/gravitas/SKILL.md` | Yes | Enforced strict ground-truth verification; required observed terminal output for all build and test status assertions. |
| `graphify` | `/Users/dharmitparmar/.gemini/config/skills/graphify/SKILL.md` | Yes | Analyzed cross-module symbol dependencies and SPM target partitioning. |

---

## 4. Files Inspected

### Production Implementation Files (`Sources/Modules/LocalShare/`)
1. `LocalShareProtocol.swift` (299 lines): Data Transfer Objects, enums, error models, constants.
2. `LocalShareIdentity.swift` (288 lines): P-256 key generation, ASN.1 DER encoder, Keychain storage, SHA-256 fingerprint.
3. `LocalShareSecurity.swift` (253 lines): Filename sanitization, path containment, disk space check, rate limiter.
4. `LocalShareFileManager.swift` (199 lines): Base and session directories, streaming atomic writer, quarantine tagging.
5. `LocalShareSession.swift` (328 lines): Session state machine, single-use file tokens, session coordinator.
6. `LocalShareServer.swift` (597 lines): `NWListener` HTTPS server, HTTP framing, route dispatcher, file upload stream sink.
7. `LocalShareDiscovery.swift` (268 lines): `NWConnectionGroup` UDP multicast discovery, announcement suppression, manual IP.
8. `LocalShareClient.swift` (310 lines): `URLSession` HTTPS client, peer certificate pinning delegate, upload/cancel APIs.
9. `LocalShareSettings.swift` (225 lines): Persistent settings, alias sanitization, Keychain PIN storage.
10. `LocalShareModuleState.swift` (341 lines): Headless engine, peer lists, active session state, bounded history.
11. `LocalShareModule.swift` (495 lines): `NotchModule` conformance, lifecycle, notification delegate, popover balance.
12. `LocalShareExpandedView.swift` (571 lines): SwiftUI expanded notch interface, radar animation, nearby peers list.
13. `LocalShareSettingsView.swift` (280 lines): SwiftUI settings section in `modules_advanced`.

### Integration & Shell Files
14. `Sources/App/AppDelegate.swift`: Module registration and factory mapping.
15. `Sources/Core/NotchModule.swift`: Theme color mapping and enabled modules list.
16. `Sources/Notch/NotchRootView.swift`: Subtitle ribbon, global drop handler, dock tab drag-and-drop routing.
17. `Sources/Settings/SettingsView.swift`: Embedding of `LocalShareSettingsView()` inside advanced settings.
18. `Sources/Notch/NotchShellCoordinator.swift`: Popover tracking and notch collapse mechanics.
19. `Sources/Core/KeychainHelper.swift`: System keychain conventions and error handling.
20. `Package.swift`: Target boundaries, dependencies, and file exclusions.

---

## 5. Security Audit — STRIDE Findings

```
              ┌────────────────────────────────────────────────────────┐
              │           LOCAL SHARE STRIDE THREAT MODEL              │
              └────────────────────────────────────────────────────────┘
                 │
                 ├── [S] Spoofing: Peer certificate pinning & alias sanitization
                 │                 (Finding 2: Unicast reply TLS failure)
                 │
                 ├── [T] Tampering: Streaming SHA-256 & quarantine tagging
                 │                 (Finding 1: Multi-file array desync)
                 │                 (Finding 3: 0-byte file size bypass)
                 │                 (Finding 4: Token race condition)
                 │
                 ├── [R] Repudiation: Bounded transfer history (10 items)
                 │                    Zero secret leakage in error logs
                 │
                 ├── [I] Information Disclosure: Keychain PIN storage
                 │                               Path traversal containment
                 │
                 ├── [D] Denial of Service: Disk checks & rate limiting
                 │                          (Finding 8: Pre-header slowloris)
                 │
                 └── [E] Elevation of Privilege: 0700 folder mode, no auto-exec
                                                 (Finding 6: Stale notification)
```

### 5.1 Spoofing (S)
- **Certificate Identity & Fingerprints**:
  - P-256 self-signed certificates are generated on first launch and stored in Keychain [CONFIRMED: `LocalShareIdentity.swift:157-163`].
  - Fingerprint is calculated as SHA-256 of the DER-encoded certificate [CONFIRMED: `LocalShareIdentity.swift:110-113`].
  - Peer certificate pinning delegate strictly evaluates leaf DER hash [CONFIRMED: `LocalShareClient.swift:295-306`].
- **Discovery Spoofing**:
  - Self-announcements are rejected by matching the local fingerprint [CONFIRMED: `LocalShareDiscovery.swift:130`].
  - Remote aliases are sanitized (stripped of control characters and capped at 32 characters) [CONFIRMED: `LocalShareSecurity.swift:194-205`].
- **Defect Found**: `sendDirectRegisterReply(to:)` fails to connect to peers over HTTPS because it lacks a permissive TLS delegate for self-signed certificates (see Finding 2).

### 5.2 Tampering (T)
- **File Integrity**:
  - File writer computes SHA-256 incrementally during streaming [CONFIRMED: `LocalShareFileManager.swift:149`].
  - Mismatch triggers immediate file deletion and returns HTTP 422 [CONFIRMED: `LocalShareFileManager.swift:174`, `LocalShareServer.swift:541`].
- **Path Traversal & Symlinks**:
  - `isContained(fileName:within:)` standardizes paths and resolves symlinks [CONFIRMED: `LocalShareSecurity.swift:72-85`].
  - Session folders are isolated under `session-<UUID>/` with restricted POSIX mode `0700` [CONFIRMED: `LocalShareFileManager.swift:60`].
- **Defects Found**:
  - Multi-file outgoing transfers repeatedly send the first file due to a faulty lookup predicate (see Finding 1).
  - 0-byte declared files bypass size-verification checks (see Finding 3).
  - Concurrent upload requests with identical tokens can execute concurrently (see Finding 4).

### 5.3 Repudiation (R)
- **Transfer History**:
  - Bounded to 10 items, storing peer alias, file names, byte size, date, direction, and status text [CONFIRMED: `LocalShareSettings.swift:5-31`, `LocalShareModule.swift:415-430`].
  - No secret tokens, PINs, or internal directory paths are stored in history.
- **Logging & Error Scrubbing**:
  - Zero raw `print()` statements exist in production files [CONFIRMED: `grep -rn "print(" Sources/Modules/LocalShare/` returned 0 results].
  - `LocalShareSecurity.scrubSecrets(from:)` scrubs `token=`, `sessionId=`, `pin=`, and `/Users/username` before exposing error messages [CONFIRMED: `LocalShareSecurity.swift:162-190`].

### 5.4 Information Disclosure (I)
- **PIN Storage**:
  - PIN code is stored strictly in macOS Keychain under service `com.notch.NotchApp.LocalShare` and account `localshare_pin_code` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` [CONFIRMED: `LocalShareSettings.swift:191-198`].
  - Raw PIN is never written to `UserDefaults`.
- **Filesystem Concealment**:
  - The HTTP server addresses files solely by random string `fileId` and opaque session tokens. Internal directory paths are never returned in HTTP responses.
- **Transport Encryption**:
  - Plaintext HTTP is disabled by default. Server only accepts TLS connections when `enableTLS: true`.

### 5.5 Denial of Service (DoS)
- **Disk Exhaustion Mitigation**:
  - Server verifies system available capacity before accepting transfers: requires `requiredBytes + 500 MB` buffer [CONFIRMED: `LocalShareSecurity.swift:131-149`].
  - Maximum files per session: 500 files [CONFIRMED: `LocalShareSecurity.swift:8`].
  - Maximum individual file size: 50 GB [CONFIRMED: `LocalShareSecurity.swift:9`].
  - Maximum JSON body size: 1 MB [CONFIRMED: `LocalShareSecurity.swift:10`].
- **Single Active Session Mutex**:
  - Server accepts strictly 1 active session at a time; concurrent offers receive HTTP 409 [CONFIRMED: `LocalShareSession.swift:275`].
- **Rate Limiting**:
  - Sliding-window rate limiter restricts clients to 10 requests per second per IP [CONFIRMED: `LocalShareServer.swift:47`, `LocalShareSecurity.swift:221-246`].
- **Defect Found**: Idle pre-header connections lack an explicit timeout watchdog, allowing slowloris socket exhaustion (see Finding 8).

### 5.6 Elevation of Privilege (E)
- **Execution Boundaries**:
  - Received files are never launched, executed, or previewed automatically.
  - Finder revelation uses `NSWorkspace.shared.selectFile(..., inFileViewerRootedAtPath:)` [CONFIRMED: `LocalShareFileManager.swift:102`].
- **Quarantine Attributes**:
  - `LocalShareFileManager.applyQuarantineAttribute(to:)` writes `com.apple.quarantine` using `setxattr`, ensuring macOS Gatekeeper prompts on first launch [CONFIRMED: `LocalShareFileManager.swift:106-111`].

---

## 6. Critical Protocol Audit (LocalSend v2.0–v2.2)

| Protocol Element | Protocol Spec v2.0–v2.2 | Local Share Implementation | Conformance Status | Notes / Discrepancies |
| :--- | :--- | :--- | :--- | :--- |
| **Protocol Version** | Payload string `"2.0"` | `"2.0"` | **CONFORMS** [CONFIRMED] | Defined in `LocalShareConstants.protocolVersion`. |
| **Multicast Group** | `224.0.0.167:53317` | `224.0.0.167:53317` | **CONFORMS** [CONFIRMED] | Bound via `NWMulticastGroup`. |
| **Default Port** | `53317` | `53317` | **CONFORMS** [CONFIRMED] | Overridable in Settings. |
| **Endpoint: `/register`** | POST, device info DTO | POST, handles & replies DTO | **PARTIAL** [CONFIRMED] | Incoming handling conforms; outgoing unicast register reply fails on HTTPS (Finding 2). |
| **Endpoint: `/prepare-upload`**| POST, JSON metadata + ?pin= | POST, verifies PIN, quota, space | **CONFORMS** [CONFIRMED] | Returns sessionId and file tokens map. |
| **Endpoint: `/upload`** | POST, binary stream + query params | POST, streams to disk in 64KB chunks | **CONFORMS** [CONFIRMED] | Query params: `sessionId`, `fileId`, `token`. |
| **Endpoint: `/cancel`** | POST, ?sessionId= | POST, purges session folder | **CONFORMS** [CONFIRMED] | Cleans up session directory immediately. |
| **Endpoint: `/info`** | GET, returns device info | GET, returns `LocalShareDeviceInfo` | **CONFORMS** [CONFIRMED] | Supports discovery polling. |
| **HTTP Status: 401** | Unauthorized / PIN Required | 401 on missing or incorrect PIN | **CONFORMS** [CONFIRMED] | LocalSend v2.1 feature. |
| **HTTP Status: 403** | Declined by user | 403 on user decline | **CONFORMS** [CONFIRMED] | Clean session cancellation. |
| **HTTP Status: 409** | Blocked by active session | 409 on concurrent transfer | **CONFORMS** [CONFIRMED] | Single-session mutex enforced. |
| **HTTP Status: 422** | Checksum mismatch | 422 on SHA-256 mismatch | **CONFORMS** [CONFIRMED] | LocalSend v2.2 feature. |
| **HTTP Status: 429** | Too Many Requests | 429 on rate limit exceeded | **CONFORMS** [CONFIRMED] | LocalSend v2.1 feature. |

---

## 7. macOS Security, Permissions & Privacy

1. **Keychain Access Controls**:
   - Items are saved with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Secrets are not synchronized to iCloud Keychain and are bound to the local hardware [CONFIRMED: `LocalShareIdentity.swift:256`, `LocalShareSettings.swift:196`].
2. **App Sandbox Compatibility**:
   - The application writes strictly inside `~/Downloads/LocalShare` (or user-selected directories via `NSOpenPanel`).
   - If App Sandbox is enabled in future app targets, `com.apple.security.network.server` and `com.apple.security.network.client` entitlements will be required to bind `NWListener` and connect `URLSession`.
3. **Local Network Privacy (macOS 15+)**:
   - macOS 15 triggers a system prompt when binding UDP multicast (`224.0.0.167`) or listening on TCP.
   - If denied, `NWMulticastGroup` fails silently and `NWListener` transitions to `.failed`. As noted in Finding 5, this failure is currently unobserved by the UI.
4. **Quarantine Flag**:
   - Extended attribute `com.apple.quarantine` is applied to every finalized incoming file [CONFIRMED: `LocalShareFileManager.swift:180`].

---

## 8. Energy, Resource & Lifecycle Audit

1. **Receive OFF Invariant**:
   - When Receive mode is OFF (the default), `LocalShareServer` is completely stopped. Zero TCP ports are opened, zero background threads run, and LAN port scans receive `Connection Refused` [CONFIRMED: `LocalShareServer.swift:119-128`].
2. **Foreground Discovery Only**:
   - Multicast UDP broadcasting and reception run strictly while the Local Share module is active in an expanded notch [CONFIRMED: `LocalShareModule.swift:65-73`].
   - When the user selects another module (AirDrop, Shelf, etc.) or when the notch collapses, `stopDiscovery()` is invoked immediately, stopping the `NWConnectionGroup` and conserving CPU/radio energy.
3. **Timer & Polling Absence**:
   - Zero polling loops or timers exist in the runtime. Sockets and transfers are completely event-driven via `Network.framework` and `URLSession` delegate callbacks.
4. **Sleep/Wake & Termination**:
   - When the application collapses the notch, `ModuleRegistry.shared.stopAll()` invokes `module.stop()` [CONFIRMED: `NotchShellCoordinator.swift:21`].
   - If Receive mode is enabled, the background `NWListener` remains ready for incoming transfers.

---

## 9. Concurrency & Thread-Safety Audit

1. **Actor Isolation**:
   - `LocalShareModule`, `LocalShareModuleState`, `LocalShareSettings`, and views are isolated to `@MainActor` [CONFIRMED: `LocalShareModule.swift:12`, `LocalShareSettings.swift:34`].
   - Asynchronous callbacks crossing thread boundaries use `Task { @MainActor in ... }` to mutate published properties safely.
2. **Mutex Protection on Shared Singletons**:
   - `LocalShareServer`, `LocalShareSession`, `LocalShareSessionCoordinator`, `LocalShareDiscovery`, and `LocalShareFileManager` are guarded with `NSLock` instances ensuring thread-safe state access across concurrent network queues.
3. **Popover Open/Close Balance**:
   - `markTransferActive()` and `markTransferFinished()` call `NotchShellCoordinator.shared.registerPopoverOpened()` and `registerPopoverClosed()`, ensuring balanced reference counting during transfers.

---

## 10. Test Audit & Existing Verification Gaps

### Current Test Execution:
- Command: `swift run NotchTests`
- Result: **104 / 104 test suites passing** (Exit code 0).
- `[TEST 103]` (20 subtests) and `[TEST 104]` (20 subtests) pass all assertions.

### Verification Gaps & Deficiencies:
1. **Loopback HTTPS Handshake Untested**:
   - Tests 103 (Subtests 15, 16, 17, 18) and Test 104 (Subtest 17) explicitly started `LocalShareServer` with `enableTLS: false`!
   - Actual TLS handshake and certificate pinning against `LocalShareServer` was never tested in loopback.
2. **Multi-File Client Upload Untested**:
   - `LocalShareClient.uploadFile` was tested only in isolation, never in a multi-file batch via `sendFiles`. Consequently, the bug where only the first file is sent (Finding 1) was not caught by tests.
3. **Direct Registration Reply Untested**:
   - `sendDirectRegisterReply` was never executed against a self-signed HTTPS endpoint in the test suite, allowing the missing permissive TLS delegate (Finding 2) to slip through.
4. **Zero-Byte File Upload Untested**:
   - No test verified uploading a file with declared size 0 containing non-zero bytes (Finding 3).

---

## 11. Confirmed Vulnerabilities & Defects

### Finding 1: Multi-File Batch Outgoing Transfer Desynchronization
- **Severity**: **Critical**
- **Status**: **CONFIRMED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareModule.swift:308-314` and `Sources/Modules/LocalShare/LocalShareModuleState.swift:251-257`
- **Evidence**:
  ```swift
  for (fileId, token) in prepResp.files {
      guard let fileURL = filesToSend.first(where: { _ in true }) else { continue } // Match file
      try await LocalShareClient.shared.uploadFile(...)
  ```
- **Scenario**: When sending multiple files (e.g. `[A, B, C]`), `filesToSend.first(where: { _ in true })` always selects `A`. File `A` is transmitted 3 times under different tokens, while `B` and `C` are never uploaded.
- **Impact**: Severe data transfer corruption. Recipient receives duplicated files instead of the intended batch.
- **Minimal Fix**: Map each `fileId` to its exact `URL` during `prepareUpload` (e.g. via a dictionary `[String: URL]`), and retrieve the exact matching URL for each `fileId`.
- **Regression Test Proposal**: In `VerificationTests.swift`, stage 3 distinct files (`fileA`, `fileB`, `fileC`) and assert that the client uploads 3 unique file paths matching their respective metadata IDs.

---

### Finding 2: Missing TLS Permissive Delegate in Direct Unicast Registration Reply
- **Severity**: **High**
- **Status**: **CONFIRMED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareDiscovery.swift:186-192`
- **Evidence**:
  ```swift
  let session = URLSession(configuration: .ephemeral)
  let task = session.dataTask(with: request) { _, _, _ in
      session.finishTasksAndInvalidate()
  }
  task.resume()
  ```
- **Scenario**: A peer broadcasts UDP multicast with `announce: true`. This Mac attempts to reply via unicast `POST /api/localsend/v2/register` over HTTPS. Because the peer uses a self-signed certificate and `URLSession` has no delegate, TLS trust verification fails immediately.
- **Impact**: Cross-device discovery fails. The peer never discovers this Mac via unicast reply.
- **Minimal Fix**: Provide `LocalSharePermissiveTLSDelegate` to the `URLSession` in `sendDirectRegisterReply`, exactly as is done in `registerManualIP` (`LocalShareDiscovery.swift:219`).
- **Regression Test Proposal**: In `VerificationTests.swift`, start a loopback server with `enableTLS: true` and assert that `sendDirectRegisterReply` successfully delivers a registration packet.

---

### Finding 3: Zero-Byte Declared File Size Verification Bypass
- **Severity**: **Medium**
- **Status**: **CONFIRMED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareFileManager.swift:164`
- **Evidence**:
  ```swift
  if expectedSize > 0 && bytesWritten != expectedSize {
      try? FileManager.default.removeItem(at: destinationURL)
      throw LocalShareError.serverError("Received size mismatch...")
  }
  ```
- **Scenario**: A malicious sender declares `size: 0` in `prepare-upload`, but transmits non-zero bytes during `/upload`. Because `expectedSize > 0` is false, size verification is skipped. The file is finalized and preserved on disk.
- **Impact**: Input validation boundary bypass. An attacker can write unexpected bytes to disk for a file declared empty.
- **Minimal Fix**: Change condition to: `if bytesWritten != expectedSize`.
- **Regression Test Proposal**: Attempt to finalize a file stream with `expectedSize: 0` and `bytesWritten: 1024`, and assert that it throws an error and deletes the file.

---

### Finding 4: Concurrent Upload Token Replay & Race Condition
- **Severity**: **Medium**
- **Status**: **CONFIRMED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareSession.swift:133-160` and `Sources/Modules/LocalShare/LocalShareServer.swift:404-407, 533`
- **Evidence**: `validateToken` checks `!consumedTokens.contains(token)`, but `markTokenConsumed` is only called after the entire file stream completes in `finalizeStreamAndRespond`.
- **Scenario**: An attacker sends two concurrent HTTP `POST /upload` requests with the same valid `token`. Both pass `validateToken`. The server opens two file streams (`file.txt` and `file (1).txt`) and writes both to disk concurrently.
- **Impact**: Single-use token invariant violation; unmetered duplicate disk writes.
- **Minimal Fix**: Mark the token as `inUse` or consume it immediately upon `validateToken` (with rollback if initialization fails).
- **Regression Test Proposal**: Concurrently dispatch two `/upload` requests with the same token and assert that the second receives HTTP 403 / 409.

---

### Finding 5: Unobserved Asynchronous `NWListener` Failure
- **Severity**: **Medium**
- **Status**: **CONFIRMED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareServer.swift:137-140` and `Sources/Modules/LocalShare/LocalShareModule.swift:101-114`
- **Evidence**:
  ```swift
  case .failed(let error):
      self.state = .failed(error.localizedDescription)
      self.listener?.cancel()
      self.listener = nil
  ```
- **Scenario**: `NWListener` fails after startup (e.g. port conflict or firewall drop). `stateUpdateHandler` sets `state = .failed`, but no callback or notification is dispatched to `LocalShareModule`.
- **Impact**: UI remains in a misleading "Receive Active" state while the receiver is dead.
- **Minimal Fix**: Add an `onStateChanged: ((LocalShareServerState) -> Void)?` handler to `LocalShareServer` and observe it in `LocalShareModule` to update `isReceiveActive = false` and show an error status.
- **Regression Test Proposal**: Simulate a listener failure and verify that `LocalShareModule.isReceiveActive` updates to `false`.

---

### Finding 6: Incoming Transfer Notification Suppression on Non-LocalShare Active Tabs
- **Severity**: **Medium**
- **Status**: **CONFIRMED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareModule.swift:160-164`
- **Evidence**:
  ```swift
  if NotchShellCoordinator.shared.state == .collapsed {
      self.postIncomingNotification(for: session)
  }
  ```
- **Scenario**: The notch is expanded to another module (e.g. Shelf, Notes, AirDrop). An incoming Local Share transfer arrives. Because the notch is not collapsed, no notification is posted. Because the active module is Shelf, the Local Share card is not visible.
- **Impact**: The user receives no notification and no visual prompt; the transfer silently hangs until it times out.
- **Minimal Fix**: Post a notification if the notch is collapsed OR if the active module is not `"localshare"`:
  `if NotchShellCoordinator.shared.state == .collapsed || ModuleRegistry.shared.activeModuleId != "localshare"`.
- **Regression Test Proposal**: Offer an incoming session while the notch is expanded to `"shelf"` and assert that a notification is dispatched.

---

## 12. Suspected Vulnerabilities & False Positives

### Finding 7: Split-State Architecture & Hook Collision Risk
- **Severity**: **Low**
- **Status**: **SUSPECTED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareModuleState.swift:119-128` vs `Sources/Modules/LocalShare/LocalShareModule.swift:153-170`
- **Analysis**: Both classes attach closures to `LocalShareServer.shared.onIncomingSessionOffered`. In `NotchApp`, `LocalShareModule` is used. However, if `LocalShareModuleState.shared` is ever accessed, it will overwrite the server hook.
- **Remediation**: Unify `LocalShareModule` and `LocalShareModuleState`, or have `LocalShareModule` wrap and delegate directly to `LocalShareModuleState`.

### Finding 8: Slowloris Pre-Header Socket Exhaustion
- **Severity**: **Low**
- **Status**: **SUSPECTED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareServer.swift:156-208`
- **Analysis**: An idle client opening a connection without sending data will hold an `NWConnection` open until TCP keepalive times out.
- **Remediation**: Add a 15-second pre-header handshake timeout timer that cancels the connection if no HTTP headers arrive.

### Finding 9: Case-Sensitive Favorite Fingerprint Duplicate Insertion
- **Severity**: **Informational**
- **Status**: **CONFIRMED**
- **File & Line**: `Sources/Modules/LocalShare/LocalShareSettings.swift:164-167`
- **Analysis**: `addFavorite(fingerprint:)` checks `!favoriteFingerprints.contains(fingerprint)` (case-sensitive), while `removeFavorite` is case-insensitive.
- **Remediation**: Use `!favoriteFingerprints.contains(where: { $0.caseInsensitiveCompare(fingerprint) == .orderedSame })`.

### Finding 10: Missing Integration Test Coverage
- **Severity**: **Informational**
- **Status**: **CONFIRMED**
- **File & Line**: `Tests/VerificationTests.swift:5107-5665`
- **Analysis**: Existing tests rely on `enableTLS: false` and test single-file scenarios, leaving multi-file client flows and TLS negotiations unverified in test automation.
- **Remediation**: Add end-to-end multi-file upload, TLS loopback handshake, and 0-byte upload tests in Stage 4.

---

## 13. Recommended Remediation Priority

| Priority | Finding ID | Severity | File & Location | Description |
| :---: | :---: | :---: | :--- | :--- |
| **P0** | **Finding 1** | **Critical** | `LocalShareModule.swift:309`, `LocalShareModuleState.swift:252` | Fix multi-file outgoing transfer mapping so each file is uploaded once. |
| **P0** | **Finding 2** | **High** | `LocalShareDiscovery.swift:187` | Add `LocalSharePermissiveTLSDelegate` to `sendDirectRegisterReply`. |
| **P1** | **Finding 3** | **Medium** | `LocalShareFileManager.swift:164` | Fix 0-byte file size verification check. |
| **P1** | **Finding 4** | **Medium** | `LocalShareSession.swift:133`, `LocalShareServer.swift:404` | Prevent concurrent `/upload` token replay by reserving tokens on upload start. |
| **P2** | **Finding 5** | **Medium** | `LocalShareServer.swift:137`, `LocalShareModule.swift:101` | Propagate asynchronous `NWListener` state transitions to the UI. |
| **P2** | **Finding 6** | **Medium** | `LocalShareModule.swift:161` | Post notifications when notch is expanded to another module (e.g. Shelf). |
| **P3** | **Finding 7** | **Low** | `LocalShareModuleState.swift:119` | Eliminate split-state hook collision risk between module and state classes. |
| **P3** | **Finding 8** | **Low** | `LocalShareServer.swift:156` | Add pre-header slowloris socket timeout. |
| **P4** | **Finding 9** | **Info** | `LocalShareSettings.swift:165` | Case-insensitive favorite fingerprint deduplication. |
| **P4** | **Finding 10** | **Info** | `Tests/VerificationTests.swift` | Add end-to-end integration tests for multi-file, TLS, and 0-byte scenarios. |

---

## 14. Audit Verification Statement

In accordance with Stage 3 constraints:
- **No production code was modified during this audit.**
- **No fixes were applied.**
- **Application was not launched; no GUI automation was performed.**
- **Branch `fix/localshare` remains intact and unpushed.**
- **All findings are categorized with evidence, impact, and minimal remediation proposals.**

Awaiting user approval before proceeding to Stage 4 (Remediation & Final Hardening).
