# Graph Report - Notch  (2026-11-01)

## Corpus Check
- 105 files · ~62,000 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1276 nodes · 2967 edges · 50 communities (44 shown, 6 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 200 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49

## God Nodes (most connected - your core abstractions)
1. `ThockModule` - 72 edges
2. `SettingsStore` - 67 edges
3. `ShelfModule` - 51 edges
4. `DesignSystem` - 44 edges
5. `AppTheme` - 43 edges
6. `KinematicEngine` - 37 edges
7. `DashboardWidgetType` - 36 edges
8. `SkeletonPose` - 32 edges
9. `ModuleRegistry` - 31 edges
10. `CompanionCoordinator` - 31 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `CreatureRigView`  [INFERRED]
  Sources/Modules/Companion/CompanionWindow.swift → Sources/Modules/Companion/CreatureRigView.swift
- `Notch Animated Desktop Companion` --conceptually_related_to--> `Notchify macOS System Hub`  [INFERRED]
  NOTCH_CREATURE_MVP.md → README.md
- `ResultantPDFPreviewCard` --calls--> `LocalUIState`  [INFERRED]
  Sources/Modules/Shelf/ShelfModule.swift → Sources/UI/DesignSystem.swift
- `StagedFileChip` --calls--> `LocalUIState`  [INFERRED]
  Sources/Modules/Shelf/ShelfModule.swift → Sources/UI/DesignSystem.swift
- `.body` --references--> `SettingsStore`  [INFERRED]
  Sources/Settings/DashboardSettingsView.swift → Sources/Core/NotchModule.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Notch Ambient Companion Architecture** — notch_creature_mvp_companion, notch_creature_mvp_state_machine, notch_creature_mvp_vector_engine, notch_creature_mvp_privacy_invariants [EXTRACTED 1.00]

## Communities (50 total, 6 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (50): ByteCountFormatter, CIContext, Int64, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body, FileStudioTool (+42 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (56): DashboardWidgetType, calendar, clock, .icon, .id, mirror, notes, nowPlaying (+48 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (43): Animation, Content, NSApplicationDelegate, NSMenu, NSStatusItem, NSTrackingArea, NSWindowDelegate, Selector (+35 more)

### Community 3 - "Community 3"
Cohesion: 0.05
Nodes (40): AVCaptureSession, AVCaptureVideoPreviewLayer, ImageIO, MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction (+32 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (52): CGContext, CGPoint, LimbBones, MouthShape, gasp, neutral, openW, sigh (+44 more)

### Community 5 - "Community 5"
Cohesion: 0.07
Nodes (33): Hashable, NSControl, NSTextField, NSTextFieldDelegate, NSTextView, ChatContact, ChatMessage, ContactSafetyValidator (+25 more)

### Community 6 - "Community 6"
Cohesion: 0.05
Nodes (51): Equatable, ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang, monkeyBarTraversal (+43 more)

### Community 7 - "Community 7"
Cohesion: 0.09
Nodes (26): AnyObject, DropDelegate, NSDragOperation, ObservableObject, ScrollViewProxy, ModuleRegistry, .activeModule, .activeModuleId (+18 more)

### Community 8 - "Community 8"
Cohesion: 0.11
Nodes (23): NSHostingView, NSPanel, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any (+15 more)

### Community 9 - "Community 9"
Cohesion: 0.11
Nodes (23): CompanionBehaviorState, celebrating, crawling, curious, dangling, inDen, musicGroove, peekingLeft (+15 more)

### Community 10 - "Community 10"
Cohesion: 0.13
Nodes (28): CGAffineTransform, GraphicsContext, MouthShape, Path, CompanionSkin, .accentColor, boba, .bodyColor (+20 more)

### Community 11 - "Community 11"
Cohesion: 0.06
Nodes (38): SettingsStore, .activeDashboardWidgets, .autoCollapseDelay, .clockDialStyle, .clockIs24Hour, .clockShowSeconds, .closeOnEsc, .closeOnOutsideClick (+30 more)

### Community 12 - "Community 12"
Cohesion: 0.09
Nodes (21): AnyCancellable, convention, NSRegularExpression, AnyView, Int32, Set, URL, ThockExpandedView (+13 more)

### Community 13 - "Community 13"
Cohesion: 0.12
Nodes (22): EventKit, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body (+14 more)

### Community 14 - "Community 14"
Cohesion: 0.06
Nodes (33): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+25 more)

### Community 15 - "Community 15"
Cohesion: 0.13
Nodes (18): Never, NoteStorageManager, .text, Bool, String, Void, NotesUIState, NotesWidgetView (+10 more)

### Community 16 - "Community 16"
Cohesion: 0.15
Nodes (15): NowPlayingAdaptiveWidgetView, .body, NowPlayingCompactTileView, .body, NowPlayingHomeCardView, .body, NowPlayingModule, .progress (+7 more)

### Community 17 - "Community 17"
Cohesion: 0.14
Nodes (12): NSScrollView, NSTextViewDelegate, NSViewRepresentable, NSVisualEffectView, Coordinator, CustomTextEditor, Context, Coordinator (+4 more)

### Community 18 - "Community 18"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 19 - "Community 19"
Cohesion: 0.12
Nodes (19): CaseIterable, Identifiable, CalendarSubsection, calendar, .id, schedule, ThockSubSection, asmr (+11 more)

### Community 20 - "Community 20"
Cohesion: 0.11
Nodes (18): 1. What We Are Trying to Achieve (Vision & Purpose), 2.1 Passive Contextual Observation, 2.2 User Direct Interactions, 2. Usage & Behavior Models (How & When it Operates), 3. Engineering Goals & Performance Budgets, 4.1 Two-Bone Analytical Inverse Kinematics (IK), 4.2 Inverted Pendulum Bipedal Walk, 4.3 Hand-Over-Hand Monkey-Bar Traversal (+10 more)

### Community 21 - "Community 21"
Cohesion: 0.23
Nodes (5): AppKit, ApplicationServices, Combine, IOKit.ps, SwiftUI

### Community 22 - "Community 22"
Cohesion: 0.14
Nodes (16): LinearGradient, .body, DesignSystem, .accentColor, .canvasColor, .cardFill, .cardGradient, .currentTheme (+8 more)

### Community 24 - "Community 24"
Cohesion: 0.13
Nodes (15): SettingsCategory, appearance, companion, dashboard, feedback, geometry, .icon, .id (+7 more)

### Community 25 - "Community 25"
Cohesion: 0.14
Nodes (14): Codable, ClockDialStyle, analog, digital, .id, .title, DashboardLayoutFlow, adaptiveAuto (+6 more)

### Community 26 - "Community 26"
Cohesion: 0.20
Nodes (7): NSSharingService, AirDropExpandedView, .body, AirDropModule, AnyView, String, URL

### Community 27 - "Community 27"
Cohesion: 0.20
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 28 - "Community 28"
Cohesion: 0.29
Nodes (8): Shape, CustomNotchShape, LiveEqualizerIndicator, .body, NotchGlassBackground, Bool, CGFloat, Color

### Community 29 - "Community 29"
Cohesion: 0.17
Nodes (12): Collectible Character Skins, Companion Auxiliary Click Panel, Curious Hover Behavior, Den Rest Behavior (0% CPU), Full-Screen Transparent Overlay Window, Inverted Pendulum Walk Gait, Monkey-Bar Traversal Motion, Music Groove Behavior (+4 more)

### Community 30 - "Community 30"
Cohesion: 0.24
Nodes (6): CFRunLoopSource, BatteryModule, AnyView, Bool, Int, String

### Community 31 - "Community 31"
Cohesion: 0.24
Nodes (7): NSObjectProtocol, .dynamicVibrancy, DynamicThemeEngine, CGRect, NSImage, Set, URL

### Community 32 - "Community 32"
Cohesion: 0.18
Nodes (8): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id, .body

### Community 33 - "Community 33"
Cohesion: 0.18
Nodes (10): ClosedRange, CompanionActivityLevel, balanced, calm, .description, .displayName, .id, .intervalRange (+2 more)

### Community 34 - "Community 34"
Cohesion: 0.24
Nodes (6): SettingsView, .appearanceSection, .detailHeaderBar, .footerBar, .motionSection, .sidebarNavigation

### Community 35 - "Community 35"
Cohesion: 0.20
Nodes (9): CompactNotchIndicator, .batteryIndicator, .body, .circadianIndicator, .dateTimeIndicator, .mediaIndicator, .minimalIndicator, CGFloat (+1 more)

### Community 36 - "Community 36"
Cohesion: 0.24
Nodes (8): DynamicVibrancy, balanced, .factor, .id, punchy, subtle, LocalUIState, String

### Community 37 - "Community 37"
Cohesion: 0.22
Nodes (5): AVFoundation, CoreGraphics, CoreImage, Foundation, PDFKit

### Community 38 - "Community 38"
Cohesion: 0.22
Nodes (9): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+1 more)

