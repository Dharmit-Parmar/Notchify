# Local Share Architecture & Design Specification (LocalSend Protocol Compatible)

> **Document Status**: Architecture & Design (Stage 0)  
> **Target Branch**: `fix/localshare`  
> **Protocol Reference**: LocalSend Protocol v2.0–v2.2 (`https://github.com/localsend/protocol`, Apache-2.0)  
> **Conformance**: Independent clean-room implementation strictly from protocol specifications. Zero source code copied from LocalSend repository.

---

## 1. Protocol Specification Summary & Network Architecture

### 1.1 Overview & Version Negotiation
The Local Share module implements the REST-over-HTTP(S) and UDP multicast protocol defined by LocalSend v2.0–v2.2 (LocalSend Protocol README.md, Section 1–6).

- **Protocol Versions**:
  - Primary target: **LocalSend Protocol v2.2** (README.md v2.2).
  - Version string in payloads: `"2.0"` (as mandated by Section 3.1 & 4.1).
  - Protocol endpoints use the `/api/localsend/v2/...` route prefix.
  - v2.1 added optional PIN query parameter (`?pin=...`) and HTTP 401/429 status codes (CHANGELOG.md v2.1).
  - v2.2 added HTTP 422 checksum mismatch response code for SHA-256 verification (CHANGELOG.md v2.2).
  - Legacy v1 (`/api/localsend/v1/...`) compatibility is not required for modern peers, but parser models will gracefully reject v1 requests with structured error responses.

### 1.2 Default Ports & Multicast Addressing
- **Multicast (UDP)**:
  - Default Multicast Group: `224.0.0.167` (README.md, Section 1).
  - Multicast Port: `53317` (README.md, Section 1).
  - Address Scope Rationale: `224.0.0.0/24` is used because certain mobile operating systems (notably Android) reject multicast groups outside this local network block (README.md, Section 1).
- **HTTP/HTTPS (TCP)**:
  - Default Port: `53317` (README.md, Section 1).
  - Configurable fallback port in settings if port 53317 is bound by another service.

### 1.3 Cryptographic Identity, TLS & Certificate Fingerprint
- **Certificate & Key Management**:
  - The module generates a self-signed X.509 certificate and private key (RSA 2048 or ECDSA P-256) on first launch.
  - The private key and identity are stored in the macOS Keychain (`kSecClassCertificate` / `kSecClassIdentity`) via `Security.framework` and `KeychainHelper` patterns [CONFIRMED-BY-READING: `Sources/Core/KeychainHelper.swift:17-80`].
- **Fingerprint Calculation & Pinning** (README.md, Section 2):
  - In HTTPS mode, the device `fingerprint` is the SHA-256 hash of the DER-encoded X.509 certificate.
  - Representation: Hexadecimal string (normalized to lowercase).
  - Purpose: Avoid self-discovery loops (README.md, Section 3.1) and allow peers to verify TLS certificate authenticity without requiring a centralized Certificate Authority (CA).
  - When communicating over HTTPS, the client pins the peer certificate's SHA-256 hash received during discovery against the peer certificate presented during the TLS handshake.
  - In plaintext HTTP mode (fallback/legacy), the fingerprint is a randomly generated UUID string.

### 1.4 Discovery Architecture
The protocol defines two discovery channels:

```
[Local Share Module]
       │
       ├── Multicast UDP (224.0.0.167:53317) ──> Broadcast Announcement (announce: true)
       │                                                 │
       │                                                 ▼
       │                                         [Nearby Peers]
       │                                                 │
       │<── HTTP POST /api/localsend/v2/register ────────┘ (Primary response)
       │<── Multicast UDP (announce: false) ─────────────┘ (Fallback response)
       │
       └── Manual Subnet / HTTP Fallback ──────> POST /api/localsend/v2/register
```

#### Multicast UDP Discovery (Default, README.md Section 3.1)
- **Announcement Packet**:
  Sent to multicast group `224.0.0.167:53317`:
  ```json
  {
    "alias": "MacBook Pro",
    "version": "2.0",
    "deviceModel": "macOS",
    "deviceType": "desktop",
    "fingerprint": "a1b2c3d4...",
    "port": 53317,
    "protocol": "https",
    "download": false,
    "announce": true
  }
  ```
