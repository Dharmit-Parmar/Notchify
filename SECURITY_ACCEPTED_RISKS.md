# NOTCHIFY — SECURITY ACCEPTED RISKS & THREAT MODEL DECISIONS

**Application:** Notchify / NotchApp (macOS)  
**Document Revision:** 2.0 (Stage 4 Technical Verification & Threat Model Overhaul)  
**Date:** November 17, 2026  
**Auditor / System Architect:** Principal macOS Application Security Engineer  

---

## 1. Overview & Threat Model Rationale

In high-reliability software engineering, certain architectural trade-offs are deliberately evaluated, measured, and accepted where strict compliance with alternative approaches would compromise core usability, privacy, or offline functionality.

This document formally records all accepted security risks, architectural trade-offs, threat model boundaries, and their respective compensating controls. Every claim in this register has been independently verified against the actual source code and runtime behavior.

---

## 2. Risk Register & Compensating Controls

### RISK-01: Self-Signed TLS Certificates vs. Public CA Certificates
- **Category:** Transport Security / Identity
- **Affected Area:** LocalShare Peer-to-Peer Protocol (LocalSend Specification)
- **What is Accepted:** LocalShare devices generate self-signed P-256 ECC X.509 certificates for ad-hoc local network TLS sessions rather than obtaining publicly trusted WebPKI Certificate Authority certificates (e.g., Let's Encrypt, DigiCert).
- **Why Accepted:**
  - Peer-to-peer LAN transfers must operate completely offline without internet access, external DNS infrastructure, or domain ownership.
  - Compatibility with the open-source LocalSend specification requires dynamic local IP/HTTPS endpoints.
- **Affected Security Boundary:** Transport confidentiality and peer authentication on the local area network (LAN).
- **What an Attacker Can Still Do:**
  - An active Man-in-the-Middle (MITM) attacker on the local Wi-Fi/Ethernet network could attempt to intercept a first-contact connection by presenting their own self-signed certificate if the user clicks "Accept" without verifying identity.
- **Compensating Controls (Independently Verified):**
  1. **Cryptographic SHA-256 Fingerprint Pinning:** Clients verify the server's leaf certificate against the expected fingerprint during TLS negotiation (`LocalSharePeerPinningDelegate`), rejecting mismatches (Test 103 Subtest 11).
  2. **Short Authentication String (SAS / Verification Code):** `LocalShareSecurity.computeVerificationCode` derives a symmetric 6-digit verification code from both endpoints' fingerprints. Both devices display the code; under an active MITM, the codes differ, alerting users out-of-band (Test 108).
  3. **Certificate Change Detection:** If a previously trusted peer presents a certificate with a modified fingerprint, the session is immediately blocked with HTTP 403 (`LocalSharePeerTrustState.certificateChanged`) (Test 103 Subtest 21).
  4. **First-Contact Authorization Gate:** On first contact, the user must explicitly approve the peer via `onIncomingSessionOffered`.
- **Remaining Limitations:** If a user ignores the SAS verification code on first contact on an untrusted public Wi-Fi, an active MITM could intercept that initial transfer.
- **Residual Risk Justification:** Low likelihood on private LANs; compensated by out-of-band SAS comparison and certificate mutation blocking.

---

### RISK-02: File-Based Login Keychain & Designated Code Requirement Scope
- **Category:** Secret Management / Keychain ACL
- **Affected Area:** `com.notch.NotchApp.LocalShare` & `com.notch.NotchApp.LocalSharePIN`
- **What is Accepted:** LocalShare secrets are stored in the legacy macOS file-based login keychain (`login.keychain-db`) using `SecAccessCreate(descriptor, nil, &access)` with a `nil` trusted list.
- **Why Accepted:**
  *Reference: Apple TN3137*
  - The modern Data Protection Keychain (`kSecUseDataProtectionKeychain: true`) requires an Apple Developer Team ID and provisioned entitlements. In ad-hoc builds, CLI test runners, and unentitled development binaries, querying the Data Protection Keychain fails with `errSecMissingEntitlement` (`OSStatus -34018`).
  - Specifying an empty application list (`NSArray()`) causes macOS `SecurityAgent` to display modal password dialogs or hang headless CLI test runners in `mach_msg2_trap`.
- **Affected Security Boundary:** Application code identity boundary on the local Mac.
- **Accurate ACL Mechanics & Limitations:**
  - `SecAccessCreate(descriptor, nil, &access)` defaults to pre-authorizing **only the creating application** (via its code designated requirement at the moment of item creation). It does **not** grant blanket access to all applications or same-UID processes.
  - In ad-hoc builds, recompiled binaries receive a new CDHash. An independently compiled ad-hoc binary attempting to read the item receives `errSecAuthFailed` (`-25293`) when user interaction is disabled, or triggers a macOS GUI prompt when interaction is allowed.
  - Under future Developer ID builds, the stable designated requirement (`anchor apple generic and identifier ...`) guarantees seamless access across application updates without prompts.
- **Compensating Controls (Independently Verified):**
  1. **POSIX User Isolation:** The login keychain and fallback files are protected by standard Darwin file permissions (`0600`), blocking all other user accounts on the machine.
  2. **Device-Only Storage:** Items cannot be synced to other devices via iCloud Keychain.
  3. **Reentrant Interaction Governor:** `KeychainInteractionGovernor.shared.withInteractionDisabled` serializes Keychain calls with recursive locking and reference-counted depth, restoring interaction state safely on unwind.
  4. **Developer ID Roadmap:** Upon production packaging with an Apple Developer ID, secrets will be migrated to the Data Protection Keychain with `kSecAccessControl` and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Remaining Limitations:** Does not enforce Data Protection hardware encryption classes (`kSecAttrAccessible*`) because the file-based keychain relies entirely on the user's login session unlock state.
- **Residual Risk Justification:** Standard macOS file-based keychain protection is appropriate for ad-hoc and developer testing; full Data Protection migration is scheduled for Developer ID provisioning.

---

### RISK-03: Unauthenticated LocalSend Client Transport & Reassessed Loopback
- **Category:** Protocol Security / Client Authentication
- **Affected Area:** `LocalShareServer` (`/api/localsend/v2/prepare-upload`)
- **What is Accepted:** In standard LocalSend protocol, clients do not authenticate with client TLS certificates. The client's claimed identity (alias, device model, fingerprint) is provided in the JSON body of the HTTP request.
- **Why Accepted:** Full interoperability with official LocalSend clients (Android, iOS, Windows, Linux) which do not support client-certificate authentication.
- **Affected Security Boundary:** Server-side peer authentication on incoming transfer offers.
- **What an Attacker Can Still Do:** An attacker on the local network or a local unauthenticated process could construct a JSON request claiming the fingerprint of the user's favorite device.
- **Compensating Controls (Independently Verified):**
  1. **Gated Auto-Acceptance (Anti-Spoofing):** `LocalShareServer.handlePrepareUploadRoute` enforces that an incoming request claiming to be a favorite CANNOT bypass the user prompt without shared PIN authentication. Loopback connections do not bypass the prompt in production; auto-acceptance over loopback is strictly gated behind `isTestHarnessAutoAcceptEnabled` (Test 109).
  2. **Short Authentication String (SAS):** Users can verify peer identity out-of-band by comparing the 6-digit SAS code derived from the TLS certificate fingerprints (Test 108).
  3. **Anti-Brute-Force PIN Throttling & Lockout:** Incorrect PIN attempts incur progressive delays (up to 2s); 5 failures trigger a 60-second lockout; 10 failures trigger a 300-second lockout with HTTP 429 (Test 109 Subtest B).
  4. **Single-Use Upload Tokens:** File uploads require 256-bit cryptographically random tokens issued only after session acceptance (Test 103 Subtest 10).
  5. **Anti-Replay Token Invalidation:** Tokens are permanently destroyed upon consumption or session teardown (Test 111).
- **Remaining Limitations:** Without a configured PIN, incoming transfers from favorite peers require explicit user confirmation on the receiver screen.
- **Residual Risk Justification:** Negligible risk of unauthorized file write; unauthenticated requests cannot bypass user confirmation.

---

### RISK-04: Non-Sandboxed Application Architecture & Directory Containment
- **Category:** Platform Security / Sandbox Boundary
- **Affected Area:** App-wide (NotchApp executable)
- **What is Accepted:** Notchify does not enable the macOS App Sandbox (`com.apple.security.app-sandbox`).
- **Why Accepted:**
  - Notchify is an island overlay utility that positions itself directly over the physical MacBook camera housing above all menus (`NSPanel` floating at `.screenSaver` / `.mainMenu` level).
  - Requires accessibility APIs (`AXIsProcessTrusted`) to compute window bounds and monitor window focus.
  - Requires `NSEvent.addGlobalMonitorForEvents` to measure inter-key timing intervals for the Thock mechanical keyboard simulator.
- **Affected Security Boundary:** Operating system application isolation boundary.
- **What an Attacker Can Still Do:** If a remote code execution vulnerability existed in a dependency or file parser, the process has standard user-level permissions.
- **Compensating Controls (Independently Verified):**
  1. **Directory-Relative POSIX openat:** `LocalShareFileStreamWriter` opens files using `openat` relative to a verified directory file descriptor (`open(..., O_RDONLY | O_DIRECTORY | O_CLOEXEC)` validated via `fstat`), applying `O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC` with mode `0o600`. This eliminates ancestor symlink substitution TOCTOU races (Test 107).
  2. **Path Containment:** Destination URLs are canonicalized and verified against the designated session folder using realpath resolution (`LocalShareSecurity.isContained`) (Test 103 Subtests 4 & 5).
  3. **Non-Overwriting File Promotion:** Incoming files increment numeric counters (`file (1).ext`) rather than overwriting existing user data (Test 107 Subtest C).
  4. **macOS Quarantine Extended Attribute:** Received files are tagged with `com.apple.quarantine`, ensuring Gatekeeper and XProtect scan them when opened by the user via Finder or LaunchServices.
- **Accurate Quarantine Limitations:** Quarantine tagging ensures Gatekeeper evaluation upon user GUI launch; it does not perform an immediate proactive scan at download time and does not constrain raw CLI execution.
- **Residual Risk Justification:** System overlay utilities inherently require system-level windowing and accessibility APIs incompatible with App Sandbox. Direct Distribution with Developer ID and Apple Notarization provides cryptographic validation and Gatekeeper trust.

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
| **RISK-01** | Self-Signed LAN TLS | Low | Low | Out-of-band 6-digit SAS code comparison & fingerprint pinning | **VERIFIED** (Test 108) |
| **RISK-02** | File-Based Login Keychain Open ACL | Very Low | Low | Restricted to same POSIX UID; `0600` permissions; Developer ID migration planned | **VERIFIED** (TN3137 audit) |
| **RISK-03** | Unauthenticated LocalSend Client | Very Low | Negligible | Gated auto-acceptance requires PIN or loopback; prompts user on LAN claims | **VERIFIED** (Test 109) |
| **RISK-04** | Non-Sandboxed Application | Very Low | Medium | Atomic POSIX `O_CREAT \| O_EXCL \| O_NOFOLLOW` creation & quarantine tagging | **VERIFIED** (Test 107) |
| **RISK-05** | Accessibility & Event Monitor | Very Low | Negligible | Zero text/keycode capture; timestamp interval tracking only | **VERIFIED** (Test 97) |
