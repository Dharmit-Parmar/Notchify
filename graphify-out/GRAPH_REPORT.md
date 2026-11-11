# Graph Report - Notch  (2026-11-11)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1894 nodes · 4242 edges · 114 communities (77 shown, 37 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 183 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d6eba955`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ShelfModule
- .tint
- ModuleRegistry
- KinematicEngine
- View
- SkeletonPose
- String
- TelegramModule
- MediaRemoteBridge
- SkeletonPose
- SettingsStore
- ThockModule
- Notchify — Design Phase Execution Log (`DESIGN_LOG.md`)
- MirrorModule
- CreatureRigView
- AirDropModule
- AppTheme
- AppDelegate
- .playClick
- SpringButtonStyle
- CompanionBehaviorState
- SwiftUI
- NotchShellCoordinator
- BatteryModule
- NotchRootView.swift
- DynamicThemeEngine
- Equatable
- DesignSystem
- KeychainHelper
- CompanionClickPanel
- NotificationModule
- NotchPanel
- CalendarModule
- CompanionSkin
- DesignSystem.swift
- ResponsiveTabContent
- NoteStorageManager
- .sendCommand
- PermissionsHelper
- .init
- Identifiable
- Notchify — Feature Matrix (Keep-and-Guard Inventory)
- FocusTextView
- Notchify Comprehensive Engineering, Performance & Lifecycle Report (Round 5)
- CalendarMiniGlanceView
- CaseIterable
- OKLabColor
- NotchHostingView
- EnvironmentState
- CompanionActivityLevel
- ThockPackMeta
- .keySoundSectionView
- CompactIndicatorStyle
- VerificationTests.swift
- main
- run_stage4_soak.py
- ScreenRouteStage
- measure_stage1.py
- DashboardLayoutFlow
- Notch Animated Desktop Companion
- .positionProfile
- VisualEffectBlur
- verify_stage3.py
- .setDashboardSlot
- GlassMaterialStyle
- MotionPhysicsStyle
- NotchCornerStyle
- Notch Cartoon Companion Specifications
- benchmark_time_to_open.py
- .saveSecretAsync
- measure_telemetry.py
- verify_stage2.py
- ClockDialStyle
- test_thock_lifecycle.sh
- .isModuleEnabled
- build_sources.py
- Creature Analytical IK & Kinematics Fixes
- Companion Rigidity & Settings Lifecycle Analysis
- Package.swift
- run_notch.sh
- resource_check.sh script
- run-tests.sh
- security-audit.sh
- soak_test.sh
- stop_notch.sh
- Crawl Animation Strip
- Hanging Idle Animation Strip
- Clean Hang Animation Strip
- Left-Peek Animation Strip
- Pull-Up Animation Strip
- Standard Walk Cycle Strip
- Right Walk Animation Strip
- Creature Animation Rigidity Analysis
- NSCache
- SettingsStore
- CompanionSkin
- NSScreen
- CompanionClickPanel
- CompanionClickPanel
- CGPoint
- Data
- DateFormatter
- Set
- CGRect
- Path
- NotchGeometry
- Any
- CustomTextEditor

## God Nodes (most connected - your core abstractions)
1. `SettingsStore` - 93 edges
2. `ThockModule` - 79 edges
3. `ShelfModule` - 65 edges
4. `DesignSystem` - 55 edges
5. `AppTheme` - 46 edges
6. `KinematicEngine` - 45 edges
7. `NotchShellCoordinator` - 39 edges
8. `DashboardWidgetType` - 38 edges
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

## Communities (114 total, 37 thin omitted)

### Community 0 - "ShelfModule"
Cohesion: 0.05
Nodes (60): ByteCountFormatter, CGRect, CIContext, Data, Int64, NSURL, PDFDocument, PDFPage (+52 more)

### Community 1 - ".tint"
Cohesion: 0.05
Nodes (61): NSViewRepresentable, AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval (+53 more)

### Community 2 - "ModuleRegistry"
Cohesion: 0.06
Nodes (41): AnyObject, DropDelegate, ModuleRegistry, NSDragOperation, ScrollViewProxy, LazyNotchModule, .isEnabled, .isLoaded (+33 more)

