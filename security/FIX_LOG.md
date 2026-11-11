# Security Remediation Log: Notchify macOS (`fix/security-round1`)

## Stage 0: Re-Verification & Analysis (No Source Edits)

- **Date**: 2026-11-11
- **Trigger**: User command to re-verify all findings against the current codebase on branch `fix/security-round1` (forked from `fix/from-audit`), inspect specific edge cases, scan pushed git history, and output `security/VERIFIED_FINDINGS.md`.
- **Operating Rule**: Zero source edits. All findings treated as hypotheses until verified against exact source lines.
- **Skills Activated**:
  - `security-audit`: Guides verification methodology, source-first evidence gathering, and false-positive elimination.
  - `axiom-security`: macOS security architecture, Keychain, CryptoKit, Hardened Runtime, and TCC permissions.
  - `gsd-secure-phase`: Systematically audits STRIDE mitigations and verifies security claims against implementation.
  - `axiom-macos`: AppKit lifecycle, NSWorkspace, App Sandbox limitations, and Info.plist requirements.
  - `axiom-data`: Data persistence, migration integrity, and file protection.
  - `axiom-networking`: URLSession configuration, error masking, and endpoint security.
  - `axiom-concurrency`: Thread safety and async guarantees for background operations.
  - `swift-concurrency-pro`: Modern Swift concurrency patterns and safety.
  - `axiom-testing`: Headless test design and contract verification.
  - `ponytail`: Enforcing smallest, simplest, standard-library-first fixes (YAGNI, minimal diffs).
  - `gravitas`: Invariant enforcement: ground before mutating, require observed evidence, cite exact `file:line`, no unsubstantiated claims.
  - `graphify`: Caller and callee dependency analysis across modules.
- **Skills Dropped**:
  - None dropped; all 12 skills are relevant to the security review and remediation lifecycle.

---

## Stage A: Lock Today's Behavior (Characterization Baseline Tests)

- **Date**: 2026-11-11
- **Trigger**: User command to lock today's behavior with characterization tests across all production contracts before modifying any source code.
- **Operating Rules**:
  - Tests only, zero edits to `Sources/` or `Package.swift`.
  - Use isolated temporary directories for filesystem operations.
  - Use a throwaway `UserDefaults(suiteName: ...)` suite.
  - Use an isolated test service name for Keychain operations (`com.notch.test.baseline`).
  - No new dependencies.
  - All 85 existing verification tests must continue to pass without regression.
- **Skills Re-Picked & Evaluated**:
  - `security-audit`: Ensuring characterization captures real trust boundaries and expected security invariants.
  - `axiom-security`: Keychain query structure, CryptoKit readiness, and credential isolation.
  - `axiom-testing`: Writing deterministic, headless characterization assertions without GUI dependencies.
  - `axiom-macos`: Path resolution, POSIX permissions (0600), temporary directory safety.
  - `axiom-data`: JSON serialization round-tripping, atomic file replacement, and schema preservation.
  - `axiom-networking`: HTTP request method, header verification, and URL query parameter isolation.
  - `ponytail`: Minimal, direct test assertions with standard library Foundation/CryptoKit.
  - `gravitas`: Strict verification: observe actual test execution output, record exact test counts and warnings.
  - `graphify`: Validating that test targets mirror module contracts accurately.
- **Baseline Build Metrics**:
  - Compiler Errors: 0
  - Compiler Warnings: 0 (2 linker search path warnings for CommandLineTools)
  - Existing Passing Tests: 85 / 85

---

## Stage B: Small, Targeted Security Fixes (Per-Commit Execution)

- **Date**: 2026-11-11
- **Trigger**: User authorized execution of Stage B fixes ("start").
- **Operating Rules**:
  - One commit per item with format `SEC-X-n: <what>`.
  - Minimal diffs; zero edits to view layouts or UI appearance.
  - Public signatures preserved.
  - Every commit accompanied by diffstat, verification test run, and regression assertions.
  - Build warnings strictly checked (must not increase from 0 warnings).
  - All existing tests (1–86) + new targeted security tests must pass.
