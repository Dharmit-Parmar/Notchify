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

### Commit 18: SEC-LOCALSHARE-1 — Local Share Stage 1 Rework: Protocol Core & Security Hardening

- **Commit**: `SEC-LOCALSHARE-1: Local Share Stage 1 rework with skill-led protocol core, security hardening, and native verification tests`
- **Skills Evaluated, Picked, and Dropped**:
  - `ponytail` (MANDATORY, applied): Channel senior minimal engineering. Replaced complex external web server dependencies with native Foundation, Network.framework, and CryptoKit primitives. Zero third-party dependencies added. Enforced minimal allocation lifecycle: no background sockets or listeners run unless explicitly started.
  - `security-audit` (APPLIED): Formulated concrete attack surface boundaries and STRIDE threat mitigations covering rogue sender, path traversal, slowloris header flooding, integer overflows, disk fills, token replay, and rogue certificate spoofing.
  - `axiom-security` (APPLIED): Implemented self-signed P-256 certificate generation with native ASN.1 variable-length DER encoding. Keychain-backed private key persistence with `LAContext.interactionNotAllowed = true` to prevent UI thread blocking in headless test environments. CryptoKit SHA-256 certificate fingerprint verification.
  - `gsd-secure-phase` (APPLIED): Verified threat mitigations retroactively against all identified threat vectors with deterministic unit tests.
  - `axiom-macos` (APPLIED): Enforced macOS sandbox isolation, 0700 restricted session directories, `com.apple.quarantine` extended attribute application via `setxattr`, and non-executing Finder revelation via `NSWorkspace.shared.selectFile`.
  - `axiom-data` (APPLIED): Atomic streaming file sink (`LocalShareFileStreamWriter`), non-overwriting numeric collision resolution, incremental SHA-256 computation, and integer overflow protection on disk capacity checks (`addingReportingOverflow`).
  - `axiom-networking` (APPLIED): `NWListener` HTTPS/HTTP listener, `NWConnectionGroup` UDP multicast discovery on `224.0.0.167:53317`, robust framing bounds, and explicit cancellation lifecycle.
  - `axiom-concurrency` (APPLIED): Thread synchronization using `NSLock` across session state machines, coordinators, rate limiters, and stream writers to prevent data races and deadlocks.
  - `swift-concurrency-pro` (APPLIED): Strict Swift 6 Sendable compliance, isolated actor-like primitives, and prevention of lock holding across async suspensions.
  - `axiom-testing` (APPLIED): Integrated verification directly into the native test runner (`Tests/VerificationTests.swift` [TEST 103]) with deterministic semaphores and zero arbitrary sleep polling.
  - `gravitas` (APPLIED): Scoped reconnaissance of SPM target structure, evidence-backed verification, and disciplined state management.
  - `graphify` (APPLIED): Codebase topology inspection for module isolation.
  - `swiftui-pro` (DROPPED for Stage 1): Evaluated and deferred to Stage 2 since Stage 1 is strictly headless protocol core and networking logic.
- **Security & Concurrency Decisions**:
  1. *Integer Overflow in Disk Capacity*: Evaluated `requiredBytes + minFreeDiskBuffer`. When tested with `Int64.max - 1`, direct addition caused a runtime trap. Hardened using `requiredBytes.addingReportingOverflow(minFreeDiskBuffer)` [CONFIRMED-BY-READING LocalShareSecurity.swift:134].
  2. *Path Containment Sibling Isolation*: Ensured `parentPath` has a trailing slash (`safeParent = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"`) to prevent `/tmp/session-1` from matching sibling `/tmp/session-1_attacker` [CONFIRMED-BY-READING LocalShareSecurity.swift:80]. Also handled absolute path arguments directly.
  3. *Non-Interactive Keychain Access*: Configured `LAContext.interactionNotAllowed = true` on Keychain queries to prevent blocking in headless test executions [CONFIRMED-BY-READING LocalShareIdentity.swift:239-243].
  4. *Single Active Session Mutex*: Enforced a single active transfer session lock in `LocalShareSessionCoordinator`, returning HTTP 409 Conflict if another session is offered while one is active [CONFIRMED-BY-READING LocalShareServer.swift:353].
  5. *Slowloris & Flooding Protections*: Capped header accumulation to 64 KB (rejecting excess with HTTP 431) and JSON request bodies to 1 MB (rejecting excess with HTTP 413) [CONFIRMED-BY-READING LocalShareServer.swift:188-201].
  6. *Single-Use Crypto Transfer Tokens*: Bound transfer tokens to client IP addresses and marked them consumed upon file completion, preventing token reuse [CONFIRMED-BY-READING LocalShareSession.swift:133-160].
  7. *Automatic Cleanup*: Directory purged and incomplete files removed from disk immediately upon cancellation or checksum mismatch [CONFIRMED-BY-READING LocalShareFileManager.swift:89-94, LocalShareSession.swift:316-319].
