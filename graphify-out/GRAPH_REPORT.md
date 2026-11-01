# Graph Report - Notch  (2026-11-01)

## Corpus Check
- Corpus is ~40,770 words - fits in a single context window. You may not need a graph.

## Summary
- 779 nodes · 1751 edges · 30 communities (27 shown, 3 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 107 edges (avg confidence: 0.82)
- Token cost: 1,200 input · 450 output

## Community Hubs (Navigation)
- Process & Script Subprocesses
- Document Studio & PDF Compression
- Contact Safety & Chat Models
- Liquid Retina Glass & Shapes
- Apple Framework Imports
- AirDrop Radar & Drag Drop
- MediaRemote Playback Engine
- Notchify Core Architecture
- Mirror Camera Preview Layer
- App Lifecycle & Status Item
- Calendar Event System
- Persistent Settings Store
- Notch Shell Coordinator
- System Notifications Manager
- Now Playing Dashboard Card
- Notch Floating Window Panel
- Settings Preferences UI
- Battery Telemetry Monitor
- Calendar Navigation Subsections
- Mouse Hover Tracking Area
- Hardware Notch Geometry Sizing
- Compact Status Indicators
- Dynamic Vibrancy Profiles
- Glass Material Aesthetics
- Apple Spring Physics
- Liquid Retina Corner Radii
- Module Registry Management
- SPM Package Configuration
- Release Runner Automation
- Process Lifecycle Scripts

## God Nodes (most connected - your core abstractions)
1. `ThockModule` - 72 edges
2. `ShelfModule` - 51 edges
3. `AppTheme` - 44 edges
4. `SettingsStore` - 39 edges
5. `DesignSystem` - 38 edges
6. `ModuleRegistry` - 29 edges
7. `NotchModule` - 28 edges
8. `MediaRemoteBridge` - 27 edges
9. `TelegramModule` - 26 edges
10. `ShelfItem` - 24 edges

## Surprising Connections (you probably didn't know these)
- `Dynamic Wallpaper Glass (60/30/10 Rule)` --implements--> `AppTheme`  [INFERRED]
  README.md → Sources/UI/DesignSystem.swift
- `.activeModule` --references--> `NotchModule`  [INFERRED]
  Sources/Core/ModuleRegistry.swift → Sources/Core/NotchModule.swift
- `.contentArea` --calls--> `CalendarHomeCardView`  [INFERRED]
  Sources/Notch/NotchRootView.swift → Sources/Modules/Calendar/CalendarModule.swift
- `.contentArea` --calls--> `NowPlayingHomeCardView`  [INFERRED]
  Sources/Notch/NotchRootView.swift → Sources/Modules/NowPlaying/NowPlayingModule.swift
- `.body` --calls--> `LiveEqualizerIndicator`  [INFERRED]
  Sources/Modules/NowPlaying/NowPlayingModule.swift → Sources/UI/DesignSystem.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Notchify Core Feature Suite** — readme_jog_wheel, readme_airdrop, readme_now_playing, readme_calendar, readme_messaging [EXTRACTED 1.00]

## Communities (30 total, 3 thin omitted)

### Community 0 - "Process & Script Subprocesses"
Cohesion: 0.05
Nodes (42): convention, NSRegularExpression, Pipe, Process, PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL (+34 more)

### Community 1 - "Document Studio & PDF Compression"
Cohesion: 0.06
Nodes (52): ByteCountFormatter, CIContext, Int64, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body, FileStudioTool (+44 more)

### Community 2 - "Contact Safety & Chat Models"
Cohesion: 0.07
Nodes (34): Codable, DateFormatter, Hashable, Identifiable, NSControl, NSTextField, NSTextFieldDelegate, NSTextView (+26 more)

### Community 3 - "Liquid Retina Glass & Shapes"
Cohesion: 0.06
Nodes (44): Configuration, LinearGradient, NSObjectProtocol, Path, Shape, .dynamicVibrancy, .body, SettingsView (+36 more)

### Community 4 - "Apple Framework Imports"
Cohesion: 0.05
Nodes (37): AppKit, ApplicationServices, AVFoundation, Combine, CoreImage, Error, Foundation, ImageIO (+29 more)

### Community 5 - "AirDrop Radar & Drag Drop"
Cohesion: 0.10
Nodes (24): AnyObject, DropDelegate, NSDragOperation, ObservableObject, ScrollViewProxy, ModuleRegistry, .activeModule, .activeModuleId (+16 more)

### Community 6 - "MediaRemote Playback Engine"
Cohesion: 0.09
Nodes (21): AVCaptureSession, Equatable, MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction (+13 more)

### Community 7 - "Notchify Core Architecture"
Cohesion: 0.05
Nodes (38): Instant AirDrop Express Radar, Dynamic Wallpaper Glass (60/30/10 Rule), Radial Document Studio (Jog Wheel), Direct Zero-Interruption Messaging, Notchify Command Center, AppTheme, .accentColor, activeApp (+30 more)

### Community 8 - "Mirror Camera Preview Layer"
Cohesion: 0.09
Nodes (18): AVCaptureVideoPreviewLayer, NSCoder, NSView, NSViewRepresentable, NSVisualEffectView, CameraHostingNSView, CameraLivePreview, MirrorContainerView (+10 more)

### Community 9 - "App Lifecycle & Status Item"
Cohesion: 0.09
Nodes (14): NSApplicationDelegate, NSHostingView, NSMenu, NSStatusItem, NSWindowDelegate, Selector, AppDelegate, .sharedDelegate (+6 more)

### Community 10 - "Calendar Event System"
Cohesion: 0.16
Nodes (14): EventKit, Adaptive Calendar, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body, .monthYearTitle (+6 more)

### Community 11 - "Persistent Settings Store"
Cohesion: 0.09
Nodes (22): SettingsStore, .autoCollapseDelay, .closeOnEsc, .closeOnOutsideClick, .compactIndicatorStyle, .contentHorizontalPadding, .contentVerticalPadding, .cornerStyle (+14 more)

### Community 12 - "Notch Shell Coordinator"
Cohesion: 0.26
Nodes (9): Animation, .body, .expandedHeaderTabs, NotchShellCoordinator, .state, .transitionAnimation, Bool, DispatchWorkItem (+1 more)

### Community 13 - "System Notifications Manager"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 14 - "Now Playing Dashboard Card"
Cohesion: 0.21
Nodes (10): NowPlayingHomeCardView, .body, NowPlayingModule, .progress, Bool, Date, DispatchWorkItem, Double (+2 more)

### Community 15 - "Notch Floating Window Panel"
Cohesion: 0.17
Nodes (12): NSPanel, NotchState, collapsed, expanded, NotchPanel, .canBecomeKey, .canBecomeMain, .isolated (+4 more)

### Community 16 - "Settings Preferences UI"
Cohesion: 0.17
Nodes (12): SettingsCategory, appearance, feedback, geometry, .icon, .id, modules, motion (+4 more)

### Community 17 - "Battery Telemetry Monitor"
Cohesion: 0.24
Nodes (6): BatteryModule, AnyCancellable, AnyView, Bool, Int, String

### Community 18 - "Calendar Navigation Subsections"
Cohesion: 0.18
Nodes (11): CaseIterable, CalendarSubsection, calendar, .id, schedule, ThockSubSection, asmr, .icon (+3 more)

### Community 19 - "Mouse Hover Tracking Area"
Cohesion: 0.31
Nodes (4): Content, NSTrackingArea, NotchHostingView, NSEvent

### Community 20 - "Hardware Notch Geometry Sizing"
Cohesion: 0.28
Nodes (6): NotchGeometry, Bool, CGFloat, CGRect, NSScreen, .geometrySection

### Community 21 - "Compact Status Indicators"
Cohesion: 0.22
Nodes (9): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+1 more)

