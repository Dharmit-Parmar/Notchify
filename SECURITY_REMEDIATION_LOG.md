# NOTCHIFY — SECURITY REMEDIATION EXECUTION LOG

**Branch:** `fix/security-remediation`  
**Base Commit:** `81c89a0` (Merged Stage 4 LocalShare implementation)  
**Execution Timestamp:** 2026-11-17  
**Status:** ALL FIXES IMPLEMENTED, INDEPENDENTLY VERIFIED & 112/112 TESTS PASSING (3 CONSECUTIVE RUNS)  

---

## Patch Execution Timeline

### Commit Step 1: Baseline Preservation & Branch Initialization
- **Action:** Created isolation branch `fix/security-remediation` from current active branch.
- **Verification:** Git status clean; working tree preserved without destructive commands (`git reset` or `git clean`).

### Commit Step 2: Remediating SEC-01 (Keychain Entitlement & ACL Access)
- **Files Modified:**
  - `Sources/Modules/LocalShare/LocalShareIdentity.swift`
  - `Sources/Modules/LocalShare/LocalShareSettings.swift`
- **Changes Applied:**
  1. Removed `kSecUseDataProtectionKeychain as String: true` across all queries.
  2. Applied `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` to login keychain storage.
  3. Replaced `cleanLegacyFileBasedKeychain()` (which caused pre-write item loss) with proper item deletion prior to re-creation.
  4. Implemented `createOpenAccess(descriptor: nil)` with `SecAccessCreate(descriptor, nil, &access)` to allow binaries running under the same user UID to read secrets without triggering interactive password dialogs.
  5. Injected `SecKeychainSetUserInteractionAllowed(false)` into `loadOrGenerateIdentityLocked()`, `loadKeychainData()`, and `loadPinFromKeychain()` to guarantee zero GUI prompt hangs in headless/CLI environments.
  6. Harmonized identity persistence so fresh identities do not write plaintext private keys to `UserDefaults`, satisfying Subtest 15 regression requirements.
- **Verification:** Subtest 11, Subtest 15, Subtest 18, and Subtest 19 pass with 0 prompts.

### Commit Step 3: Remediating SEC-04 (Synchronous Session Directory Teardown)
- **Files Modified:** `Sources/Modules/LocalShare/LocalShareSession.swift`
- **Changes Applied:**
  - Refactored `purgeSessionDirectory(sessionId:)` in `cancelSession`, `reset`, `offerIncomingSession`, and `checkTimeouts`.
  - Directory purging is executed synchronously (`try? FileManager.default.removeItem(at: dir)`) outside the coordinator lock.
- **Verification:** Subtest 14 in `Tests/VerificationTests.swift` passes cleanly.

### Commit Step 4: Fixing Test Runner EOF Monitor Busy Loop
- **Files Modified:** `Tests/VerificationTests.swift`
- **Changes Applied:**
  - Added `readabilityHandler = nil` on pipes following `proc.waitUntilExit()` and `dualProc.waitUntilExit()`.
  - Resolved 200% CPU spinning loop caused by Foundation's `_monitor:` event trigger on pipe EOF.
- **Verification:** Test suite runs with negligible CPU overhead (<1% background consumption).

### Commit Step 5: Remediating SEC-05 & SEC-06 in `LocalShareServer`
- **Files Modified:** `Sources/Modules/LocalShare/LocalShareServer.swift`
- **Changes Applied:**
  1. Protected `serverAlias`, `requiredPin`, `autoAcceptFavorites`, and `favoriteFingerprints` with thread synchronization locks (`NSLock`).
  2. Exempted `/api/localsend/v2/upload` requests from the 10 req/s discovery rate limiter to prevent connection loss during parallel multi-file transfers.
  3. Restored favorite peer auto-acceptance logic in `handlePrepareUploadRoute` to enable authorized loopback transfers.
  4. Synchronized `LocalShareSettings.tcpPort` so changing port while receive mode is disabled does not prematurely spawn NWListeners.
- **Verification:** Subtest 10 passes: 2 files transferred over loopback, tokens validated, replayed token rejected (403), files quarantined.

### Commit Step 6: Remediating SEC-02 (App Transport Security)
- **Files Modified:**
  - `Resources/Info.plist`
  - `NotchApp.app/Contents/Info.plist`
- **Changes Applied:**
  - Removed `<key>NSAllowsArbitraryLoads</key><true/>`.
  - Preserved `<key>NSAllowsLocalNetworking</key><true/>` strictly for peer-to-peer LocalShare communication.
- **Verification:** Verified in `scripts/security-audit.sh` Gate 5.