- **Skills Activated**:
  - `security-audit`: Ensuring each vulnerability is resolved at root cause without altering user-facing UX.
  - `axiom-security`: Hardening Keychain, environment isolation, input validation, and process permissions.
  - `axiom-macos`: Process management, path canonicalization, POSIX permissions, and LaunchServices integration.
  - `axiom-networking`: Ephemeral URLSession, request redaction, and credential protection.
  - `axiom-testing`: Writing new regression test for each item proving defect is eliminated.
  - `ponytail`: Minimal lines of code, standard library first, zero new dependencies.
  - `gravitas`: Evidence-backed commits: run `swift build` and `swift run NotchTests` after every single commit.

### Commit 1: SEC-E-2 — Stop Deleting Applications & Symlinks at Launch

- **Commit**: `SEC-E-2: stop deleting or relinking applications at launch`
- **Files Changed**:
  - `Sources/App/AppDelegate.swift`: Removed launch-time `PermissionsHelper.ensureApplicationsSymlink()`.
  - `Sources/Core/PermissionsHelper.swift`: Removed all `removeItem` calls; only creates symlink when target path does not exist.
  - `run_notch.sh`: Replaced `ln -sfn` with non-destructive existence check (`[ ! -e ... ] && [ ! -L ... ]`).
  - `Tests/VerificationTests.swift`: Added `[TEST 87]` verifying real directories and foreign symlinks are never modified or removed.
- **Diffstat**:
  `Sources/App/AppDelegate.swift | 3 +/-`
  `Sources/Core/PermissionsHelper.swift | 20 +/-`
  `run_notch.sh | 18 +/-`
  `Tests/VerificationTests.swift | 57 +/-`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 87 / 87 passing.
- **Safety Analysis (F8)**:
  - *What could break*: An installation expecting automatic overwrite of older symlinks would not overwrite them.
  - *How verified*: Existing symlinks and real application directories remain preserved. Test 87 asserts non-destructive behavior across real directories and foreign symlinks.

### Commit 2: SEC-C-1 — Sanitized SafeEnvironment Allowlist for Child Processes

- **Commit**: `SEC-C-1: sanitize child process environment allowlist`
- **Files Changed**:
  - `Sources/Core/SafeEnvironment.swift`: Added `SafeEnvironment.make()` allowlist restricting variables to `PATH`, `HOME`, `USER`, `LANG`, `TERM`, `CARGO_HOME`, `RUSTUP_HOME` plus caller extras.
  - `Sources/Modules/Thock/ThockModule.swift`: Applied `SafeEnvironment.make()` to `cloneProc`, `checkoutProc`, `cargoProc`, and `thock-cli` `proc`.
  - `Tests/VerificationTests.swift`: Added `[TEST 88]` verifying that ambient secrets (`SECRET_TEST_TOKEN`, `AWS_ACCESS_KEY_ID`, `GITHUB_TOKEN`) are filtered out while required toolchain variables remain.
- **Diffstat**:
  `Sources/Core/SafeEnvironment.swift | 52 +`
  `Sources/Modules/Thock/ThockModule.swift | 11 ++---`
  `Tests/VerificationTests.swift | 81 ++++++++-`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 88 / 88 passing.
- **Cargo Toolchain Verification**: `cargo` operation verified; `HOME` and `PATH` are preserved, ensuring Cargo finds toolchain binaries, global registry caches, and config.
- **Safety Analysis (F8)**:
  - *What could break*: If a child process relied on non-standard custom ambient variables (e.g. proxy variables), they would be missing.
  - *How verified*: Toolchains only require `HOME`, `USER`, `PATH`, `TERM`, and `LANG`. `SafeEnvironment` includes callers' explicit extras.

### Commit 3: SEC-C-2 — Add --locked to Cargo Build Arguments

- **Commit**: `SEC-C-2: enforce locked dependencies in cargo build`
- **Files Changed**:
  - `Sources/Modules/Thock/ThockModule.swift`: Added `"--locked"` to `cargoProc.arguments` (`["build", "--locked", "--release", "--bin", "thock-cli"]`).
  - `Tests/VerificationTests.swift`: Added `[TEST 89]` verifying that cargo build arguments strictly include `--locked` before target binaries.
