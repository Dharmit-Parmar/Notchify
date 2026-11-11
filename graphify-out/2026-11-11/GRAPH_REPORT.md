# Graph Report - Notch  (2026-11-10)

## Corpus Check
- 68 files · ~685,930 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1725 nodes · 3940 edges · 90 communities (70 shown, 20 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 181 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5682c6b7`
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
- ClockWidgetView
- NotificationModule
- CGFloat
- VerificationTests.swift
- CGPoint
- SettingsCategory
- PermissionsHelper
- NotchPanel
- Notchify — Design Phase Execution Log (`DESIGN_LOG.md`)
- NoteStorageManager
- DynamicThemeEngine
- BatteryModule
- CompanionActivityLevel
- .tint
- Notchify Comprehensive Engineering, Performance & Lifecycle Report (Round 5)
- Equatable
- ScreenRouteStage
- View
- .dispatch
- Notch Animated Desktop Companion
- Identifiable
- CompanionFrameStripStubs.swift
- measure_telemetry.py
- NotchRootView.swift
- Notch Cartoon Companion Specifications
- ThockSubSection
- SettingsView
- NotchRootView
- Creature Analytical IK & Kinematics Fixes
- Companion Rigidity & Settings Lifecycle Analysis
- Package.swift
- run_notch.sh
- security-audit.sh
- EnvironmentState
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
- FocusCompanionRotationManager
- AIProvider
- test_thock_lifecycle.sh
- SpringDamper
- run-tests.sh
- soak_test.sh
- AskAIWidgetView
- SettingsInk
- Notchify — Feature Matrix (Keep-and-Guard Inventory)
- OKLabColor
- main
- VisualEffectBlur
- run_stage4_soak.py
- measure_stage1.py
- SettingsWindowAppearance
- verify_stage3.py
- benchmark_time_to_open.py
- CustomNotchShape
- verify_stage2.py
- resource_check.sh script

## God Nodes (most connected - your core abstractions)
1. `SettingsStore` - 78 edges
2. `ThockModule` - 78 edges
3. `ShelfModule` - 55 edges
4. `DesignSystem` - 54 edges
5. `AppTheme` - 48 edges
6. `KinematicEngine` - 46 edges
7. `CompanionSkin` - 38 edges
8. `DashboardWidgetType` - 37 edges
9. `ModuleRegistry` - 36 edges
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

## Communities (90 total, 20 thin omitted)

### Community 0 - "ShelfModule"
Cohesion: 0.05
Nodes (54): ByteCountFormatter, CIContext, Int64, NSURL, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body (+46 more)

### Community 1 - "ModuleRegistry"
Cohesion: 0.07
Nodes (34): AnyObject, DropDelegate, NSDragOperation, ScrollViewProxy, LazyNotchModule, .isEnabled, .isLoaded, .loadedInstance (+26 more)

### Community 2 - "AppDelegate"
Cohesion: 0.11
Nodes (14): DispatchSourceSignal, NSApplicationDelegate, NSMenu, NSStatusItem, NSWindowDelegate, Selector, AppDelegate, .sharedDelegate (+6 more)

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
Cohesion: 0.06
Nodes (27): AnyCancellable, convention, NSRegularExpression, pid_t, Pipe, Process, AnyView, Double (+19 more)

### Community 8 - "AirDropModule"
Cohesion: 0.05
Nodes (31): Error, NSObject, NSScrollView, NSSharingService, NSSharingServiceDelegate, NSTextView, NSTextViewDelegate, AirDropExpandedView (+23 more)

### Community 9 - "NowPlayingModule"
Cohesion: 0.13
Nodes (18): NSString, NowPlayingAdaptiveWidgetView, .body, NowPlayingCompactTileView, .body, NowPlayingHomeCardView, .body, NowPlayingModule (+10 more)

### Community 10 - "SettingsStore"
Cohesion: 0.04
Nodes (50): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .autoRotateCompanion, .clockDialStyle, .clockIs24Hour (+42 more)

### Community 11 - "PasteableTextField"
Cohesion: 0.13
Nodes (13): NSControl, NSTextField, NSTextFieldDelegate, Coordinator, CustomPasteableNSTextField, PasteableTextField, Binding, Context (+5 more)

### Community 12 - "CompactIndicatorStyle"
Cohesion: 0.20
Nodes (10): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+2 more)

### Community 13 - "CalendarModule"
Cohesion: 0.12
Nodes (21): CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body, .monthYearTitle (+13 more)

### Community 14 - "AppTheme"
Cohesion: 0.05
Nodes (37): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+29 more)

### Community 15 - "TelegramModule"
Cohesion: 0.14
Nodes (17): Hashable, ChatContact, ChatMessage, ContactSafetyValidator, AnyView, Bool, DateFormatter, String (+9 more)

### Community 16 - "String"
Cohesion: 0.15
Nodes (11): ObservableObject, AskAIService, .currentLoginBadgeText, .hasAnyCloudLogin, .isCurrentProviderAuthenticated, Bool, .twoSpaceView, .aiAssistantCustomizationSection (+3 more)

### Community 17 - ".playClick"
Cohesion: 0.18
Nodes (14): NotesUIState, .selectedProvider, NotesWidgetView, .body, .charCount, .fourSpaceView, .oneSpaceView, .twoSpaceView (+6 more)

### Community 18 - "KeychainHelper"
Cohesion: 0.21
Nodes (10): GitHub Security & Sensitive Data Hardening Audit, Hardware-Bound AES-256-GCM Vault Architecture, LAContext, KeychainHelper, Bool, String, .connectedGoogleEmail, .geminiApiKey (+2 more)

### Community 19 - "SwiftUI"
Cohesion: 0.13
Nodes (8): AppKit, ApplicationServices, Combine, Darwin, EventKit, Foundation, IOKit.ps, SwiftUI

### Community 20 - "CompanionBehaviorState"
Cohesion: 0.10
Nodes (17): CompanionBehaviorState, celebrating, crawling, curious, dangling, inDen, musicGroove, peekingLeft (+9 more)

### Community 21 - "DesignSystem"
Cohesion: 0.09
Nodes (22): LinearGradient, DesignSystem, .accentColor, .appAccentColor, .canvasColor, .cardBorder, .cardFill, .cardGradient (+14 more)

### Community 22 - "MediaRemoteBridge"
Cohesion: 0.13
Nodes (15): MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction, MRMediaRemoteSendCommandFunction, Sendable (+7 more)

### Community 23 - "MirrorModule"
Cohesion: 0.09
Nodes (20): AVCaptureSession, NSCoder, NSView, CameraHostingNSView, CameraLivePreview, CameraSessionManager, MirrorAdaptiveWidgetView, .body (+12 more)

### Community 24 - "NotchShellCoordinator"
Cohesion: 0.15
Nodes (13): Animation, CFTimeInterval, .body, NotchShellCoordinator, .isExpanded, .state, .transitionAnimation, Bool (+5 more)

### Community 25 - ".init"
Cohesion: 0.16
Nodes (12): NSHostingView, NSPanel, CompanionClickPanel, CompanionPanel, CreatureClickTargetView, .body, CreatureContainerView, .body (+4 more)

### Community 26 - "ClockWidgetView"
Cohesion: 0.18
Nodes (18): AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval, .timeZoneAbbreviation (+10 more)

### Community 27 - "NotificationModule"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 28 - "CGFloat"
Cohesion: 0.18
Nodes (13): Configuration, ImageIO, ButtonStyle, .spring, LiveEqualizerIndicator, .body, MultiZonePalette, NotchGlassBackground (+5 more)

### Community 29 - "VerificationTests.swift"
Cohesion: 0.22
Nodes (8): AVFoundation, CoreImage, CryptoKit, IOKit, LocalAuthentication, PDFKit, Security, TestOutputAccumulator

### Community 30 - "CGPoint"
Cohesion: 0.21
Nodes (14): CoreGraphics, CGPoint, LimbBones, Result, Bool, CGFloat, TorsoBones, .leftHipAnchor (+6 more)

### Community 31 - "SettingsCategory"
Cohesion: 0.17
Nodes (12): SettingsCategory, appearance, companion, dashboard, feedback, geometry, .icon, .id (+4 more)

### Community 32 - "PermissionsHelper"
Cohesion: 0.20
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 33 - "NotchPanel"
Cohesion: 0.17
Nodes (12): SettingsStore, NotchState, collapsed, expanded, NotchPanel, .canBecomeKey, .canBecomeMain, .isolated (+4 more)

### Community 34 - "Notchify — Design Phase Execution Log (`DESIGN_LOG.md`)"
Cohesion: 0.05
Nodes (41): 10. Stage A: Stop the Lag and Regressions, 11. Resource Diet — Stage 1: Baseline and Floor, 12. Resource Diet — Stage 2: Eager-Load Purge, 13. Resource Diet — Stage 3: Sleep and Suspend, 14. Resource Diet — Stage 4: Deep Idle Soak, 15. Resource Diet — Stage 5: Guardrails and Check Script, 1. Full Installed Skill Inventory, 2. Selected Skills for Notchify Design Phase & Rationale (+33 more)

### Community 35 - "NoteStorageManager"
Cohesion: 0.17
Nodes (11): NoteStorageManager, .storageURL, .text, Bool, Never, NSObjectProtocol, String, Task (+3 more)

### Community 36 - "DynamicThemeEngine"
Cohesion: 0.15
Nodes (12): CGImage, .dynamicVibrancy, ColorDetectionDiagnostics, DynamicThemeEngine, Date, Never, NSImage, NSObjectProtocol (+4 more)

### Community 37 - "BatteryModule"
Cohesion: 0.24
Nodes (6): CFRunLoopSource, BatteryModule, AnyView, Bool, Int, String

### Community 38 - "CompanionActivityLevel"
Cohesion: 0.18
Nodes (10): ClosedRange, CompanionActivityLevel, balanced, calm, .description, .displayName, .id, .intervalRange (+2 more)

### Community 39 - ".tint"
Cohesion: 0.16
Nodes (19): DashboardSettingsUIState, DashboardSettingsView, .body, .clockCustomizationSection, .layoutMiniPreviewSection, .layoutModeSelectionSection, DraggableWidgetPaletteCard, .body (+11 more)

### Community 40 - "Notchify Comprehensive Engineering, Performance & Lifecycle Report (Round 5)"
Cohesion: 0.15
Nodes (12): 1. Removal of CLI Terminal from Thock Module, 1. Skill & Auditor Execution Table, 2. Issues Addressed in Round 5, 2. Status & Permission Tags Cleanup (Single-Appearance & Dismiss Cross Button), 3. Empirical Proof: Thock Termination Across All 6 Exit Paths, 3. Modernization of Native Keychain (Zero Deprecation Warnings), 4. Ground-Truth Memory & Thermal Metrics, 5. Architectural Boundaries & Operational Notes (+4 more)

### Community 41 - "Equatable"
Cohesion: 0.20
Nodes (10): Equatable, MouthShape, gasp, neutral, openW, sigh, smile, Bool (+2 more)

### Community 42 - "ScreenRouteStage"
Cohesion: 0.22
Nodes (9): ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang, monkeyBarTraversal, rightWalk (+1 more)

### Community 43 - "View"
Cohesion: 0.18
Nodes (16): DashboardWidgetType, askAI, calendar, clock, .icon, .id, mirror, notes (+8 more)

### Community 44 - ".dispatch"
Cohesion: 0.39
Nodes (4): DirectMessenger, .isAccessibilityGranted, MainActor, Sendable

### Community 45 - "Notch Animated Desktop Companion"
Cohesion: 0.29
Nodes (7): Comprehensive Codebase Analysis Report, Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 46 - "Identifiable"
Cohesion: 0.05
Nodes (48): CaseIterable, Codable, Identifiable, ClockDialStyle, analog, digital, .id, .title (+40 more)

### Community 47 - "CompanionFrameStripStubs.swift"
Cohesion: 0.32
Nodes (6): CompanionClickPanel, CompanionPanel, .screen, .shared, NSScreen, SkeletonPose

### Community 48 - "measure_telemetry.py"
Cohesion: 0.70
Nodes (4): cleanup_notch(), main(), measure_scenario(), run_top_sample()

### Community 49 - "NotchRootView.swift"
Cohesion: 0.16
Nodes (13): CompactBatteryIndicator, .body, CompactMediaIndicator, .body, CompactNotchIndicator, .body, .circadianIndicator, .dateTimeIndicator (+5 more)

### Community 50 - "Notch Cartoon Companion Specifications"
Cohesion: 0.33
Nodes (6): Climb-Over Animation Strip, Monkey-Bar Traversal Animation Strip, Clean Left-Peek Animation Strip, Clean Den Sleep Animation Strip, Clean Right Walk Animation Strip, Notch Cartoon Companion Specifications

### Community 51 - "ThockSubSection"
Cohesion: 0.40
Nodes (5): ThockSubSection, asmr, .icon, .id, keySound

### Community 52 - "SettingsView"
Cohesion: 0.16
Nodes (13): AdvancedSettingsSection, CursorTrackingState, PointerCursorModifier, SettingsView, .appearanceSection, .companionSection, .detailHeaderBar, .geometrySection (+5 more)

### Community 53 - "NotchRootView"
Cohesion: 0.19
Nodes (7): NSTrackingArea, NotchRootView, .contentArea, .isExpanded, NotchHostingView, Content, NSEvent

### Community 59 - "EnvironmentState"
Cohesion: 0.17
Nodes (12): ProcessInfo, EnvironmentState, .isolated, Bool, CGRect, NSObjectProtocol, String, NotchGeometry (+4 more)

### Community 69 - "ThockPackMeta"
Cohesion: 0.20
Nodes (7): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id

### Community 70 - "FocusCompanionRotationManager"
Cohesion: 0.17
Nodes (11): DividerUIState, DottedDividerView, .body, FocusCompanionRotationManager, LineShape, Bool, CGFloat, CGRect (+3 more)

### Community 71 - "AIProvider"
Cohesion: 0.14
Nodes (17): AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id, .shortName (+9 more)

### Community 72 - "test_thock_lifecycle.sh"
Cohesion: 0.83
Nodes (3): cleanup_all(), count_thock(), test_thock_lifecycle.sh script

### Community 76 - "AskAIWidgetView"
Cohesion: 0.21
Nodes (11): AskAIWidgetUIState, AskAIWidgetView, .body, .fourSpaceView, .oneSpaceView, Bool, Int, Never (+3 more)

### Community 77 - "SettingsInk"
Cohesion: 0.16
Nodes (11): .body, SettingsInk, .isLight, .primary, .secondary, .tertiary, SettingsNavigationState, .footerBar (+3 more)

### Community 78 - "Notchify — Feature Matrix (Keep-and-Guard Inventory)"
Cohesion: 0.15
Nodes (12): 10. Geometry & Interaction Settings (`SettingsStore`), 11. Companion Mascot Settings (`SettingsStore`), 1. Appearance & Themes (`AppTheme`), 2. Dynamic Vibrancy (`DynamicVibrancy`), 3. Glass Material Styles (`GlassMaterialStyle`), 4. Corner Radii Styles (`NotchCornerStyle`), 5. Motion Physics Profiles (`MotionPhysicsStyle`), 6. Collapsed Compact Indicator Styles (`CompactIndicatorStyle`) (+4 more)

### Community 79 - "OKLabColor"
Cohesion: 0.29
Nodes (3): ContrastGuard, OKLabColor, CGFloat

### Community 80 - "main"
Cohesion: 0.47
Nodes (8): get_footprint(), get_top_stats(), main(), measure_time_to_open(), post_mouse_click(), post_mouse_move(), start(), stop()

### Community 81 - "VisualEffectBlur"
Cohesion: 0.48
Nodes (4): NSVisualEffectView, Context, NSView, VisualEffectBlur

### Community 82 - "run_stage4_soak.py"
Cohesion: 0.44
Nodes (8): get_footprint(), get_rss(), get_top_stats(), main(), post_mouse_click(), post_mouse_move(), start(), stop()

### Community 83 - "measure_stage1.py"
Cohesion: 0.50
Nodes (7): format_agg(), get_process_metrics(), main(), post_mouse_click(), post_mouse_move(), start_notch(), stop_notch()

### Community 84 - "SettingsWindowAppearance"
Cohesion: 0.38
Nodes (5): NSViewRepresentable, .body, SettingsWindowAppearance, Context, NSView

### Community 86 - "benchmark_time_to_open.py"
Cohesion: 0.67
Nodes (5): get_window_height(), measure_open(), post_mouse_move(), start_notch(), stop_notch()

### Community 87 - "CustomNotchShape"
Cohesion: 0.33
Nodes (4): Shape, CustomNotchShape, CGRect, Path

## Knowledge Gaps
- **436 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `.isolated`, `LocalAuthentication`, `.isDashboardPinned` (+431 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **20 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SettingsStore` connect `SettingsStore` to `DynamicThemeEngine`, `ThockPackMeta`, `CompanionActivityLevel`, `AIProvider`, `CompanionSkin`, `View`, `CompactIndicatorStyle`, `Identifiable`, `AppTheme`, `String`, `KeychainHelper`, `SwiftUI`?**
  _High betweenness centrality (0.114) - this node is a cross-community bridge._
- **Why does `View` connect `View` to `ShelfModule`, `ModuleRegistry`, `CompanionSkin`, `ThockModule`, `AirDropModule`, `NowPlayingModule`, `CalendarModule`, `TelegramModule`, `.playClick`, `MirrorModule`, `.init`, `ClockWidgetView`, `NotificationModule`, `CGFloat`, `.tint`, `NotchRootView.swift`, `SettingsView`, `NotchRootView`, `ThockPackMeta`, `FocusCompanionRotationManager`, `AskAIWidgetView`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Why does `AppTheme` connect `AppTheme` to `SettingsStore`, `Identifiable`, `String`, `DesignSystem`, `CGFloat`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `.isolated` to the rest of the system?**
  _436 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ShelfModule` be split into smaller, more focused modules?**
  _Cohesion score 0.053975363941769314 - nodes in this community are weakly interconnected._
- **Should `ModuleRegistry` be split into smaller, more focused modules?**
  _Cohesion score 0.07243460764587525 - nodes in this community are weakly interconnected._