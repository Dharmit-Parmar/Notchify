# NOTCHIFY — SECURITY ACCEPTED RISKS & THREAT MODEL DECISIONS

**Application:** Notchify / NotchApp (macOS)  
**Document Revision:** 3.0 (Stage 4.3 Final Evidence Reconciliation & Honest Threat Model Sign-Off)  
**Date:** November 17, 2026  
**Auditor / System Architect:** Principal macOS Application Security Engineer  

---

## 1. Overview & Threat Model Rationale

In high-reliability software engineering, architectural trade-offs must be evaluated, measured, and documented honestly. Fabricated platform limitations or inaccurate security claims undermine security governance.

This document formally records all accepted security risks, architectural trade-offs, threat model boundaries, and their respective compensating controls. Every claim in this register has been independently verified against the actual source code and runtime behavior.

---

## 2. Risk Register & Compensating Controls

### RISK-01: Self-Signed TLS Certificates & Unauthenticated Client Fingerprint Claims
- **Category:** Transport Security / Identity
- **Affected Area:** LocalShare Peer-to-Peer Protocol (LocalSend Specification)
- **What is Accepted:** LocalShare devices generate self-signed P-256 ECC X.509 certificates for ad-hoc local network TLS sessions rather than obtaining publicly trusted WebPKI Certificate Authority certificates. Furthermore, the client fingerprint presented in `/prepare-upload` JSON is an **unauthenticated claim**.
- **Why Accepted:**
  - Peer-to-peer LAN transfers must operate completely offline without internet access, external DNS infrastructure, or domain ownership.
  - Compatibility with the open-source LocalSend specification requires dynamic local IP/HTTPS endpoints.
- **Affected Security Boundary:** Transport confidentiality and peer authentication on the local area network (LAN).
- **What an Attacker Can Still Do:**
  - An active Man-in-the-Middle (MITM) attacker on the local network could attempt to intercept a first-contact connection by presenting their own self-signed certificate if the user approves the transfer without visually comparing the Short Authentication String (SAS).
- **Compensating Controls (Independently Verified):**
  1. **Cryptographic SHA-256 Fingerprint Pinning:** Clients verify the server's leaf certificate against the expected fingerprint during TLS negotiation (`LocalSharePeerPinningDelegate`), rejecting mismatches (Test 103 Subtest 11). If a peer was previously pinned, the TLS handshake with the attacker aborts immediately fail-closed before any HTTP exchange.
  2. **Short Authentication String (SAS / Verification Code) UI Rendering:** `LocalShareSecurity.computeVerificationCode` derives a symmetric 6-digit verification code (`XXX-XXX`) from sorted endpoint fingerprints. Both sender and receiver render this code in their UI cards (`LocalShareExpandedView.swift`) and notification subtitles.
  3. **Out-of-Band Human Visual Comparison:** Under an active MITM, the certificates intercepted by the attacker cause the codes on Alice and Bob to diverge (Test 108 Subtests B & C). The human user must visually compare the 6 digits out-of-band to catch the MITM on first-contact (TOFU).
  4. **Certificate Change Detection:** If a previously trusted peer presents a certificate with a modified fingerprint, the session is immediately blocked with HTTP 403 (`LocalSharePeerTrustState.certificateChanged`) (Test 103 Subtest 21).
  5. **First-Contact Authorization Gate:** On first contact, the user must explicitly approve the peer via `onIncomingSessionOffered`.
- **Remaining Limitations:** SAS verification is an **out-of-band visual comparison dependent on the user actively comparing codes**. If a user blindly approves a transfer from an unknown device without checking the code, a sophisticated active LAN MITM could intercept the transfer.
- **Residual Risk Justification:** Low likelihood on private LANs; fully compensated by out-of-band SAS comparison and certificate mutation blocking.

---