### Community 3 - "KinematicEngine"
Cohesion: 0.08
Nodes (25): CompanionClickPanel, CompanionPanel, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any (+17 more)

### Community 4 - "View"
Cohesion: 0.05
Nodes (52): ObservableObject, Shape, DashboardWidgetType, askAI, battery, calendar, clock, .icon (+44 more)

### Community 5 - "SkeletonPose"
Cohesion: 0.06
Nodes (55): CGContext, LimbBones, CompanionProductionPoseChecks, CGFloat, CGPoint, LimbBones, MouthShape, gasp (+47 more)

### Community 6 - "String"
Cohesion: 0.07
Nodes (40): AIChatMessage, AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id (+32 more)

### Community 7 - "TelegramModule"
Cohesion: 0.06
Nodes (37): Codable, DateFormatter, Hashable, NSControl, NSObject, NSTextField, NSTextFieldDelegate, Selector (+29 more)

### Community 8 - "MediaRemoteBridge"
Cohesion: 0.06
Nodes (35): MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction, MRMediaRemoteSendCommandFunction, NSString (+27 more)

### Community 9 - "SkeletonPose"
Cohesion: 0.06
Nodes (44): CoreGraphics, Path, .body, CGPoint, LimbBones, MouthShape, gasp, neutral (+36 more)

### Community 10 - "SettingsStore"
Cohesion: 0.04
Nodes (51): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .autoRotateCompanion, .clockDialStyle, .clockIs24Hour (+43 more)

### Community 11 - "ThockModule"
Cohesion: 0.07
Nodes (25): AnyCancellable, convention, NSRegularExpression, pid_t, Pipe, Process, Set, AnyView (+17 more)

### Community 12 - "Notchify — Design Phase Execution Log (`DESIGN_LOG.md`)"
Cohesion: 0.05
Nodes (41): 10. Stage A: Stop the Lag and Regressions, 11. Resource Diet — Stage 1: Baseline and Floor, 12. Resource Diet — Stage 2: Eager-Load Purge, 13. Resource Diet — Stage 3: Sleep and Suspend, 14. Resource Diet — Stage 4: Deep Idle Soak, 15. Resource Diet — Stage 5: Guardrails and Check Script, 1. Full Installed Skill Inventory, 2. Selected Skills for Notchify Design Phase & Rationale (+33 more)

### Community 13 - "MirrorModule"
Cohesion: 0.09
Nodes (20): AVCaptureSession, NSCoder, NSView, CameraHostingNSView, CameraLivePreview, CameraSessionManager, MirrorAdaptiveWidgetView, .body (+12 more)

### Community 14 - "CreatureRigView"
Cohesion: 0.22
Nodes (19): CGAffineTransform, CGPoint, Gradient, GraphicsContext, KinematicEngine, CreatureRigView, .body, .cartoonStrokeStyle (+11 more)

### Community 15 - "AirDropModule"
Cohesion: 0.11
Nodes (17): Error, NSSharingService, NSSharingServiceDelegate, AirDropExpandedView, .body, AirDropModule, AirDropRadarAnimation, AirDropSharingDelegate (+9 more)

### Community 16 - "AppTheme"
Cohesion: 0.05
Nodes (37): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+29 more)

### Community 17 - "AppDelegate"
Cohesion: 0.10
Nodes (15): DispatchSourceSignal, NotchPanel, NSApplicationDelegate, NSMenu, NSStatusItem, NSWindowDelegate, AppDelegate, .sharedDelegate (+7 more)

### Community 18 - ".playClick"
Cohesion: 0.18
Nodes (14): NotesUIState, NotesWidgetView, .body, .charCount, .fourSpaceView, .oneSpaceView, .twoSpaceView, AIProvider (+6 more)

### Community 19 - "SpringButtonStyle"
Cohesion: 0.32
Nodes (5): Configuration, ButtonStyle, .spring, SpringButtonStyle, Double

### Community 20 - "CompanionBehaviorState"
Cohesion: 0.07
Nodes (24): CompanionBehaviorState, celebrating, crawling, curious, dangling, inDen, musicGroove, peekingLeft (+16 more)

