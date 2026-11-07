# Graph Report - Notch  (2026-11-06)

## Corpus Check
- 64 files · ~212,642 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1425 nodes · 3387 edges · 69 communities (52 shown, 17 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 194 edges (avg confidence: 0.82)
- Token cost: 12,000 input · 1,500 output

## Community Hubs (Navigation)
- PDF Processing & Document Pipeline
- Drag & Drop Shelf Interactions
- Drag & Drop Shelf Interactions
- Desktop Companion Coordinator
- Kinematic Limb Verification
- Kinematic Limb Verification
- Desktop Companion Coordinator
- Process Management & Signal Isolation
- Drag & Drop Shelf Interactions
- Clock & Chronometer Widgets
- Mascot Vector Rendering & Skins
- Kinematic Limb Verification
- Clock & Chronometer Widgets
- EventKit Calendar & Agenda
- Theme System & Visual Palettes
- Hashable Subsystem
- PDF Processing & Document Pipeline
- NotesUIState Subsystem
- MediaRemote Playback Bridge
- macOS App Lifecycle & Status Bar
- NSControl Subsystem
- Theme System & Visual Palettes
- MediaRemote Playback Bridge
- Camera Hardware & Mirror Preview
- Hardware Secret Vault & Cryptography
- Desktop Companion Coordinator
- MediaRemote Playback Bridge
- NotificationModule.swift Subsystem
- Configuration Subsystem
- Mechanical Keyboard Thock Engine
- Ask AI & Multi-Provider Engine
- Modular Bento Dashboard System
- PermissionsHelper.swift Subsystem
- CFRunLoopSource Subsystem
- Ask AI & Multi-Provider Engine
- Camera Hardware & Mirror Preview
- DynamicThemeEngine Subsystem
- Mechanical Keyboard Thock Engine
- CompactIndicatorStyle Subsystem
- PDF Processing & Document Pipeline
- LinearGradient Subsystem
- DirectMessenger Subsystem
- CompactNotchIndicator Subsystem
- Desktop Companion Coordinator
- Camera Hardware & Mirror Preview
- Modular Bento Dashboard System
- Modular Bento Dashboard System
- GlassMaterialStyle Subsystem
- MotionPhysicsStyle Subsystem
- NotchCornerStyle Subsystem
- Climb-Over Animation Strip Subsystem
- MediaRemote Playback Bridge
- Bool Subsystem
- CompanionFrameStripGenerator.swift Subsystem
- Desktop Companion Coordinator
- Companion Rigidity & Settings Lifecycle Analysis Subsystem
- Package.swift Subsystem
- run_notch.sh Subsystem
- security-audit.sh Subsystem
- CGFloat Subsystem
- stop_notch.sh Subsystem
- Crawl Animation Strip Subsystem
- Hanging Idle Animation Strip Subsystem
- Clean Hang Animation Strip Subsystem
- Left-Peek Animation Strip Subsystem
- Pull-Up Animation Strip Subsystem
- Standard Walk Cycle Strip Subsystem
- Right Walk Animation Strip Subsystem
- Desktop Companion Coordinator

## God Nodes (most connected - your core abstractions)
1. `SettingsStore` - 74 edges
2. `ThockModule` - 74 edges
3. `ShelfModule` - 51 edges
4. `KinematicEngine` - 46 edges
5. `DesignSystem` - 44 edges
6. `AppTheme` - 43 edges
7. `CompanionSkin` - 38 edges
8. `DashboardWidgetType` - 36 edges
9. `ModuleRegistry` - 34 edges
10. `CompanionCoordinator` - 33 edges

## Surprising Connections (you probably didn't know these)
- `GitHub Security & Sensitive Data Hardening Audit` --conceptually_related_to--> `KeychainHelper`  [INFERRED]
  GITHUB_SECURITY_AND_SENSITIVE_DATA_AUDIT.md → Sources/Core/KeychainHelper.swift
- `Notch Cartoon Companion Specifications` --references--> `Climb-Over Animation Strip`  [EXTRACTED]
  NOTCH_CARTOON_FEATURE.md → artifacts/companion-frame-strips/climb-over.png
- `Notch Cartoon Companion Specifications` --references--> `Monkey-Bar Traversal Animation Strip`  [EXTRACTED]
  NOTCH_CARTOON_FEATURE.md → artifacts/companion-frame-strips/monkey-bar.png
- `Notch Cartoon Companion Specifications` --references--> `Clean Left-Peek Animation Strip`  [EXTRACTED]
  NOTCH_CARTOON_FEATURE.md → artifacts/companion-frame-strips/peek-left-clean.png
- `Notch Cartoon Companion Specifications` --references--> `Clean Den Sleep Animation Strip`  [EXTRACTED]
  NOTCH_CARTOON_FEATURE.md → artifacts/companion-frame-strips/sleep-clean.png

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Notch Ambient Companion Architecture** — notch_creature_mvp_companion, notch_creature_mvp_state_machine, notch_creature_mvp_vector_engine, notch_creature_mvp_privacy_invariants [EXTRACTED 1.00]
- **Bubu Mascot Motion Capture & Kinematics Library** — companion_strip_climb_over, companion_strip_monkey_bar, companion_strip_peek_left_clean, companion_strip_sleep_clean, companion_strip_walk_right_clean [EXTRACTED 1.00]

## Communities (69 total, 17 thin omitted)

### Community 0 - "PDF Processing & Document Pipeline"
Cohesion: 0.06
Nodes (52): ByteCountFormatter, CIContext, Int64, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body, FileStudioTool (+44 more)

### Community 1 - "Drag & Drop Shelf Interactions"
Cohesion: 0.06
Nodes (47): AnyObject, DropDelegate, NSDragOperation, ObservableObject, ScrollViewProxy, ModuleRegistry, .activeModule, .activeModuleId (+39 more)

### Community 2 - "Drag & Drop Shelf Interactions"
Cohesion: 0.05
Nodes (43): Animation, Content, NSApplicationDelegate, NSMenu, NSStatusItem, NSTrackingArea, NSWindowDelegate, SettingsStore (+35 more)

### Community 3 - "Desktop Companion Coordinator"
Cohesion: 0.06
Nodes (38): CompanionPanel, Never, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any (+30 more)

### Community 4 - "Kinematic Limb Verification"
Cohesion: 0.06
Nodes (55): CGContext, LimbBones, CompanionProductionPoseChecks, CGFloat, CGPoint, LimbBones, MouthShape, gasp (+47 more)

### Community 5 - "Kinematic Limb Verification"
Cohesion: 0.05
Nodes (52): CoreGraphics, Equatable, ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang (+44 more)

### Community 6 - "Desktop Companion Coordinator"
Cohesion: 0.12
Nodes (35): CGAffineTransform, Gradient, GraphicsContext, CompanionSkin, .accentColor, boba, .bodyColor, bubu (+27 more)

### Community 7 - "Process Management & Signal Isolation"
Cohesion: 0.08
Nodes (24): AnyCancellable, convention, NSRegularExpression, pid_t, AnyView, Double, Int32, Set (+16 more)

### Community 8 - "Drag & Drop Shelf Interactions"
Cohesion: 0.06
Nodes (30): Error, NSObject, NSScrollView, NSSharingService, NSSharingServiceDelegate, NSTextViewDelegate, NSViewRepresentable, NSVisualEffectView (+22 more)

### Community 9 - "Clock & Chronometer Widgets"
Cohesion: 0.13
Nodes (22): AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval, .timeZoneAbbreviation (+14 more)

### Community 10 - "Mascot Vector Rendering & Skins"
Cohesion: 0.05
Nodes (41): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .clockDialStyle, .clockIs24Hour, .clockShowSeconds (+33 more)

### Community 11 - "Kinematic Limb Verification"
Cohesion: 0.21
Nodes (9): KinematicEngine, .ledgeY, .walkLedgeY, Bool, CGFloat, CGPoint, Double, Int (+1 more)

### Community 12 - "Clock & Chronometer Widgets"
Cohesion: 0.07
Nodes (33): CaseIterable, ClosedRange, Codable, Identifiable, ClockDialStyle, analog, digital, .id (+25 more)

### Community 13 - "EventKit Calendar & Agenda"
Cohesion: 0.12
Nodes (22): EventKit, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body (+14 more)

### Community 14 - "Theme System & Visual Palettes"
Cohesion: 0.06
Nodes (33): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+25 more)