- **Diffstat**:
  `Sources/Modules/Thock/ThockModule.swift | 2 +/-`
  `Tests/VerificationTests.swift | 16 +++-`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 89 / 89 passing.
- **Supply Chain Verification**: Confirmed `Cargo.lock` is present in pinned commit `264ef80…`; `--locked` ensures exact crate resolution without network fetching or unauthorized dependency upgrades during compilation.
- **Safety Analysis (F8)**:
  - *What could break*: If `Cargo.lock` was missing or out of sync with `Cargo.toml`, `cargo build --locked` would fail.
  - *How verified*: Checked via `git ls-tree` that `Cargo.lock` exists in pinned commit `264ef80…`.

### Commit 4: SEC-C-3 — Hardened Engine Binary Verification & Safe Path Migration

- **Commit**: `SEC-C-3: harden thock binary resolution and remove dev symlinks`
- **Reported Engine Path**: `/Users/dharmitparmar/Doc/KeySound/target/release/thock-cli` (verified regular file, owner UID matched, 0755).
- **Files Changed**:
  - `Sources/Modules/Thock/ThockModule.swift`:
    - Added `validateBinarySecurity(at:)` checking that engine binary is a regular file, owned by current UID, executable, and not group/world-writable.
    - Added safe automatic migration `migrateLocalDevKeySoundIfNeeded` from dev path to `~/Library/Application Support/Notch/KeySound`.
    - Added `NotchApp_AllowDevKeySound` fallback (default true if present) to ensure user's existing engine works seamlessly without triggering a clone or build.
    - Removed automatic symlink creation to `~/Doc/KeySound`.
    - Updated `isInstalled` and `startEngine()` to gate on `validateBinarySecurity`.
  - `Tests/VerificationTests.swift`: Added `[TEST 90]` testing regular 0755 executables pass while symlinks, world-writable files, and non-executables are rejected.
- **Diffstat**:
  `Sources/Modules/Thock/ThockModule.swift | 102 ++++++++++++++--`
  `Tests/VerificationTests.swift | 49 ++++++++++-`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 90 / 90 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If the user had a working engine in `~/Doc/KeySound`, restricting search without a migration or fallback would show "Engine not installed".
  - *How verified*: Existing path is explicitly supported via opt-in developer path and safe file copy migration. Test 90 asserts that the binary security checks hold.

### Commit 5: SEC-C-4 — Precise Canonical Realpath & UID Match in Orphan Sweeper

- **Commit**: `SEC-C-4: match realpath and user uid in orphan process sweep`
- **Files Changed**:
  - `Sources/Modules/Thock/ThockModule.swift`: In `sweepOrphanProcesses()`, replaced loose `hasSuffix("/thock-cli")` with canonical `URL.resolvingSymlinksInPath().path` exact equality, and added `bsdInfo.pbi_uid == geteuid()` ownership check.
  - `Tests/VerificationTests.swift`: Added `[TEST 91]` asserting that foreign binaries with identical filenames or different UIDs are never swept.
- **Diffstat**:
  `Sources/Modules/Thock/ThockModule.swift | 15 ++++++++++----`
  `Tests/VerificationTests.swift | 32 +++++++++++++++++++++++++++++++-`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 91 / 91 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If the resolved binary path differed in symlink representation from the kernel-reported `proc_pidpath`, it might fail to sweep our own orphans.
  - *How verified*: Both paths are normalized through `resolvingSymlinksInPath()`. Test 91 confirms our own orphans are swept while foreign processes are protected.

### Commit 6: SEC-C-5 — Stdin Command Injection Prevention & Pack Name Whitelist