### Community 21 - "SwiftUI"
Cohesion: 0.15
Nodes (7): AppKit, ApplicationServices, Combine, Darwin, Foundation, IOKit.ps, SwiftUI

### Community 22 - "NotchShellCoordinator"
Cohesion: 0.15
Nodes (13): Animation, CFTimeInterval, .body, NotchShellCoordinator, .cachedExpandedRect, .isExpanded, .state, .transitionAnimation (+5 more)

### Community 23 - "BatteryModule"
Cohesion: 0.11
Nodes (18): CFRunLoopSource, BatteryExpandedView, .body, BatteryModule, .batteryColor, .batteryIconName, .formattedTimeEstimate, .statusDescription (+10 more)

### Community 24 - "NotchRootView.swift"
Cohesion: 0.14
Nodes (20): CollapsedLayout, CompactBatteryIndicator, .body, CompactMediaIndicator, .body, CompactNotchIndicator, .body, .circadianIndicator (+12 more)

### Community 25 - "DynamicThemeEngine"
Cohesion: 0.12
Nodes (18): CGImage, OKLabColor, .dynamicVibrancy, ColorDetectionDiagnostics, CustomNotchShape, DynamicThemeEngine, MultiZonePalette, CGFloat (+10 more)

### Community 26 - "Equatable"
Cohesion: 0.20
Nodes (14): Equatable, ActiveNotchEvents, .hasAnyActiveEvent, CollapsedLayout, ExpandedLayout, NotchGeometry, Bool, CGFloat (+6 more)

### Community 27 - "DesignSystem"
Cohesion: 0.09
Nodes (26): LinearGradient, DesignSystem, .accentColor, .appAccentColor, .canvasColor, .cardBorder, .cardFill, .cardGradient (+18 more)

### Community 28 - "KeychainHelper"
Cohesion: 0.20
Nodes (9): GitHub Security & Sensitive Data Hardening Audit, Hardware-Bound AES-256-GCM Vault Architecture, LAContext, KeychainHelper, Bool, Never, String, Task (+1 more)

### Community 29 - "CompanionClickPanel"
Cohesion: 0.17
Nodes (11): NSHostingView, NSPanel, CompanionClickPanel, CompanionPanel, CreatureClickTargetView, .body, CreatureContainerView, .body (+3 more)

### Community 30 - "NotificationModule"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 31 - "NotchPanel"
Cohesion: 0.19
Nodes (11): Any, NotchState, collapsed, expanded, NotchPanel, .canBecomeKey, .canBecomeMain, .isolated (+3 more)

### Community 32 - "CalendarModule"
Cohesion: 0.20
Nodes (11): CalendarEventItem, .color, CalendarHomeCardView, .body, .monthYearTitle, .weekDays, .weekStripCells, CalendarModule (+3 more)

### Community 33 - "CompanionSkin"
Cohesion: 0.12
Nodes (17): CompanionSkin, .accentColor, boba, .bodyColor, bubu, cyber, .darkAccentColor, .displayName (+9 more)

### Community 34 - "DesignSystem.swift"
Cohesion: 0.13
Nodes (18): AVFoundation, ImageIO, CollapsedNotchMode, alwaysShowWings, hideBehindNotch, .icon, .id, .subtitle (+10 more)

### Community 35 - "ResponsiveTabContent"
Cohesion: 0.23
Nodes (13): Content, EnvironmentKey, EnvironmentValues, .notchCompact, .notchContentHeight, .notchTight, NotchCompactKey, NotchContentHeightKey (+5 more)

### Community 36 - "NoteStorageManager"
Cohesion: 0.18
Nodes (11): NoteStorageManager, .storageURL, .text, Bool, Never, NSObjectProtocol, String, Task (+3 more)

### Community 38 - "PermissionsHelper"
Cohesion: 0.20
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 39 - ".init"
Cohesion: 0.15
Nodes (12): AppTheme, CollapsedNotchMode, CompactIndicatorStyle, CompanionActivityLevel, CompanionSkin, DynamicVibrancy, GlassMaterialStyle, MotionPhysicsStyle (+4 more)

### Community 40 - "Identifiable"
Cohesion: 0.19
Nodes (11): EventKit, Identifiable, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarSubsection, calendar, .id (+3 more)