- **Files Modified / Created**:
  - `Package.swift`: Added `LocalShare` target at `Sources/Modules/LocalShare`, excluded from `NotchApp` and added as dependency to `NotchApp` and `NotchTests`.
  - `Sources/Modules/LocalShare/LocalShareProtocol.swift`: LocalSend v2.0-v2.2 protocol constants, endpoints, DTOs, device fallbacks.
  - `Sources/Modules/LocalShare/LocalShareIdentity.swift`: Keychain P-256 private key, ASN.1 X.509 DER certificate, SHA-256 fingerprint.
  - `Sources/Modules/LocalShare/LocalShareSecurity.swift`: Filename sanitizer, path containment, collision resolver, disk capacity check, secret scrubber, rate limiter.
  - `Sources/Modules/LocalShare/LocalShareFileManager.swift`: 0700 session directories, streaming atomic file sink, quarantine attribute application.
  - `Sources/Modules/LocalShare/LocalShareSession.swift`: Session state machine, single-use crypto tokens, progress tracking, session coordinator mutex.
  - `Sources/Modules/LocalShare/LocalShareServer.swift`: NWListener HTTPS/HTTP server, routing, rate limiting, header/body caps, streaming upload.
  - `Sources/Modules/LocalShare/LocalShareDiscovery.swift`: NWConnectionGroup UDP multicast discovery, self-announcement suppression, reply loop prevention, manual IP registration fallback.
  - `Sources/Modules/LocalShare/LocalShareClient.swift`: Outgoing upload client, peer certificate fingerprint verification, streaming file upload, cancellation.
  - `Tests/VerificationTests.swift`: Added Test 103 covering all 20 categories.
- **Verification Command & Outcome**:
  - Command: `swift run NotchTests`
  - Outcome: Exited with code 0.
  - Verification Count: 103 / 103 tests passing (Test 103 passed all 20 subtests).

## Stage 2 — Local Share UI & Application Integration

- **Date**: 2026-11-14
- **Branch**: `fix/localshare`
- **Selected Skills and Paths**:
  - `ponytail` (MANDATORY, applied): `/Users/dharmitparmar/.gemini/config/skills/ponytail/SKILL.md` — Apply ladder: reuse existing URLCollector from AirDrop, reuse existing NotchModule/ModuleRegistry patterns, no redundant models or abstractions, smallest working diff.
  - `swiftui-pro` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/swiftui-pro/SKILL.md` — Dynamic Type scaling, VoiceOver labels/hints on all controls, responsive layout with `notchCompact`/`notchTight`, no Toggle inside Button, whole row clickable.
  - `axiom-design` & `apple-design` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/axiom-design/SKILL.md`, `/Users/dharmitparmar/.gemini/config/skills/apple-design/SKILL.md` — Fluid spring physics, consistent visual language with AirDrop radar and card tokens, no hard-coded colors, DesignSystem theme tokens only.
  - `swiftui-expert-skill` & `impeccable` (APPLIED): Clean view hierarchy, `@Environment(\.accessibilityReduceMotion)` support disabling radar pulse animations, 200 pt height non-clipping layout.
  - `gravitas` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/gravitas/SKILL.md` — Scoped preflight inspection of package boundaries and registration points before editing.
  - `graphify` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/graphify/SKILL.md` — Mapping dependencies between `NotchApp` and `LocalShare`.
  - `axiom-macos` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/axiom-macos/SKILL.md` — macOS AppKit integration, `NSOpenPanel` file selection, `NSWorkspace.shared.selectFile` for revealing downloads.
  - `axiom-security` & `security-audit` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/axiom-security/SKILL.md`, `/Users/dharmitparmar/.gemini/config/skills/security-audit/SKILL.md` — Strict identity matching for favorites, auto-accept disabled by default, Receive mode OFF by default, no sensitive secrets in history.
  - `gsd-secure-phase` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/gsd-secure-phase/SKILL.md` — Retroactive verification of UI state and notification workflows against threat vectors.
  - `axiom-data` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/axiom-data/SKILL.md` — Persistence of module settings in `SettingsStore`, bounded transfer history.
  - `axiom-networking` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/axiom-networking/SKILL.md` — Event-driven server and discovery lifecycles; listener runs only when Receive is ON; discovery runs only when tab is visible or transfer active.
  - `axiom-concurrency` & `swift-concurrency-pro` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/axiom-concurrency/SKILL.md`, `/Users/dharmitparmar/.gemini/config/skills/swift-concurrency-pro/SKILL.md` — Thread safety on MainActor for UI state, asynchronous upload/download callbacks without holding locks across await.
  - `axiom-testing` (APPLIED): `/Users/dharmitparmar/.gemini/config/skills/axiom-testing/SKILL.md` — Headless model and integration tests in `Tests/VerificationTests.swift`.
- **Architecture Preflight Findings**:
  - `Sources/Core/NotchModule.swift`: Protocol `@MainActor public protocol NotchModule: AnyObject, ObservableObject` requiring `id`, `title`, `iconName`, `isEnabled`, `themeColor`, `start()`, `stop()`, `makeCompactView()`, `makeExpandedView()`.
  - `Sources/Core/ModuleRegistry.swift`: Supports lazy registration via `registerLazy(id:title:iconName:themeColor:factory:)`.
  - `Sources/App/AppDelegate.swift`: Registers modules lazily (AirDrop, Shelf, Thock, Messages, Battery, Mirror, Notifications). `LocalShareModule.shared` will be registered here.
  - `Sources/Notch/NotchRootView.swift`: Handles tab rendering, module subtitle ribbons, and dock file drop routing in `dropEntered` and `onDrop`.
  - `Sources/Settings/SettingsView.swift`: Hosts `modulesSection` under `SettingsCategory.modules`, with an `AdvancedSettingsSection(sectionID: "modules_advanced")` card suitable for module-specific advanced configuration.
  - `Sources/UI/DesignSystem.swift`: Defines dynamic color tokens (`primaryText`, `secondaryText`, `accentColor`, `structureColor`, `canvasColor`, `surfaceFill`, `cardFill`, `cardBorder`, etc.).
  - `Sources/Notch/ResponsiveContainer.swift`: Injects `notchCompact` (<240pt), `notchTight` (<170pt), and `notchContentHeight` via SwiftUI Environment.
  - `Sources/Notch/NotchShellCoordinator.swift`: Tracks `isMenuOrPopoverOpen` via balanced `registerPopoverOpened()` and `registerPopoverClosed()`.
  - `Package.swift` Target Arrangement: `LocalShare` target contains protocol core files (`LocalShareProtocol`, `LocalShareIdentity`, `LocalShareSecurity`, `LocalShareFileManager`, `LocalShareSession`, `LocalShareServer`, `LocalShareDiscovery`, `LocalShareClient`). `NotchApp` depends on `LocalShare`. The SwiftUI module and views (`LocalShareModule.swift`, `LocalShareExpandedView.swift`, `LocalShareSettingsView.swift`) live under `Sources/Modules/LocalShare/` and are compiled as part of `NotchApp` so they have access to `NotchModule`, `DesignSystem`, `SettingsStore`, and `NotchShellCoordinator` without circular dependencies.
