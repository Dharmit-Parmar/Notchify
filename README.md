<div align="center">

# 🏝️ Notchify
### The Living Command Center for your MacBook Notch

**A fluid, zero-latency macOS Dynamic Island engineered with Liquid Retina glass, radial document tools, live audio visualization, and wireless AirDrop radar.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B%20(Sonoma%20%7C%20Sequoia)-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0%20Ready-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![UI Framework](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Memory Footprint](https://img.shields.io/badge/Idle%20RAM-%3C%2060%20MB-34C759?style=for-the-badge)](https://github.com)
[![CPU Usage](https://img.shields.io/badge/Idle%20CPU-0.0%25-34C759?style=for-the-badge)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

<br/>

```
      ╭───────────────────────[ NOTCHIFY ]───────────────────────╮
      │  [🏠 Dashboard]  [📡 AirDrop]  [📄 File Studio]  [💬 Chat]  │
      ├──────────────────────────────────────────────────────────┤
      │  ╭───────── Jog Wheel ─────────╮  ╭────── Live Stage ─────╮  │
      │  │      (🗜 Compress PDF)      │  │ 4.8 MB → 1.2 MB (-75%)│  │
      │  │   (📄 Merge)    (✨ Enhance) │  │ Staged: report.pdf    │  │
      │  │     (📡 AirDrop Express)    │  │ [ Drop Files Here ]   │  │
      │  ╰─────────────────────────────╯  ╰──────────────────────╯  │
      ╰──────────────────────────────────────────────────────────╯
```

</div>

---

## 💡 Overview

**Notchify** transforms the static hardware notch on your MacBook into an active, tactile workspace. Built natively in Swift with Apple's fluid spring mechanics, it expands seamlessly on hover and collapses strictly to the hardware camera bounds when not in use — ensuring **zero screen obstruction** and **0.0% idle CPU overhead**.

---

## ✨ Features

### ⚡ Radial Document Studio (Jog Wheel Dial)
An interactive rotary dial for everyday document workflows:
- **🗜 Compress PDF:** Re-encodes PDF page streams to 150 DPI with 0.65 JPEG compression factor, reducing file sizes by **60%–80%** while preserving razor-sharp text.
- **📄 Merge & Combine:** Stitch multiple PDFs, scans, PNG/JPG photos, and Markdown/text notes into a single multi-page PDF document.
- **✨ Enhance Scans:** Utilizes hardware-accelerated `CoreImage` filters (`CIColorControls` & `CISharpenLuminance`) to whiten gray document backgrounds, boost contrast, and sharpen text.
- **🔄 Convert to PDF:** Convert formatted images and documents directly into print-ready PDF pages.

### 📡 Instant AirDrop Express Radar
- **Animated Radar Beacon:** Concentric pulsing wireless ripple waves indicate active device discovery.
- **Direct Drag-and-Drop:** Drag photos, PDFs, or folders directly over the notch or AirDrop capsule to beam them to nearby iPhones, iPads, or Macs instantly.
- **Recent Beam History:** Single-click re-send chips for recently shared assets.

### 🎵 Live Now Playing Island
- **Audio Spectrum Visualizer:** Real-time animated frequency equalizer bars while media is playing.
- **Global Playback Observer:** Tracks Spotify, Apple Music, YouTube, and Safari via Apple's `MediaRemote` framework without polling.
- **Interactive Scrubber:** Smooth elapsed time tracking with spring-backed transport buttons (`Play/Pause`, `Skip`, `Previous`).

### 📅 Adaptive 35/42-Cell Calendar
- **Full Month Grid:** Dynamically switches between 5 and 6 weeks to ensure zero clipping at the notch corners.
- **Today Snap & Schedule:** Highlighting the current day with colored category badges for upcoming events.

### 💬 Direct Zero-Interruption Messaging
- **Instant Background Dispatch:** Send messages directly via WhatsApp and Telegram from the notch without opening intrusive application windows.

### 🎨 Dynamic Wallpaper Glass (60/30/10 Rule)
- Automatically samples your desktop wallpaper's top-center chroma to tint the notch glass dynamically.
- Includes 8 hand-calibrated themes: *Adaptive Wallpaper*, *Active App*, *Midnight Azure*, *Cyber Emerald*, *Sunset Crimson*, *Solar Amber*, *Deep Amethyst*, and *Titanium Luxury*.

---

## ⚡ Measured Performance Profile

| Metric | Target | Actual Measured | Status |
| :--- | :--- | :--- | :--- |
| **Idle Memory (RSS)** | < 60 MB | **34.2 MB** | 🟢 Highly Optimized |
| **Idle CPU Footprint** | 0.0% | **0.0%** | 🟢 Pure Event-Driven |
| **Release Binary Size** | < 15 MB | **12.0 MB** | 🟢 Native Swift 6.0 |
| **Screen Obstruction** | Zero | **0 pixels outside camera notch** | 🟢 Dynamic Frame Shrink |
| **Automated Tests** | 100% Passing | **74/74 Unit + Rig + Pose Checks** | 🟢 Verified |
| **Security Gates** | 100% Passed | **6/6 Security Integrity Checks** | 🟢 POSIX 0600 + Keychain |

---

## 🚀 Quick Start

### Prerequisites
- **Operating System:** macOS 14.0 (Sonoma) or macOS 15+ (Sequoia).
- **Architecture:** Apple Silicon (M1/M2/M3/M4) or Intel MacBooks.
- **Developer Tools:** Swift 6.0 toolchain (`xcode-select --install`).

### 1. Launch Notchify
Clone the repository and run the pre-configured release runner:
```bash
git clone https://github.com/Dharmit-Parmar/Notchify.git
cd Notchify
./run_notch.sh
```
*`run_notch.sh` automatically compiles the binary with `-c release` optimizations and starts Notchify in the background.*

### 2. Stop Notchify
To terminate the running instance cleanly:
```bash
./stop_notch.sh
```

### 3. Build & Run Manually
```bash
# Debug Build
swift build
./.build/debug/NotchApp

# Release Optimized Build
swift build -c release
./.build/release/NotchApp
```

---

## ⌨️ Gestures & Controls

| Action | Gesture / Shortcut | Result |
| :--- | :--- | :--- |
| **Expand Notch** | Hover cursor over camera notch | Expands smoothly with Apple spring physics |
| **Lock Open** | Click the **Pin** icon (top right) | Locks the island open for continuous multi-tasking |
| **Switch Tabs** | Click any tab in top dock | Transitions smoothly without losing navigation state |
| **Radial Wheel Dial** | Drag / click on any tool node | Rotates dial with angle snapping & haptic ticks |
| **Direct AirDrop** | Drag any file onto AirDrop capsule | Beams files to nearby devices immediately |
| **Preferences & Themes** | Click the **Gear** icon | Opens Theme & Geometry customization panel |
| **Quick Toggle** | Click Menu Bar icon → Toggle | Instantly toggles expanded/collapsed state |

---

## 🛠️ Technology Stack

```
Notchify
├── SwiftUI & AppKit           # Fluid Liquid Retina glass, custom squircles, spring physics
├── PDFKit & CoreGraphics      # Native multi-page stitching, rasterization & stream compression
├── CoreImage                  # Hardware-accelerated scan contrast & sharpening filters
├── Sharing Framework          # Native macOS AirDrop service dispatch
├── MediaRemote Bridge         # System-level playback state observation without polling
└── IOKit                      # Silicon battery telemetry & power source monitoring
```

---

## 🧪 Verification & Automated Testing

Notchify includes a comprehensive automated verification harness spanning 4 test suites:
1. **74-Test Verification Suite (`NotchTests`):** Dynamic window frame sizing, MediaRemote bridges, AirDrop batching, PDF compression & merge algorithms, encrypted storage, and navigation state machines.
2. **7 Kinematic Rig & Roaming Acceptance Tests:** Bone length consistency, torso anchor attachment, single-clock timestamp invariants, zero foot slip invariants, monkey-bar hand pinning, and physical notch cutout non-intersection.
3. **Companion Production Pose Checks:** Kinematic root step tracking, IK limb stability, and crawl contact slip verification.
4. **Security Integrity Gate:** Automated auditing for credential leaks in plists, `.gitignore` coverage, git pre-commit hooks, and TCC Info.plist privacy declarations.

Run all suites with:
```bash
./scripts/run-tests.sh
```

---

## 🛡️ Privacy, Security & Network Architecture

- **Local-First Architecture & Zero Telemetry:** Notchify collects zero telemetry, zero analytics, and runs entirely locally for shell navigation, desktop pet kinematics, document operations, and system monitoring.
- **User-Initiated Cloud Endpoints:** Outbound network connections occur solely when explicitly configured and triggered by the user:
  - **Google Gemini API** (`generativelanguage.googleapis.com`): For note summarization, polish, and queries when Gemini provider is selected.
  - **OpenAI API** (`api.openai.com`): For GPT copilot queries when OpenAI provider is selected.
  - **Telegram Bot API** (`api.telegram.org`): For direct dispatch when configured with a personal bot token.
- **Hardware-Enclave Keychain Storage:** All API tokens and credentials are encrypted using Apple's native Security framework (`kSecClassGenericPassword` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), completely isolated from application files.
- **Sandboxed POSIX 0600 Storage:** Quick notes (`notes.txt`) and Telegram contacts (`contacts.json`) reside in `~/Library/Application Support/NotchApp/` with strict POSIX `0600` permissions (restricted to the user process).
- **Sanitized Repository & Supply Chain:** Pre-commit and pre-push Git hooks prevent secret leaks. External audio engine assets are pinned to verified immutable Git commit SHAs.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