- **Commit**: `SEC-C-5: reject control chars in stdin commands and whitelist pack names`
- **Files Changed**:
  - `Sources/Modules/Thock/ThockModule.swift`:
    - In `sendCommand(_:)`: Added validation rejecting strings containing `\n`, `\r`, or ASCII control chars (< 32).
    - Added `isValidPackName(_:)` enforcing `^[A-Za-z0-9_-]+$`.
    - In `loadPacksFromDisk()`: Gated folder discovery with `isValidPackName`.
    - In `selectPack(_:)`: Gated selection with `isValidPackName`.
  - `Tests/VerificationTests.swift`: Added `[TEST 92]` verifying rejection of newlines, carriage returns, escape sequences, and path traversal in pack names, while verifying that all 14 known sound packs (`bubble_heaven`, `creamy_butter`, `creamy_lite_calm`, `banana_split_lubed`, `nk_cream`, `overlubed_custom`, `tealios_v2`, `cherry_mx_red_pbt`, `cherry_mx_red_abs`, `cherry_mx_brown_pbt`, `cherry_mx_brown_abs`, `cherry_mx_black_pbt`, `steelseries_apex_pro_v2`, `animal_crossing_nl`) continue to pass.
- **Diffstat**:
  `Sources/Modules/Thock/ThockModule.swift | 19 +++++++++++++++++--`
  `Tests/VerificationTests.swift | 66 ++++++++++++++++++++++++++++++++-`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 92 / 92 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If a legitimate pack name contained special characters or spaces, it would be excluded.
  - *How verified*: All 14 known pack names were verified against the validator; all pass cleanly.

### Commit 7: SEC-E-1 — Sanitize Document Export Names and Pack Path Traversal

- **Commit**: `SEC-E-1: sanitize document export names and pack path traversal`
- **Files Changed**:
  - `Sources/Modules/Shelf/ShelfModule.swift`: In `exportURL(for doc:)`, sanitized `doc.fileName` using `(cleanName as NSString).lastPathComponent`, stripped non-printable control characters (< 32), stripped leading dots, and verified prefix containment within `tempCacheDirectory.standardizedFileURL.path`.
  - `Sources/Modules/Thock/ThockModule.swift`: In `playPackSample(_:)`, sanitized `packName` with `lastPathComponent`, `isValidPackName`, and prefix check against `packsDir`.
  - `Tests/VerificationTests.swift`: Added `[TEST 93]` testing `../../x.pdf`, `/etc/passwd`, `a/b.pdf`, empty string fallback, 5,000-char long name, `..`, and embedded NUL byte.
- **Diffstat**:
  `Sources/Modules/Shelf/ShelfModule.swift | 16 ++++++++++++++--`
  `Sources/Modules/Thock/ThockModule.swift | 5 ++++-`
  `Tests/VerificationTests.swift | 66 ++++++++++++++++++++++++++++++++++-`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 93 / 93 passing.
- **Safety Analysis (F8)**:
  - *What could break*: Legitimate file renames might be altered if they rely on leading dots or directory slashes.
  - *How verified*: Standard filenames ("My Document.pdf", "Invoice 2026") are completely unchanged. Traversal attempts (`../../etc/passwd`) are safely contained.

### Commit 8: SEC-A-3 — Remove Silent Clipboard Overwrite on Siri Dispatch

- **Commit**: `SEC-A-3: remove silent clipboard copy on siri dispatch`
- **Files Changed**:
  - `Sources/Modules/AI/AskAIService.swift`: In `triggerSiri(query:context:launchApp:)`, removed silent overwriting of `NSPasteboard.general`; updated status string to remove inaccurate claims of prompt copying while preserving Siri activation dispatch.
  - `Sources/Core/PermissionsHelper.swift`: Fixed argument label `createSymbolicLink(at:withDestinationURL:)`.
  - `Tests/VerificationTests.swift`: Added `[TEST 94]` verifying that `NSPasteboard.general` is never modified on Siri dispatch with non-empty queries or note contexts.
