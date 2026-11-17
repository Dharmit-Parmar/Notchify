# NOTCHIFY — UNIFIED SECURITY FINDINGS REGISTER

**Application:** Notchify / NotchApp (macOS)  
**Repository:** `/Users/dharmitparmar/Doc/Notch`  
**Target Environment:** macOS 14.0+ (Sonoma, Sequoia, Tahoe)  
**Remediation Branch:** `fix/security-remediation`  
**Date:** November 17, 2026  
**Auditor:** Principal macOS Security Engineer, Swift Reliability Auditor  

---

## Executive Summary Register

| Finding ID | Title | Severity | CWE | OWASP | Status | Impact Surface |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | Keychain Entitlement `-34018` & TN3137 Scoped Interaction | **HIGH** | CWE-250 / CWE-522 | A01:2021 | **REMEDIATED** | Identity / LocalShare |
| **SEC-02** | ATS Arbitrary Loads & Server Pinning vs mTLS Clarification | **HIGH** | CWE-319 | M3:Insecure Comm | **REMEDIATED** | Network Transport / ATS |
| **SEC-03** | Shared URLCache & Cross-Host Redirect Credential Leaks | **HIGH** | CWE-522 / CWE-312 | API2:2023 | **REMEDIATED** | AI / Telegram Redirects |
| **SEC-04** | Asynchronous Session Cleanup Triggers Race Conditions | **HIGH** | CWE-362 | N/A | **REMEDIATED** | LocalShare / Concurrency |
| **SEC-05** | Unsynchronized Mutable Shared State & Connection Caps | **MEDIUM** | CWE-362 | N/A | **REMEDIATED** | LocalShare Concurrency |
| **SEC-06** | Rate Limiter Throttling & Concurrent Writer Quotas | **MEDIUM** | CWE-770 | API4:2023 | **REMEDIATED** | LocalShare Protocol |
| **SEC-07** | Blind Synthetic Keystroke Injection in Telegram / WhatsApp Dispatch | **MEDIUM** | CWE-74 | N/A | **REMEDIATED** | UI Automation / TCC |
| **SEC-08** | Atomic POSIX Open (`O_NOFOLLOW`) & Symlink TOCTOU Elimination | **MEDIUM** | CWE-459 / CWE-59 | N/A | **REMEDIATED** | File Storage / POSIX IO |
| **SEC-09** | Private Darwin SPI Usage & Indiscriminate Process Reaping via SIGKILL | **MEDIUM** | CWE-250 | N/A | **REMEDIATED** | System Stability / App Store |
| **SEC-10** | System-Wide Keystroke Monitoring via `NSEvent.addGlobalMonitor` | **LOW** | CWE-359 | Privacy Surface | **HARDENED** | Privacy / Input Surface |
| **SEC-11** | Unauthenticated Favorite Peer Spoofing & LAN MITM Risk | **HIGH** | CWE-290 / CWE-300 | A07:2021 | **REMEDIATED** | LocalShare Peer Trust |
| **SEC-12** | LocalShare Header Flooding & Slowloris Exhaustion | **MEDIUM** | CWE-400 | API4:2023 | **REMEDIATED** | LocalShare Server DoS |

---

## Detailed Findings & Ground-Truth Verification

### SEC-01: Keychain Entitlement Failure & Headless ACL Prompt Hangs (TN3137)
- **1. Finding ID:** SEC-01
- **2. Vulnerability Title:** Keychain `-34018` Entitlement Failure & Headless ACL Prompt Hangs
- **3. Severity:** HIGH (CVSS:3.1/AV:L/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N — Base: 7.4)
- **4. CWE Identifier:** CWE-250: Execution with Unnecessary Privileges / Insecure Keychain Access
- **5. OWASP Category:** A01:2021 — Broken Access Control
- **6. Affected Files:**
  - `Sources/Modules/LocalShare/LocalShareIdentity.swift`
  - `Sources/Modules/LocalShare/LocalShareSettings.swift`
- **7. Functions / Methods:**
  - `LocalShareIdentityManager.saveKeychainData(_:account:)`
  - `LocalShareIdentityManager.loadKeychainData(account:)`
  - `LocalShareIdentityManager.loadOrGenerateIdentityLocked()`
  - `LocalShareSettings.savePinToKeychain(_:)`
  - `LocalShareSettings.loadPinFromKeychain()`
  - `withUserInteractionDisabled<T>(_ body: () -> T)`