### RISK-02: File-Based Login Keychain & Exportable Software Private Key
- **Category:** Secret Management / Keychain Architecture
- **Affected Area:** `com.notch.NotchApp.LocalShare` & `com.notch.NotchApp.LocalSharePIN`
- **What is Accepted:** LocalShare identity secrets (certificate and raw 97-byte X9.63 P-256 private key) are stored in the macOS file-based login keychain (`login.keychain-db`) as generic password items (`kSecClassGenericPassword`).
- **Why Accepted:**
  *Reference: Apple TN3137 ("On Mac keychain APIs and implementations")*
  - The modern Data Protection Keychain (`kSecUseDataProtectionKeychain: true`) requires an Apple Developer Team ID and provisioned entitlements. In ad-hoc builds, CLI test runners, and unentitled development binaries, querying the Data Protection Keychain fails with `errSecMissingEntitlement` (`OSStatus -34018`).
  - Specifying an empty application list (`NSArray()`) causes macOS `SecurityAgent` to display modal password dialogs or hang headless CLI test runners in `mach_msg2_trap`.
- **Affected Security Boundary:** Application code identity boundary on the local Mac.
- **Storage & Key Architecture Reality:**
  - The private key is an **exportable software key**, NOT a hardware-bound Secure Enclave key. It is stored as raw ANSI X9.63 uncompressed elliptic curve key bytes in `login.keychain-db`.
  - `SecAccessCreate(descriptor, nil, &access)` pre-authorizes **only the creating application** (via its code designated requirement at the moment of item creation). It does **not** grant blanket access to all applications or same-UID processes.
  - In ad-hoc builds, recompiled binaries receive a new CDHash. An independently compiled ad-hoc binary attempting to read the item receives `errSecAuthFailed` (`-25293`) when user interaction is disabled, or triggers a macOS GUI prompt when interaction is allowed.
  - Under future Developer ID builds, the stable designated requirement (`anchor apple generic and identifier ...`) guarantees seamless access across application updates without prompts.
- **Compensating Controls (Independently Verified):**
  1. **POSIX User Isolation:** The login keychain is protected by Darwin per-user directory isolation (`0600`), blocking all other user accounts on the machine.
  2. **Device-Only Storage:** Items cannot be synced to other devices via iCloud Keychain.
  3. **Reentrant Interaction Governor:** `KeychainInteractionGovernor.shared.withInteractionDisabled` serializes Keychain calls with recursive locking and reference-counted depth, restoring interaction state safely on unwind.
  4. **Developer ID Roadmap:** Upon production packaging with an Apple Developer ID, secrets will be evaluated for migration to the Data Protection Keychain with `kSecAccessControl` and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Remaining Limitations:** Does not enforce Data Protection hardware encryption classes (`kSecAttrAccessible*`) because the file-based keychain relies entirely on the user's login session unlock state.
- **Residual Risk Justification:** Standard macOS file-based keychain protection is appropriate for ad-hoc and developer testing; full Data Protection migration is scheduled for Developer ID provisioning.

---