### Community 39 - "Community 39"
Cohesion: 0.38
Nodes (5): Configuration, ButtonStyle, .spring, SpringButtonStyle, Double

### Community 40 - "Community 40"
Cohesion: 0.29
Nodes (6): NSObject, NSSharingServiceDelegate, AirDropRadarAnimation, .body, AirDropSharingDelegate, Bool

### Community 43 - "Community 43"
Cohesion: 0.29
Nodes (7): GlassMaterialStyle, crystal, deepOLED, frosted, .id, luminous, .subtitle

### Community 44 - "Community 44"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 45 - "Community 45"
Cohesion: 0.33
Nodes (5): Error, Any, NSRect, NSWindow, UnsafeMutablePointer

### Community 46 - "Community 46"
Cohesion: 0.33
Nodes (6): Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

## Knowledge Gaps
- **335 isolated node(s):** `.actionTitle`, `airdrop`, `compress`, `convert`, `enhance` (+330 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `Community 1` to `Community 0`, `Community 3`, `Community 5`, `Community 7`, `Community 8`, `Community 10`, `Community 12`, `Community 13`, `Community 15`, `Community 16`, `Community 18`, `Community 24`, `Community 26`, `Community 28`, `Community 32`, `Community 34`, `Community 35`, `Community 39`, `Community 40`?**
  _High betweenness centrality (0.112) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Community 21` to `Community 0`, `Community 1`, `Community 33`, `Community 3`, `Community 35`, `Community 37`, `Community 6`, `Community 5`, `Community 40`, `Community 36`, `Community 13`, `Community 16`, `Community 18`, `Community 24`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Why does `AppTheme` connect `Community 14` to `Community 36`, `Community 11`, `Community 19`, `Community 22`, `Community 25`, `Community 28`?**
  _High betweenness centrality (0.088) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ThockModule` (e.g. with `.keySoundSectionView` and `.terminalSectionView`) actually correct?**
  _`ThockModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.actionTitle`, `airdrop`, `compress` to the rest of the system?**
  _335 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.057967313585291114 - nodes in this community are weakly interconnected._