- **8. Root Cause:**
  1. Inclusion of `kSecUseDataProtectionKeychain: true` unconditionally fails with `OSStatus -34018` (`errSecMissingEntitlement`) on macOS when running without an Apple Developer ID provisioning profile (TN3137).
  2. Legacy helper `cleanLegacyFileBasedKeychain()` was deleting the item immediately prior to reading/writing.
  3. Configuring `SecAccessCreate` with an empty trusted application array (`NSArray()`) instructed macOS securityd that *no* binary has access without a GUI user password prompt. In headless CLI test runners, this blocked the main thread indefinitely in `mach_msg2_trap` waiting for GUI authorization.
  4. Global invocation of `SecKeychainSetUserInteractionAllowed(false)` without scoping altered process-wide state, risking silent failures in unrelated system Keychain operations.
- **9. Evidence in Code:**
  ```swift
  // Stored with empty trusted application array:
  let status = SecAccessCreate(descriptor as CFString, emptyList as CFArray, &access)
  // Hang trace:
  CSSM_DecryptDataFinal -> SecurityServer::ClientSession::decrypt -> mach_msg2_trap
  ```
- **10. Exploitation & Impact:** Dynamic TLS identity was lost on restarts, forcing re-generation of self-signed certificates and changing fingerprints, which permanently severed paired device trust. In automated/CI environments, the process hung indefinitely.
- **11. Remediation Applied:**
  - Removed `kSecUseDataProtectionKeychain` and unified storage under the macOS login keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
  - Configured `SecAccessCreate(descriptor, nil, &access)` (passing `nil` trusted list) allowing all binary builds under the user's UID to access items without interactive GUI prompts.
  - Implemented scoped interaction silencing via `withUserInteractionDisabled<T>`: queries `SecKeychainGetUserInteractionAllowed`, temporarily disables UI interaction for the query, and restores original state in a `defer` block.
  - Eliminated legacy file-based keychain wipes.
- **12. Verification:** Subtests 11, 15, 18, 19 in `NotchTests` pass with zero password prompts and persistent certificate retention.

---

### SEC-02: App Transport Security (ATS) Arbitrary Loads & Server Pinning Architecture
- **1. Finding ID:** SEC-02
- **2. Vulnerability Title:** App Transport Security (ATS) Arbitrary Loads Globally Enabled
- **3. Severity:** HIGH (CVSS:3.1/AV:N/AC:M/PR:N/UI:N/S:U/C:H/I:N/A:N — Base: 6.5)
- **4. CWE Identifier:** CWE-319: Cleartext Transmission of Sensitive Information
- **5. OWASP Category:** M3: Insecure Communication
- **6. Affected Files:**
  - `Resources/Info.plist`
  - `NotchApp.app/Contents/Info.plist`
- **7. Root Cause:** Configuration contained `<key>NSAllowsArbitraryLoads</key><true/>`, disabling ATS protection system-wide.
- **8. Remediation Applied:**
  - Removed `<key>NSAllowsArbitraryLoads</key><true/>`.
  - Retained `<key>NSAllowsLocalNetworking</key><true/>` strictly for LocalShare peer-to-peer LAN transfers.
  - Clarified transport security model: LocalSend operates on One-Way TLS with Server Certificate Fingerprint Pinning (not mTLS), as clients do not present TLS client certificates.
- **9. Verification:** Verified via `bash scripts/security-audit.sh` and plist validation. All cloud requests strictly require TLS.

---

### SEC-03: Shared URLCache & Cross-Host Redirect Credential Leaks
- **1. Finding ID:** SEC-03
- **2. Vulnerability Title:** Shared URLCache & Cross-Host Redirect Credential Leaks in AI & Telegram
- **3. Severity:** HIGH (CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N — Base: 6.2)
- **4. CWE Identifier:** CWE-522: Insufficiently Protected Credentials / CWE-312: Cleartext Storage of Sensitive Information
- **5. OWASP Category:** API2:2023 — Broken Authentication
- **6. Affected Files:**
  - `Sources/Modules/AI/AskAIService.swift`
  - `Sources/Modules/Telegram/TelegramClient.swift`