- **Peer Response**:
  - When a peer receives an announcement with `"announce": true`, it must reply with its own device info.
  - Primary response: TCP HTTP(S) `POST /api/localsend/v2/register` directly to the announcer's IP:port (README.md, Section 3.1).
  - Fallback response: Multicast UDP message with `"announce": false` (README.md, Section 3.1).
  - Responses with `"announce": false` must NEVER trigger another response, preventing broadcast storms.
  - Messages with the local device's own `fingerprint` are discarded immediately.

#### HTTP Legacy / Manual IP Discovery (README.md Section 3.2)
- Used when multicast is blocked by network hardware or when targeting a specific peer IP.
- The sender transmits `POST /api/localsend/v2/register` with its device info body.
- The receiver responds with its own device info JSON (HTTP 200).

### 1.5 File Transfer Workflow (Upload API, README.md Section 4)
The Upload API is the standard transfer mechanism between devices:

```
Sender (Client)                                Receiver (Server)
   │                                                 │
   ├── POST /api/localsend/v2/prepare-upload?pin= ──>│
   │   (Device Info + Files Metadata)                │  [Prompt User / Check Favorite]
   │<── HTTP 200 { sessionId, files: { id: token } }─┤
   │                                                 │
   ├── POST /api/localsend/v2/upload?sessionId=... ─>│
   │   (Binary file payload stream)                  │  [Stream to session directory]
   │<── HTTP 200 OK ─────────────────────────────────┤  [Verify SHA-256 hash]
   │                                                 │
   ├── [Optional] POST /api/localsend/v2/cancel ────>│
   │<── HTTP 200 OK ─────────────────────────────────┤  [Purge partial files]
```

#### Step 1: Preparation (`POST /api/localsend/v2/prepare-upload`, Section 4.1)
- Query parameter: Optional `?pin=123456` if PIN protection is active.
- Request Body:
  - `info`: Sender device alias, version (`"2.0"`), deviceModel, deviceType (`desktop`), fingerprint, port, protocol.
  - `files`: Dictionary mapping `fileId` -> file metadata:
    - `id`: Unique string ID.
    - `fileName`: Original file name string.
    - `size`: Size in bytes (`Int64`).
    - `fileType`: MIME type string (e.g. `application/pdf`, `image/png`).
    - `sha256`: Optional SHA-256 hex string.
    - `preview`: Optional preview string (null for local share).
    - `metadata`: Optional timestamps dictionary (`modified`, `accessed`).
- Response:
  - `sessionId`: Cryptographically unique session identifier string.
  - `files`: Dictionary mapping `fileId` -> secret per-file transfer `token`.
- Response Status Codes:
  - `200`: Accepted by receiver with session ID and tokens.
  - `204`: Finished (0 files accepted or empty batch).
  - `400`: Invalid JSON body or malformed payload.
  - `401`: PIN required or incorrect PIN (v2.1).
  - `403`: Transfer rejected by receiver.
  - `409`: Receiver busy with another active session.
  - `429`: Too many requests / rate limited.
  - `500`: Internal error on receiver.

#### Step 2: Upload Stream (`POST /api/localsend/v2/upload`, Section 4.2)
- Query Parameters: `?sessionId=...&fileId=...&token=...`
- Headers: Standard HTTP headers.
- Request Body: Raw binary file data stream.
- Response: Empty body with HTTP 200 OK.
- Response Status Codes:
  - `200`: File successfully received and verified.
  - `400`: Missing query parameters (`sessionId`, `fileId`, `token`).
  - `403`: Invalid file token or unexpected sender IP.
  - `409`: Invalid or mismatched session ID.
  - `422`: Checksum mismatch against provided `sha256` (v2.2).
  - `500`: Disk write error or storage failure.

#### Step 3: Cancellation (`POST /api/localsend/v2/cancel`, Section 4.3)
- Query Parameter: `?sessionId=...`
- Receiver immediately aborts pending network writes, closes file handles, and removes partial uncommitted files from disk.

#### Step 4: Info Route (`GET /api/localsend/v2/info`, Section 6.1)
- Returns JSON representation of the local device for diagnostics and interoperability validation.

---

## 2. Codebase Integration & AirDropModule Mapping

### 2.1 Existing AirDropModule Architecture
A comprehensive audit of `AirDropModule.swift` reveals its structure and integration points:

1. **Module Protocol Conformance** [CONFIRMED-BY-READING: `Sources/Core/NotchModule.swift:6-17`]:
   - Conforms to `NotchModule` (`id`, `title`, `iconName`, `isEnabled`, `themeColor`, `start()`, `stop()`, `makeCompactView()`, `makeExpandedView()`).
   - `id = "airdrop"`, `title = "AirDrop"`, `iconName = "airdrop"`.