### Community 41 - "Notchify — Feature Matrix (Keep-and-Guard Inventory)"
Cohesion: 0.15
Nodes (12): 10. Geometry & Interaction Settings (`SettingsStore`), 11. Companion Mascot Settings (`SettingsStore`), 1. Appearance & Themes (`AppTheme`), 2. Dynamic Vibrancy (`DynamicVibrancy`), 3. Glass Material Styles (`GlassMaterialStyle`), 4. Corner Radii Styles (`NotchCornerStyle`), 5. Motion Physics Profiles (`MotionPhysicsStyle`), 6. Collapsed Compact Indicator Styles (`CompactIndicatorStyle`) (+4 more)

### Community 42 - "FocusTextView"
Cohesion: 0.21
Nodes (6): NSTextView, FocusTextView, .acceptsFirstResponder, Bool, NSEvent, NSWindow

### Community 43 - "Notchify Comprehensive Engineering, Performance & Lifecycle Report (Round 5)"
Cohesion: 0.15
Nodes (12): 1. Removal of CLI Terminal from Thock Module, 1. Skill & Auditor Execution Table, 2. Issues Addressed in Round 5, 2. Status & Permission Tags Cleanup (Single-Appearance & Dismiss Cross Button), 3. Empirical Proof: Thock Termination Across All 6 Exit Paths, 3. Modernization of Native Keychain (Zero Deprecation Warnings), 4. Ground-Truth Memory & Thermal Metrics, 5. Architectural Boundaries & Operational Notes (+4 more)

### Community 44 - "CalendarMiniGlanceView"
Cohesion: 0.29
Nodes (7): CalendarMiniGlanceView, .body, .dayNumber, .monthAbbrev, .nextEvent, .todayDate, .weekdayAbbrev

### Community 45 - "CaseIterable"
Cohesion: 0.17
Nodes (12): CaseIterable, ThockSubSection, asmr, .icon, .id, keySound, DynamicVibrancy, balanced (+4 more)

### Community 46 - "OKLabColor"
Cohesion: 0.38
Nodes (3): ContrastGuard, OKLabColor, CGFloat

### Community 47 - "NotchHostingView"
Cohesion: 0.23
Nodes (6): NSPoint, NSTrackingArea, NotchHostingView, Content, NSEvent, NSView

### Community 48 - "EnvironmentState"
Cohesion: 0.22
Nodes (8): ProcessInfo, EnvironmentState, .isolated, Bool, CGRect, NotchGeometry, NSObjectProtocol, String

### Community 49 - "CompanionActivityLevel"
Cohesion: 0.20
Nodes (9): ClosedRange, CompanionActivityLevel, balanced, calm, .displayName, .id, .intervalRange, playful (+1 more)

### Community 50 - "ThockPackMeta"
Cohesion: 0.22
Nodes (7): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id

### Community 52 - "CompactIndicatorStyle"
Cohesion: 0.20
Nodes (10): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+2 more)

### Community 53 - "VerificationTests.swift"
Cohesion: 0.29
Nodes (6): CoreImage, CryptoKit, IOKit, LocalAuthentication, PDFKit, Security

### Community 54 - "main"
Cohesion: 0.47
Nodes (8): get_footprint(), get_top_stats(), main(), measure_time_to_open(), post_mouse_click(), post_mouse_move(), start(), stop()

### Community 55 - "run_stage4_soak.py"
Cohesion: 0.44
Nodes (8): get_footprint(), get_rss(), get_top_stats(), main(), post_mouse_click(), post_mouse_move(), start(), stop()

### Community 56 - "ScreenRouteStage"
Cohesion: 0.20
Nodes (9): ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang, monkeyBarTraversal, rightWalk (+1 more)

### Community 57 - "measure_stage1.py"
Cohesion: 0.50
Nodes (7): format_agg(), get_process_metrics(), main(), post_mouse_click(), post_mouse_move(), start_notch(), stop_notch()

### Community 58 - "DashboardLayoutFlow"
Cohesion: 0.25
Nodes (8): DashboardLayoutFlow, adaptiveAuto, bentoQuad, focusDominant, horizontalStrip, .icon, .id, .title