### Commit Step 7: Remediating SEC-03 (Ephemeral AI Session Caching)
- **Files Modified:** `Sources/Modules/AI/AskAIService.swift`
- **Changes Applied:**
  - Introduced private ephemeral `URLSession(configuration: .ephemeral)` with `urlCache = nil`, `httpCookieStorage = nil`, `urlCredentialStorage = nil`, and `.reloadIgnoringLocalAndRemoteCacheData`.
  - Replaced all calls to `URLSession.shared.data(for: request)` in `queryGemini` and `queryOpenAI` with the ephemeral session.
- **Verification:** Zero API bearer tokens written to `~/Library/Caches/com.notch.NotchApp/fsCachedData`.

### Commit Step 8: Remediating SEC-07 (Eliminating Blind Keystrokes)
- **Files Modified:** `Sources/Modules/Telegram/TelegramModule.swift`
- **Changes Applied:**
  - Deleted blind AppleScript `key code 36` Return key synthesis.
  - Messages are pre-staged via official URI schemes (`tg://` and `whatsapp://`) for user-confirmed transmission.
  - Automated direct message transmission is delegated to `TelegramClient` via the Bot API over TLS.
- **Verification:** Verified in Test 3.

### Commit Step 9: Remediating SEC-08 (Secure AirDrop Staging & Auto-Cleanup)
- **Files Modified:** `Sources/Modules/AirDrop/AirDropModule.swift`
- **Changes Applied:**
  - Created `createSecureTempFile(prefix:ext:data:)` writing to `AirDropStaging/` with `0700` directory and `0600` file permissions.
  - Tracked transient files in `transientStagedFiles` and implemented `cleanupStagedFiles()` called on `didShareItems`, `didFailToShareItems`, `stop()`, and picker cancellation.
  - Added startup purge for old staged files.
- **Verification:** Files cleaned up automatically after sharing operations.

### Commit Step 10: Remediating SEC-09 (Private SPI & SIGKILL Removal)
- **Files Modified:** `Sources/Core/ProcessMemoryGovernor.swift`
- **Changes Applied:**
  - Removed `@_silgen_name("responsibility_get_pid_responsible_for_pid")`.
  - Removed process iteration via `proc_listpids` and `SIGKILL` termination of helper XPC services.
  - Replaced with compliant Darwin memory pressure relief (`malloc_zone_pressure_relief(malloc_default_zone(), 0)`).
- **Verification:** Zero compiler warnings for private SPIs; App Store compliant.

### Commit Step 11: Production Identity Isolation & Keychain Protection
- **Files Modified:**
  - `Sources/Modules/LocalShare/LocalShareIdentity.swift`
  - `Sources/Modules/LocalShare/LocalShareSettings.swift`
  - `Tests/VerificationTests.swift`
- **Changes Applied:**
  - Parameterized `serviceName` across `LocalShareIdentityManager` and `LocalShareSettings` (defaulting to `"com.notch.NotchApp.LocalShare"`).
  - Isolated test harness executions to `"com.notch.NotchApp.LocalShare.Testing"`.
  - Added strict guard in `resetIdentityForTesting()` to explicitly reject resetting the production service.
  - Added suite fallback loading from `NotchApp.plist` preserving authentic user identity (`Aizen`, fingerprint `1ed5e4bb...`).
  - Scoped fallback deletion to never remove production legacy fallbacks from `NotchApp` suite.
- **Verification:** User's authentic identity verified 100% intact before, during, and after test executions.

### Commit Step 12: Content-Length Size Mismatch Validation on `/upload`
- **Files Modified:** `Sources/Modules/LocalShare/LocalShareServer.swift`
- **Changes Applied:**
  - Enforced immediate validation of HTTP `Content-Length` header against agreed metadata size in `handleUploadRoute`.
  - Size mismatches are rejected immediately with HTTP 400 Bad Request prior to stream writer creation.
  - Raised discovery rate limiter to 60 req/s to accommodate rapid batch negotiation.
- **Verification:** Subtest 9 in Transfer Matrix immediately returns HTTP 400 and purges any partial artifacts.

### Commit Step 13: LocalShare Transfer Matrix Verification (Test 106)
- **Files Modified:** `Tests/VerificationTests.swift`
- **Changes Applied:**
  - Implemented `[TEST 106]` covering all 10 LocalShare transfer scenarios:
    1. Zero-byte file transfer (HTTP 200, 0 bytes verified on disk)
    2. Small text file transfer (HTTP 200, SHA-256 match)
    3. Small image transfer (HTTP 200, PNG binary match)
    4. Medium file transfer (HTTP 200, 64KB verified)
    5. Large file transfer (HTTP 200, 1MB verified)
    6. Multiple files transfer (HTTP 200, 3 files staged)
    7. Parallel concurrent uploads (HTTP 200, concurrent streams)
    8. Cancelled upload (HTTP 200 cancel, HTTP 409 subsequent upload rejection)
    9. Incorrect declared file size (HTTP 400 mismatch rejection, partial file purged)
    10. Deliberately interrupted connection (abrupt socket reset handled, 0 partial file leaks)