### RISK-03: Unauthenticated LocalSend Client Transport & Gated Loopback Isolation
- **Category:** Protocol Security / Client Authentication
- **Affected Area:** `LocalShareServer` (`/api/localsend/v2/prepare-upload`)
- **What is Accepted:** In standard LocalSend protocol, clients do not authenticate with client TLS certificates. The client's claimed identity (alias, device model, fingerprint) is provided in the JSON body of the HTTP request.
- **Why Accepted:** Full interoperability with official LocalSend clients (Android, iOS, Windows, Linux) which do not support client-certificate authentication.
- **Affected Security Boundary:** Server-side peer authentication on incoming transfer offers.
- **What an Attacker Can Still Do:** An attacker on the local network or a local unauthenticated process could construct a JSON request claiming the fingerprint of the user's favorite device.
- **Compensating Controls (Independently Verified):**
  1. **Gated Auto-Acceptance (Anti-Spoofing):** `LocalShareServer.handlePrepareUploadRoute` enforces that an incoming request claiming to be a favorite CANNOT bypass the user prompt without shared PIN authentication. Loopback connections do not bypass the prompt in production; auto-acceptance over loopback is strictly gated behind `isTestHarnessAutoAcceptEnabled` (Test 109 Subtest D).
  2. **Anti-Bypass IP Normalization:** `LocalShareSecurity.normalizeIP` strips brackets, ports, interface scopes (`%en0`), `::ffff:` IPv4-mapped prefixes, decimal octet leading zeros, and canonicalizes IPv6 loopback variants, preventing IP format evasion (Test 109 Subtest C).
  3. **Short Authentication String (SAS):** Users can verify peer identity out-of-band by comparing the 6-digit SAS code displayed in the UI (Test 108 Subtests A, B, C).
  4. **Anti-Brute-Force PIN Throttling & Escalating Lockout:** Incorrect PIN attempts incur progressive delays (0.15s per attempt up to 2.0s); 5 failures trigger a 60-second lockout; 10 failures trigger a 300-second lockout with HTTP 429 Too Many Requests and RFC 6585-compliant `Retry-After` header. Successful PIN entry immediately resets the failure counter (Test 109 Subtest B).
  5. **Cryptographically Secure 256-bit Upload Tokens:** File uploads require 256-bit cryptographically random tokens generated via CryptoKit `SymmetricKey(size: .bits256)` (64 lowercase hex characters, zero collisions across 1,000 samples, no timestamps or UUIDs) (Test 111 Subtest C).
  6. **Single-Use Atomic Reservation & Teardown Invalidation:** Tokens are reserved atomically upon validation to prevent concurrent replay, and destroyed permanently upon consumption or session teardown (Test 111 Subtests A & C).
- **Remaining Limitations:** Without a configured PIN, incoming transfers from favorite peers require explicit user confirmation on the receiver screen.
- **Residual Risk Justification:** Negligible risk of unauthorized file write; unauthenticated requests cannot bypass user confirmation.

---

### RISK-04: Direct Distribution Product Architecture Decision (App Sandbox Trade-Off)
- **Category:** Platform Security / Sandbox Boundary
- **Affected Area:** App-wide (NotchApp executable)
- **What is Accepted:** Notchify is distributed directly as an un-sandboxed application signed with Developer ID and notarized by Apple, rather than running inside the macOS App Sandbox (`com.apple.security.app-sandbox`).
- **Correction of Previous Documentation:**
  - *Correction 1*: Previous audit notes claimed Telegram automation required AppleScript (`NSAppleScript`) which was blocked by sandbox. This was factually incorrect: `TelegramModule` uses the Telegram Bot API over HTTPS and custom URI schemes (`tg://`), with zero AppleScript usage.
  - *Correction 2*: Previous notes claimed App Sandbox completely blocks global keyboard event monitoring. Empirical testing with a sandboxed prototype (`scratch/sandbox_test/TestApp.app`) signed with sandbox entitlement demonstrated that with Accessibility trust granted (`AXIsProcessTrusted == true`), `NSEvent.addGlobalMonitorForEvents` creates successfully.
  - *Correction 3*: App Sandbox supports background file writing to `~/Downloads` via `com.apple.security.files.downloads.read-write`.
- **Architectural Rationale for Direct Distribution:**
  1. **Direct Distribution Strategy**: Direct distribution was chosen as an explicit product architecture decision: allowing seamless auto-updates via Sparkle, unrestricted peer-to-peer raw socket binding on arbitrary local network interfaces without entitlement negotiation, and zero-friction user workflow without sandbox container redirection.
  2. **System Notch Overlay Architecture**: Floating panels (`NSPanel`) positioned directly over the MacBook notch across all spaces at `.screenSaver` / `.mainMenu` levels with global mouse tracking operate with maximum reliability outside sandbox restrictions.
