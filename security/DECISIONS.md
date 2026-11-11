# Architecture & Security Decisions (Stage D)

This document formalizes architectural and operational security decisions for the Notchify macOS project, balancing system capability with defense-in-depth security.

---

## Decision 1: App Sandbox Evaluation (SEC-D-1)

### Context & Threat Model
App Sandbox is Apple's kernel-enforced containerization mechanism that restricts file access, inter-process communication, hardware peripherals, and system event observation.

### Impact on Notch Core Features
1. **Global Keyboard Audio Synthesis (Thock Module)**:
   - Thock monitors physical keystrokes system-wide via `CGEventTap` and `IOHIDManager` to play mechanical switch sounds with sub-10ms latency.
   - **Sandbox Impact**: App Sandbox strictly prohibits global `CGEventTap` and global input monitoring across other applications. Sandboxing Thock completely disables keyboard audio synthesis.
2. **Child Process Execution**:
   - Thock spawns `thock-cli` as a dedicated background worker communicating via bidirectional POSIX pipes.
   - **Sandbox Impact**: App Sandbox blocks arbitrary child process execution and process group management (`setpgid`).
3. **NowPlaying Media Remote Bridge**:
   - The media widget interacts with system audio/video playback via `dlopen` on macOS private framework `MediaRemote.framework`.
   - **Sandbox Impact**: App Sandbox restricts dynamic linking of non-public system frameworks.
4. **Direct Messaging Dispatch**:
   - Direct messaging uses AppleScript (`NSAppleScript`) to interact with WhatsApp and Telegram.
   - **Sandbox Impact**: Sandbox requires explicit entitlement access to specific scriptable applications (`com.apple.security.scripting-targets`) and blocks cross-app GUI scripting.
5. **Universal Document Shelf & PDF Studio**:
   - Shelf allows users to drag files from any location (Desktop, Downloads, external drives, networked shares), merge them, compress them, and export resultant PDFs.
   - **Sandbox Impact**: Accessing secondary filesystem paths and temporary export caches without persistent security-scoped bookmarks causes permission crashes.

### Final Decision: **DO NOT SANDBOX NOTCHAPP**
- **Rationale**: Notch is a utility and productivity island whose core features require legitimate macOS system integration. Sandboxing would break 80% of its functionality.
- **Compensating Controls**:
  - File permissions: All sensitive data (`notes.txt`, `contacts.json`, `vault.enc`) are restricted to POSIX mode `0600` (user read/write only).
  - Directory permissions: Application Support and temporary cache directories enforce POSIX mode `0700`.
  - Child process environment: Strict allowlist (`SafeEnvironment`) strips ambient secrets, tokens, and credentials.
  - Path traversal defense: All user-influenced filenames are canonicalized and confined to their target cache directories.

---

## Decision 2: Code Signing & Hardened Runtime (SEC-D-2 & SEC-F-1)

### Context
Ad-hoc signing (`codesign --sign -`) produces an ephemeral designated requirement whose cryptographic hash (CDHash) changes upon every compilation. Consequently, macOS TCC revokes Accessibility and Input Monitoring permissions on every rebuild, forcing repetitive user prompts.

### Evaluation of Options
- **Option A: Persistent Local Developer Certificate (Development)**:
  - Create a persistent self-signed Code Signing Certificate in the user's macOS login keychain (e.g., `"Notch Local Signing Authority"`).
  - Sign using `codesign -s "Notch Local Signing Authority" --options runtime --timestamp=none`.
  - **Pros**: Zero cost; designated requirement remains identical across builds; TCC permissions persist across development rebuilds.
  - **Cons**: Only trusted on the local machine; cannot be distributed to other users without Gatekeeper warnings.
- **Option B: Apple Developer ID Application (Production Distribution)**:
  - Sign with an official Apple Developer ID certificate and submit to Apple Notary Service (`xcrun notarytool`).
  - **Pros**: Trusted on all Macs; zero Gatekeeper warnings; official production distribution path.
  - **Cons**: Requires active Apple Developer Program membership ($99/year).

### Final Decision: **ADOPT TWO-TIER SIGNING ARCHITECTURE**
1. **Local Development**: Configure `run_notch.sh` to check for a persistent local signing identity. If present, sign with `--options runtime` using the persistent certificate to eliminate TCC prompt churn.
2. **Production Release**: Sign with Developer ID Application certificate and submit for Apple Notarization before release.

---

## Decision 3: AppleScript Auto-Send Keystroke Injection (SEC-D-3)

### Context & Risk
`DirectMessenger` dispatches messages via AppleScript (`System Events`) by waiting 450ms and simulating a Return key press (`key code 36`). If the user switches windows during this 450ms window, the Return keystroke could be sent to an unintended active application (e.g., Terminal or Slack).

### Evaluation of Options
- **Option A: Target Window & Process Verification**:
  - Before injecting `key code 36`, query `NSWorkspace.shared.frontmostApplication` to confirm that the active bundle identifier strictly matches `ru.keepcoder.Telegram` or `net.whatsapp.WhatsApp`.
- **Option B: User Preference Toggle (Default OFF)**:
  - Introduce an explicit toggle in Settings: `"Automatically press Return to send"`. Default to `OFF`.
  - When `OFF`, Notch pre-fills the message in the recipient's chat and focuses the chat window, allowing the user to review and press Return themselves.
  - When `ON`, Notch performs frontmost process verification before dispatching the keystroke.

### Final Decision: **IMPLEMENT OPTION B WITH OPTION A VERIFICATION**
- **Rationale**: Eliminates accidental message dispatch by default, gives users full control, and prevents race conditions if the user enables auto-send.

---

## Decision 4: Pre-Built Binary vs. Local Cargo Compilation (SEC-C-3)

### Context
Compiling `thock-cli` from source requires the Rust toolchain (~1.5 GB), takes 45–90 seconds on first launch, and requires internet access to fetch crate dependencies.

### Evaluation of Options
- **Option A: Pre-compiled Bundled Binary in App Resources**:
  - Pre-compile a universal `thock-cli` binary (arm64 + x86_64) with `--locked --release`.
  - Bundle inside `NotchApp.app/Contents/Resources/thock-cli`.
  - Sign with the app's code signing identity.
- **Option B: On-Demand Source Compilation (Current)**:
  - Clone pinned commit from GitHub and compile locally with `cargo build --locked`.

### Final Decision: **BUNDLE PRE-COMPILED UNIVERSAL BINARY WITH OPT-IN DEV FALLBACK**
- **Production builds**: Bundle signed universal `thock-cli` in `Contents/Resources`. Launch time is instantaneous, requires no Rust toolchain, and eliminates internet dependency during setup.
- **Developer builds**: Support `~/Doc/KeySound` or local compilation when running in development mode.

---

## Decision 5: Author Identity & Git Metadata

### Context
Git commit logs contain the developer's personal email address (`dharmit.parmar07@gmail.com`).

### Decision: **PRESERVE LOCAL GIT HISTORY, USE GITHUB NOREPLY FOR REMOTE PUSHES**
- Local git commits retain current author metadata.
- For public remote repositories, configure Git to use GitHub's privacy noreply address (`username@users.noreply.github.com`) to prevent public email scraping by web bots.