- **Diffstat**:
  `Sources/Modules/AI/AskAIService.swift | 25 ++---`
  `Sources/Core/PermissionsHelper.swift | 2 +-`
  `Tests/VerificationTests.swift | 45 ++++++++++++++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 94 / 94 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If a user specifically relied on Siri trigger to put text on their clipboard rather than using the explicit copy button, it is no longer placed on clipboard.
  - *How verified*: Explicit copy buttons in Note view and AI view remain functional; clipboard history and sensitive data are protected from background overwrites. Test 94 asserts pasteboard state remains strictly intact.

### Commit 9: SEC-B-1 — Encapsulate Telegram Requests in Ephemeral Client and Scrub Errors

- **Commit**: `SEC-B-1: encapsulate telegram requests in ephemeral client and scrub errors`
- **Files Changed**:
  - `Sources/Modules/Telegram/TelegramClient.swift`: Created dedicated `TelegramClient` enforcing ephemeral `URLSessionConfiguration` (no disk caching, no cookies, no credentials on disk, reload ignoring local/remote cache data) with `sendMessage` and `getMe` operations and `scrubErrorDescription(_:token:)`.
  - `Sources/Modules/Telegram/TelegramModule.swift`: Replaced `URLSession.shared` in `dispatchViaTelegramBot` and `testBotConnection` with `TelegramClient.shared`, scrubbing all raw tokens and endpoint URLs from error descriptions before setting `lastDispatchStatus` or `testBotStatus`.
  - `Tests/VerificationTests.swift`: Added `[TEST 95]` asserting that raw tokens and URL endpoints are scrubbed to `[REDACTED_TOKEN]` and ephemeral configuration invariants hold.
- **Diffstat**:
  `Sources/Modules/Telegram/TelegramClient.swift | 152 ++++++++++++++++++`
  `Sources/Modules/Telegram/TelegramModule.swift | 38 +++---`
  `Tests/VerificationTests.swift | 47 ++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 95 / 95 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If a custom network setup depended on system-wide cookies or shared disk cache for Telegram API requests, those are no longer stored to disk.
  - *How verified*: Telegram Bot API is stateless HTTP POST/GET; ephemeral session is standard and prevents token persistence in `~/Library/Caches`. Test 95 confirms error scrubbing and ephemeral session isolation.

### Commit 10: SEC-B-2 — Delimit Note Context and Cap Prompt Length

- **Commit**: `SEC-B-2: delimit note context and cap prompt length`
- **Files Changed**:
  - `Sources/Modules/AI/AskAIService.swift`: Added `formatPromptWithBoundedContext(prompt:context:)` which wraps untrusted user note context in non-executable data boundary tags (`<<<USER_NOTE_CONTEXT_DO_NOT_EXECUTE>>>` / `<<<END_USER_NOTE_CONTEXT>>>`) and caps length at 2,000 characters. Integrated across `queryGeminiViaGoogleAccount`, `queryGemini`, and `queryOpenAI`.
  - `Tests/VerificationTests.swift`: Added `[TEST 96]` testing nil/empty context pass-through, delimiter wrapping, 2,000-character boundary truncation, and prompt injection neutralization within data tags.
- **Diffstat**:
  `Sources/Modules/AI/AskAIService.swift | 36 +++++++++++++++-----`
  `Tests/VerificationTests.swift | 62 +++++++++++++++++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 96 / 96 passing.
- **Safety Analysis (F8)**:
  - *What could break*: Very long user notes exceeding 2,000 characters will have trailing text truncated when sent as prompt context.
  - *How verified*: Normal note queries (< 2,000 chars) are preserved in full. Delimiters prevent context from escaping and overriding model system instructions. Test 96 verifies formatting and truncation bounds.

### Commit 11: SEC-A-4 — Clean Up Legacy Vault Files Post-Keychain Migration

- **Commit**: `SEC-A-4: clean up legacy vault files post-keychain migration`
- **Files Changed**:
  - `Sources/Core/KeychainHelper.swift`: Extended `migrateLegacyVaultIfNeeded` to accept optional custom paths and check both `NotchApp/vault.enc` and `Notch/vault.enc`; added zero-overwrite sanitization prior to removal to ensure ciphertext and decrypted residue do not linger on disk.
  - `Tests/VerificationTests.swift`: Added `[TEST 97]` testing legacy AES-GCM vault migration, zero-fill wiping, complete file deletion post-migration, and secret recovery into memory.
- **Diffstat**:
  `Sources/Core/KeychainHelper.swift | 48 +++++++++++++++++++-------`
  `Tests/VerificationTests.swift | 49 ++++++++++++++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 97 / 97 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If a user had an un-migrated legacy vault file, failing to clean it up leaves ciphertext on disk, while deleting it prematurely loses keys.
  - *How verified*: Fallback decryption is executed first; secrets are committed to the Keychain; then the vault file is securely overwritten with zeroes and deleted. Test 97 asserts full lifecycle correctness.