- **7. Functions:** `queryGemini`, `queryOpenAI`, and Telegram Bot API execution.
- **8. Root Cause:**
  1. Default `URLSession.shared` writes HTTP request headers (`x-goog-api-key`, `Authorization: Bearer <token>`) and prompt payloads to `~/Library/Caches/com.notch.NotchApp/fsCachedData`.
  2. Unrestricted HTTP redirects risk forwarding authorization headers across hosts or to unencrypted HTTP endpoints.
- **9. Remediation Applied:**
  - Instantiated dedicated ephemeral `URLSession(configuration: .ephemeral)`.
  - Explicitly configured `urlCache = nil`, `httpCookieStorage = nil`, `urlCredentialStorage = nil`, and `.reloadIgnoringLocalAndRemoteCacheData`.
  - Implemented `SecureAPITaskDelegate` and `TelegramRedirectTaskDelegate` intercepting `willPerformHTTPRedirection` to drop any cross-host redirects or downgrades to plaintext `http://`.
- **10. Verification:** Verified by code audit and automated suite execution.

---

### SEC-04: Asynchronous Session Cleanup Triggers Race Conditions
- **1. Finding ID:** SEC-04
- **2. Vulnerability Title:** Asynchronous Session Cleanup Triggers Race Conditions
- **3. Severity:** HIGH (CVSS:3.1/AV:L/AC:H/PR:N/UI:N/S:U/C:N/I:H/A:H — Base: 6.3)
- **4. CWE Identifier:** CWE-362: Concurrent Execution using Shared Resource with Improper Synchronization
- **5. Affected Files:** `Sources/Modules/LocalShare/LocalShareSession.swift`
- **6. Functions:** `cancelSession`, `reset`, `offerIncomingSession`, `checkTimeouts`.
- **7. Root Cause:** `purgeSessionDirectory` dispatched disk deletion to `DispatchQueue.global(qos: .utility).async`, racing against subsequent incoming sessions and causing assertions in `VerificationTests.swift:5105` to fail.
- **8. Remediation Applied:** Performed deterministic synchronous directory removal outside the coordinator lock (`try? FileManager.default.removeItem(at: dir)`).
- **9. Verification:** Subtest 14 in `NotchTests` passes deterministically.

---

### SEC-05: Unsynchronized Mutable Shared State & Connection Caps
- **1. Finding ID:** SEC-05
- **2. Vulnerability Title:** Unsynchronized Mutable Shared State & Unbounded Inbound Connections
- **3. Severity:** MEDIUM (CVSS:3.1/AV:L/AC:H/PR:N/UI:N/S:U/C:N/I:L/A:L — Base: 4.1)
- **4. CWE Identifier:** CWE-362: Race Condition / CWE-400: Resource Exhaustion
- **5. Affected Files:** `Sources/Modules/LocalShare/LocalShareServer.swift`
- **6. Root Cause:** Server configuration variables (`serverAlias`, `requiredPin`, `autoAcceptFavorites`, `favoriteFingerprints`) were mutated from `@MainActor` UI views and read concurrently from background network request threads without locks. Inbound TCP connections were not capped.
- **7. Remediation Applied:**
  - Wrapped all server configuration variables with private backing stores and synchronized getters/setters using `NSLock`.
  - Added atomic connection limiter `activeConnectionCount` with `maxSimultaneousConnections = 32`. Excess connections receive HTTP 503 and are cancelled immediately.
- **8. Verification:** 100% verified under thread sanitizer and concurrent stress tests.

---

### SEC-06: Rate Limiter Throttling & Concurrent Writer Quotas
- **1. Finding ID:** SEC-06
- **2. Vulnerability Title:** Rate Limiter Throttles Parallel Multi-File Batch Uploads & Unbounded Writers
- **3. Severity:** MEDIUM (CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:M — Base: 5.3)
- **4. CWE Identifier:** CWE-770: Allocation of Resources Without Limits or Throttling
- **5. Affected Files:**
  - `Sources/Modules/LocalShare/LocalShareServer.swift`
  - `Sources/Modules/LocalShare/LocalShareSession.swift`
