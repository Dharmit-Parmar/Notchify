# 🪵 Notchify — Changelog & Engineering Release Notes

All notable changes, architectural improvements, and security enhancements to Notchify are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.0] — 2026-11-23

### 🛡️ Security & Zero-Leak Credential Guarantees
- **RFC 8252 Native App PKCE OAuth**: Added `GoogleOAuthManager` utilizing Proof Key for Code Exchange (RFC 7636, S256). Operates without any bundled client secrets, eliminating credential leakage risk in native binary distributions.
- **Ephemeral Loopback Binding**: Implemented local TCP loopback redirect listener (`http://127.0.0.1:<port>/oauth2callback`) with random port binding prior to browser dispatch, eliminating authorization code interception and race conditions.
- **Hardware-Isolated Keychain Storage**: Refactored `KeychainHelper` to store generic password secrets (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) with an enforced non-interactive context (`LAContext.interactionNotAllowed = true`), preventing unwanted interactive system dialogs and thread deadlocks.
- **Zero-Disk-Cache Network Pipeline**: Configured strict ephemeral `URLSession` instances with zero disk caching, zero persistent cookie storage, and domain-bounded redirect validation (`SecureAPITaskDelegate`) to prevent cross-host credential leakage.
- **Encrypted Local Storage (AES-256-GCM)**: Hardened `EncryptedFileStore` with atomic file writes, POSIX `0600` permissions, and automated migration from legacy UserDefaults plaintext caches to authenticated ciphertext (`calendar_cache.enc`).

### 📅 Google Calendar & Google Tasks Integration
- **Unified Account Synchronization**: Added `GoogleSyncService` supporting single-sign-on linking across Ask AI, Calendar, and Tasks.
- **Interactive OAuth & Token Refresh**: Built seamless automated token renewal via OAuth refresh tokens preserved in Apple Keychain, with fallback for offline cached event reading.
- **Direct Event & Checklist Parsing**: Added full ISO 8601 parsing for both RFC 3339 timestamped events and all-day Gregorian calendar entries, mapped to native color-coded widget cards.

### 🎨 Modular Bento Dashboard & UX Improvements
- **Interactive Drag & Drop Canvas**: Replaced legacy static slot assignments with an interactive 4-slot canvas (`DashboardSettingsView`), featuring span toggles (1-space vs 2-spaces), quick-eject, and click-to-assign capabilities.
- **Silhouette Mini Preview**: Unified empty-state placeholders (`emptyPreviewPlaceholder`) across all layout flow modes (`horizontalStrip`, `focusDominant`, `bentoQuad`, `adaptiveAuto`), eliminating phantom bar rendering when slots are unassigned.
- **Accessibility & Focus Rings**: Implemented custom focus-state indicators (`@FocusState`) across API key and model text fields to maintain clear visual affordances under `.textFieldStyle(.plain)`.
- **Clock & Quick Controls Refinements**: Polished `ClockWidgetView` digital/analog rendering and tightened responsiveness in `NotchRootView` and `ModularDashboardView`.

### 📦 Shelf & AirDrop Module Enhancements
- **Multi-File Staging Shelf**: Expanded drag-and-drop file ingestion support across images, PDFs, URLs, and plain text with security-scoped resource handling (`startAccessingSecurityScopedResource`).
- **Deferred Cleanup Governance**: Added automatic release of deferred security-scoped bookmarks on idle teardown to prevent file descriptor leaks.

### 🧹 Repository Hygiene & Memory Optimization
- **Compiler Cache Purge**: Reclaimed ~2.75 GB of disk space by purging redundant compiler index stores, debug products, and obsolete build intermediates.
- **Knowledge Graph Synchronization**: Fully regenerated and clustered the project's semantic knowledge graph with Graphify (2,524 nodes, 6,528 edges, 120 communities).
- **Toolchain CLT Compatibility**: Resolved macro plugin incompatibilities (`SwiftUIMacros.StateMacro`) under macOS Command Line Tools by using decoupled state wrappers.

---

## [2.0.0] — 2026-11-17

### Added
- **Radial Document Studio**: 360° circular jog-wheel dial for PDF/image manipulation, compression, and visual QA directly under the notch.
- **Mechanical Thock Audio Engine**: Real-time acoustic keyboard simulation supporting Blue, Brown, Red, and Holy Panda switch profiles with low-latency `AVAudioEngine`.
- **Encrypted LocalShare**: Decentralized peer-to-peer Wi-Fi/AWDL file transfer with TLS-encrypted mutual authentication and Zero-Configuration Bonjour discovery.
- **OKLab Dynamic Glass**: Perceptually uniform OKLab color palette engine synchronizing with album art, active wallpaper, and circadian solar cycles.