### Commit 12: SEC-E-1 — Enforce 0700 Permissions and Cleanup on Temp Cache

- **Commit**: `SEC-E-1: enforce 0700 permissions and cleanup on temp cache`
- **Files Changed**:
  - `Sources/Modules/Shelf/ShelfModule.swift`: Enforced POSIX mode `0700` (`0o700`) during `NotchifyStudio` creation and startup via `attributes: [.posixPermissions: 0o700]`; updated `stop()` to purge all temporary files (`all: true`).
  - `Tests/VerificationTests.swift`: Added `[TEST 98]` verifying `0700` POSIX permission bits on temporary cache directory and testing the two-tier cleanup contract (15-min sweep retains active files, quit purge wipes all).
- **Diffstat**:
  `Sources/Modules/Shelf/ShelfModule.swift | 6 ++--`
  `Tests/VerificationTests.swift | 53 ++++++++++++++++++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 98 / 98 passing.
- **Safety Analysis (F8)**:
  - *What could break*: Other accounts on the same machine cannot access `NotchifyStudio` files.
  - *How verified*: Cache files are user-specific working copies; restricting access to user-only (`0700`) is standard macOS security best practice. Test 98 asserts permission bits and two-tier cleanup logic.

### Commit 13: SEC-C-4 — Guard Process Signaling with PID Start-Time Validation

- **Commit**: `SEC-C-4: guard process signaling with pid start-time validation`
- **Files Changed**:
  - `Sources/Modules/Thock/ThockModule.swift`: Added `processStartTime(pid:)` reading `pbi_start_tvsec` from kernel `proc_pidinfo`. Stored `spawnedProcessStartTime` at process launch. Replaced raw `kill(pid, ...)` in `suspendChildProcess`, `resumeChildProcess`, `terminateProcess`, and `checkProcessStateZeroOverhead` with `safeKill` / `safeKillGroup`, preventing signals from being delivered if the OS has recycled the PID for another process.
  - `Tests/VerificationTests.swift`: Added `[TEST 99]` verifying that signal delivery succeeds for matching start times and is immediately blocked when the start time differs (PID reuse), when the process has exited, or when PID <= 1.
- **Diffstat**:
  `Sources/Modules/Thock/ThockModule.swift | 54 ++++++++++++++++++---`
  `Tests/VerificationTests.swift | 56 ++++++++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 99 / 99 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If process start time could not be read during initial launch, subsequent signals would be blocked.
  - *How verified*: `proc_pidinfo` with `PROC_PIDTBSDINFO` is standard Darwin kernel API available on macOS 10.5+ and always succeeds for live child processes. If start time is nil, `safeKill` falls back safely. Test 99 confirms signal blocking on recycled PIDs and dead processes.

### Commit 14: SEC-D-4 — Verify Info.plist Usage Descriptions Against Active APIs

- **Commit**: `SEC-D-4: verify infoplist usage descriptions against active apis`
- **Files Changed**:
  - `Tests/VerificationTests.swift`: Added `[TEST 100]` auditing `Resources/Info.plist` against active APIs: asserts that `NSCameraUsageDescription`, `NSAppleEventsUsageDescription`, and `NSCalendarsUsageDescription` are present and non-empty, and verifies that unneeded usage descriptions (`NSContactsUsageDescription`, `NSMicrophoneUsageDescription`) are excluded since their respective frameworks/APIs are never called.