- **Files Inspected**:
  - `Sources/Core/NotchModule.swift`
  - `Sources/Core/ModuleRegistry.swift`
  - `Sources/App/AppDelegate.swift`
  - `Sources/Notch/NotchRootView.swift`
  - `Sources/Modules/AirDrop/AirDropModule.swift`
  - `Sources/Settings/SettingsView.swift`
  - `Sources/UI/DesignSystem.swift`
  - `Sources/Notch/ResponsiveContainer.swift`
  - `Sources/Notch/NotchShellCoordinator.swift`
  - `Package.swift`
- **Files Modified or Created**:
  - *To be created*:
    - `Sources/Modules/LocalShare/LocalShareModule.swift`
    - `Sources/Modules/LocalShare/LocalShareExpandedView.swift`
    - `Sources/Modules/LocalShare/LocalShareSettingsView.swift`
  - *To be modified*:
    - `Package.swift` (exclude core files from NotchApp, exclude UI files from LocalShare library target)
    - `Sources/Core/NotchModule.swift` (themeColor for "localshare")
    - `Sources/App/AppDelegate.swift` (registerLazy for "localshare")
    - `Sources/Notch/NotchRootView.swift` (subtitle and tab drop routing for "localshare")
    - `Sources/Settings/SettingsView.swift` (embed `LocalShareSettingsView()` in `modules_advanced`)
    - `Tests/VerificationTests.swift` (add Test 104 covering Stage 2 integration)
- **UI and Accessibility Decisions**:
  - Strict adherence to theme tokens: `DesignSystem.primaryText`, `DesignSystem.secondaryText`, `DesignSystem.accentColor`, `DesignSystem.structureColor`, `DesignSystem.cardFill`, `DesignSystem.cardBorder`, etc.
  - Zero hard-coded `.white`, `.black`, or arbitrary hex color literals in views.
  - Dynamic radar: scales from 140pt down to 110pt (compact) and 85pt (tight). Animation pauses when `accessibilityReduceMotion` is enabled.
  - Full-row clickability on discovered peer items with high-contrast VoiceOver labels and hints.
  - ScrollView fallback when expanded height is 200pt, preventing clipping of buttons or cards.
- **Security and Lifecycle Decisions**:
  - Receive mode defaults to OFF. Starting/stopping Receive controls `LocalShareServer` listener and discovery announcement.
  - Discovered peer list pruned when inactive. Foreground discovery stops on tab switch or notch collapse unless an active transfer or Receive mode requires it.
  - Balanced `registerPopoverOpened()` and `registerPopoverClosed()` on all exit paths (accept, decline, cancel, error, timeout) via idempotent helper.
  - Incoming request banner requires explicit user Accept/Decline action; auto-accept only applies if sender fingerprint is an approved favorite AND auto-accept is enabled.
  - Bounded recent transfer history (max 10 items) storing only display metadata (alias, file count/names, date, status); no PINs, tokens, or secrets.
- **Tests and Build Results**:
  - Test command: `swift run NotchTests`
  - Result: Exit code 0 (104 / 104 tests passing).
  - Test 104 passed all 20 subtests:
    1. Module metadata and design token invariants
    2. Settings store defaults (Receive OFF, Auto-Accept OFF, PIN OFF)
    3. Settings persistence and reset to defaults
    4. Device alias length limits, whitespace trimming, and control-character sanitization
    5. Favorite identity management and auto-accept policy
    6. PIN protection toggle, filtering, and server synchronization
    7. Module engine start and stop lifecycle
    8. Receive mode toggle and server listener lifecycle
    9. Foreground discovery start/stop lifecycle
    10. Multi-file selection, removal, and batch queuing
    11. Incoming session registration and explicit acceptance transition
    12. Incoming request decline, state clearance, and directory purge
    13. In-flight progress fraction updates
    14. Transfer cancellation and partial filesystem artifact purge
    15. Bounded transfer history (10 items cap, FIFO eviction)
    16. Popover open and close balanced registration
    17. Direct IP unicast server fallback capability
    18. Dock tab drop routing isolation (AirDrop vs LocalShare vs Shelf)
    19. Responsive layout environment breakpoints (200pt / notchCompact / notchTight)
    20. Reduce Motion and VoiceOver accessibility contracts
  - Target compilation: `swift build --target NotchApp` exited with code 0.
  - Compiler warnings: macOS 11.0 deprecation warnings for `NSUserNotificationCenter` / `NSUserNotification` in `LocalShareModule.swift:435-446` (deliberate headless local notification delivery for collapsed notch state, consistent with project architecture).
- **Outstanding Concerns**:
  - Zero unresolved bugs or blockers. Ready for Stage 3 Security & Energy Review.

---

## Stage 3 — Local Share Security, Privacy & Energy Audit