### Community 59 - "Notch Animated Desktop Companion"
Cohesion: 0.29
Nodes (7): Comprehensive Codebase Analysis Report, Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 60 - ".positionProfile"
Cohesion: 0.57
Nodes (3): DisplayPositionProfile, NSScreen, .displayPositionProfiles

### Community 61 - "VisualEffectBlur"
Cohesion: 0.48
Nodes (4): NSVisualEffectView, Context, NSView, VisualEffectBlur

### Community 63 - ".setDashboardSlot"
Cohesion: 0.33
Nodes (3): .dashboardSlots, .widgetSpans, Int

### Community 64 - "GlassMaterialStyle"
Cohesion: 0.29
Nodes (7): GlassMaterialStyle, crystal, deepOLED, frosted, .id, luminous, .subtitle

### Community 65 - "MotionPhysicsStyle"
Cohesion: 0.29
Nodes (7): MotionPhysicsStyle, appleFluid, .damping, gentle, .id, .response, snappy

### Community 66 - "NotchCornerStyle"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 67 - "Notch Cartoon Companion Specifications"
Cohesion: 0.33
Nodes (6): Climb-Over Animation Strip, Monkey-Bar Traversal Animation Strip, Clean Left-Peek Animation Strip, Clean Den Sleep Animation Strip, Clean Right Walk Animation Strip, Notch Cartoon Companion Specifications

### Community 68 - "benchmark_time_to_open.py"
Cohesion: 0.67
Nodes (5): get_window_height(), measure_open(), post_mouse_move(), start_notch(), stop_notch()

### Community 69 - ".saveSecretAsync"
Cohesion: 0.33
Nodes (5): TimeInterval, .connectedGoogleEmail, .geminiApiKey, .openAIApiKey, .botToken

### Community 70 - "measure_telemetry.py"
Cohesion: 0.70
Nodes (4): cleanup_notch(), main(), measure_scenario(), run_top_sample()

### Community 72 - "ClockDialStyle"
Cohesion: 0.40
Nodes (5): ClockDialStyle, analog, digital, .id, .title

### Community 73 - "test_thock_lifecycle.sh"
Cohesion: 0.83
Nodes (3): cleanup_all(), count_thock(), test_thock_lifecycle.sh script

### Community 113 - "CustomTextEditor"
Cohesion: 0.21
Nodes (7): NSScrollView, NSTextViewDelegate, Coordinator, CustomTextEditor, Context, Coordinator, Notification

## Knowledge Gaps
- **475 isolated node(s):** `.actionTitle`, `airdrop`, `compress`, `convert`, `enhance` (+470 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **37 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SwiftUI` connect `SwiftUI` to `ShelfModule`, `.tint`, `DesignSystem.swift`, `ResponsiveTabContent`, `View`, `TelegramModule`, `Identifiable`, `SkeletonPose`, `MediaRemoteBridge`, `MirrorModule`, `AirDropModule`, `CompanionActivityLevel`, `CompanionBehaviorState`, `VerificationTests.swift`, `ScreenRouteStage`, `NotchRootView.swift`, `CompanionClickPanel`, `NotificationModule`?**
  _High betweenness centrality (0.101) - this node is a cross-community bridge._
- **Why does `SettingsStore` connect `SettingsStore` to `View`, `.saveSecretAsync`, `String`, `.init`, `ClockDialStyle`, `.isModuleEnabled`, `NotchPanel`, `ThockPackMeta`, `SwiftUI`, `DynamicThemeEngine`, `DashboardLayoutFlow`, `.positionProfile`, `.setDashboardSlot`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Why does `NotchModule` connect `ModuleRegistry` to `ShelfModule`, `View`, `TelegramModule`, `ThockModule`, `MirrorModule`, `AirDropModule`, `SwiftUI`, `BatteryModule`, `NotificationModule`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.actionTitle`, `airdrop`, `compress` to the rest of the system?**
  _475 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ShelfModule` be split into smaller, more focused modules?**
  _Cohesion score 0.0512287988923503 - nodes in this community are weakly interconnected._
- **Should `.tint` be split into smaller, more focused modules?**
  _Cohesion score 0.050940438871473356 - nodes in this community are weakly interconnected._