### Community 22 - "Dynamic Vibrancy Profiles"
Cohesion: 0.25
Nodes (7): CGFloat, DynamicVibrancy, balanced, .factor, .id, punchy, subtle

### Community 23 - "Glass Material Aesthetics"
Cohesion: 0.29
Nodes (7): GlassMaterialStyle, crystal, deepOLED, frosted, .id, luminous, .subtitle

### Community 24 - "Apple Spring Physics"
Cohesion: 0.29
Nodes (7): MotionPhysicsStyle, appleFluid, .damping, gentle, .id, .response, snappy

### Community 25 - "Liquid Retina Corner Radii"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 26 - "Module Registry Management"
Cohesion: 0.60
Nodes (3): .enabledModules, Bool, String

## Knowledge Gaps
- **164 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `.themeColor`, `.notchWidth`, `.notchHeight` (+159 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NotchModule` connect `AirDrop Radar & Drag Drop` to `Process & Script Subprocesses`, `Document Studio & PDF Compression`, `Contact Safety & Chat Models`, `Apple Framework Imports`, `Mirror Camera Preview Layer`, `System Notifications Manager`, `Battery Telemetry Monitor`?**
  _High betweenness centrality (0.148) - this node is a cross-community bridge._
- **Why does `ThockModule` connect `Process & Script Subprocesses` to `App Lifecycle & Status Item`, `Calendar Navigation Subsections`, `Apple Framework Imports`, `AirDrop Radar & Drag Drop`?**
  _High betweenness centrality (0.126) - this node is a cross-community bridge._
- **Why does `AppTheme` connect `Notchify Core Architecture` to `Process & Script Subprocesses`, `Contact Safety & Chat Models`, `Liquid Retina Glass & Shapes`, `Persistent Settings Store`, `Calendar Navigation Subsections`, `Dynamic Vibrancy Profiles`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ThockModule` (e.g. with `.keySoundSectionView` and `.terminalSectionView`) actually correct?**
  _`ThockModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `.themeColor` to the rest of the system?**
  _164 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Process & Script Subprocesses` be split into smaller, more focused modules?**
  _Cohesion score 0.050615901455767075 - nodes in this community are weakly interconnected._