### Community 15 - "Hashable Subsystem"
Cohesion: 0.15
Nodes (16): Hashable, ChatContact, ChatMessage, ContactSafetyValidator, AnyView, Bool, DateFormatter, String (+8 more)

### Community 16 - "PDF Processing & Document Pipeline"
Cohesion: 0.18
Nodes (9): AskAIService, .currentLoginBadgeText, .hasAnyCloudLogin, .isCurrentProviderAuthenticated, Bool, .oneSpaceView, .twoSpaceView, .aiAssistantCustomizationSection (+1 more)

### Community 17 - "NotesUIState Subsystem"
Cohesion: 0.18
Nodes (13): NotesUIState, .selectedProvider, NotesWidgetView, .body, .charCount, .fourSpaceView, .oneSpaceView, .twoSpaceView (+5 more)

### Community 18 - "MediaRemote Playback Bridge"
Cohesion: 0.12
Nodes (14): MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction, MRMediaRemoteSendCommandFunction, MediaRemoteBridge (+6 more)

### Community 19 - "macOS App Lifecycle & Status Bar"
Cohesion: 0.15
Nodes (7): AppKit, ApplicationServices, Combine, Foundation, IOKit.ps, SwiftUI, UniformTypeIdentifiers

### Community 20 - "NSControl Subsystem"
Cohesion: 0.12
Nodes (14): NSControl, NSTextField, NSTextFieldDelegate, NSTextView, Selector, Coordinator, CustomPasteableNSTextField, PasteableTextField (+6 more)