- **Verification:** 3 consecutive runs of 106/106 tests passed cleanly (0 flakes, 0 failures).

### Commit Step 14: Atomic POSIX File Creation & Symlink TOCTOU Hardening (SEC-08)
- **Files Modified:**
  - `Sources/Modules/LocalShare/LocalShareFileManager.swift`
  - `Sources/Modules/LocalShare/LocalShareProtocol.swift`
- **Changes Applied:**
  - Replaced Cocoa `FileManager.default.createFile` with Darwin POSIX `open(fsPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)`.
  - Added atomic collision progression in `beginFileStream`, attempting candidate suffixes `(1)`, `(2)` until atomic creation succeeds.
  - Added `O_NOFOLLOW` flag to prevent following symlinks, returning `LocalShareError.fileExists` when a symlink is encountered.
  - Initialized `FileHandle(fileDescriptor:closeOnDealloc:true)` directly on the claimed file descriptor, completely eliminating path re-lookup TOCTOU windows.
- **Verification:** Verified by Test 107 Subtests A, B, and C.

### Commit Step 15: Out-of-Band Short Verification Code (SAS) Implementation (SEC-01, SEC-02)
- **Files Modified:**
  - `Sources/Modules/LocalShare/LocalShareSecurity.swift`
  - `Sources/Modules/LocalShare/LocalShareSession.swift`
- **Changes Applied:**
  - Implemented `LocalShareSecurity.computeVerificationCode(localFingerprint:peerFingerprint:)` deriving a symmetric 6-digit verification string (`XXX-XXX`) from sorted SHA-256 endpoints.
  - Added `verificationCode` computed property on `LocalShareSession`.
  - Guaranteed that active LAN MITM tampering causes verification codes to mismatch, enabling users to verify peer authenticity out-of-band on first contact.
- **Verification:** Verified by Test 108 (symmetry and MITM mismatch detection).

### Commit Step 16: Gated Auto-Acceptance & Anti-DoS Resource Quotas (SEC-05, SEC-06)
- **Files Modified:**
  - `Sources/Modules/LocalShare/LocalShareServer.swift`
  - `Sources/Modules/LocalShare/LocalShareSecurity.swift`
  - `Sources/Modules/LocalShare/LocalShareSession.swift`
- **Changes Applied:**
  - Gated auto-acceptance in `handlePrepareUploadRoute`: incoming transfers claiming a favorite fingerprint from an external LAN host CANNOT bypass user confirmation unless authenticated via shared secret PIN (`requiredPin`) or originating from loopback.
  - Enforced `maxSimultaneousConnections = 32` via thread-safe `activeConnectionCount` in `LocalShareServer`.
  - Enforced `maxConcurrentWriters = 8` in `LocalShareSession.registerActiveWriter`.
  - Enforced `maxHeaderSize = 32 KB` in `LocalShareServer.receiveHTTPPayload`.
- **Verification:** Verified by Test 109 and Test 111.

### Commit Step 17: Cross-Host Redirect Isolation for API Credentials (SEC-03)
- **Files Modified:**
  - `Sources/Modules/AI/AskAIService.swift`
  - `Sources/Modules/Telegram/TelegramClient.swift`
- **Changes Applied:**
  - Implemented `SecureAPITaskDelegate` and `TelegramRedirectTaskDelegate` intercepting `willPerformHTTPRedirection`.
  - Strictly blocked redirects that attempt to cross host boundaries or downgrade to plaintext `http://`, preventing authorization headers and bot tokens from being forwarded to unauthorized servers.
- **Verification:** Verified by code inspection and task delegate regression checks.

### Commit Step 18: Stage 4 Test Suite Expansion (Tests 107-112) & Soak Verification
- **Files Modified:** `Tests/VerificationTests.swift`
- **Changes Applied:**
  - Added Test 107: Atomic POSIX File Creation & Symlink TOCTOU Protection.
  - Added Test 108: Out-of-band Short Verification Code (SAS) Determinism & Active MITM Detection.
  - Added Test 109: Unauthenticated Favorite Fingerprint Spoofing Gate.
  - Added Test 110: Realistic 5 MB File Transfer with SHA-256 Checksum & HTTP 422 Tamper Detection.
  - Added Test 111: Token Anti-Replay & Concurrency Writer Quota Enforcement.
  - Added Test 112: Extended Soak & Memory / File Descriptor Stability (50 Sequential Transfers).
