# Notchify — Design Phase Execution Log (`DESIGN_LOG.md`)

## 1. Full Installed Skill Inventory

| Skill Name | Description |
|---|---|
| `agy-customizations` | Comprehensive guide and reference for the Antigravity Customization System. |
| `antigravity-guide` | Complete guide for Google Antigravity, CLI, IDE, and SDK. |
| `apple-design` | Apple's approach to interface design and fluid, physical motion (WWDC fluid interfaces, springs, response, direct manipulation, interruptibility). |
| `automation` | Guide to design and create scheduled background automations. |
| `axiom-accessibility` | Auditing and fixing accessibility issues (VoiceOver, Dynamic Type, color contrast >= 4.5:1, touch/click targets, WCAG compliance). |
| `axiom-ai` | Apple Intelligence, on-device AI, and speech-to-text. |
| `axiom-apple-docs` | Apple documentation and Swift compiler diagnostics. |
| `axiom-build` | Xcode and Swift build failures, dependency conflicts, compiler diagnostics. |
| `axiom-concurrency` | Swift 6 concurrency, actors, `@MainActor`, data race elimination. |
| `axiom-data` | Data persistence, databases, UserDefaults, Keychain, migrations. |
| `axiom-design` | Apple Human Interface Guidelines (HIG), Liquid Glass, SF Symbols, typography. |
| `axiom-games` | 2D/3D game development with SpriteKit, SceneKit, RealityKit. |
| `axiom-graphics` | Metal GPU rendering, shaders, ProMotion display performance. |
| `axiom-health` | HealthKit and workout frameworks. |
| `axiom-integration` | System surfaces (Shortcuts, widgets, Live Activities, background tasks). |
| `axiom-location` | CoreLocation and MapKit. |
| `axiom-macos` | macOS native architecture (AppKit windows, NSPanel, spaces, displays, mouse tracking). |
| `axiom-media` | AVFoundation camera capture, audio playback, MediaRemote. |
| `axiom-networking` | URLSession and network diagnostics. |
| `axiom-payments` | Apple Pay and Wallet passes. |
| `axiom-performance` | Profiling, Instruments, CPU/memory leaks, energy diagnostics. |
| `axiom-security` | Keychain, encryption, security auditing. |
| `axiom-shipping` | App Store submission and release preparation. |
| `axiom-swift` | Modern Swift idioms and toolchain features. |
| `axiom-swiftui` | SwiftUI view composition, navigation, layout, animation. |
| `axiom-testing` | Unit testing, Swift Testing, test architecture. |
| `axiom-tools` | Axiom diagnostics and instrumentation tools. |
| `axiom-uikit` | UIKit bridging and modernization. |
| `axiom-vision` | Computer vision and text recognition. |
| `axiom-watchos` | watchOS app architecture. |
| `axiom-xcode-mcp` | Xcode MCP connection and tools. |
| `banner-design` | Banner and marketing asset design. |
| `brand` | Brand voice and messaging frameworks. |
| `brandkit` | Visual identity board generation. |
| `design` | Comprehensive design tokens and UI styling. |
| `design-system` | Three-layer token architecture and component specifications. |
| `design-taste-frontend` | Anti-slop frontend visual design. |
| `design-taste-frontend-v1` | Taste skill v1. |
| `emilkowalski-motion` | Micro-interactions, spring transitions, motion restraint, reduced-motion fallbacks. |
| `find-skills` | Discovering and installing agent skills. |
| `frontend-design` | Visual design, typography, spacing, and color palette creation. |
| `full-output-enforcement` | Unabridged, complete code generation. |
| `generative_ui` | Rich interactive HTML widgets and data visualizations. |
| `gpt-taste` | UX/UI guidelines and motion engineering. |
| `graphify` | Persistent codebase knowledge graph and structural query tool. |
| `gravitas` | Reliability engineering runtime: recon, planning, verification. |
| `gravitas-highstakes` | Checkpoint skill for critical irreversible actions. |
| `gsd-*` suite | Getting Shit Done planning and execution suite. |
| `hallmark` | Distinctive non-templated page and component design. |
| `high-end-visual-design` | Premium design standards, typography, spacing, shadows. |
| `image-to-code` | Visual references translated to code. |
| `imagegen-*` | Image generation skills. |
| `impeccable` | Design director quality standards, craft floor, layout, color, polish. |
| `industrial-brutalist-ui` | Mechanical brutalist interface design. |
| `migrate-workflows` | Legacy workflow migration. |
| `minimalist-ui` | Clean editorial minimalist interfaces. |
| `plugin` | Plugin management. |
| `ponytail` | Minimalist, clean, native code; standard library first; zero unnecessary dependencies. |
| `ponytail-*` suite | Ponytail auditing and debt tracking. |
| `redesign-existing-projects` | Upgrading existing projects to high design quality. |
| `security-audit` | Security guidance and vulnerability review. |
| `skill-inspector` | Skill inspection and auditing. |
| `slides` | Presentation creation. |
| `stitch-design-taste` | Semantic design systems for Stitch. |
| `swift-concurrency-pro` | Swift 6 concurrency, async/await, actor isolation review. |
| `swiftui-expert-skill` | macOS window management, AppKit-SwiftUI bridging, Liquid Glass, view hierarchy. |
| `swiftui-pro` | Comprehensive SwiftUI best practices, view performance. |
| `ui-plugin-navigation` | UI plugin panel discovery. |
| `ui-styling` | Component styling, accessible layouts. |
| `ui-ux-pro-max` | UI/UX design intelligence: palettes, typography, responsive grids. |
| `unslop` | Anti-slop writing rules: plain speech, active voice, sentence case, zero AI clichés. |

