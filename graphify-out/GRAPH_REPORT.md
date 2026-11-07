# Graph Report - Notch  (2026-11-07)

## Corpus Check
- 55 files · ~217,934 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1457 nodes · 3407 edges · 69 communities (52 shown, 17 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 174 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4d89cb54`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ShelfModule
- ModuleRegistry
- Main.swift
- KinematicEngine
- SkeletonPose
- SkeletonPose
- CompanionSkin
- ThockModule
- AirDropModule
- ClockWidgetView
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
- CGFloat
- VerificationTests.swift
- AIProvider
- SettingsCategory
- PermissionsHelper
- Identifiable
- AskAIWidgetView
- NoteStorageManager
- DynamicThemeEngine
- Codable
- NotchCornerStyle
- .isModuleEnabled
- 3. Bugs Found (Grouped by Root Cause) & Resolutions
- TelegramModule.swift
- ScreenRouteStage
- .setDashboardSlot
- .dispatch
- Notch Animated Desktop Companion
- DesignSystem.swift
- CompanionPanel
- measure_telemetry.py
- CompactNotchIndicator
- Notch Cartoon Companion Specifications
- .init
- ThockSubSection
- Creature Analytical IK & Kinematics Fixes
- Companion Rigidity & Settings Lifecycle Analysis
- Package.swift
- run_notch.sh
- security-audit.sh
- SettingsView
- stop_notch.sh
- Crawl Animation Strip
- Hanging Idle Animation Strip
- Clean Hang Animation Strip
- Left-Peek Animation Strip
- Pull-Up Animation Strip
- Standard Walk Cycle Strip
- Right Walk Animation Strip
- Creature Animation Rigidity Analysis
- run-tests.sh

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

## Communities (69 total, 17 thin omitted)

### Community 0 - "ShelfModule"
Cohesion: 0.06
Nodes (51): ByteCountFormatter, CIContext, Int64, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body, FileStudioTool (+43 more)

### Community 1 - "ModuleRegistry"
Cohesion: 0.09
Nodes (26): AnyObject, DropDelegate, NSDragOperation, ScrollViewProxy, ModuleRegistry, .activeModule, .activeModuleId, .isDashboardPinned (+18 more)

### Community 3 - "KinematicEngine"
Cohesion: 0.09
Nodes (22): CompanionPanel, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any, Bool (+14 more)

### Community 4 - "SkeletonPose"
Cohesion: 0.06
Nodes (56): CGContext, Equatable, LimbBones, CompanionProductionPoseChecks, CGFloat, CGPoint, LimbBones, MouthShape (+48 more)

### Community 5 - "SkeletonPose"
Cohesion: 0.06
Nodes (42): CoreGraphics, CGPoint, LimbBones, MouthShape, gasp, neutral, openW, sigh (+34 more)

### Community 6 - "CompanionSkin"
Cohesion: 0.12
Nodes (34): CGAffineTransform, Gradient, GraphicsContext, CompanionSkin, .accentColor, boba, .bodyColor, bubu (+26 more)

### Community 7 - "ThockModule"
Cohesion: 0.06
Nodes (34): AnyCancellable, convention, NSRegularExpression, pid_t, Pipe, Process, AsmrLayerCard, .body (+26 more)

### Community 8 - "AirDropModule"
Cohesion: 0.10
Nodes (18): Error, NSSharingService, NSSharingServiceDelegate, AirDropExpandedView, .body, AirDropModule, AirDropRadarAnimation, .body (+10 more)

### Community 9 - "ClockWidgetView"
Cohesion: 0.18
Nodes (18): AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval, .timeZoneAbbreviation (+10 more)

### Community 10 - "SettingsStore"
Cohesion: 0.05
Nodes (41): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .clockDialStyle, .clockIs24Hour, .clockShowSeconds (+33 more)

### Community 11 - "PasteableTextField"
Cohesion: 0.16
Nodes (11): NSControl, NSObject, NSTextFieldDelegate, NSTextView, Selector, Coordinator, PasteableTextField, Binding (+3 more)

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
Cohesion: 0.16
Nodes (10): AnyView, DateFormatter, URL, TelegramModule, .contactsFileURL, .selectedContact, TelegramModuleExpandedView, .body (+2 more)

### Community 16 - "String"
Cohesion: 0.17
Nodes (10): AskAIService, .currentLoginBadgeText, .hasAnyCloudLogin, .isCurrentProviderAuthenticated, Bool, .oneSpaceView, .twoSpaceView, .aiAssistantCustomizationSection (+2 more)

### Community 17 - ".playClick"
Cohesion: 0.20
Nodes (13): NotesUIState, NotesWidgetView, .charCount, .fourSpaceView, .oneSpaceView, .twoSpaceView, Bool, Int (+5 more)

### Community 18 - "KeychainHelper"
Cohesion: 0.23
Nodes (9): GitHub Security & Sensitive Data Hardening Audit, Hardware-Bound AES-256-GCM Vault Architecture, KeychainHelper, Bool, String, .connectedGoogleEmail, .geminiApiKey, .openAIApiKey (+1 more)

### Community 19 - "SwiftUI"
Cohesion: 0.16
Nodes (6): AppKit, ApplicationServices, Combine, IOKit.ps, SwiftUI, CompanionFrameStripGenerator

### Community 20 - "CompanionBehaviorState"
Cohesion: 0.05
Nodes (33): CFRunLoopSource, ClosedRange, BatteryModule, AnyView, Bool, Int, String, CompanionActivityLevel (+25 more)

### Community 21 - "DesignSystem"
Cohesion: 0.14
Nodes (13): .footerBar, DesignSystem, .accentColor, .canvasColor, .cardFill, .currentTheme, .defaultHoverCollapseDelay, .reduceMotion (+5 more)

### Community 22 - "MediaRemoteBridge"
Cohesion: 0.07
Nodes (34): MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction, MRMediaRemoteSendCommandFunction, Sendable (+26 more)

### Community 23 - "MirrorModule"
Cohesion: 0.05
Nodes (33): AVCaptureSession, AVCaptureVideoPreviewLayer, NSCoder, NSScrollView, NSTextViewDelegate, NSView, NSViewRepresentable, NSVisualEffectView (+25 more)

### Community 24 - "NotchShellCoordinator"
Cohesion: 0.05
Nodes (42): Animation, Content, NSApplicationDelegate, NSMenu, NSStatusItem, NSTrackingArea, NSWindowDelegate, SettingsStore (+34 more)

### Community 25 - ".init"
Cohesion: 0.16
Nodes (12): NSHostingView, NSPanel, CompanionClickPanel, CompanionPanel, CreatureClickTargetView, .body, CreatureContainerView, .body (+4 more)

### Community 26 - "View"
Cohesion: 0.07
Nodes (40): Configuration, ObservableObject, DashboardWidgetType, askAI, calendar, clock, .icon, .id (+32 more)

### Community 27 - "NotificationModule"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 28 - "CGFloat"
Cohesion: 0.23
Nodes (11): LinearGradient, Shape, CustomNotchShape, .cardGradient, LiveEqualizerIndicator, .body, NotchGlassBackground, .body (+3 more)

### Community 29 - "VerificationTests.swift"
Cohesion: 0.18
Nodes (8): AVFoundation, CoreImage, CryptoKit, Foundation, IOKit, PDFKit, Security, TestOutputAccumulator

### Community 30 - "AIProvider"
Cohesion: 0.14
Nodes (17): AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id, .shortName (+9 more)

### Community 31 - "SettingsCategory"
Cohesion: 0.12
Nodes (16): SettingsCategory, appearance, companion, dashboard, feedback, geometry, .icon, .id (+8 more)

### Community 32 - "PermissionsHelper"
Cohesion: 0.18
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 33 - "Identifiable"
Cohesion: 0.15
Nodes (13): Identifiable, ClockDialStyle, analog, digital, .id, .title, DashboardLayoutFlow, adaptiveAuto (+5 more)

### Community 34 - "AskAIWidgetView"
Cohesion: 0.16
Nodes (11): AskAIWidgetUIState, AskAIWidgetView, .body, .fourSpaceView, Bool, Int, Never, String (+3 more)

### Community 35 - "NoteStorageManager"
Cohesion: 0.16
Nodes (12): NoteStorageManager, .storageURL, .text, Bool, Never, NSObjectProtocol, String, Task (+4 more)

### Community 36 - "DynamicThemeEngine"
Cohesion: 0.22
Nodes (8): .dynamicVibrancy, DynamicThemeEngine, CGRect, NSImage, NSObjectProtocol, Path, Set, URL

### Community 37 - "Codable"
Cohesion: 0.38
Nodes (6): Codable, Hashable, ChatContact, ChatMessage, String, UUID

### Community 38 - "NotchCornerStyle"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 40 - "3. Bugs Found (Grouped by Root Cause) & Resolutions"
Cohesion: 0.15
Nodes (12): 1. Skill & Auditor Execution Table, 2. Before & After Telemetry Across All Scenarios, 3. Bugs Found (Grouped by Root Cause) & Resolutions, 4. Ground-Truth Documentation Updates, 5. Items Left Open & Manual Verification Checklist, Category 1: Energy Leaks & Unnecessary Background Work, Category 2: Settings Toggles That Did Not Function as Advertised, Category 3: Concurrency, Task Lifecycles & Hardware Teardown (+4 more)

### Community 41 - "TelegramModule.swift"
Cohesion: 0.21
Nodes (6): NSTextField, ContactSafetyValidator, CustomPasteableNSTextField, Bool, Context, NSEvent

### Community 42 - "ScreenRouteStage"
Cohesion: 0.22
Nodes (9): ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang, monkeyBarTraversal, rightWalk (+1 more)

### Community 43 - ".setDashboardSlot"
Cohesion: 0.33
Nodes (3): .dashboardSlots, .widgetSpans, Int

### Community 44 - ".dispatch"
Cohesion: 0.48
Nodes (4): DirectMessenger, .isAccessibilityGranted, MainActor, Sendable

### Community 45 - "Notch Animated Desktop Companion"
Cohesion: 0.29
Nodes (7): Comprehensive Codebase Analysis Report, Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 46 - "DesignSystem.swift"
Cohesion: 0.19
Nodes (12): ImageIO, ButtonStyle, .spring, MotionPhysicsStyle, appleFluid, .damping, gentle, .id (+4 more)

### Community 47 - "CompanionPanel"
Cohesion: 0.33
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

### Community 51 - ".init"
Cohesion: 0.11
Nodes (19): CaseIterable, CGFloat, CalendarSubsection, calendar, .id, schedule, DynamicVibrancy, balanced (+11 more)

### Community 53 - "ThockSubSection"
Cohesion: 0.33
Nodes (6): ThockSubSection, asmr, .icon, .id, keySound, terminal

### Community 59 - "SettingsView"
Cohesion: 0.31
Nodes (7): SettingsView, .appearanceSection, .companionSection, .detailHeaderBar, .feedbackSection, .geometrySection, .motionSection

## Knowledge Gaps
- **372 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned`, `.themeColor`, `nowPlaying` (+367 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `View` to `ShelfModule`, `ModuleRegistry`, `AskAIWidgetView`, `CompanionSkin`, `ThockModule`, `AirDropModule`, `ClockWidgetView`, `SettingsView`, `CalendarModule`, `TelegramModule`, `.playClick`, `CompactNotchIndicator`, `MediaRemoteBridge`, `MirrorModule`, `.init`, `NotificationModule`, `CGFloat`, `SettingsCategory`?**
  _High betweenness centrality (0.115) - this node is a cross-community bridge._
- **Why does `SettingsStore` connect `SettingsStore` to `Identifiable`, `DynamicThemeEngine`, `CompanionSkin`, `.isModuleEnabled`, `NotchCornerStyle`, `.setDashboardSlot`, `CompactIndicatorStyle`, `AppTheme`, `DesignSystem.swift`, `String`, `KeychainHelper`, `SwiftUI`, `.init`, `CompanionBehaviorState`, `View`, `AIProvider`?**
  _High betweenness centrality (0.103) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `SwiftUI` to `ShelfModule`, `SkeletonPose`, `AirDropModule`, `ClockWidgetView`, `TelegramModule.swift`, `CalendarModule`, `DesignSystem.swift`, `CompanionBehaviorState`, `MediaRemoteBridge`, `MirrorModule`, `.init`, `View`, `NotificationModule`, `VerificationTests.swift`, `SettingsCategory`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ThockModule` (e.g. with `.keySoundSectionView` and `.terminalSectionView`) actually correct?**
  _`ThockModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned` to the rest of the system?**
  _372 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ShelfModule` be split into smaller, more focused modules?**
  _Cohesion score 0.0568986568986569 - nodes in this community are weakly interconnected._