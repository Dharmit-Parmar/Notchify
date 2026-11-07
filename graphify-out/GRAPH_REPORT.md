# Graph Report - Notch  (2026-11-07)

## Corpus Check
- 54 files · ~214,833 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1454 nodes · 3400 edges · 66 communities (46 shown, 20 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 174 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `19d86a4e`
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
- View
- SettingsStore
- CustomTextEditor
- .init
- Identifiable
- AppTheme
- TelegramModule
- String
- NotesWidgetView
- KeychainHelper
- SwiftUI
- CompanionBehaviorState
- DesignSystem
- NowPlayingModule
- MediaRemoteBridge
- NotchShellCoordinator
- .init
- DashboardWidgetType
- NotificationModule
- CGFloat
- .init
- AIProvider
- SettingsCategory
- PermissionsHelper
- DashboardLayoutFlow
- .playClick
- NoteStorageManager
- DynamicThemeEngine
- ThockPackMeta
- NotchCornerStyle
- .isModuleEnabled
- 2. Bugs Found (Grouped by Root Cause) & Resolutions
- .sendCommand
- NotchPanel
- Notch Animated Desktop Companion
- DesignSystem.swift
- Notch Cartoon Companion Specifications
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
- .startEngine
- ThockExpandedView
- .keySoundSectionView
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

## Communities (66 total, 20 thin omitted)

### Community 0 - "ShelfModule"
Cohesion: 0.06
Nodes (52): ByteCountFormatter, CIContext, Int64, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body, FileStudioTool (+44 more)

### Community 1 - "ModuleRegistry"
Cohesion: 0.05
Nodes (48): AnyObject, DropDelegate, NSDragOperation, ObservableObject, ScrollViewProxy, ModuleRegistry, .activeModule, .activeModuleId (+40 more)

### Community 2 - "AppDelegate"
Cohesion: 0.11
Nodes (12): NSApplicationDelegate, NSMenu, NSStatusItem, NSWindowDelegate, Selector, AppDelegate, .sharedDelegate, Bool (+4 more)

### Community 3 - "KinematicEngine"
Cohesion: 0.09
Nodes (22): CompanionPanel, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any, Bool (+14 more)

### Community 4 - "SkeletonPose"
Cohesion: 0.07
Nodes (52): CGContext, CGPoint, LimbBones, MouthShape, gasp, neutral, openW, sigh (+44 more)

### Community 5 - "SkeletonPose"
Cohesion: 0.05
Nodes (52): CoreGraphics, Equatable, ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang (+44 more)

### Community 6 - "CompanionSkin"
Cohesion: 0.12
Nodes (34): CGAffineTransform, Gradient, GraphicsContext, CompanionSkin, .accentColor, boba, .bodyColor, bubu (+26 more)

### Community 7 - "ThockModule"
Cohesion: 0.10
Nodes (18): AnyCancellable, convention, NSRegularExpression, pid_t, Int32, Set, URL, ThockModule (+10 more)

### Community 8 - "AirDropModule"
Cohesion: 0.11
Nodes (17): Error, NSSharingService, NSSharingServiceDelegate, AirDropExpandedView, .body, AirDropModule, AirDropRadarAnimation, .body (+9 more)

### Community 9 - "View"
Cohesion: 0.12
Nodes (23): Configuration, AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval (+15 more)

### Community 10 - "SettingsStore"
Cohesion: 0.05
Nodes (41): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .clockDialStyle, .clockIs24Hour, .clockShowSeconds (+33 more)

### Community 11 - "CustomTextEditor"
Cohesion: 0.14
Nodes (12): NSScrollView, NSTextViewDelegate, NSViewRepresentable, NSVisualEffectView, Coordinator, CustomTextEditor, Context, Coordinator (+4 more)

### Community 12 - ".init"
Cohesion: 0.06
Nodes (33): CaseIterable, ClockDialStyle, analog, digital, .id, .title, CGFloat, CalendarSubsection (+25 more)

### Community 13 - "Identifiable"
Cohesion: 0.09
Nodes (29): EventKit, Identifiable, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView (+21 more)

### Community 14 - "AppTheme"
Cohesion: 0.06
Nodes (33): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+25 more)