### Community 21 - "Theme System & Visual Palettes"
Cohesion: 0.12
Nodes (19): SettingsView, .appearanceSection, .companionSection, .detailHeaderBar, .footerBar, .motionSection, .sidebarNavigation, DesignSystem (+11 more)

### Community 22 - "MediaRemote Playback Bridge"
Cohesion: 0.17
Nodes (15): NowPlayingAdaptiveWidgetView, .body, NowPlayingCompactTileView, .body, NowPlayingHomeCardView, .body, NowPlayingModule, .progress (+7 more)

### Community 23 - "Camera Hardware & Mirror Preview"
Cohesion: 0.17
Nodes (12): CameraLivePreview, MirrorAdaptiveWidgetView, .body, MirrorCompactTileView, .body, MirrorContainerView, .body, MirrorModule (+4 more)

### Community 24 - "Hardware Secret Vault & Cryptography"
Cohesion: 0.20
Nodes (10): GitHub Security & Sensitive Data Hardening Audit, Hardware-Bound AES-256-GCM Vault Architecture, KeychainHelper, Bool, String, URL, .connectedGoogleEmail, .geminiApiKey (+2 more)

### Community 25 - "Desktop Companion Coordinator"
Cohesion: 0.16
Nodes (12): NSHostingView, NSPanel, CompanionClickPanel, CompanionPanel, CreatureClickTargetView, .body, CreatureContainerView, .body (+4 more)

### Community 26 - "MediaRemote Playback Bridge"
Cohesion: 0.11
Nodes (16): DashboardWidgetType, askAI, calendar, clock, .icon, .id, mirror, notes (+8 more)

### Community 27 - "NotificationModule.swift Subsystem"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 28 - "Configuration Subsystem"
Cohesion: 0.23
Nodes (11): Configuration, ButtonStyle, .spring, LiveEqualizerIndicator, .body, NotchGlassBackground, SpringButtonStyle, Bool (+3 more)

### Community 29 - "Mechanical Keyboard Thock Engine"
Cohesion: 0.17
Nodes (3): Pipe, Process, .body

### Community 30 - "Ask AI & Multi-Provider Engine"
Cohesion: 0.14
Nodes (17): AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id, .shortName (+9 more)

### Community 31 - "Modular Bento Dashboard System"
Cohesion: 0.13
Nodes (15): SettingsCategory, appearance, companion, dashboard, feedback, geometry, .icon, .id (+7 more)

### Community 32 - "PermissionsHelper.swift Subsystem"
Cohesion: 0.20
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 33 - "CFRunLoopSource Subsystem"
Cohesion: 0.22
Nodes (7): CFRunLoopSource, BatteryModule, AnyView, Bool, Int, String, .description

### Community 34 - "Ask AI & Multi-Provider Engine"
Cohesion: 0.19
Nodes (8): AskAIWidgetUIState, AskAIWidgetView, .body, .fourSpaceView, Bool, Int, String, Void

### Community 35 - "Camera Hardware & Mirror Preview"
Cohesion: 0.25
Nodes (6): AVCaptureVideoPreviewLayer, NSCoder, NSView, CameraHostingNSView, Context, NSRect

### Community 36 - "DynamicThemeEngine Subsystem"
Cohesion: 0.27
Nodes (7): .dynamicVibrancy, DynamicThemeEngine, CGRect, NSImage, NSObjectProtocol, Set, URL

### Community 37 - "Mechanical Keyboard Thock Engine"
Cohesion: 0.20
Nodes (7): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id

### Community 38 - "CompactIndicatorStyle Subsystem"
Cohesion: 0.22
Nodes (9): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+1 more)

### Community 39 - "PDF Processing & Document Pipeline"
Cohesion: 0.29
Nodes (6): AVFoundation, CoreImage, CryptoKit, IOKit, PDFKit, Security

### Community 40 - "LinearGradient Subsystem"
Cohesion: 0.25
Nodes (6): LinearGradient, Shape, CustomNotchShape, .cardGradient, .body, Path

### Community 41 - "DirectMessenger Subsystem"
Cohesion: 0.39
Nodes (4): DirectMessenger, .isAccessibilityGranted, MainActor, Sendable

