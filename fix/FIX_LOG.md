# Notchify Fix Execution Log

This log documents every batch change, pre-mortem analysis, skill activation, evidence collection, and regression sweep.

---

## Skills Re-Pick Log

| Timestamp | Phase / Batch | Trigger | Skills Added | Skills Retained / Dropped |
|---|---|---|---|---|
| 2026-11-11 00:50 | Phase 0 & 1 Setup | Initial audit & question bank ingestion | `ponytail`, `gravitas`, `graphify`, `swiftui-pro`, `swiftui-expert-skill`, `swift-concurrency-pro`, `axiom-performance`, `axiom-security`, `axiom-data` | Retained all foundational skills |
| 2026-11-11 01:00 | Batch B1 Execution | Data and crash safety (Keychain, Tests, MediaRemote, CompanionPanel) | `axiom-security`, `axiom-data`, `axiom-concurrency`, `axiom-testing` | Dropped UI-specific styling skills for B1 |
| 2026-11-11 01:15 | Batch B2 Execution | Lag and responsiveness (SettingsStore fan-out, TimelineView, hover) | `axiom-performance`, `axiom-swiftui`, `apple-design`, `emilkowalski-motion` | Retained concurrency & performance |

---

## Batch B1 Entry: Data & Crash Safety
- **Batch ID:** B1
- **Files Modified:**
  - `Tests/VerificationTests.swift:1240-1249` (Sandboxed Test 44 to isolated `UserDefaults` suite)
  - `Sources/Core/KeychainHelper.swift:28-40` (Added non-blocking `saveSecretAsync`)
  - `Sources/Core/NotchModule.swift:198-206` (Async keychain saving for Gemini, OpenAI, Google Account keys)
  - `Sources/Modules/Telegram/TelegramModule.swift:362` (Async keychain saving for Telegram bot token)
  - `Sources/Modules/NowPlaying/MediaRemoteBridge.swift:36-50, 140-150, 200-210, 260-275` (Added `cacheLock` synchronization)
  - `Sources/Modules/Companion/CompanionWindow.swift:89-91, 154-158` (Removed forceful `self.contentView = nil`)
- **Why:** Prevent test runs from deleting developer notes, prevent keystroke freezes on main thread, prevent data races on concurrent artwork caches, prevent EXC_BAD_ACCESS in AppKit window deallocation.
- **Pre-Mortem Result:** Verified that removing `contentView = nil` safely delegates deallocation to ARC (matching commit `5682c6b`). Verified async keychain write does not lose in-memory credentials.
- **Complaints Addressed:** C10, C1.
- **Evidence File:** `fix/evidence/b1_test_output.txt` (83/83 verification tests passed).
