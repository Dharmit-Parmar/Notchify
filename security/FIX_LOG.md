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