2. **State & Reactive Properties** [CONFIRMED-BY-READING: `Sources/Modules/AirDrop/AirDropModule.swift:127-139`]:
   - `@Published public var isEnabled: Bool = true`
   - `@Published public var recentFiles: [URL] = []`
   - `@Published public var isDropTargeted: Bool = false`
   - `@Published public var statusMessage: String`
   - `@Published public var isBeaming: Bool = false`
3. **Drop Handler & URL Extraction** [CONFIRMED-BY-READING: `Sources/Modules/AirDrop/AirDropModule.swift:6-60`]:
   - `URLCollector` extracts file URLs asynchronously from `[NSItemProvider]` across multiple drag formats (`UTType.fileURL`, URL objects, string paths).
4. **Dock Registration & Lazy Loading** [CONFIRMED-BY-READING: `Sources/App/AppDelegate.swift:45-51`]:
   - Registered in `ModuleRegistry` using `registry.registerLazy(...)` with custom theme color `Color(red: 0.20, green: 0.60, blue: 1.00)`.
5. **Dock Tab Drop Interaction** [CONFIRMED-BY-READING: `Sources/Notch/NotchRootView.swift:640-643` & `Sources/Notch/NotchRootView.swift:121-123`]:
   - Dropping files onto the dock header triggers `AirDropModule.shared.shareFiles(urls)` and activates the tab via `registry.selectFileDropTarget(for: "airdrop")`.
6. **Dynamic Subtitle Display** [CONFIRMED-BY-READING: `Sources/Notch/NotchRootView.swift:448-452`]:
   - Reads `AirDropModule.shared.statusMessage` for display in the notch header ribbon.
7. **Window / Popover Pinning** [CONFIRMED-BY-READING: `Sources/Modules/AirDrop/AirDropModule.swift:148-160`]:
   - Calls `NotchShellCoordinator.shared.registerPopoverOpened()` and `registerPopoverClosed()` to keep the notch window open during modal operations and sheets.
8. **Expanded UI Layout** [CONFIRMED-BY-READING: `Sources/Modules/AirDrop/AirDropModule.swift:250-390`]:
   - Left Column: Radar animation canvas (`AirDropRadarAnimation`).
   - Right Column: Drop stage card, manual file picker button (`Browse Files...`), horizontal scroll of recent items.

### 2.2 Local Share Architecture & Reuse Plan
The `LocalShare` module is isolated in `Sources/Modules/LocalShare/` and reuses proven Notch infrastructure without duplicating common utilities:

| Component | AirDropModule Implementation | LocalShare Module Implementation | Reuse Strategy |
| :--- | :--- | :--- | :--- |
| **Drop Extraction** | `URLCollector.extractURLs` [CONFIRMED-BY-READING: `AirDropModule.swift:20`] | Reuses existing `URLCollector` directly | Zero code duplication |
| **Dock Tab Drop** | Checked in `NotchRootView.swift:640` | Extended for `targetId == "localshare"` | Minimal 3-line registration |
| **Subheader Status**| `AirDropModule.shared.statusMessage` | `LocalShareModule.shared.statusMessage` | Registered in `NotchRootView.swift:448` |
| **Dock Registration** | `AppDelegate.swift:45` | `AppDelegate.swift` registers `localshare` | Lazy initialization on demand |
| **Settings Toggle** | Automatic via `registry.allOrderedModules` | Automatic via `ModuleRegistry` | Standard dock toggle |
| **Settings Advanced**| Handled in `SettingsView.swift` | Dedicated `LocalShareSettingsSection` | Modular settings view |
| **Popover State** | `registerPopoverOpened/Closed` | `registerPopoverOpened/Closed` | Guaranteed balanced calls |
| **Visual Style** | Radar canvas + Drop Box | Peer Radar/List + Drop Box + Progress | Identical card design tokens |

---

## 3. STRIDE Threat Model & Mitigations for Local HTTP(S) Server

Running a local HTTP(S) listener on the local area network introduces security challenges. The threat model follows the STRIDE methodology:

```
                ┌────────────────────────────────────────────────────────┐
                │                     LAN Threat Actors                  │
                └───────────────────────────┬────────────────────────────┘
                                            │
                        ┌───────────────────┴───────────────────┐
                        ▼                                       ▼
             [Spoofed Sender / Rogue]              [Network Sniffing / MITM]
                        │                                       │
                        ├─► Spoofed Alias (S)                   ├─► Packet Eavesdropping (I)
                        ├─► Malicious Path (E)                  └─► Payload Tampering (T)
                        ├─► Disk Exhaustion (D)
                        └─► Replay / State Desync (R)
                                │
                                ▼
                ┌────────────────────────────────────────────────────────┐
                │          LocalShareServer Defensive Perimeter          │
                ├────────────────────────────────────────────────────────┤
                │ 1. TLS 1.3 / 1.2 with SHA-256 Fingerprint Pinning      │
                │ 2. Receive OFF by default (Listener closed)            │
                │ 3. Explicit Acceptance Prompt (UI interactive gate)    │
                │ 4. Filename Sanitization & Symlink Containment         │
                │ 5. Per-Session Isolated 0700 Directories               │
                │ 6. Storage Quota & Free Disk Verification Pre-flight   │
                │ 7. Rate Limiting (5 req/sec/IP) & 1-Session Lock       │
                │ 8. Secret / Token Scrubbing in Logs and Errors         │
                └────────────────────────────────────────────────────────┘
```

### 3.1 Spoofing (S)
- **Threat**: A rogue device on the same Wi-Fi advertises a deceptive device name (e.g. "My iPhone") or falsifies certificate fingerprints to trick users into accepting untrusted files.
- **Mitigations**:
  - **TLS Certificate Fingerprint Pinning**: Peer certificates are pinned to their SHA-256 fingerprint obtained during discovery (README.md, Section 2).
  - **Alias Sanitization**: Sender aliases are stripped of ASCII control codes, non-printable characters, and ANSI escape sequences. Max length capped at 32 characters.
  - **Zero Trust Acceptance Gate**: All incoming transfers require explicit user confirmation showing the peer's verified IP address, sanitized alias, total file count, and total byte size.
  - **Optional PIN Protection**: When enabled, the receiver rejects any `prepare-upload` request that lacks the matching `?pin=...` query parameter with HTTP 401.

### 3.2 Tampering (T)
- **Threat**: An active attacker on an unencrypted or compromised Wi-Fi network injects or modifies file contents during transit.
- **Mitigations**:
  - **Mandatory HTTPS**: TLS 1.2 / TLS 1.3 encryption across all transfer endpoints via `NWListener` and `URLSession`.
  - **SHA-256 Hash Verification**: If the sender provides a `sha256` digest in `prepare-upload`, the server computes the SHA-256 hash incrementally during reception and verifies it before finalizing. If a mismatch occurs, the file is deleted immediately and HTTP 422 is returned (CHANGELOG.md v2.2).

### 3.3 Repudiation (R)
- **Threat**: Sender denies initiating a transfer, or receiver claims a transfer never arrived; attacker replays old session tokens.
- **Mitigations**:
  - **Ephemeral Session UUIDs**: Every transfer session generates a cryptographically random session identifier (UUID v4) and unique per-file tokens (`CryptoKit.SymmetricKey`).
  - **Single-Use Tokens**: File tokens are invalidated once received or when the session closes.
  - **In-Memory Audit Ledger**: The module tracks the last 20 transfer events (peer fingerprint, timestamp, file list, completion state).

### 3.4 Information Disclosure (I)
- **Threat**: Eavesdropping on transfers; leaking internal filesystem paths or secret session tokens in URLs, console logs, or HTTP responses; port scanning detecting the app.
- **Mitigations**:
  - **Encrypted Payloads**: Transport encryption via TLS.
  - **Path Concealment**: HTTP responses never disclose host filesystem paths. Files are addressed solely via opaque identifiers (`fileId`).
  - **Secret Scrubbing**: URL query parameters (`token`, `sessionId`, `pin`) and local filesystem paths are strictly scrubbed from error messages and logs using regex redaction [CONFIRMED-BY-READING: `Sources/Modules/Telegram/TelegramClient.swift:27-48`].
  - **Closed Ports When Idle**: The HTTP(S) listener and multicast group are completely shut down when Receive mode is OFF. LAN scanners receive connection refused.