### Community 15 - "TelegramModule"
Cohesion: 0.06
Nodes (36): Codable, Hashable, NSControl, NSObject, NSTextField, NSTextFieldDelegate, NSTextView, ChatContact (+28 more)

### Community 16 - "String"
Cohesion: 0.24
Nodes (6): AskAIService, .currentLoginBadgeText, .hasAnyCloudLogin, .isCurrentProviderAuthenticated, Bool, String

### Community 17 - "NotesWidgetView"
Cohesion: 0.18
Nodes (14): NotesUIState, .selectedProvider, NotesWidgetView, .charCount, .fourSpaceView, .oneSpaceView, .twoSpaceView, Bool (+6 more)

### Community 18 - "KeychainHelper"
Cohesion: 0.23
Nodes (9): GitHub Security & Sensitive Data Hardening Audit, Hardware-Bound AES-256-GCM Vault Architecture, KeychainHelper, Bool, String, .connectedGoogleEmail, .geminiApiKey, .openAIApiKey (+1 more)

### Community 19 - "SwiftUI"
Cohesion: 0.05
Nodes (33): AppKit, ApplicationServices, AVFoundation, Combine, CoreImage, CryptoKit, Foundation, IOKit (+25 more)

### Community 20 - "CompanionBehaviorState"
Cohesion: 0.05
Nodes (33): CFRunLoopSource, ClosedRange, BatteryModule, AnyView, Bool, Int, String, CompanionActivityLevel (+25 more)

### Community 21 - "DesignSystem"
Cohesion: 0.10
Nodes (21): LinearGradient, SettingsView, .companionSection, .detailHeaderBar, .footerBar, .motionSection, .sidebarNavigation, DesignSystem (+13 more)

### Community 22 - "NowPlayingModule"
Cohesion: 0.14
Nodes (16): NowPlayingAdaptiveWidgetView, .body, NowPlayingCompactTileView, .body, NowPlayingHomeCardView, .body, NowPlayingModule, .progress (+8 more)

### Community 23 - "MediaRemoteBridge"
Cohesion: 0.05
Nodes (39): AVCaptureSession, AVCaptureVideoPreviewLayer, MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction (+31 more)

### Community 24 - "NotchShellCoordinator"
Cohesion: 0.19
Nodes (12): Animation, .body, NotchShellCoordinator, .state, .transitionAnimation, Bool, DispatchWorkItem, NSObjectProtocol (+4 more)

### Community 25 - ".init"
Cohesion: 0.16
Nodes (12): NSHostingView, NSPanel, CompanionClickPanel, CompanionPanel, CreatureClickTargetView, .body, CreatureContainerView, .body (+4 more)

### Community 26 - "DashboardWidgetType"
Cohesion: 0.11
Nodes (16): DashboardWidgetType, askAI, calendar, clock, .icon, .id, mirror, notes (+8 more)

### Community 27 - "NotificationModule"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 28 - "CGFloat"
Cohesion: 0.29
Nodes (8): Shape, CustomNotchShape, LiveEqualizerIndicator, .body, NotchGlassBackground, Bool, CGFloat, Color

### Community 30 - "AIProvider"
Cohesion: 0.14
Nodes (17): AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id, .shortName (+9 more)

### Community 31 - "SettingsCategory"
Cohesion: 0.13
Nodes (15): SettingsCategory, appearance, companion, dashboard, feedback, geometry, .icon, .id (+7 more)

### Community 32 - "PermissionsHelper"
Cohesion: 0.20
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 33 - "DashboardLayoutFlow"
Cohesion: 0.29
Nodes (7): DashboardLayoutFlow, adaptiveAuto, bentoQuad, horizontalStrip, .icon, .id, .title

### Community 34 - ".playClick"
Cohesion: 0.15
Nodes (13): AskAIWidgetUIState, AskAIWidgetView, .body, .fourSpaceView, .oneSpaceView, .twoSpaceView, Bool, Int (+5 more)

### Community 35 - "NoteStorageManager"
Cohesion: 0.16
Nodes (12): NoteStorageManager, .storageURL, .text, Bool, Never, NSObjectProtocol, String, Task (+4 more)

