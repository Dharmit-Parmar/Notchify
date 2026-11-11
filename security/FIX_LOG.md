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