### 3.5 Denial of Service (DoS) & Resource Exhaustion (D)
- **Threat**: Malicious peer sends massive files to exhaust disk space, floods `prepare-upload` requests to exhaust CPU/memory, streams infinite bytes, or opens thousands of idle sockets.
- **Mitigations**:
  - **Pre-Flight Disk Space Check**: The receiver inspects the total batch size in `prepare-upload` and queries system free disk space via `URLResourceValues.volumeAvailableCapacityKey`. If available space is less than `totalBatchSize + 500 MB`, the request is rejected with HTTP 403 / 507.
  - **Hard Caps**:
    - Max files per transfer session: **500 files**.
    - Max individual file size: **50 GB**.
    - Max request body for JSON metadata endpoints: **1 MB**.
  - **Streaming Disk I/O**: Files are read from network transport in 64 KB chunks and written directly to disk via `FileHandle` / `OutputStream`. Files are never loaded entirely into memory.
  - **Single Active Session Constraint**: Only 1 active transfer session is permitted at a time (README.md, Section 4.1). Concurrent transfer requests receive HTTP 409 Conflict.
  - **Rate Limiting**: Requests per remote IP are limited to 5 requests per second; excess requests receive HTTP 429.
  - **Socket & Idle Timeouts**: Idle TCP connections time out after 30 seconds; entire session times out after 15 minutes of inactivity.