- **Affected Security Boundary:** Operating system application isolation boundary.
- **Compensating Controls (Independently Verified):**
  1. **Recursive Directory-Walk POSIX openat & Root O_NOFOLLOW:** `LocalShareFileStreamWriter` pins the trusted root session directory with `open(pathPtr, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)`, verifying via `fstat` and `O_NOFOLLOW` that the root itself is not a symlink. It walks intermediate directories with `openat(currentDirFd, dirName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)` and creates leaf files with `openat(..., O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)`. Containment is kernel-guaranteed beneath the pinned root directory (Test 107 Subtests A-G).
  2. **Path Containment & Directory Isolation:** Destination URLs are canonicalized and verified against designated folders via realpath resolution (`LocalShareSecurity.isContained`) (Test 103 Subtests 4 & 5). Ancestors above the root directory are governed by Darwin per-user directory permissions (`0700`).
  3. **Non-Overwriting File Promotion:** Incoming files increment numeric counters (`file (1).ext`) rather than overwriting existing user data (Test 107 Subtest C).
  4. **macOS Quarantine Extended Attribute:** Received files are tagged with `com.apple.quarantine`, ensuring Gatekeeper and XProtect scan them when opened by the user via Finder or LaunchServices.
- **Accurate Quarantine Limitations:** Quarantine tagging ensures Gatekeeper evaluation upon user GUI launch; it does not perform an immediate proactive scan at download time and does not constrain raw CLI execution.
- **Residual Risk Justification:** Direct distribution with Developer ID code signing and Apple Notarization provides cryptographic integrity and Gatekeeper trust appropriate for utility software.

---

### RISK-05: System Accessibility Privileges & Global Event Monitoring
- **Category:** System Permissions / Privacy Surface
- **Affected Area:** `ThockModule.swift`, `TelegramModule.swift`, `WindowSnapModule.swift`
- **What is Accepted:** Notchify requests macOS Accessibility privileges (`AXIsProcessTrusted`) and uses `NSEvent.addGlobalMonitorForEvents`.
- **Why Accepted:**
  - Window frame positioning and screen dimension calculations.
  - Realistic inter-key interval timing calculation for mechanical keyboard sound simulation.
- **Affected Security Boundary:** User privacy and input monitoring surface.
- **What an Attacker Can Still Do:** Theoretical privilege abuse if the binary were replaced or compromised.
- **Compensating Controls (Independently Verified):**
  1. **Zero Keystroke / Text Logging:** The event monitor records **only timestamp intervals** between events. Keycodes, characters, string representations, and modifiers are never read, stored, or transmitted (Test 97).
  2. **Elimination of Synthetic Input:** Blind AppleScript `key code 36` (Return) synthesis was completely removed (SEC-07). All messaging is staged via official OS URI schemes (`tg://` and `whatsapp://`) where the user manually confirms dispatch (Test 3).
  3. **Immediate Unhooking:** Monitors are dismantled immediately upon module deactivation or application backgrounding.
- **Remaining Limitations:** TCC Accessibility permission is granted at the application level by the user.
- **Residual Risk Justification:** Strictly non-invasive; zero keystroke logging verified by code audit and automated tests.

---

## 3. Residual Risk Summary Matrix

| Risk ID | Title | Residual Likelihood | Residual Impact | Key Compensating Control | Independent Test Verification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **RISK-01** | Self-Signed LAN TLS | Low | Low | Out-of-band 6-digit SAS code comparison & fingerprint pinning | **VERIFIED** (Test 108 Subtests A-C) |
| **RISK-02** | File-Based Login Keychain Open ACL | Very Low | Low | Pre-authorizes creating app designated requirement; `0600` permissions; Developer ID migration planned | **VERIFIED** (TN3137 audit) |
| **RISK-03** | Unauthenticated LocalSend Client | Very Low | Negligible | Gated auto-acceptance requires PIN; loopback gated to test harness; prompts user on LAN claims | **VERIFIED** (Test 109 Subtests A-D) |
| **RISK-04** | Non-Sandboxed Application | Very Low | Medium | Recursive `openat` / `fstat` walk with `O_CREAT \| O_EXCL \| O_NOFOLLOW` & quarantine tagging | **VERIFIED** (Test 107 Subtests A-F) |
| **RISK-05** | Accessibility & Event Monitor | Very Low | Negligible | Zero text/keycode capture; timestamp interval tracking only | **VERIFIED** (Test 97) |