### Community 36 - "DynamicThemeEngine"
Cohesion: 0.20
Nodes (9): .dynamicVibrancy, .appearanceSection, DynamicThemeEngine, CGRect, NSImage, NSObjectProtocol, Path, Set (+1 more)

### Community 37 - "ThockPackMeta"
Cohesion: 0.22
Nodes (7): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id

### Community 38 - "NotchCornerStyle"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 40 - "2. Bugs Found (Grouped by Root Cause) & Resolutions"
Cohesion: 0.13
Nodes (14): 1. Executive Summary, 2. Bugs Found (Grouped by Root Cause) & Resolutions, 3. Before and After Metrics, 4. Verification Evidence, 5. Items Left Open, Category A: Swift Compilation & Test Suite Execution, Category B: Security Vulnerabilities (from `SECURITY_AUDIT_REPORT.md`), Category C: Lifecycle & Memory Management (+6 more)

### Community 44 - "NotchPanel"
Cohesion: 0.19
Nodes (11): SettingsStore, NotchState, collapsed, expanded, NotchPanel, .canBecomeKey, .canBecomeMain, .isolated (+3 more)

### Community 45 - "Notch Animated Desktop Companion"
Cohesion: 0.29
Nodes (7): Comprehensive Codebase Analysis Report, Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 46 - "DesignSystem.swift"
Cohesion: 0.19
Nodes (12): ImageIO, ButtonStyle, .spring, MotionPhysicsStyle, appleFluid, .damping, gentle, .id (+4 more)

### Community 50 - "Notch Cartoon Companion Specifications"
Cohesion: 0.33
Nodes (6): Climb-Over Animation Strip, Monkey-Bar Traversal Animation Strip, Clean Left-Peek Animation Strip, Clean Den Sleep Animation Strip, Clean Right Walk Animation Strip, Notch Cartoon Companion Specifications

### Community 52 - "NotchHostingView"
Cohesion: 0.29
Nodes (4): Content, NSTrackingArea, NotchHostingView, NSEvent

### Community 59 - "NotchGeometry"
Cohesion: 0.28
Nodes (6): NotchGeometry, Bool, CGFloat, CGRect, NSScreen, .geometrySection

### Community 70 - "ThockExpandedView"
Cohesion: 0.33
Nodes (3): AnyView, ThockExpandedView, .terminalSectionView

## Knowledge Gaps
- **374 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned`, `.themeColor`, `nowPlaying` (+369 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **20 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `View` to `ShelfModule`, `ModuleRegistry`, `.playClick`, `ThockPackMeta`, `CompanionSkin`, `ThockExpandedView`, `AirDropModule`, `Identifiable`, `TelegramModule`, `NotesWidgetView`, `SwiftUI`, `DesignSystem`, `NowPlayingModule`, `MediaRemoteBridge`, `.init`, `NotificationModule`, `CGFloat`, `SettingsCategory`?**
  _High betweenness centrality (0.115) - this node is a cross-community bridge._
- **Why does `SettingsStore` connect `SettingsStore` to `ModuleRegistry`, `DashboardLayoutFlow`, `DynamicThemeEngine`, `CompanionSkin`, `.isModuleEnabled`, `NotchCornerStyle`, `.init`, `AppTheme`, `DesignSystem.swift`, `String`, `KeychainHelper`, `SwiftUI`, `CompanionBehaviorState`, `DashboardWidgetType`, `AIProvider`?**
  _High betweenness centrality (0.103) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `SwiftUI` to `ShelfModule`, `ModuleRegistry`, `.playClick`, `SkeletonPose`, `AirDropModule`, `View`, `Identifiable`, `DesignSystem.swift`, `TelegramModule`, `NotesWidgetView`, `CompanionBehaviorState`, `NotchHostingView`, `NowPlayingModule`, `MediaRemoteBridge`, `.init`, `NotificationModule`, `SettingsCategory`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ThockModule` (e.g. with `.keySoundSectionView` and `.terminalSectionView`) actually correct?**
  _`ThockModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `.isDashboardPinned` to the rest of the system?**
  _374 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ShelfModule` be split into smaller, more focused modules?**
  _Cohesion score 0.05613951266125179 - nodes in this community are weakly interconnected._