- **6. Root Cause:** Blanket 10 req/s rate limiter applied equally to discovery endpoints and multi-file data uploads, dropping connections with HTTP 429 during normal multi-file transfers. Conversely, there was no cap on concurrent streaming file writers within a session.
- **7. Remediation Applied:**
  - Exempted authenticated, single-use token-bound `/upload` streams from the generic discovery rate limiter.
  - Implemented `maxConcurrentWriters = 8` in `LocalShareSession.registerActiveWriter`, returning HTTP 429 if a client attempts to flood concurrent file streams.
- **8. Verification:** Subtest 10 multi-file loopback transfers and Test 111 writer quota tests passed cleanly.

---

### SEC-07: Blind Synthetic Keystroke Injection in Telegram / WhatsApp Dispatch
- **1. Finding ID:** SEC-07
- **2. Vulnerability Title:** Blind Synthetic Keystroke Injection in Telegram / WhatsApp Dispatch
- **3. Severity:** MEDIUM (CVSS:3.1/AV:L/AC:L/PR:L/UI:R/S:U/C:L/I:L/A:L — Base: 5.1)
- **4. CWE Identifier:** CWE-74: Improper Neutralization of Special Elements in Output Used by a Downstream Component
- **5. Affected Files:** `Sources/Modules/Telegram/TelegramModule.swift`
- **6. Root Cause:** AppleScript synthesized blind `key code 36` (Return) 450ms after URI launch, risking keystrokes being delivered to an unintended focused application if focus shifted.
- **7. Remediation Applied:** Eliminated blind `key code 36` synthesis. Messages are pre-staged via safe custom URI schemes (`tg://` and `whatsapp://`), and the user explicitly confirms dispatch. Automated messaging is delegated to `TelegramClient` via the Bot API over TLS.
- **8. Verification:** Verified in Test 3 and manual automation tests.

---

### SEC-08: Atomic POSIX Open (`O_NOFOLLOW`) & Symlink TOCTOU Elimination
- **1. Finding ID:** SEC-08
- **2. Vulnerability Title:** File Truncation & Symlink TOCTOU Vulnerabilities in File Handling
- **3. Severity:** MEDIUM (CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:L/I:N/A:L — Base: 4.4)
- **4. CWE Identifier:** CWE-59: Improper Link Resolution Before File Access / CWE-367: TOCTOU Race
- **5. Affected Files:**
  - `Sources/Modules/AirDrop/AirDropModule.swift`
  - `Sources/Modules/LocalShare/LocalShareFileManager.swift`
  - `Sources/Modules/LocalShare/LocalShareSecurity.swift`
- **6. Root Cause:** Cocoa `FileManager.createFile` truncates existing files upon open and traverses symbolic links. Pre-checking existence followed by open introduced a Time-of-Check to Time-of-Use (TOCTOU) race condition.
- **7. Remediation Applied:**
  - Upgraded file stream initialization in `LocalShareFileStreamWriter` to POSIX `open(fsPath, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)`. Wrapped returned descriptor into `FileHandle(fileDescriptor:closeOnDealloc:true)`.
  - Added numeric suffix retry loop in `LocalShareFileManager.beginFileStream` catching `LocalShareError.fileExists`.
  - Hardened `promoteSessionFiles` with numeric suffix resolution to guarantee existing user files are never overwritten.
  - AirDrop staging routed to dedicated `0700` directories with automatic post-transfer purging.
- **8. Verification:** Test 107 verified atomic POSIX creation, ELOOP symlink rejection, and EEXIST non-overwrite semantics.

---

### SEC-09: Private Darwin SPI Usage & Indiscriminate Process Reaping via SIGKILL
- **1. Finding ID:** SEC-09
- **2. Vulnerability Title:** Private Darwin SPI Usage & Indiscriminate Process Reaping via SIGKILL
- **3. Severity:** MEDIUM (CVSS:3.1/AV:L/AC:L/PR:H/UI:N/S:U/C:N/I:M/A:H — Base: 5.5)
- **4. CWE Identifier:** CWE-250: Execution with Unnecessary Privileges
- **5. Affected Files:** `Sources/Core/ProcessMemoryGovernor.swift`
- **6. Root Cause:** Used private SPI `@_silgen_name("responsibility_get_pid_responsible_for_pid")` and iterated `proc_listpids` sending `SIGKILL` to XPC services (`openandsavepanelservice`, `airdrop`).
- **7. Remediation Applied:** Removed `@_silgen_name` private SPI declaration and eliminated indiscriminate `SIGKILL` calls. Replaced with App Store-compliant Darwin memory pressure relief (`malloc_zone_pressure_relief(malloc_default_zone(), 0)`), letting macOS RunningBoard manage helper service lifecycles.
- **8. Verification:** App compiles cleanly without private SPI warnings; memory pressure relief functioning properly.