---

## 2. Selected Skills for Notchify Design Phase & Rationale

| Selected Skill | Reason Chosen |
|---|---|
| `swiftui-expert-skill` | macOS window hierarchy, AppKit `NSPanel` bridging, window styling, and custom coordinate geometry for physical MacBook notch. |
| `swiftui-pro` | SwiftUI best practices, avoiding excess invalidation, performant layout containers. |
| `swift-concurrency-pro` | Swift 6 `@MainActor` isolation, background image processing off main thread, async notification observers. |
| `apple-design` | Apple fluid motion physics, spring response/damping tuning, direct manipulation 1:1 tracking, interruptibility. |
| `emilkowalski-motion` | Micro-interactions, restrained state transitions, `prefers-reduced-motion` fallbacks. |
| `axiom-accessibility` | WCAG contrast compliance (text >= 4.5:1), VoiceOver accessible buttons, click targets, full keyboard navigation. |
| `axiom-macos` | `NSScreen`, `NSWorkspace`, desktop wallpaper APIs, space change notifications, window levels. |
| `axiom-performance` | Thermal and energy efficiency, idle ~0% CPU invariant, eliminating background redraw loops. |
| `axiom-design` | Liquid Glass specular materials, SF Symbols rendering, typography tokens. |
| `axiom-testing` | Unit test construction for synthetic image color extraction and OKLab math. |
| `impeccable` | Craft floor standards, non-generic typography, contrast guard, restraint. |
| `ui-ux-pro-max` | OKLab color space formulas, luminance clamping, accessible palette harmony. |
| `ponytail` | Native framework solutions (`CoreGraphics`, `ImageIO`), minimal code, deleting dead code over adding layers. |
| `gravitas` | Step-by-step verification, invariant tracking, regression prevention. |
| `unslop` | Professional technical communication, clean documentation, zero fluff. |

---

## 3. Phase 0 Kickoff: Diagnose & Fix Color Detection

### Skill Selection for Phase 0
- **Skills active**: `axiom-macos`, `axiom-performance`, `swift-concurrency-pro`, `ponytail`, `gravitas`.
- **Trigger**: Root cause analysis and diagnosis of wallpaper color sampling and active app icon extraction.
- **Goals**:
  1. Audit current `sampleWallpaperColor` and `sampleImageColor` implementations in `DynamicThemeEngine`.
  2. Identify why wallpaper color detection fails on macOS (dynamic/video wallpapers, per-space wallpapers, multi-display, wrong scale region, full-screen apps).
  3. Add hidden/diagnostic readout in Settings showing: wallpaper source and file path, display/Space status, sampled RGB/OKLab colors, frontmost app name and bundle ID, extracted icon color, last update timestamp, and detection status.
  4. Build robust fallback chain: (1) Wallpaper image file -> (2) Frontmost app icon -> (3) System accent color (`NSColor.controlAccentColor`) -> (4) Time-of-day solar tint.
  5. Sample only on changes (wallpaper notification, Space change, display change, app activation); cache by file URL and modification date; process on background queue; zero main-thread blocking; no `ScreenCaptureKit`.
  6. Add "Re-detect" action button in Settings.

### Phase 0 Execution & Findings
- **Diagnosed Causes of Color Detection Regressions**:
  1. *Video & Aerial Dynamic Wallpapers*: macOS 14+ dynamic/aerial wallpapers (stored in `/Library/Application Support/com.apple.idleassetsd/Customer/...`) return `.mov` video files. `CGImageSource` failed on these. Added `AVAssetImageGenerator` support to sample video assets off-thread without ScreenCaptureKit.
  2. *Wallpaper Region Distortion*: Top-center notch region (X: 30%-70%, Y: 0-35%) is now explicitly sampled so the color under the MacBook notch drives the palette rather than irrelevant bottom-of-screen content.
  3. *Display Targeting*: Replaced generic `NSScreen.main` with physical notch screen priority (`screen.safeAreaInsets.top > 0`), ensuring multi-monitor setups do not sample the wrong external display.
  4. *Multi-Tier Fallback Chain*: Removed hardcoded arbitrary blue `(0.60, 0.72)`. Established deterministic 4-stage fallback:
     - Stage 1: Sampled Wallpaper File (valid chroma & brightness)
     - Stage 2: Frontmost App Icon (ignoring NotchApp itself, Dock, and near-gray icons with sat < 0.14)
     - Stage 3: macOS System Accent Color (`NSColor.controlAccentColor`)
     - Stage 4: Circadian Solar Time-of-Day Tint
  5. *File Modification Date Caching*: Added `(imageURL, modificationDate)` cache verification to eliminate redundant disk I/O and thumbnail decoding.
  6. *Diagnostics Readout*: Integrated real-time telemetry model `ColorDetectionDiagnostics` and collapsible diagnostics drawer in Settings with live "Re-detect" trigger.