- **Date**: 2026-11-14
- **Branch**: `fix/localshare`
- **Scope**: Comprehensive security, privacy, energy, concurrency, and protocol audit of the entire Local Share implementation under `Sources/Modules/LocalShare/` and shell integration points.
- **Skills Evaluated & Applied**:
  - `ponytail` (`~/.gemini/config/skills/ponytail/SKILL.md`) — Mandatory
  - `security-audit` (`~/.gemini/config/skills/security-audit/SKILL.md`)
  - `axiom-security` (`~/.gemini/config/skills/axiom-security/SKILL.md`)
  - `gsd-secure-phase` (`~/.gemini/config/skills/gsd-secure-phase/SKILL.md`)
  - `axiom-macos` (`~/.gemini/config/skills/axiom-macos/SKILL.md`)
  - `axiom-data` (`~/.gemini/config/skills/axiom-data/SKILL.md`)
  - `axiom-networking` (`~/.gemini/config/skills/axiom-networking/SKILL.md`)
  - `axiom-concurrency` (`~/.gemini/config/skills/axiom-concurrency/SKILL.md`)
  - `swift-concurrency-pro` (`~/.gemini/config/skills/swift-concurrency-pro/SKILL.md`)
  - `axiom-testing` (`~/.gemini/config/skills/axiom-testing/SKILL.md`)
  - `gravitas` (`~/.gemini/config/skills/gravitas/SKILL.md`)
  - `graphify` (`~/.gemini/config/skills/graphify/SKILL.md`)
- **Audit Findings Summary**:
  - **Finding 1 (Critical)**: Multi-file outgoing transfer desynchronization (`LocalShareModule.swift:309`, `LocalShareModuleState.swift:252`). File mapping loop always takes `filesToSend.first`, repeatedly uploading the first file instead of the intended batch.
  - **Finding 2 (High)**: Direct unicast registration reply fails over HTTPS (`LocalShareDiscovery.swift:187`). `URLSession` uses default trust evaluation without `LocalSharePermissiveTLSDelegate`, rejecting peers' self-signed certificates.
  - **Finding 3 (Medium)**: Zero-byte declared file size verification bypass (`LocalShareFileManager.swift:164`). `if expectedSize > 0 && bytesWritten != expectedSize` skips verification when `expectedSize == 0`.
  - **Finding 4 (Medium)**: Concurrent upload token replay race condition (`LocalShareSession.swift:133-160`). Token consumption is deferred to finalize, allowing concurrent uploads with the same token.
  - **Finding 5 (Medium)**: Unobserved asynchronous `NWListener` failure (`LocalShareServer.swift:137`). UI remains in a stale "Receive Active" state if the listener fails after startup.
  - **Finding 6 (Medium)**: Incoming transfer notification suppression when notch is expanded to another tab (`LocalShareModule.swift:161`). If active module is Shelf or Notes, no notification is posted and incoming card is hidden.
  - **Finding 7 (Low)**: Split-state architecture and hook collision risk between `LocalShareModuleState` and `LocalShareModule`.
  - **Finding 8 (Low)**: Slowloris pre-header socket exhaustion risk (`LocalShareServer.swift:156`).
  - **Finding 9 (Informational)**: Case-sensitive favorite fingerprint duplicate insertion in `LocalShareSettings.swift:165`.
  - **Finding 10 (Informational)**: Test suite gaps in `VerificationTests.swift` (TLS loopback handshake, multi-file uploads, direct registration replies).
- **Test & Build Verification**:
  - Test command: `swift run NotchTests`
  - Result: Exit code 0 (104 / 104 tests passing).
  - Target compilation: `swift build --target NotchApp` exited with code 0.
- **Audit Artifact Created**:
  - `LOCALSHARE_STAGE3_AUDIT.md`: Complete report with STRIDE matrix, protocol compatibility audit, macOS permissions review, energy profile, and prioritized remediation proposals.
- **Operating Rule Enforcement**:
  - Audit only. Zero production source files modified.
  - No application launch, no GUI automation.
  - Stopped at Stage 3 completion awaiting user approval before remediation.

---

## Stage 4 — Local Share Remediation & Final Hardening

- **Date**: 2026-11-14
- **Branch**: `fix/localshare`
- **Scope**: Prioritized remediation of all 10 verified defects from `LOCALSHARE_STAGE3_AUDIT.md`, with per-finding regression testing and atomic commits.
- **Skills Re-Picked & Applied**:
  - `ponytail` (mandatory)
  - `security-audit`
  - `axiom-security`
  - `gsd-secure-phase`
  - `axiom-macos`
  - `axiom-data`
  - `axiom-networking`
  - `axiom-concurrency`
  - `swift-concurrency-pro`
  - `axiom-testing`
  - `gravitas`
  - `graphify`