### 3.6 Elevation of Privilege & Path Traversal (E)
- **Threat**: Malicious `fileName` containing directory traversal sequences (`../../etc/passwd`), null bytes (`\0`), leading dots (`.bashrc`), absolute paths (`/usr/local/bin/malware`), or overwriting existing user documents; automatic execution of transferred binaries.
- **Mitigations**:
  - **Strict Filename Sanitizer**:
    1. Extract `URL(fileURLWithPath: rawFileName).lastPathComponent`.
    2. Strip directory separators (`/`, `\`), null bytes (`\0`), and ASCII control characters (0–31, 127).
    3. Strip leading dots (`.`) to prevent hidden files.
    4. Trim whitespace; fallback to `"unnamed_file"` if empty.
    5. Containment Check: Verify that `(sessionDir as NSString).appendingPathComponent(sanitizedName)` resolves strictly inside `sessionDir` via `standardizingPath`.
    6. Non-Overwriting Rename: If a file with the target name exists, append sequential suffixes (`" (1)"`, `" (2)"`).
  - **Restricted Session Folders**: Received files land in a dedicated per-session folder created with POSIX mode `0700` (`S_IRWXU`: owner read/write/execute only).
  - **Zero Auto-Execution**: Files are NEVER executed, opened, or launched automatically. The UI provides only an explicit "Open Folder" / "Show in Finder" button using `NSWorkspace.shared.selectFile`.
  - **Quarantine Tagging**: Received files are tagged with macOS quarantine attributes (`com.apple.quarantine`) using `setxattr`.

### 3.7 Receiving While Notch is Collapsed
- **Threat**: When the notch is collapsed, an incoming transfer could be missed or hang indefinitely, or cause unexpected UI transitions.
- **Mitigations**:
  - When Receive mode is ON and an incoming `prepare-upload` request arrives while the notch is collapsed:
    - User can configure: Display macOS user notification with "Accept" / "Decline" actions, OR automatically expand the Notch to display the acceptance card.
    - If user does not respond within 45 seconds, the request times out and returns HTTP 403.
    - During an active transfer, the module holds a popover registration (`registerPopoverOpened()`) [CONFIRMED-BY-READING: `Sources/Notch/NotchShellCoordinator.swift:436`] so the notch remains stably open until transfer completion or cancellation.

---

## 4. Energy, Battery & Memory Management Plan

macOS utility applications running in the menu bar or notch must consume near-zero resources when idle. Local Share is engineered with strict energy and RAM budgets:

```
[Module Disabled]
  ├── Allocations: 0 bytes
  ├── Network Sockets: 0
  ├── Timers / Tasks: 0
  └── CPU Usage: 0.0%

[Module Enabled, Receive Mode OFF (Default)]
  ├── LocalShareModule: Lightweight @ObservedObject (~4 KB)
  ├── NWListener: STOPPED (No TCP port listening)
  ├── Multicast Group: STOPPED (No UDP socket)
  ├── Timers / Tasks: 0
  └── CPU Usage: 0.0%

[Local Share Tab Opened (Sending / Discovery)]
  ├── Multicast Announce: Single UDP broadcast burst
  ├── Multicast Listener: Listens for peer replies while tab is active
  └── On Tab Switch / Notch Collapse: Multicast discovery immediately stopped

[Receive Mode ON]
  ├── NWListener: Listening on TCP 53317 (event-driven, 0 CPU when idle)
  ├── Multicast Listener: Bound to 224.0.0.167:53317 (event-driven)
  └── Sockets cleanly torn down on app quit, system sleep, or network change
```

### 4.1 Zero Background Overhead
- **Receive OFF by Default**: No TCP server listener is opened until the user explicitly toggles Receive mode ON.
- **Lazy Module Instantiation**: `ModuleRegistry.registerLazy` [CONFIRMED-BY-READING: `Sources/Core/ModuleRegistry.swift:64-79`] ensures that `LocalShareModule` is not even initialized until first activated by the user.
- **Event-Driven NWFramework**: All networking uses Apple's native `Network.framework` (`NWListener`, `NWConnectionGroup`, `NWConnection`). No polling loops, no thread blocking, and no periodic run-loop timers.

### 4.2 Dynamic Discovery Lifecycle
- Multicast announce/listen runs **only** when:
  1. The Local Share tab is currently selected and visible in the expanded Notch, OR
  2. An active send or receive transfer is in progress.
- As soon as the user collapses the notch or switches to another tab (e.g. Dashboard, Shelf, Thock), peer discovery is cancelled and UDP sockets are closed immediately.

### 4.3 Sleep & Network Change Handlers
- The module monitors system power notifications (`NSWorkspace.willSleepNotification`) and network path transitions (`NWPathMonitor`).
- On system sleep or network interface transition:
  - Active transfers are cancelled cleanly.
  - Sockets are closed.
  - On wake, if Receive mode was ON, the listener rebinds smoothly to the active primary interface.

### 4.4 Bounded RAM During File Transfers
- Transfer chunks are constrained to 64 KB buffers.
- Direct disk streaming prevents loading multi-gigabyte video or archive files into heap memory.
- Peak memory during a 20 GB file transfer stays under **2 MB** above base idle footprint.

---

## 5. UI Architecture & Responsive Notch Layout

### 5.1 Expanded Notch Layout (Height: 200 pt Compatibility)
The expanded view must conform to the responsive container requirements (`notchCompact` and `notchTight`) [CONFIRMED-BY-READING: `Sources/Notch/ResponsiveContainer.swift:18-35`]:

```
┌────────────────────────────────────────────────────────────────────────┐
│ [📡 Local Share]       ● Receive: ON (192.168.1.105:53317)  [Settings] │
├──────────────────────────┬─────────────────────────────────────────────┤
│   Nearby Peers Radar     │           Drop Zone / Transfer Stage        │
│                          │                                             │
│   ╭──────────────────╮   │   ╭─────────────────────────────────────╮   │
│   │  Animated Rings  │   │   │     Drag & Drop Files Here          │   │
│   │  ● Pixel 8       │   │   │     (or click to browse)            │   │
│   │  ● iPad Pro      │   │   ╰─────────────────────────────────────╯   │
│   ╰──────────────────╯   │   [Incoming: "Photo.jpg" (4.2 MB)]          │
│                          │   [Accept]  [Decline]                       │
└──────────────────────────┴─────────────────────────────────────────────┘
```

- **Height Constraints**:
  - When height is clamped to 200 pt (`notchCompact = true` or `notchTight = true`), the view adopts a compact horizontal flow:
    - Radar diameter reduces from 120 pt to 80 pt.
    - Drop zone height scales to 54 pt.
    - Secondary labels switch to single-line truncation.
    - Vertical scrolling is enabled via `ScrollView` to prevent any text or control clipping.
- **Text & Accessibility Minimums**:
  - Minimum text size: **10 pt** across all labels (exceeding standard 8.5 pt AirDrop labels).
  - All interactive rows are fully clickable (no small disjoint click targets).
  - VoiceOver labels and hints provided on all controls.
  - `accessibilityReduceMotion` respected: Animations and radar ripples freeze when reduce motion is enabled [CONFIRMED-BY-READING: `Sources/UI/DesignSystem.swift:1258`].
- **Theme Color Token Discipline**:
  - Pure zero hard-coded colors (no `.white`, `.black`, or static hex values in views).
  - Primary text: `DesignSystem.primaryText` [CONFIRMED-BY-READING: `Sources/UI/DesignSystem.swift:1262`].
  - Secondary text: `DesignSystem.secondaryText` [CONFIRMED-BY-READING: `Sources/UI/DesignSystem.swift:1257`].
  - Surface cards: `DesignSystem.surfaceFill`, `DesignSystem.cardFill`, `DesignSystem.cardBorder` [CONFIRMED-BY-READING: `Sources/UI/DesignSystem.swift:1277-1288`].
  - Module Theme Tint: `Color(red: 0.15, green: 0.70, blue: 0.85)` (Local Share Cyan).

---

## 6. Decisions Required from User

Before finalizing the configuration defaults during implementation, the following decisions are submitted for user direction:

1. **Default HTTP(S) Server Port**:
   - *Option A (Recommended)*: Port `53317` (standard LocalSend port; required for automatic discovery with other standard LocalSend clients).
   - *Option B*: Ephemeral or user-configurable port (requires manual port entry on peer devices).
   - *Recommendation*: **Port 53317** with automatic fallback to port 0 (ephemeral) if bound.

2. **Default Receive Destination Directory**:
   - *Option A (Recommended)*: `~/Downloads/LocalShare` (clear separation from general downloads, easily locatable, sandbox-safe).
   - *Option B*: Standard `~/Downloads` folder.
   - *Option C*: Prompt on first receive / configurable in Settings via `NSOpenPanel`.
   - *Recommendation*: **`~/Downloads/LocalShare`** (created automatically on first transfer).

3. **Auto-Accept from Favorites / Known Peers**:
   - *Option A (Recommended)*: Require explicit user confirmation ("Accept" / "Decline") for **every** transfer session regardless of sender.
   - *Option B*: Allow users to mark specific certificate fingerprints as "Favorites" in Settings, enabling auto-accept only for those trusted devices.
   - *Recommendation*: **Option A as default** (maximum safety), with an optional opt-in "Auto-accept from Favorites" toggle in Advanced Settings.

4. **PIN Protection Policy**:
   - *Option A (Recommended)*: PIN protection disabled by default (matches typical home/office LocalSend workflow). User can enable a 4–6 digit PIN in Settings.
   - *Option B*: Require PIN generation on first receive setup.
   - *Recommendation*: **Disabled by default**, fully supported via Settings.

5. **Default Device Alias**:
   - *Option A (Recommended)*: Current macOS computer name (e.g. `Host.current().localizedName ?? "MacBook"`).
   - *Option B*: Generic `"Notch Mac"` to prevent disclosing user account names.
   - *Recommendation*: **macOS computer name** with an editable text field in Settings.

6. **Notification / UI Behavior When Notch is Collapsed**:
   - *Option A (Recommended)*: When an incoming transfer arrives while collapsed, post a macOS User Notification with interactive "Accept" and "Decline" buttons. Clicking "Accept" opens the notch and begins reception.
   - *Option B*: Automatically expand the Notch to present the incoming transfer card.
   - *Recommendation*: **Option A** (non-intrusive, preserves user workflow).

---

## 7. Stage Breakdown & Verification Strategy

- **Stage 0 (Current)**: Protocol review, architecture mapping, threat model (STRIDE), energy/RAM plan, user decision checklist. STOP and wait for approval.
- **Stage 1**: Protocol Core: Codable models, `LocalShareServer` (`NWListener` HTTPS), `LocalShareDiscovery` (multicast UDP), `LocalShareClient` (`URLSession` pinned TLS), filename sanitizer, security caps, automated tests.
- **Stage 2**: Module UI: `LocalShareModule`, `LocalShareExpandedView`, Settings panel in Tab Modules > Advanced, dock tab drag-and-drop routing, popover tracking.
- **Stage 3**: Security & Energy Review: `LOCALSHARE_SECURITY.md`, code audit, manual validation instructions, clean `swift build`, and `LOCALSHARE_REPORT.md`.

---

## 8. Stage 2 UI & Application Integration Specification

### 8.1 Module Architecture & State Isolation
The Local Share module is structured into distinct headless and view layers to ensure zero UI coupling with network primitives:
- `LocalShareModule`: Conforms to `NotchModule`, manages the module lifecycle, view factory methods (`makeCompactView()`, `makeExpandedView()`), and popover balance tracking via `NotchShellCoordinator` [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareModule.swift:1-490`].
- `LocalShareModuleState`: Headless state store holding peer lists, active sessions, in-flight progress, selected files, status messages, and bounded history [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareModuleState.swift:1-325`].
- `LocalShareSettings`: Persistent settings store with `UserDefaults` backup, validating alias sanitization, custom receive directory path, PIN code in macOS Keychain, and trusted favorite peer certificate fingerprints [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareSettings.swift:1-220`].
- `LocalShareExpandedView`: Pure SwiftUI expanded notch interface adhering strictly to Notchify design tokens and responsive height constraints [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareExpandedView.swift:1-600`].
- `LocalShareSettingsView`: Modular settings view integrated under `AdvancedSettingsSection(sectionID: "modules_advanced")` [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareSettingsView.swift:1-280`].

