# Graph Report - Notch  (2026-11-07)

## Corpus Check
- 57 files · ~219,836 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1470 nodes · 3429 edges · 76 communities (56 shown, 20 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 173 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `31e0628a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ShelfModule
- ModuleRegistry
- AppDelegate
- KinematicEngine
- SkeletonPose
- SkeletonPose
- CompanionSkin
- ThockModule
- AirDropModule
- NowPlayingModule
- SettingsStore
- PasteableTextField
- CompactIndicatorStyle
- CalendarModule
- AppTheme
- TelegramModule
- String
- .playClick
- KeychainHelper
- SwiftUI
- CompanionBehaviorState
- DesignSystem
- MediaRemoteBridge
- MirrorModule
- NotchShellCoordinator
- .init
- View
- NotificationModule
- DesignSystem.swift
- VerificationTests.swift
- CGPoint
- SettingsCategory
- PermissionsHelper
- NotchPanel
- .init
- NoteStorageManager
- DynamicThemeEngine
- BatteryModule
- CompanionActivityLevel
- .isModuleEnabled
- 3. Bugs Found & Fixed in This Round (Round 3)
- Equatable
- ScreenRouteStage
- .setDashboardSlot
- .dispatch
- Notch Animated Desktop Companion
- MotionPhysicsStyle
- CompanionFrameStripStubs.swift
- measure_telemetry.py
- CompactNotchIndicator
- Notch Cartoon Companion Specifications
- Identifiable
- .keySoundSectionView
- NotchHostingView
- Creature Analytical IK & Kinematics Fixes
- Companion Rigidity & Settings Lifecycle Analysis
- Package.swift
- run_notch.sh
- security-audit.sh
- NotchGeometry
- stop_notch.sh
- Crawl Animation Strip
- Hanging Idle Animation Strip
- Clean Hang Animation Strip
- Left-Peek Animation Strip
- Pull-Up Animation Strip
- Standard Walk Cycle Strip
- Right Walk Animation Strip
- Creature Animation Rigidity Analysis
- ThockPackMeta
- ThockExpandedView
- LinearGradient
- test_thock_lifecycle.sh
- SpringDamper
- run-tests.sh
- soak_test.sh

## God Nodes (most connected - your core abstractions)
1. `ThockModule` - 76 edges
2. `SettingsStore` - 74 edges
3. `ShelfModule` - 51 edges
4. `KinematicEngine` - 46 edges
5. `DesignSystem` - 44 edges
6. `AppTheme` - 43 edges
7. `CompanionSkin` - 38 edges
8. `DashboardWidgetType` - 36 edges
9. `ModuleRegistry` - 34 edges
10. `CompanionCoordinator` - 34 edges

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
- **Bubu Mascot Motion Capture & Kinematics Library** — companion_strip_climb_over, companion_strip_monkey_bar, companion_strip_peek_left_clean, companion_strip_sleep_clean, companion_strip_walk_right_clean [EXTRACTED 1.00]
- **Notch Ambient Companion Architecture** — notch_creature_mvp_companion, notch_creature_mvp_state_machine, notch_creature_mvp_vector_engine, notch_creature_mvp_privacy_invariants [EXTRACTED 1.00]

## Communities (76 total, 20 thin omitted)

### Community 0 - "ShelfModule"
Cohesion: 0.06
Nodes (52): ByteCountFormatter, CIContext, Int64, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body, FileStudioTool (+44 more)

### Community 1 - "ModuleRegistry"
Cohesion: 0.09
Nodes (26): AnyObject, DropDelegate, NSDragOperation, ScrollViewProxy, ModuleRegistry, .activeModule, .activeModuleId, .isDashboardPinned (+18 more)

### Community 2 - "AppDelegate"
Cohesion: 0.10
Nodes (14): DispatchSourceSignal, NSApplicationDelegate, NSMenu, NSStatusItem, NSWindowDelegate, AppDelegate, .sharedDelegate, Bool (+6 more)

### Community 3 - "KinematicEngine"
Cohesion: 0.08
Nodes (23): CompanionPanel, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any, Bool (+15 more)

### Community 4 - "SkeletonPose"
Cohesion: 0.06
Nodes (55): CGContext, LimbBones, CompanionProductionPoseChecks, CGFloat, CGPoint, LimbBones, MouthShape, gasp (+47 more)

### Community 5 - "SkeletonPose"
Cohesion: 0.10
Nodes (20): SkeletonPose, .chest, .head, .leftElbow, .leftFoot, .leftFootPlanted, .leftHand, .leftHandPlanted (+12 more)

### Community 6 - "CompanionSkin"
Cohesion: 0.12
Nodes (35): CGAffineTransform, Gradient, GraphicsContext, CompanionSkin, .accentColor, boba, .bodyColor, bubu (+27 more)

### Community 7 - "ThockModule"
Cohesion: 0.09
Nodes (21): AnyCancellable, convention, NSRegularExpression, pid_t, Pipe, Double, Int32, Set (+13 more)

### Community 8 - "AirDropModule"
Cohesion: 0.06
Nodes (30): Error, NSObject, NSScrollView, NSSharingService, NSSharingServiceDelegate, NSTextViewDelegate, NSViewRepresentable, NSVisualEffectView (+22 more)

### Community 9 - "NowPlayingModule"
Cohesion: 0.14
Nodes (16): NowPlayingAdaptiveWidgetView, .body, NowPlayingCompactTileView, .body, NowPlayingHomeCardView, .body, NowPlayingModule, .progress (+8 more)

### Community 10 - "SettingsStore"
Cohesion: 0.05
Nodes (41): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .clockDialStyle, .clockIs24Hour, .clockShowSeconds (+33 more)

### Community 11 - "PasteableTextField"
Cohesion: 0.12
Nodes (14): NSControl, NSTextField, NSTextFieldDelegate, NSTextView, Selector, Coordinator, CustomPasteableNSTextField, PasteableTextField (+6 more)

### Community 12 - "CompactIndicatorStyle"
Cohesion: 0.22
Nodes (9): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+1 more)

### Community 13 - "CalendarModule"
Cohesion: 0.12
Nodes (22): EventKit, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body (+14 more)

### Community 14 - "AppTheme"
Cohesion: 0.06
Nodes (33): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+25 more)

### Community 15 - "TelegramModule"
Cohesion: 0.14
Nodes (17): Hashable, ChatContact, ChatMessage, ContactSafetyValidator, AnyView, Bool, DateFormatter, String (+9 more)

### Community 16 - "String"
Cohesion: 0.07
Nodes (38): ObservableObject, AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id (+30 more)

### Community 17 - ".playClick"
Cohesion: 0.17
Nodes (15): NotesUIState, .selectedProvider, NotesWidgetView, .body, .charCount, .fourSpaceView, .oneSpaceView, .twoSpaceView (+7 more)

### Community 18 - "KeychainHelper"
Cohesion: 0.21
Nodes (9): GitHub Security & Sensitive Data Hardening Audit, Hardware-Bound AES-256-GCM Vault Architecture, KeychainHelper, Bool, String, .connectedGoogleEmail, .geminiApiKey, .openAIApiKey (+1 more)

### Community 19 - "SwiftUI"
Cohesion: 0.17
Nodes (7): AppKit, ApplicationServices, Combine, Darwin, IOKit.ps, SwiftUI, UniformTypeIdentifiers

### Community 20 - "CompanionBehaviorState"
Cohesion: 0.10
Nodes (17): CompanionBehaviorState, celebrating, crawling, curious, dangling, inDen, musicGroove, peekingLeft (+9 more)

### Community 21 - "DesignSystem"
Cohesion: 0.13
Nodes (18): SettingsView, .appearanceSection, .companionSection, .detailHeaderBar, .motionSection, .sidebarNavigation, DesignSystem, .accentColor (+10 more)

### Community 22 - "MediaRemoteBridge"
Cohesion: 0.13
Nodes (15): MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction, MRMediaRemoteSendCommandFunction, Sendable (+7 more)

### Community 23 - "MirrorModule"
Cohesion: 0.09
Nodes (21): AVCaptureSession, AVCaptureVideoPreviewLayer, NSCoder, NSView, CameraHostingNSView, CameraLivePreview, CameraSessionManager, MirrorAdaptiveWidgetView (+13 more)

### Community 24 - "NotchShellCoordinator"
Cohesion: 0.19
Nodes (11): Animation, .body, NotchShellCoordinator, .state, .transitionAnimation, Bool, DispatchWorkItem, NSObjectProtocol (+3 more)

### Community 25 - ".init"
Cohesion: 0.16
Nodes (12): NSHostingView, NSPanel, CompanionClickPanel, CompanionPanel, CreatureClickTargetView, .body, CreatureContainerView, .body (+4 more)

### Community 26 - "View"
Cohesion: 0.06
Nodes (55): DashboardWidgetType, askAI, calendar, clock, .icon, .id, mirror, notes (+47 more)

### Community 27 - "NotificationModule"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 28 - "DesignSystem.swift"
Cohesion: 0.21
Nodes (12): Configuration, ImageIO, ButtonStyle, .spring, LiveEqualizerIndicator, .body, NotchGlassBackground, SpringButtonStyle (+4 more)

### Community 29 - "VerificationTests.swift"
Cohesion: 0.15
Nodes (8): AVFoundation, CoreImage, CryptoKit, Foundation, IOKit, PDFKit, Security, TestOutputAccumulator

### Community 30 - "CGPoint"
Cohesion: 0.21
Nodes (14): CoreGraphics, CGPoint, LimbBones, Result, Bool, CGFloat, TorsoBones, .leftHipAnchor (+6 more)

### Community 31 - "SettingsCategory"
Cohesion: 0.13
Nodes (15): SettingsCategory, appearance, companion, dashboard, feedback, geometry, .icon, .id (+7 more)

### Community 32 - "PermissionsHelper"
Cohesion: 0.18
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 33 - "NotchPanel"
Cohesion: 0.19
Nodes (12): SettingsStore, NotchState, collapsed, expanded, NotchPanel, .canBecomeKey, .canBecomeMain, .isolated (+4 more)

### Community 35 - "NoteStorageManager"
Cohesion: 0.18
Nodes (11): NoteStorageManager, .storageURL, .text, Bool, Never, NSObjectProtocol, String, Task (+3 more)

### Community 36 - "DynamicThemeEngine"
Cohesion: 0.22
Nodes (8): .dynamicVibrancy, DynamicThemeEngine, CGRect, NSImage, NSObjectProtocol, Path, Set, URL

### Community 37 - "BatteryModule"
Cohesion: 0.22
Nodes (7): CFRunLoopSource, BatteryModule, AnyView, Bool, Int, String, .description

### Community 38 - "CompanionActivityLevel"
Cohesion: 0.20
Nodes (9): ClosedRange, CompanionActivityLevel, balanced, calm, .displayName, .id, .intervalRange, playful (+1 more)

### Community 40 - "3. Bugs Found & Fixed in This Round (Round 3)"
Cohesion: 0.14
Nodes (13): 1. Mascot Kinematics & Rendering Fixes, 1. Skill & Auditor Execution Table, 2. Before & After Telemetry: Ground Truth Measurements, 2. Window Lifecycle & Hover Glitches, 3. Bugs Found & Fixed in This Round (Round 3), 3. Concurrency & Energy Optimizations, 4. UI Design & Clean Hierarchy, 4. Work Carried Over from Earlier Rounds (+5 more)

### Community 41 - "Equatable"
Cohesion: 0.20
Nodes (10): Equatable, MouthShape, gasp, neutral, openW, sigh, smile, Bool (+2 more)

### Community 42 - "ScreenRouteStage"
Cohesion: 0.22
Nodes (9): ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang, monkeyBarTraversal, rightWalk (+1 more)

### Community 43 - ".setDashboardSlot"
Cohesion: 0.33
Nodes (3): .dashboardSlots, .widgetSpans, Int

### Community 44 - ".dispatch"
Cohesion: 0.39
Nodes (4): DirectMessenger, .isAccessibilityGranted, MainActor, Sendable

### Community 45 - "Notch Animated Desktop Companion"
Cohesion: 0.29
Nodes (7): Comprehensive Codebase Analysis Report, Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 46 - "MotionPhysicsStyle"
Cohesion: 0.29
Nodes (7): MotionPhysicsStyle, appleFluid, .damping, gentle, .id, .response, snappy

### Community 47 - "CompanionFrameStripStubs.swift"
Cohesion: 0.32
Nodes (6): CompanionClickPanel, CompanionPanel, .screen, .shared, NSScreen, SkeletonPose

### Community 48 - "measure_telemetry.py"
Cohesion: 0.70
Nodes (4): cleanup_notch(), main(), measure_scenario(), run_top_sample()

### Community 49 - "CompactNotchIndicator"
Cohesion: 0.25
Nodes (8): CompactNotchIndicator, .batteryIndicator, .body, .circadianIndicator, .dateTimeIndicator, .mediaIndicator, .minimalIndicator, CGFloat

### Community 50 - "Notch Cartoon Companion Specifications"
Cohesion: 0.33
Nodes (6): Climb-Over Animation Strip, Monkey-Bar Traversal Animation Strip, Clean Left-Peek Animation Strip, Clean Den Sleep Animation Strip, Clean Right Walk Animation Strip, Notch Cartoon Companion Specifications

### Community 51 - "Identifiable"
Cohesion: 0.06
Nodes (46): CaseIterable, Codable, Identifiable, ClockDialStyle, analog, digital, .id, .title (+38 more)

### Community 53 - "NotchHostingView"
Cohesion: 0.33
Nodes (4): Content, NSTrackingArea, NotchHostingView, NSEvent

### Community 59 - "NotchGeometry"
Cohesion: 0.28
Nodes (6): NotchGeometry, Bool, CGFloat, CGRect, NSScreen, .geometrySection

### Community 69 - "ThockPackMeta"
Cohesion: 0.25
Nodes (7): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id

### Community 70 - "ThockExpandedView"
Cohesion: 0.33
Nodes (3): AnyView, ThockExpandedView, .terminalSectionView

### Community 71 - "LinearGradient"
Cohesion: 0.33
Nodes (5): LinearGradient, Shape, CustomNotchShape, .cardGradient, .body

### Community 72 - "test_thock_lifecycle.sh"
Cohesion: 0.83
Nodes (3): cleanup_all(), count_thock(), test_thock_lifecycle.sh script

## Knowledge Gaps
- **375 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned`, `.themeColor`, `nowPlaying` (+370 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **20 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `View` to `ShelfModule`, `ModuleRegistry`, `ThockPackMeta`, `CompanionSkin`, `ThockExpandedView`, `AirDropModule`, `NowPlayingModule`, `CalendarModule`, `TelegramModule`, `String`, `.playClick`, `CompactNotchIndicator`, `DesignSystem`, `MirrorModule`, `.init`, `NotificationModule`, `DesignSystem.swift`, `SettingsCategory`?**
  _High betweenness centrality (0.140) - this node is a cross-community bridge._
- **Why does `SettingsStore` connect `SettingsStore` to `DynamicThemeEngine`, `CompanionActivityLevel`, `.isModuleEnabled`, `CompanionSkin`, `.setDashboardSlot`, `CompactIndicatorStyle`, `AppTheme`, `MotionPhysicsStyle`, `String`, `KeychainHelper`, `Identifiable`, `SwiftUI`, `View`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **Why does `KinematicEngine` connect `KinematicEngine` to `CompanionSkin`, `SpringDamper`, `ScreenRouteStage`, `String`, `CompanionBehaviorState`, `VerificationTests.swift`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ThockModule` (e.g. with `.keySoundSectionView` and `.terminalSectionView`) actually correct?**
  _`ThockModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned` to the rest of the system?**
  _375 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ShelfModule` be split into smaller, more focused modules?**
  _Cohesion score 0.05613951266125179 - nodes in this community are weakly interconnected._