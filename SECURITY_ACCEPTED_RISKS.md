# NOTCHIFY — SECURITY ACCEPTED RISKS & THREAT MODEL DECISIONS

**Application:** Notchify / NotchApp  
**Document Revision:** 1.0  
**Date:** November 17, 2026  
**Auditor / System Architect:** Principal macOS Application Security Engineer  

---

## 1. Overview & Threat Model Rationale

In high-reliability software engineering, certain architectural trade-offs are deliberately evaluated, measured, and accepted where strict compliance with alternative approaches would compromise core usability, privacy, or offline functionality.

This document formally records all accepted security risks, architectural trade-offs, threat model boundaries, and their respective compensating controls.

---

## 2. Risk Register & Compensating Controls

### RISK-01: Self-Signed TLS Certificates vs. Public CA Certificates
- **Category:** Transport Security / Identity
- **Affected Area:** LocalShare P2P Protocol (LocalSend Specification)
- **Description:** LocalShare devices generate self-signed P-256 ECC X.509 certificates for ad-hoc local network TLS sessions rather than relying on public WebPKI Certificate Authorities (e.g. Let's Encrypt, DigiCert).
- **Threat Scenario:** A passive adversary on the local LAN could attempt a Man-in-the-Middle (MitM) TLS proxy by presenting a different self-signed certificate.
- **Why Accepted:** Peer-to-peer file transfer must operate entirely offline without internet connectivity, external DNS resolution, or central infrastructure. LocalSend compatibility requires dynamic local TLS endpoints.
- **Compensating Controls:**
  1. **Cryptographic SHA-256 Fingerprint Pinning:** During the initial mDNS/HTTP discovery handshake, the peer's certificate fingerprint is exchanged and displayed.
  2. **First-Contact Authorization Gate:** On first contact, the user must explicitly approve or verify the peer device (`LocalSharePeerTrustState.unverifiedFirstContact`).
  3. **Certificate Change Detection:** If a previously trusted peer presents a certificate DER that hashes to a different fingerprint, the session is immediately blocked with HTTP 403 (`LocalSharePeerTrustState.certificateChanged`) and quarantined.
  4. **Mutual Client Fingerprint Validation:** Clients verify the server's leaf certificate against the expected fingerprint during TLS negotiation.

---

### RISK-02: Open Keychain Access List for Recompiled Ad-Hoc Binaries
- **Category:** Secret Management / Keychain ACL
- **Affected Area:** `com.notch.NotchApp.LocalShare` & `com.notch.NotchApp.LocalSharePIN`
- **Description:** `SecAccessCreate` is passed a `nil` trusted application array, allowing binaries executing under the exact same user account (POSIX UID) to read the stored local TLS identity and PIN without interactive GUI authorization modals.
- **Threat Scenario:** A rogue process executing as the current user could query the macOS login keychain and read the local peer certificate or PIN.
- **Why Accepted:**
  - Without this, every newly compiled developer binary, test execution, or headless CI runner prompts the user with macOS SecurityAgent password dialogs or hangs indefinitely in headless terminal environments.
  - The threat boundary in macOS user-space considers any process running under the same UID to already possess the user's execution privileges.
- **Compensating Controls:**
  1. Access is restricted to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, preventing decryption when the Mac is locked or booted into recovery.
  2. File-based fallback and notes are protected with `0600` POSIX file permissions, blocking any other macOS user accounts on the machine.
  3. Items cannot be synchronized across iCloud Keychain (`ThisDeviceOnly` attribute enforced).

---

### RISK-03: Localhost Loopback HTTP/HTTPS Communication
- **Category:** Network Boundaries / IPC
- **Affected Area:** LocalShare loopback testing, Thock CLI telemetry, Local Web Preview
- **Description:** The app binds NWListeners and connects via `127.0.0.1` ephemeral ports for intra-process test verification and local browser file downloads.
- **Threat Scenario:** Another local application running under a different user account on a shared multi-user machine could connect to the loopback port.
- **Why Accepted:** Necessary for automated end-to-end integration testing and zero-configuration browser downloads.
- **Compensating Controls:**
  1. **Single-Use Cryptographic Tokens:** File download and upload routes require cryptographically random 128-bit UUID tokens generated per file and bound to the client's session.
  2. **Client IP Binding:** Tokens validated during upload/download strictly verify that the connecting client IP matches the session's registered IP.
  3. **Token Invalidation:** Tokens are permanently destroyed upon first consumption; replay attempts return HTTP 403.
  4. **Path Traversal Containment:** All file writes and reads are resolved through `LocalShareSecurity.resolveSafeDestination` and canonical realpath sandboxing, preventing directory escape.

---

### RISK-04: Accessibility API Integration for Direct Messaging & UI Navigation
- **Category:** System Permissions / TCC Surface
- **Affected Area:** `TelegramModule.swift`, `WhatsAppModule.swift`, `WindowSnapModule.swift`
- **Description:** Notch requests macOS Accessibility privileges (`AXIsProcessTrusted`) to calculate window frame boundaries, position the dynamic notch island, and inspect UI states.
- **Threat Scenario:** Excessive accessibility privileges could theoretically inspect other window contents.
- **Why Accepted:** Notch is an island overlay positioned above macOS menu bars and requires accurate window frame sizing to prevent click-through blocking.
- **Compensating Controls:**
  1. **Deprecation of Synthetic Keystrokes:** Blind AppleScript `key code 36` Return key synthesis was completely removed (SEC-07). All message dispatching uses official OS URL schemes (`tg://` and `whatsapp://`) where the user retains confirmation control.
  2. **Zero Text Capture:** The global key monitor in `ThockModule` measures only time deltas between key events for acoustic sound playback; no keycodes, characters, or text buffers are ever logged or retained.
  3. **Minimal Framing:** The window dynamically collapses to the physical camera housing dimensions (`210 x 34 px`), preventing screen obstruction.

---

## 3. Residual Risk Assessment Summary

| Accepted Risk | Residual Likelihood | Residual Impact | Justification |
| :--- | :--- | :--- | :--- |
| Self-Signed LAN TLS | Low (Local LAN only) | Low | Mitigated by SHA-256 fingerprint pinning and change detection. |
| Open Keychain ACL (Same UID) | Very Low | Low | Mitigated by device-only storage and POSIX user boundary. |
| Loopback Networking | Very Low | Negligible | Mitigated by single-use token binding and IP verification. |
| Accessibility Privileges | Very Low | Negligible | Keystroke synthesis eliminated; read-only window geometry. |