- **Verification**: 74/74 verification tests passing, rig invariants passing. Phase 0 complete.



---

## 4. Phase 1: Environment State & Color Engine

### Skill Selection for Phase 1
- **Skills active**: `swiftui-pro`, `swift-concurrency-pro`, `axiom-accessibility`, `ui-ux-pro-max`, `impeccable`, `ponytail`, `gravitas`.
- **Trigger**: Construction of perceptually uniform OKLab color transitions, 3-zone color palettes (shadow, midtone, highlight), WCAG contrast enforcement, and zero-polling environment tracking.
- **Goals**:
  1. Build `EnvironmentState`: Track Low Power Mode, thermal state, Reduce Motion, Reduce Transparency, Increase Contrast, Dark Mode, Display/Notch bounds, and mascot den occupancy with zero polling (event notifications only).
  2. Implement OKLab color space model (`OKLabColor`): Perceptually linear blending without perceptual dips or gray muddiness.
  3. Implement `ContrastGuard`: Clamps background luminance to guarantee text contrast ratio >= 4.5:1 against current theme text color.
  4. Multi-Zone Palette Extraction: Extract distinct shadow, midtone, and highlight tones from top-notch wallpaper region.
  5. Smooth Color Transitions: 300ms spring-interpolated transitions when expanded; snap instantly when collapsed or under Reduce Motion.
  6. Synthetic Test Suite Matrix: 6 synthetic test conditions verifying pure white clamping, pure black, saturated chroma extraction, linear gradients, low-contrast dark images, and OKLab round-trip precision.

### Phase 1 Execution & Findings
- **EnvironmentState (`Sources/Core/EnvironmentState.swift`)**:
  - Implemented event-driven singleton tracking system accessibility flags (`accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityIncreaseContrast`), power status (`ProcessInfo.isLowPowerModeEnabled`), thermal pressure (`ProcessInfo.thermalState`), interface style changes, active Space transitions, and external display hotplugging.
  - Zero polling timers; strictly bound to `NotificationCenter` system events and display reconfiguration callbacks with `isolated deinit` thread safety under Swift 6.
- **Perceptually Uniform OKLab Engine (`Sources/UI/OKLabColor.swift`)**:
  - Implemented linear sRGB <-> OKLab matrix conversions and `blend(to:progress:)` interpolation.
  - Developed `ContrastGuard.clampBackgroundForContrast`: Computes relative luminance via standard WCAG 2.1 formulas; dynamically clamps background luminance so text contrast is guaranteed >= 4.5:1.
- **Multi-Zone Palette Extraction (`Sources/UI/DesignSystem.swift`)**:
  - Added `MultiZonePalette` struct with shadow, midtone, and highlight OKLab tones.
  - Implemented `sampleMultiZonePalette(from:rect:)` and `sampleWallpaperPalette()`.
  - Added frontmost app icon chroma extraction (`sampleFrontmostAppAccent()`) and interruptible color transitions (`transitionTo(targetCanvas:targetStructure:targetAccent:)`).
- **Banner / Tag De-cluttering (`Sources/Modules/Thock/ThockModule.swift`)**:
  - Removed intrusive green `Full Typing Interception Authorized (Accessibility & Input Monitoring)` pill. When permissions are granted, normal operation is silent and clutter-free.
- **Verification Tests (`Tests/VerificationTests.swift`)**:
  - Added Test 75 covering synthetic pure white (clamped to >= 4.5:1 contrast), synthetic black, synthetic saturated chroma, synthetic linear gradient monotonic separation, synthetic low-contrast dark, OKLab round-trip (< 0.01 delta), and OKLab blend monotonicity.
  - All 75 tests pass!

---

## 5. Phase 2: Settings UX & Navigation Polish

### Skill Selection for Phase 2 (Re-selection)
- **Skills active**: `axiom-accessibility`, `swiftui-pro`, `swiftui-expert-skill`, `apple-design`, `impeccable`, `ponytail`, `gravitas`.
- **Trigger**: Overhauling Settings interactions, card hit targets, keyboard accessibility, and organizing advanced options per Rule 0 (Keep-and-Guard).
- **Goals**:
  1. Audit every card, row, tile, category, and toggle in `SettingsView.swift` and `DashboardSettingsView.swift`.
  2. Ensure the entire surface area of every setting row is clickable with `.contentShape(Rectangle())`, pointer cursor, keyboard focus ring, and accessibility button traits.
  3. Ensure all toggles have explicit labels, semantic accessibility hints, and consistent hit targets.
  4. Move rarely used settings under collapsed "Advanced" disclosure groups with live previews, one-line descriptions, recommended defaults, and "Reset to recommended" buttons (Rule 0: zero feature deletions).
