# Security Skill Log

## Step 0 — Security Audit Skill Selection & Applicability

- **Phase**: Step 0 — Security Audit Setup & Skill Alignment
- **Date**: 2026-11-11
- **Trigger**: Full security audit of the Notchify (Notch) macOS application requested on branch `fix/from-audit`.
- **Target**: Native macOS (AppKit / SwiftUI) utility application.
- **Constraints**:
  - No app execution, no synthetic events, no osascript, no screenshots.
  - Read-only static inspection and exact code citations (`file:line` + quoted snippet).
  - No source edits; fixes proposed as architectural recommendations.
  - Zero unverified claims; all assertions labeled with evidence levels.

### 1. Primary Security Skills & macOS Applicability

| Skill | Applicable Checks (macOS Native App) | N/A Checks & Justification |
| :--- | :--- | :--- |
| **`security-audit`** | • Credential scanning across source, git history, dotfiles, and logs<br>• Process execution (`Process()`, `posix_spawn`, `NSTask`, `cargo`, `git`, `thock-cli`)<br>• Local file system security, atomic writes, permissions, path traversal<br>• Supply chain and dependency pinning (Cargo.lock, Package.swift)<br>• Deserialization safety and untrusted file handling | • Cloudflare edge / WAF / CDN / Serverless: *N/A, app is a local macOS client application with no edge infrastructure.*<br>• SQL Injection / Web Application CSRF/XSS: *N/A, no web server or relational SQL backend.*<br>• Container / Kubernetes orchestration: *N/A, runs as a native macOS Mach-O binary under the user's GUI session.* |
| **`axiom-security`** | • macOS Keychain API usage (`SecItemAdd`, `SecItemCopyMatching`, `kSecAttrAccessible`)<br>• Data protection at rest (`NSFileProtection`, file access permissions)<br>• macOS App Sandbox, entitlements, Hardened Runtime, and code signing<br>• AI & Agentic security (prompt injection in Ask AI / Notes, tool confirmation)<br>• Keystroke monitoring and CGEvent tap leakage risks | • App Attest (`DCAppAttestService`): *N/A, app has no proprietary attestation backend server.*<br>• Passkeys (`ASAuthorizationController`): *N/A, app does not implement WebAuthn or account identity federation.*<br>• SensitiveContentAnalysis: *N/A, app does not process CSAM or use SensitiveContentAnalysis APIs.*<br>• Apple Pay / Wallet: *N/A, utility app without financial transactions.* |
| **`gsd-secure-phase`** | • STRIDE threat modeling per feature module<br>• Trust boundary and attack surface enumeration<br>• Verification of claimed mitigations in code and documentation<br>• Formal threat register tracking and gap analysis | • Automated npm runner / CLI hooks (`gsd-tools.cjs`): *N/A, static review mode without workspace phase automation.*<br>• Automated git branch shipping / CI gates: *N/A, audit-only phase without git push.* |

### 2. Supporting Technical Skills Chosen

- **`axiom-macos`**: Reviewing macOS AppKit lifecycle, NSPanel window levels, App Sandbox boundaries, entitlements, and TCC permissions (Accessibility, Input Monitoring, Camera).
- **`axiom-data`**: Reviewing data persistence (`UserDefaults`, JSON file storage, `NoteStorageManager`), atomic writes, and data privacy.
- **`axiom-networking`**: Reviewing outbound network requests in `AskAIService`, `TelegramModule`, `MediaRemoteBridge`, App Transport Security (ATS), and URL validation.
- **`axiom-concurrency` & `swift-concurrency-pro`**: Reviewing thread safety, actors, data races, `@unchecked Sendable`, and cancellation handling.
- **`ponytail`**: Identifying simplest, robust architectural fixes (e.g., native Keychain wrappers, stdlib alternatives) instead of complex custom cryptographic layers.
- **`gravitas`**: Enforcing evidence-backed findings, zero unverified assumptions, exact file:line citations, and strict confidence labeling.
- **`graphify`**: Mapping dependencies, entry points, and architectural cross-references across the codebase.

---