- **Diffstat**:
  `Tests/VerificationTests.swift | 30 ++++++++++++++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 100 / 100 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If an undeclared TCC API is called, macOS kills the process.
  - *How verified*: Verified via grep that `CNContactStore` and microphone recording APIs are never called anywhere in the codebase. Active usage descriptions (`NSCameraUsageDescription`, `NSAppleEventsUsageDescription`, `NSCalendarsUsageDescription`) are confirmed present and valid. Test 100 asserts this contract.

### Commit 15: SEC-F-2 — Expand Security Audit Script Checks Without Loosening Gates

- **Commit**: `SEC-F-2: expand security audit script checks without loosening gates`
- **Files Changed**:
  - `scripts/security-audit.sh`: Expanded audit gates from 6 to 8 checks: added check for `NSCalendarsUsageDescription` in Info.plist (falling back to `Resources/Info.plist`), and added POSIX permission verification (0600) for `notes.txt` and `contacts.json`. All gates remain strictly add-only with zero relaxation of existing security checks.
- **Diffstat**:
  `scripts/security-audit.sh | 45 +++++++++++++++++++++++++++++++++++++++------`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 100 / 100 passing (audit script passes with 8/8 gates).
- **Safety Analysis (F8)**:
  - *What could break*: If notes.txt or contacts.json existed with loose permissions (>0600), the audit script would fail.
  - *How verified*: The app writes both files with strict 0600 attributes (`[.posixPermissions: 0o600]`). The script confirms 0600 compliance.

---

## Stage C: Encrypt Notes and Contacts at Rest (SEC-A-1 & SEC-A-2)

- **Date**: 2026-11-11
- **Trigger**: Execution of Stage C requirement to protect persistent notes (`notes.txt`) and contact records (`contacts.json`) with authenticated AES-256-GCM encryption at rest, backed by macOS Keychain key management.
- **Operating Rules**:
  - No new dependencies: standard library `CryptoKit`, `Security`, and `Foundation` only.
  - Transparent plaintext backward-compatibility: unencrypted legacy files are seamlessly read and automatically upgraded to encrypted format.
  - Atomic writing with POSIX `0600` permissions.
  - Zero edits to view bodies or UI layouts.
  - Zero compiler warnings.
- **Skills Re-Picked & Activated**:
  - `axiom-security`: CryptoKit AES-256-GCM sealed box, authenticated tags, Secure Enclave / login keychain storage.
  - `axiom-data`: File persistence, atomic swapping, schema preservation, transparent plaintext migration.
  - `axiom-macos`: POSIX permissions (`0600`), Application Support directory sandboxing (`0700`).
  - `axiom-testing`: Writing deterministic unit tests for round-trip encryption, tamper rejection, and migration.
  - `ponytail`: Minimal lines, Apple native frameworks, zero external dependencies.
  - `gravitas`: Evidence-backed testing, zero unsubstantiated claims, verified test counts.

### Commit 16: SEC-A-1 & SEC-A-2 — Encrypt Notes and Contacts at Rest with CryptoKit AES-GCM

- **Commit**: `SEC-A-1 & SEC-A-2: encrypt notes and contacts at rest with cryptokit aes-gcm`
- **Files Changed**:
  - `Sources/Core/EncryptedFileStore.swift`: Created `EncryptedFileStore` implementing CryptoKit AES-256-GCM encryption with 256-bit Keychain-stored keys, `NOTCHENC1\x01` wire format, atomic writes, and transparent legacy plaintext migration.
  - `Sources/Modules/Notes/NoteStorageManager.swift`: Integrated `EncryptedFileStore` for loading and saving `notes.txt`.
  - `Sources/Modules/Telegram/TelegramModule.swift`: Integrated `EncryptedFileStore` for loading and persisting `contacts.json`.
  - `Tests/VerificationTests.swift`: Added `[TEST 101]` (Subtests 1–5) verifying encryption round-trip, magic header bytes, tamper rejection on bit flip, legacy plaintext auto-migration, and 0600 permissions.
  - `security/MANUAL_CHECKS_C.md`: Created manual verification guide for Stage C at-rest encryption.
- **Diffstat**:
  `Sources/Core/EncryptedFileStore.swift | 125 ++++++++++++++++++++++++++`
  `Sources/Modules/Notes/NoteStorageManager.swift | 15 +++-`
  `Sources/Modules/Telegram/TelegramModule.swift | 37 +++++---`
  `Tests/VerificationTests.swift | 94 ++++++++++++++++++++++++++++++`
  `security/MANUAL_CHECKS_C.md | 85 ++++++++++++++++++++++++++`
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 101 / 101 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If a user had an existing plaintext `notes.txt` or `contacts.json`, failing to read plaintext would lose user data.
  - *How verified*: `read()` checks for the `NOTCHENC1` magic header; if absent, it recovers the plaintext data seamlessly, passes it to the UI, and automatically rewrites it to disk as an authenticated encrypted file with 0600 permissions. Test 101 Subtest 4 asserts legacy recovery and migration.

### Commit 17: SEC-A-1 — Harden EncryptedFileStore Key Lifecycle, Migration Verification, and Caller Error Handling

- **Commit**: `SEC-A-1: harden EncryptedFileStore key lifecycle, migration verification, and caller error handling`
- **Files Changed**:
  - `Sources/Core/KeychainHelper.swift`: Extracted `KeychainManaging` protocol and conformed `KeychainHelper` for decoupled dependency injection and testability.
  - `Sources/Core/EncryptedFileStore.swift`:
    - Defined strongly-typed `EncryptedFileStoreError` enum (`keyMissing`, `keychainSaveFailed`, `verificationFailed`, `corruptedData`, `unsupportedVersion`, `invalidEncoding`).
    - Enforced Invariant 1: Key resolution never creates a key if a target ciphertext file exists on disk (throws `keyMissing` instead).
    - Enforced Invariant 2: Generates a key only when no ciphertext file exists, and checks that `saveSecret` succeeded; if it failed, throws `keychainSaveFailed` and writes nothing to disk.
    - Enforced Invariant 3: Caches the key in memory after the first load (zero Keychain IPC calls per note save or contact update).
    - Enforced Invariant 4: Two-phase plaintext migration verification (encrypts, verifies in memory, writes to sidecar `.tmp`, verifies disk read-back decryption matches original data, and only then atomically replaces original via `replaceItemAt`). On any error, deletes `.tmp` and keeps the original file untouched on disk. Added `migrationVerificationHook` for deterministic testing.
    - Added `isCiphertextFile(at:)` magic header inspector.
  - `Sources/Modules/Notes/NoteStorageManager.swift`:
    - Added `userHasEdited` tracking.
    - On read error: keeps file untouched, sets `text = ""`, `isDirty = false`, `userHasEdited = false`.
    - `commitToDisk` and `saveImmediately` guard `userHasEdited`; never writes to disk until user explicitly types.
    - Added dependency-injected initializer `init(customStorageURL:fileStore:)` for test isolation.
  - `Sources/Modules/Telegram/TelegramModule.swift`:
    - Added `userHasModifiedContacts` tracking.
    - On read error: keeps file untouched, sets `contacts = []`, `selectedContactId = nil`, `userHasModifiedContacts = false`.
    - `persistContacts` guards `userHasModifiedContacts`; never writes to disk until user adds/removes contacts or sends messages.
    - Added dependency-injected initializer `init(customContactsURL:fileStore:)` for test isolation.
  - `Tests/VerificationTests.swift`:
    - Added `[TEST 102]` with 7 comprehensive subtests covering missing key + existing ciphertext, failed Keychain save, memory key caching (1 Keychain load only), corrupt file handling, migration verification failure keeping original file untouched, migration verification success, and caller lazy write behavior.
- **Compiler Warnings**: 0 warnings.
- **Test Count**: 102 / 102 passing.
- **Safety Analysis (F8)**:
  - *What could break*: If key retrieval failed, an app might regenerate a random key and overwrite or orphan user ciphertext.
  - *How verified*: Invariant 1 explicitly checks `isCiphertextFile(at:)` before generating any key. If ciphertext exists, it refuses to generate a key and throws `keyMissing`. Callers run with empty state and never overwrite disk until explicit user action, ensuring data integrity.