### Community 42 - "CompactNotchIndicator Subsystem"
Cohesion: 0.25
Nodes (8): CompactNotchIndicator, .batteryIndicator, .body, .circadianIndicator, .dateTimeIndicator, .mediaIndicator, .minimalIndicator, CGFloat

### Community 43 - "Desktop Companion Coordinator"
Cohesion: 0.32
Nodes (6): CompanionClickPanel, CompanionPanel, .screen, .shared, NSScreen, SkeletonPose

### Community 44 - "Camera Hardware & Mirror Preview"
Cohesion: 0.48
Nodes (4): AVCaptureSession, Sendable, CameraSessionManager, MainActor

### Community 45 - "Modular Bento Dashboard System"
Cohesion: 0.29
Nodes (7): Comprehensive Codebase Analysis Report, Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 46 - "Modular Bento Dashboard System"
Cohesion: 0.29
Nodes (7): DashboardLayoutFlow, adaptiveAuto, bentoQuad, horizontalStrip, .icon, .id, .title

### Community 47 - "GlassMaterialStyle Subsystem"
Cohesion: 0.29
Nodes (7): GlassMaterialStyle, crystal, deepOLED, frosted, .id, luminous, .subtitle

### Community 48 - "MotionPhysicsStyle Subsystem"
Cohesion: 0.29
Nodes (7): MotionPhysicsStyle, appleFluid, .damping, gentle, .id, .response, snappy

### Community 49 - "NotchCornerStyle Subsystem"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 50 - "Climb-Over Animation Strip Subsystem"
Cohesion: 0.33
Nodes (6): Climb-Over Animation Strip, Monkey-Bar Traversal Animation Strip, Clean Left-Peek Animation Strip, Clean Den Sleep Animation Strip, Clean Right Walk Animation Strip, Notch Cartoon Companion Specifications

### Community 51 - "MediaRemote Playback Bridge"
Cohesion: 0.40
Nodes (4): ImageIO, Bool, Double, SystemMediaTrack

## Knowledge Gaps
- **361 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned`, `.themeColor`, `nowPlaying` (+356 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SettingsStore` connect `Mascot Vector Rendering & Skins` to `Drag & Drop Shelf Interactions`, `DynamicThemeEngine Subsystem`, `Mechanical Keyboard Thock Engine`, `Desktop Companion Coordinator`, `CompactIndicatorStyle Subsystem`, `Clock & Chronometer Widgets`, `Modular Bento Dashboard System`, `Theme System & Visual Palettes`, `GlassMaterialStyle Subsystem`, `MotionPhysicsStyle Subsystem`, `NotchCornerStyle Subsystem`, `macOS App Lifecycle & Status Bar`, `Bool Subsystem`, `PDF Processing & Document Pipeline`, `Hardware Secret Vault & Cryptography`, `MediaRemote Playback Bridge`, `CGFloat Subsystem`, `Ask AI & Multi-Provider Engine`?**
  _High betweenness centrality (0.107) - this node is a cross-community bridge._
- **Why does `View` connect `Clock & Chronometer Widgets` to `PDF Processing & Document Pipeline`, `Drag & Drop Shelf Interactions`, `Ask AI & Multi-Provider Engine`, `Mechanical Keyboard Thock Engine`, `Desktop Companion Coordinator`, `Process Management & Signal Isolation`, `Drag & Drop Shelf Interactions`, `CompactNotchIndicator Subsystem`, `EventKit Calendar & Agenda`, `Hashable Subsystem`, `NotesUIState Subsystem`, `Theme System & Visual Palettes`, `MediaRemote Playback Bridge`, `Camera Hardware & Mirror Preview`, `Desktop Companion Coordinator`, `NotificationModule.swift Subsystem`, `Configuration Subsystem`, `Modular Bento Dashboard System`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `macOS App Lifecycle & Status Bar` to `PDF Processing & Document Pipeline`, `Drag & Drop Shelf Interactions`, `Kinematic Limb Verification`, `PDF Processing & Document Pipeline`, `Clock & Chronometer Widgets`, `Desktop Companion Coordinator`, `Clock & Chronometer Widgets`, `EventKit Calendar & Agenda`, `Hashable Subsystem`, `CompanionFrameStripGenerator.swift Subsystem`, `MediaRemote Playback Bridge`, `Camera Hardware & Mirror Preview`, `Desktop Companion Coordinator`, `NotificationModule.swift Subsystem`, `Configuration Subsystem`, `Modular Bento Dashboard System`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ThockModule` (e.g. with `.keySoundSectionView` and `.terminalSectionView`) actually correct?**
  _`ThockModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned` to the rest of the system?**
  _361 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `PDF Processing & Document Pipeline` be split into smaller, more focused modules?**
  _Cohesion score 0.05613951266125179 - nodes in this community are weakly interconnected._