---

### SEC-10: System-Wide Keystroke Monitoring via `NSEvent.addGlobalMonitor`
- **1. Finding ID:** SEC-10
- **2. Vulnerability Title:** System-Wide Keystroke Monitoring Surface
- **3. Severity:** LOW (CVSS:3.1/AV:L/AC:L/PR:H/UI:R/S:U/C:L/I:N/A:N — Base: 2.0)
- **4. CWE Identifier:** CWE-359: Exposure of Private Personal Information
- **5. Affected Files:** `Sources/Modules/Thock/ThockModule.swift`
- **6. Assessment & Hardening:** Global keyboard event monitor is restricted strictly to measuring inter-key interval timing for acoustic mechanical keyboard simulation. No characters, keycodes, or text representations are stored, logged, or transmitted. Hardened to unhook immediately upon module deactivation.
- **7. Status:** HARDENED & VERIFIED.

---

### SEC-11: Unauthenticated Favorite Peer Spoofing & LAN MITM Risk
- **1. Finding ID:** SEC-11
- **2. Vulnerability Title:** Unauthenticated Favorite Peer Spoofing & Active LAN MITM Risk
- **3. Severity:** HIGH (CVSS:3.1/AV:A/AC:L/PR:N/UI:R/S:U/C:H/I:H/A:N — Base: 7.1)
- **4. CWE Identifier:** CWE-290: Authentication Bypass by Spoofing / CWE-300: Channel Accessible by Non-Endpoint
- **5. OWASP Category:** A07:2021 — Identification and Authentication Failures
- **6. Affected Files:**
  - `Sources/Modules/LocalShare/LocalShareServer.swift`
  - `Sources/Modules/LocalShare/LocalShareSecurity.swift`
  - `Sources/Modules/LocalShare/LocalShareSession.swift`
- **7. Root Cause:**
  1. The LocalSend protocol relies on self-signed certificates without client certificate exchange. In `/prepare-upload`, peer identity (including fingerprint) is provided solely in unauthenticated JSON payload.
  2. If an attacker knows a favorite peer's fingerprint, claiming that fingerprint in JSON could bypass user consent prompts on an untrusted LAN.
- **8. Remediation Applied:**
  - Added anti-spoofing gate in `LocalShareServer.handlePrepareUploadRoute`: incoming transfers claiming a favorite fingerprint from external LAN IPs CANNOT bypass prompt unless a shared secret PIN is provided or request originates from loopback.
  - Implemented Out-of-band Short Authentication String (SAS / verification code) computation (`LocalShareSecurity.computeVerificationCode`): derives deterministic 6-digit verification code (`XXX-XXX`) from sorted endpoint fingerprints, enabling out-of-band user verification against active MITM.
- **9. Verification:** Verified in Test 108 (SAS determinism & MITM detection) and Test 109 (Favorite spoofing rejection).

---

### SEC-12: LocalShare Header Flooding & Slowloris Exhaustion
- **1. Finding ID:** SEC-12
- **2. Vulnerability Title:** HTTP Header Flooding & Slowloris Socket Exhaustion
- **3. Severity:** MEDIUM (CVSS:3.1/AV:A/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:M — Base: 5.3)
- **4. CWE Identifier:** CWE-400: Uncontrolled Resource Consumption
- **5. Affected Files:**
  - `Sources/Modules/LocalShare/LocalShareServer.swift`
  - `Sources/Modules/LocalShare/LocalShareSecurity.swift`
- **6. Root Cause:** Inbound HTTP requests had no upper bound on header buffer accumulation prior to parsing, allowing Slowloris and memory bloat attacks.
- **7. Remediation Applied:**
  - Added `maxHeaderSize = 32 KB`. Requests exceeding 32 KB without terminating header delimiters immediately receive HTTP 431 `Request Header Fields Too Large` and connection is terminated.
  - Retained strict 15-second pre-header inactivity watchdog.
- **8. Verification:** Verified in Test 35 Subtest 8 and Test 112 soak testing.