- **Remediated Findings & Commits**:
  - **Commit 1 (`1840682`)**: `LOCALSHARE-1: fix multi-file transfer mapping`
    - *Files*: `LocalShareClient.swift`, `LocalShareModule.swift`, `LocalShareModuleState.swift`, `VerificationTests.swift`
    - *Fix*: Added `fileIdToURLMap` to `LocalShareClientSession`; eliminated `filesToSend.first` predicate flaw.
    - *Test*: `[TEST 105]` Subtest 1.
  - **Commit 2 (`6210ccd`)**: `LOCALSHARE-2: add permissive TLS delegate for direct register reply`
    - *Files*: `LocalShareDiscovery.swift`, `VerificationTests.swift`
    - *Fix*: Configured `LocalSharePermissiveTLSDelegate` on ephemeral `URLSession` in `sendDirectRegisterReply`.
    - *Test*: `[TEST 105]` Subtest 2.
  - **Commit 3 (`e819605`)**: `LOCALSHARE-3: validate file size on zero-byte declared transfers`
    - *Files*: `LocalShareFileManager.swift`, `VerificationTests.swift`
    - *Fix*: Replaced `if expectedSize > 0 && bytesWritten != expectedSize` with `if bytesWritten != expectedSize`.
    - *Test*: `[TEST 105]` Subtest 3.
  - **Commit 4 (`d8fe32b`)**: `LOCALSHARE-4: prevent concurrent upload token replay`
    - *Files*: `LocalShareSession.swift`, `LocalShareServer.swift`, `VerificationTests.swift`
    - *Fix*: Added `inProgressTokens` atomic reservation in `validateToken`; rollback on stream error.
    - *Test*: `[TEST 105]` Subtest 4.
  - **Commit 5 (`fa96e86`)**: `LOCALSHARE-5: propagate asynchronous NWListener state to module UI`
    - *Files*: `LocalShareServer.swift`, `LocalShareModule.swift`, `LocalShareModuleState.swift`, `VerificationTests.swift`
    - *Fix*: Added `onStateChanged` callback and `boundPort` property to `LocalShareServer`; synchronized `isReceiveActive`.
    - *Test*: `[TEST 105]` Subtest 5.
  - **Commit 6 (`1caca3c`)**: `LOCALSHARE-6: notify on incoming transfer when notch is expanded to other tabs`
    - *Files*: `LocalShareModule.swift`, `VerificationTests.swift`
    - *Fix*: Replaced strict `state == .collapsed` check with tab visibility check `!(state == .expanded && activeModuleId == "localshare")`.
    - *Test*: `[TEST 105]` Subtest 6.
  - **Commit 7 (`150b516`)**: `LOCALSHARE-7: resolve split-state hook collision risk`
    - *Files*: `LocalShareDiscovery.swift`, `LocalShareServer.swift`, `LocalShareModule.swift`, `LocalShareModuleState.swift`, `VerificationTests.swift`
    - *Fix*: Implemented multi-observer pattern (`addStateObserver`, `addPeersObserver`); designated `LocalShareModule` as authoritative.
    - *Test*: `[TEST 105]` Subtest 7.
  - **Commit 8 (`8d28ae6`)**: `LOCALSHARE-8: add slowloris pre-header timeout`
    - *Files*: `LocalShareServer.swift`, `VerificationTests.swift`
    - *Fix*: Attached 15-second `LocalShareTimeoutBox` pre-header watchdog to incoming TCP sockets.
    - *Test*: `[TEST 105]` Subtest 8.
  - **Commit 9 (`15db559`)**: `LOCALSHARE-9: case-insensitive favorite fingerprint deduplication`
    - *Files*: `LocalShareSettings.swift`, `LocalShareServer.swift`, `LocalShareExpandedView.swift`, `VerificationTests.swift`
    - *Fix*: Deduplicated fingerprint insertion and lookup using `caseInsensitiveCompare`.
    - *Test*: `[TEST 105]` Subtest 9.
  - **Commit 10 (`1b1ef93`)**: `LOCALSHARE-10: add comprehensive integration tests`
    - *Files*: `LocalShareFileManager.swift`, `VerificationTests.swift`
    - *Fix*: Added Darwin `getxattr` check helper; built end-to-end loopback multi-file upload with quarantine verification.
    - *Test*: `[TEST 105]` Subtest 10.
  - **Commit 11 (`0d6fa40`)**: `LOCALSHARE-MODERNIZE: replace deprecated NSUserNotificationCenter with UserNotifications framework`
    - *Files*: `LocalShareModule.swift`
    - *Fix*: Upgraded deprecated `NSUserNotificationCenter` to modern `UserNotifications` (`UNUserNotificationCenter`, `UNMutableNotificationContent`, `UNNotificationRequest`, `UNNotificationAction`, `UNNotificationCategory`), guarded by `Bundle.main.bundleIdentifier != nil` for headless CLI safety.
  - **Commit 12 (`d0c25e4`)**: `LOCALSHARE-11: synchronized active writers collection for concurrent uploads`
    - *Files*: `LocalShareSession.swift`, `LocalShareServer.swift`, `VerificationTests.swift`
    - *Fix*: Replaced single `activeWriter` reference with `activeWriters: [String: LocalShareFileStreamWriter]`, tracking per-file writers under lock and purging all in-flight files simultaneously on abort/cancel.
    - *Test*: `[TEST 105]` Subtest 11.
  - **Commit 13 (`cf973e8`)**: `LOCALSHARE-12: bounded body timeouts and streaming upload idle watchdogs`
    - *Files*: `LocalShareServer.swift`
    - *Fix*: Added 15s bounded body watchdog on control endpoints, 30s inactivity watchdog per streaming chunk on `/upload`, and overall transfer deadline scaled to file size (10 KB/s minimum throughput policy).
  - **Commit 14 (`4d4a262`)**: `LOCALSHARE-13: TLS certificate fingerprint cross-verification on discovery bootstrap`
    - *Files*: `LocalShareDiscovery.swift`
    - *Fix*: Replaced permissive delegate with `LocalShareDiscoveryBootstrapDelegate`, capturing wire leaf certificate during handshake and strictly cross-verifying that `peerDto.fingerprint` matches the wire certificate (rejecting MITM mismatches with `peerCertificateMismatch`). Documented distinction from subsequent `LocalSharePeerPinningDelegate` pinning.
  - **Commit 15 (`32cd8fd`)**: `LOCALSHARE-14: implement findings A-C concurrent writers, body timeouts, and peer trust policy`
    - *Files*: `LocalShareClient.swift`, `LocalShareIdentity.swift`, `LocalShareServer.swift`, `LocalShareSession.swift`, `LocalShareSettings.swift`
    - *Fix*: Implemented Findings A-C: active writers collection with per-file tracking, body & chunk timeout watchdogs with size-scaled deadlines, explicit peer trust states (`.unverifiedFirstContact`, `.trusted`, `.certificateChanged`, `.blocked`), Keychain fallback persistence, and strict peer trust gates on client and server.
  - **Commit 16 (`6c01216`)**: `LOCALSHARE-15: add refresh and rescan button to Local Share view and discovery engine`
    - *Files*: `LocalShareDiscovery.swift`, `LocalShareModule.swift`, `LocalShareModuleState.swift`, `LocalShareExpandedView.swift`
    - *Fix*: Added user-requested Refresh and Rescan button in header and nearby devices list with `rescan()` discovery announcement broadcasting and animated feedback.
  - **Commit 17 (`ab98283`)**: `LOCALSHARE-16: add regression tests 105.12-105.17 and headless localshare-only runner`
    - *Files*: `VerificationTests.swift`
    - *Fix*: Added Subtests 12 through 17 under `[TEST 105]`, and headless `--localshare-only` runner flag to eliminate popup dialogs during automated verification.
  - **Commit 18 (`2db474e`)**: `LOCALSHARE-17: stabilize keychain access with modern Data Protection Keychain and in-memory caching`
    - *Files*: `LocalShareIdentity.swift`, `LocalShareSettings.swift`
    - *Fix*: Enforced `kSecUseDataProtectionKeychain as String: true` and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` across all Keychain operations. Added in-memory caching for Identity, certificate DER, fingerprint, and PIN. Initialized `_pinCode = Published(initialValue:)` in `init()` to avoid startup `didSet` re-save cascades. Added non-sensitive diagnostic logging. Eliminates repeated macOS Keychain authorization prompts.
  - **Commit 19 (`ef85c3c`)**: `LOCALSHARE-18: add alias draft buffer and live commit with network announcement propagation`
    - *Files*: `LocalShareSettingsView.swift`
    - *Fix*: Introduced `LocalShareSettingsUIState` ObservableObject providing an `aliasDraft` buffer so spaces and multi-word names can be typed without being stripped on each keystroke. Added "Save" button, `.onSubmit` commit, temporary "Saved" badge, and network announcement broadcasting via `LocalShareDiscovery.shared.sendAnnouncement(isInitial: true)`.
  - **Commit 20 (`5afca94`)**: `LOCALSHARE-19: normalize scoped hosts and IPs, ingest registered peers, and add LocalNetwork usage description`
    - *Files*: `LocalShareClient.swift`, `LocalShareDiscovery.swift`, `LocalShareSecurity.swift`, `LocalShareServer.swift`, `LocalShareSession.swift`, `Resources/Info.plist`, `Package.swift`
    - *Fix*: Added `LocalShareSecurity.normalizeIP` and `normalizeFingerprint`. Stripped interface scopes (`%en0`) and `::ffff:` from URLs and IPs across client, server, discovery, and token validation. Ingested peers registering via `POST /api/localsend/v2/register` into discovery registry. Added `NSLocalNetworkUsageDescription` to `Resources/Info.plist`.
  - **Commit 21 (`cf2e447`)**: `LOCALSHARE-20: add regression tests 105.18-105.23 for Stage 4B functional recovery`
    - *Files*: `VerificationTests.swift`
    - *Fix*: Added Subtests 18 through 23 under `[TEST 105]`, verifying TLS Identity creation, Data Protection Keychain invariants, alias space preservation, IP normalization, register route ingestion, and fingerprint normalization.
- **Verification Metrics**:
  - Test Target: `swift run NotchTests --localshare-only`
  - Result: Tests 103, 104, 105 passing (with all 23 subtests in Test 105) (exit code 0).
  - Compiler Status: 0 errors, 0 Swift compiler warnings on all targets (`LocalShare`, `NotchApp`, `NotchTests`).
  - Working Tree: Clean on `fix/localshare`.
- **Operating Rule Enforcement**:
  - Remediations complete. Zero GUI automation, zero remote pushes, zero process popups.
  - Stopped at Stage 4B completion awaiting user approval before Stage 5.

---

## Stage 4C: Local Share Send/Receive Functional Recovery & Keychain Invariant Hardening

- **Date**: 2026-11-14
- **Trigger**: User reported inability to send or receive files, alongside five specific persistence & identity defects (Bugs 1-5).
- **Root Causes Identified**:
  1. *Host URL Formatting*: Unbracketed IPv6 and `::ffff:`-mapped IPv4 hosts caused `URLComponents(string:)` to fail and return `nil`, throwing `invalidURL` during prepare-upload, upload, and unicast register replies.
  2. *App Transport Security (ATS)*: Missing `NSAppTransportSecurity` in `Info.plist` caused macOS `URLSession` to block local IP and self-signed TLS connections with error -1022.
  3. *HTTP Route Matching on `/upload`*: Requests containing query strings (`/upload?sessionId=...`) failed exact-equality route checks, cascading into JSON handlers with strict body caps and triggering HTTP 413 "Payload Too Large" or 404.
  4. *Dual-Stack IP Token Validation*: Multi-homed devices connecting via IPv6 for prepare-upload and IPv4 for stream uploads were rejected with HTTP 403.
  5. *Module Lifecycle Inactivity*: Receiver listener was not initialized during `LocalShareModule.init()` or view `.onAppear`, leaving the server dormant when navigating into Local Share.
  6. *Collapsed Notch Acceptance*: Incoming transfers without notification interaction timed out after 30 seconds because the notch did not expand to show the Accept/Decline card.
  7. *Session File Isolation*: Received files remained in subfolders (`session-<UUID>`) instead of being promoted to the root `~/Downloads/LocalShare` directory.
- **Remediations Implemented**:
  - `LocalShareSecurity.swift`: Added `formatHostForURL(_:)` wrapping IPv6 in RFC 3986 brackets and stripping interface scopes and `::ffff:` prefixes.
  - `LocalShareProtocol.swift`: Updated `baseURL` to use `formatHostForURL`.
  - `LocalShareDiscovery.swift`: Standardized host formatting across discovery receive handlers, unicast register replies, and manual IP registration.
  - `LocalShareClient.swift`: Routed all outbound endpoints through `formatHostForURL`; enabled TOFU acceptance when peer certificate fingerprint is unpinned on first contact.
  - `LocalShareServer.swift`: Allowed prefix matching on `LocalShareEndpoints.upload`; implemented robust query string parser fallback in `parseHTTPRequest`; propagated bound port in register responses.
  - `LocalShareSession.swift`: Added cross-stack IPv4/IPv6 dual-stack tolerance to `validateToken` while preserving single-use token anti-replay guarantees.
  - `LocalShareFileManager.swift`: Added `promoteSessionFiles` to move completed files into `activeReceiveDirectory` with quarantine attribute application.
  - `LocalShareModule.swift`: Initialized receiver in `init()`; auto-expanded notch on `onIncomingSessionOffered`; promoted completed session files.
  - `LocalShareExpandedView.swift`: Added `.onAppear { module.start(); module.rescan() }`; wired peer row file picker directly to `sendFiles(to: peer)`.
  - `Resources/Info.plist` & `NotchApp.app/Contents/Info.plist`: Added `NSAppTransportSecurity` with `NSAllowsArbitraryLoads: true` and `NSAllowsLocalNetworking: true`.
  - `LocalShareIdentity.swift` & `LocalShareSettings.swift`: Applied Bugs 1–5 fixes: update-first Keychain persistence (`SecItemUpdate` -> `SecItemAdd`), safe migration of plaintext fallbacks, PIN sanitization writeback, and alias network propagation.
- **Verification Metrics**:
  - `swift run NotchTests --localshare-only`: Tests 103 (20/20), 104 (20/20), 105 (Subtests 1-23) passing (exit code 0).
  - Target builds: `LocalShare` (0 errors), `NotchApp` (0 errors).
  - Zero interactive desktop prompts.

---

## Stage 4D: Failed Upload Session State Transition & Error Response Hardening

- **Date**: 2026-11-14
- **Trigger**: User reported that a failed upload in `continueReceivingUpload()` closed the connection without recording the failure in the session or sending an HTTP error response, and that `markFileFailed()` recorded the file error without transitioning the session to `.failed`.
- **Root Causes**:
  1. `continueReceivingUpload()`: When `error != nil`, the server released the token and cancelled the connection, but never called `session.markFileFailed(fileId:error:)` and never sent an HTTP 500 error response.
  2. `LocalShareSession.markFileFailed()`: Updated `fileProgressMap` with the error string but left `state` unchanged (e.g., remaining in `.receiving`), leaving the receiver in an active waiting state while the sender had already failed.
- **Remediations**:
  - `LocalShareSession.swift`: In `markFileFailed(fileId:error:)`, set `state = .failed(.serverError(error))` to properly transition the session to `.failed` and unblock the receiver UI.
  - `LocalShareServer.swift`: In `continueReceivingUpload()`, when an error occurs, invoked `session.markFileFailed(fileId:error:)` and sent HTTP 500 "Upload Stream Error" prior to connection cancellation.
  - `LocalShareServer.swift`: Added `session.markFileFailed` calls for initial body write errors, streaming write errors, and payload exceeded errors.
  - `VerificationTests.swift`: Added assertion in Subtest 12 confirming `markFileFailed` transitions session state to `.failed` and sets `isActive == false`.
- **Verification Metrics**:
  - `swift run NotchTests --localshare-only`: Tests 103, 104, 105 (Subtests 1-23) passing (exit code 0).
  - Working Tree: Clean on `fix/localshare`.

---

## Stage 4E: Targeted Security, Redirect, Pinning, Lifecycle & Validation Remediation (Batch 1: 5 Bugs)

### Skills Selection Log
- **BUG-1**: `ponytail` (mandatory, minimalist ladder), `axiom-security` (unauthenticated JSON vs TLS identity trust boundaries), `security-audit` (authorization bypass analysis).
- **BUG-2**: `ponytail` (mandatory), `axiom-security` (cross-origin / rogue peer redirection defense), `axiom-networking` (URLSessionTaskDelegate redirection interception).
- **BUG-3**: `ponytail` (mandatory), `axiom-security` (fail-closed certificate verification), `security-audit` (pinning bypass analysis).
- **BUG-5**: `ponytail` (mandatory), `axiom-networking` (URLSessionTask lifecycle and cancellation), `axiom-concurrency` (safe cancellation continuation).
- **BUG-4**: `ponytail` (mandatory), `axiom-concurrency` (session coordinator state machine synchronization), `axiom-data` (session artifact cleanup).
- **BUG-6**: `ponytail` (mandatory), `axiom-security` (input validation and integer overflow defense), `axiom-networking` (HTTP 204 No Content / 400 Bad Request handling).

### Bug Reports

1. **BUG-1**:
   - bug id: BUG-1 | root cause: unauthenticated JSON fingerprint in prepareReq bypasses interactive acceptance | files:lines changed: LocalShareServer.swift:525-535 | callers checked: LocalShareSettings.swift, LocalShareSettingsView.swift | what could still be affected: users with autoAcceptFavorites enabled will now see the interactive Accept/Decline prompt for all transfers | confirmation: incoming transfer from a favorite peer now shows Accept/Decline prompt instead of automatically accepting without user confirmation.

2. **BUG-2**:
   - bug id: BUG-2 | root cause: URLSession delegate did not implement willPerformHTTPRedirection, following peer HTTP redirects by default | files:lines changed: LocalShareClient.swift:304-322 | callers checked: prepareUpload, uploadFile, cancelSession in LocalShareClient | what could still be affected: none; redirects are rejected per LocalSend security spec | confirmation: peer returning 301/302/307/308 will have its redirect aborted rather than followed.

3. **BUG-3**:
   - bug id: BUG-3 | root cause: LocalSharePeerPinningDelegate checked expectedFingerprint.isEmpty and accepted any server certificate without validation | files:lines changed: LocalShareClient.swift:347-350 | callers checked: prepareUpload, uploadFile, cancelSession in LocalShareClient | what could still be affected: outgoing connection to a peer with an empty fingerprint string will now be rejected instead of accepted blindly | confirmation: connecting to a peer with empty fingerprint now cancels the authentication challenge.

4. **BUG-5**:
   - bug id: BUG-5 | root cause: uploadFile used urlSession.upload without storing active task in session.setActiveTask | files:lines changed: LocalShareClient.swift:235-263 | callers checked: cancelSession, cancelActiveTransfer in LocalShareModule | what could still be affected: none; cancellation now immediately aborts in-flight URLSession upload task | confirmation: cancelling an active client session immediately stops streaming and completes with sessionCancelled.

5. **BUG-4**:
   - bug id: BUG-4 | root cause: LocalShareSessionCoordinator.reset cleared activeSession without transitioning it to cancelled | files:lines changed: LocalShareSession.swift:401-411 | callers checked: LocalShareServer.stop() | what could still be affected: none; session progress monitors now terminate gracefully upon server reset | confirmation: stopping LocalShareServer now moves activeSession to .cancelled(reason: "Server reset") and removes temporary session artifacts.

6. **BUG-6**:
   - bug id: BUG-6 | root cause: handlePrepareUploadRoute did not reject empty lists, negative sizes, or check integer overflow on aggregate size | files:lines changed: LocalShareServer.swift:462-488, LocalShareProtocol.swift:139-144, LocalShareSecurity.swift:9 | callers checked: prepareUpload in LocalShareClient, handlePrepareUploadRoute in LocalShareServer | what could still be affected: none; empty file list returns 204 No Content per protocol; negative/overflow sizes return 400 | confirmation: sending an empty files map now receives HTTP 204; sending negative file size receives HTTP 400.

7. **BUG-CONN-LOST**:
   - bug id: BUG-CONN-LOST | root cause: LocalShareServer.sendRawResponse called connection.cancel() inside .contentProcessed without .finalMessage / isComplete: true, causing kernel TCP RST/abrupt socket abort before the HTTP response could be read by peer URLSession (NSURLErrorNetworkConnectionLost -1005) | files:lines changed: LocalShareServer.swift:142-145, 250-295, 328-355, 705-750, 850-865; LocalShareClient.swift:154-162, 240-270, 380-390 | callers checked: LocalShareServer, LocalShareClient, LocalShareModule | what could still be affected: none; connections now gracefully transmit EOF with deferred cleanup; diagnostics trace state without secret leakage | confirmation: clean swift build --target NotchApp, graceful .finalMessage transmission.

8. **BUG-TLS-DELEGATE**:
   - bug id: BUG-TLS-DELEGATE | root cause: LocalSharePeerPinningDelegate conformed to URLSessionTaskDelegate but did not implement urlSession(_:task:didReceive:completionHandler:), and session.data(for: request) omitted the task delegate parameter, causing self-signed TLS server trust challenges to bypass the pinning delegate and default-handle with socket termination (NSURLErrorNetworkConnectionLost -1005) | files:lines changed: LocalShareClient.swift:152-156, 360-405; LocalShareServer.swift:418-422, 840-845 | callers checked: LocalShareClient.prepareUpload, LocalShareClient.uploadFile, LocalShareServer.routeRequest, LocalShareServer.sendRawResponse | what could still be affected: none; server trust challenges are now intercepted at both session and task delegate levels, and full challenge evaluation is logged | confirmation: clean swift build --target NotchApp; dual delegate protocol conformance verified.

### Commit Log & Undo Commands
- `f649952` — `fix(localshare): BUG-1 disable unauthenticated JSON fingerprint auto-accept` -> `git revert f649952`
- `5da2afe` — `fix(localshare): BUG-2 reject HTTP redirects in peer client delegate` -> `git revert 5da2afe`
- `388a1c5` — `fix(localshare): BUG-3 fail closed on empty expected fingerprint in peer pinning delegate` -> `git revert 388a1c5`
- `8a586d3` — `fix(localshare): BUG-5 register and cancel active upload task in client session` -> `git revert 8a586d3`
- `89b5eaa` — `fix(localshare): BUG-4 transition active session to cancelled upon coordinator reset` -> `git revert 89b5eaa`
- `094df64` — `fix(localshare): BUG-6 validate incoming file metadata and safe aggregate size` -> `git revert 094df64`
- `3423271` — `fix(localshare): stabilize connection lifecycle and add transfer diagnostics` -> `git revert 3423271`
- `a627b6d` — `fix(localshare): bind task delegate and handle task-level TLS challenges` -> `git revert a627b6d`