### 8.2 Dock & Navigation Integration
- **Module Registration**: Registered lazily in `Sources/App/AppDelegate.swift` under ID `"localshare"` next to AirDrop:
  `registry.registerLazy(id: "localshare", title: "Local Share", icon: "arrow.triangle.2.circlepath")` [CONFIRMED-BY-READING: `Sources/App/AppDelegate.swift:131-137`].
- **Dock Tab Drop Handling**: Integrated into `NotchRootView.swift` within `dropEntered` and `handleExternalDrop`:
  Files dragged onto the `"localshare"` dock tab immediately switch the active module, trigger spring-loaded expansion, and stage the files into `LocalShareModuleState` without routing to AirDrop or Shelf [CONFIRMED-BY-READING: `Sources/Notch/NotchRootView.swift:203-207`, `658-662`].
- **Subtitle Ribbon**: Dynamic status message displayed in the header bar when `"localshare"` is active [CONFIRMED-BY-READING: `Sources/Notch/NotchRootView.swift:766-770`].

### 8.3 Collapsed Notch Notification Architecture
- When an incoming transfer request arrives while the notch is collapsed (`NotchShellCoordinator.shared.state == .collapsed`), an `NSUserNotification` is posted with interactive `"Accept"` and `"Decline"` actions [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareModule.swift:434-445`].
- Activating `"Accept"` automatically expands the notch (`NotchShellCoordinator.shared.state = .expanded`), switches to the `"localshare"` module, and begins streaming reception [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareModule.swift:455-465`].
- Activating `"Decline"` rejects the session via `LocalShareSessionCoordinator.shared.cancelSession`, clears temporary files, and closes the notification without expanding the notch [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareModule.swift:470-475`].

### 8.4 Popover Lifecycle & Auto-Collapse Protection
- To prevent premature notch collapse during transfers or file selection:
  - `markTransferActive()` calls `NotchShellCoordinator.shared.registerPopoverOpened()` and sets window level to `.floating` [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareModule.swift:138-142`].
  - `markTransferFinished()` restores window level to `.popUpMenu` and calls `NotchShellCoordinator.shared.registerPopoverClosed()` [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareModule.swift:145-149`].
  - The popover balance tracker guarantees the notch stays pinned while active transfers proceed, collapsing gracefully upon completion.

### 8.5 Responsive Layout & 200 pt Height Constraint
- The expanded notch UI dynamically queries `@Environment(\.notchHeight)` and `DesignSystem`:
  - At expanded heights < 240 pt (`notchCompact`), spacing is reduced from 12 pt to 6 pt, and header icons scale down.
  - At expanded heights < 170 pt (`notchTight`), non-essential sub-cards collapse into horizontal scrolling chips.
  - The entire content hierarchy is wrapped in a smooth `ScrollView(.vertical, showsIndicators: false)` with clipped-free boundaries, ensuring zero text or button clipping at 200 pt [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareExpandedView.swift:45-120`].
- Typography conforms strictly to Apple HIG: minimum text size is 10 pt (`DesignSystem.captionFont2`), with primary labels at 12–14 pt [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareExpandedView.swift:200-260`].

### 8.6 Accessibility & Motion Design
- `accessibilityDisplayShouldReduceMotion` is verified at runtime:
  - When enabled, radar ripples, glowing rings, and pulse animations are replaced with static rings and solid state indicators [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareExpandedView.swift:22-38`, `250-290`].
- VoiceOver:
  - All interactive cards, toggle pills, and list rows use `.accessibilityElement(children: .combine)`, `.accessibilityLabel(...)`, and `.accessibilityHint(...)` [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareExpandedView.swift:310-380`].
  - Whole rows and cards are explicitly clickable using `.contentShape(Rectangle())` with tactile haptic and click feedback [CONFIRMED-BY-READING: `Sources/Modules/LocalShare/LocalShareExpandedView.swift:350-390`].