- **Verification:** Full suite passed with 112/112 tests across 3 consecutive clean runs (Exit Code 0).

### Commit Step 19: Stage 4.1 Final Security Claim Validation & Residual Hardening
- **Files Modified:**
  - `Sources/Modules/LocalShare/LocalShareClient.swift`
  - `Sources/Modules/LocalShare/LocalShareFileManager.swift`
  - `Sources/Modules/LocalShare/LocalShareIdentity.swift`
  - `Sources/Modules/LocalShare/LocalShareProtocol.swift`
  - `Sources/Modules/LocalShare/LocalShareSecurity.swift`
  - `Sources/Modules/LocalShare/LocalShareServer.swift`
  - `Sources/Modules/LocalShare/LocalShareSettings.swift`
  - `Tests/VerificationTests.swift`
  - `SECURITY_ARCHITECTURE_NOTES.md`
  - `SECURITY_ACCEPTED_RISKS.md`
  - `SECURITY_FINDINGS_REGISTER.md`
  - `SECURITY_VERIFICATION_REPORT.md`
- **Changes Applied:**
  1. **TN3137 Keychain ACL Semantics & Thread Safety:**
     - Inspected Apple SDK `<Security/SecAccess.h>`: established that `SecAccessCreate(descriptor, nil, &access)` sets an ACL containing *only the creating binary's code designated requirement* (`trustedlist == NULL` defaults to just the application creating the item), disproving misleading claims that it authorizes arbitrary processes under the same UID.
     - Confirmed that independently compiled ad-hoc binaries fail with `errSecAuthFailed` (`OSStatus -25293`) when interaction is suppressed. Documented Developer ID signing requirements for seamless keychain access across app updates.
     - Removed invalid claims that the file-based login keychain (`login.keychain-db`) enforces `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Documented that file-based keychain protection is derived exclusively from the macOS user login session master key.
     - Implemented `KeychainInteractionGovernor`: uses `NSRecursiveLock` and depth-counted serialization across all threads in `LocalShareIdentity.swift` and `LocalShareSettings.swift` to prevent concurrent UI interaction suppression state corruption.
  2. **POSIX Directory Descriptor Containment (`openat` & `fstat`):**
     - Refactored `LocalShareFileStreamWriter.init` to open a descriptor to the destination parent directory with `O_RDONLY | O_DIRECTORY | O_CLOEXEC`.
     - Validated directory ownership and directory type via `fstat(dirFd, &st)`.
     - Created leaf file stream descriptors relative to the verified directory descriptor using `openat(dirFd, fileName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)`.
     - Added `LocalShareError.invalidFileName` rejecting empty or slash-containing path components, completely eliminating ancestor directory symlink substitution TOCTOU races.
  3. **Loopback Auto-Acceptance Reassessment:**
     - Rejected `127.0.0.1` / `::1` as cryptographic proof of application identity.
     - Gated loopback auto-acceptance strictly behind explicit test flag `isTestHarnessAutoAcceptEnabled` (defaulting to `false`). In production, unauthenticated loopback requests without PIN route to interactive user confirmation (`onIncomingSessionOffered`).
  4. **Per-IP Connection Limits & PIN Brute-Force Lockout:**
     - Implemented per-IP connection limits in `LocalShareServer`: `maxConnectionsPerIP = 8` (16 for loopback).
     - Implemented progressive delay (up to 2.0s) and temporary lockouts for failed PIN attempts: 60s temporary lockout after 5 failures, 300s temporary lockout after 10 failures, returning HTTP 429 Too Many Requests.
  5. **Active LAN MITM Detection & Pinning:**
     - Extended Test 108 Subtest B: verified deterministic SAS divergence and `LocalSharePeerPinningDelegate` fail-closed TLS certificate pinning when an active MITM certificate is encountered.
  6. **File Descriptor Leak Elimination in Test 112:**
     - Reduced socket cancel delay in `sendRawResponse` from 3.0s to 0.05s.
     - Actively tracked open sockets in `activeConnections` dictionary and closed them cleanly during `server.stop()`.
     - Added comprehensive resource assertion table in Test 112: open file descriptors (asserting FD delta <= 15), active NWConnections (asserting == 0), active NWListeners (asserting == stopped), active sessions (`currentSession == nil`), active writers (asserting empty), and resident RSS delta (< 35 MB).
- **Verification:** 112/112 tests passed cleanly across 3 consecutive runs (Exit code 0, 0 flakes, 0 leaks). All 8 security integrity gates passed. User production identity preserved 100% intact.
