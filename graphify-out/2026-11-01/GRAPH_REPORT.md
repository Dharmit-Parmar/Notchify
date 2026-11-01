# Graph Report - Notch  (2026-11-01)

## Corpus Check
- 32 files · ~52,793 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 961 nodes · 2231 edges · 49 communities (43 shown, 6 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 141 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- File Studio & PDF Engine
- Telegram Direct Bot & Messaging
- Modular Bento Dashboard & Settings
- Mirror Camera Live Preview
- Mirror Camera Live Preview
- Notes Scratchpad & Debounce Storage
- System Permissions & Finder Drag
- System Permissions & Finder Drag
- Interactive Calendar & Agenda
- Liquid Retina Glass & Dynamic Theme
- Notes Scratchpad & Debounce Storage
- Notes Scratchpad & Debounce Storage
- Clock Chronometer & Zero-Allocation Cache
- File Studio & PDF Engine
- MediaRemote Audio & Video Bridge
- Modular Bento Dashboard & Settings
- Clock Chronometer & Zero-Allocation Cache
- Sources Modules
- Modular Bento Dashboard & Settings
- Notes Scratchpad & Debounce Storage
- Thock Mechanical Audio Engine
- Thock Mechanical Audio Engine
- Liquid Retina Glass & Dynamic Theme
- Modular Bento Dashboard & Settings
- Battery & Power RunLoop Source
- Notch Geometry & Window Coordinator
- Modular Bento Dashboard & Settings
- Notch Geometry & Window Coordinator
- Notch Geometry & Window Coordinator
- Liquid Retina Glass & Dynamic Theme
- Liquid Retina Glass & Dynamic Theme
- Battery & Power RunLoop Source
- Modular Bento Dashboard & Settings
- Thock Mechanical Audio Engine
- Modular Bento Dashboard & Settings
- Modular Bento Dashboard & Settings
- System Permissions & Finder Drag
- Sources Notch
- Liquid Retina Glass & Dynamic Theme
- Liquid Retina Glass & Dynamic Theme
- Telegram Direct Bot & Messaging
- Clock Chronometer & Zero-Allocation Cache
- Modular Bento Dashboard & Settings
- AirDrop Direct Sharing Service
- Thock Mechanical Audio Engine
- Interactive Calendar & Agenda
- Package
- Notch
- Stop Notch

## God Nodes (most connected - your core abstractions)
1. `ThockModule` - 72 edges
2. `SettingsStore` - 57 edges
3. `ShelfModule` - 51 edges
4. `AppTheme` - 43 edges
5. `DesignSystem` - 43 edges
6. `DashboardWidgetType` - 36 edges
7. `ModuleRegistry` - 31 edges
8. `NotchModule` - 29 edges
9. `MediaRemoteBridge` - 27 edges
10. `TelegramModule` - 26 edges

## Surprising Connections (you probably didn't know these)
- `Notch Animated Desktop Companion` --conceptually_related_to--> `Notchify macOS System Hub`  [INFERRED]
  NOTCH_CREATURE_MVP.md → README.md
- `.activeModule` --references--> `NotchModule`  [INFERRED]
  Sources/Core/ModuleRegistry.swift → Sources/Core/NotchModule.swift
- `.body` --references--> `DashboardWidgetType`  [INFERRED]
  Sources/Settings/DashboardSettingsView.swift → Sources/Core/NotchModule.swift
- `.body` --references--> `SettingsStore`  [INFERRED]
  Sources/Settings/DashboardSettingsView.swift → Sources/Core/NotchModule.swift
- `.wordCount` --references--> `NoteStorageManager`  [INFERRED]
  Sources/Modules/Notes/NotesWidgetView.swift → Sources/Modules/Notes/NoteStorageManager.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Notch Ambient Companion Architecture** — notch_creature_mvp_companion, notch_creature_mvp_state_machine, notch_creature_mvp_vector_engine, notch_creature_mvp_privacy_invariants [EXTRACTED 1.00]

## Communities (49 total, 6 thin omitted)

### Community 0 - "File Studio & PDF Engine"
Cohesion: 0.06
Nodes (51): ByteCountFormatter, CIContext, Int64, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body, FileStudioTool (+43 more)

### Community 1 - "Telegram Direct Bot & Messaging"
Cohesion: 0.07
Nodes (34): Codable, Hashable, NSControl, NSTextField, NSTextFieldDelegate, NSTextView, ChatContact, ChatMessage (+26 more)

### Community 2 - "Modular Bento Dashboard & Settings"
Cohesion: 0.09
Nodes (25): AnyObject, DropDelegate, NSDragOperation, ScrollViewProxy, ModuleRegistry, .activeModule, .activeModuleId, .orderedModules (+17 more)

### Community 3 - "Mirror Camera Live Preview"
Cohesion: 0.08
Nodes (23): AVCaptureVideoPreviewLayer, NSCoder, NSView, NSViewRepresentable, NSVisualEffectView, CameraHostingNSView, CameraLivePreview, MirrorAdaptiveWidgetView (+15 more)

### Community 4 - "Mirror Camera Live Preview"
Cohesion: 0.09
Nodes (22): AVCaptureSession, Equatable, MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction (+14 more)

### Community 5 - "Notes Scratchpad & Debounce Storage"
Cohesion: 0.07
Nodes (24): Error, NSObject, NSScrollView, NSSharingService, NSSharingServiceDelegate, NSTextViewDelegate, AirDropExpandedView, .body (+16 more)

### Community 6 - "System Permissions & Finder Drag"
Cohesion: 0.07
Nodes (29): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, SettingsCategory (+21 more)

### Community 7 - "System Permissions & Finder Drag"
Cohesion: 0.09
Nodes (21): AnyCancellable, convention, NSRegularExpression, AnyView, Int32, Set, URL, ThockExpandedView (+13 more)

### Community 8 - "Interactive Calendar & Agenda"
Cohesion: 0.12
Nodes (22): EventKit, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body (+14 more)

### Community 9 - "Liquid Retina Glass & Dynamic Theme"
Cohesion: 0.06
Nodes (33): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+25 more)

### Community 10 - "Notes Scratchpad & Debounce Storage"
Cohesion: 0.12
Nodes (18): Never, NoteStorageManager, .text, Bool, String, Void, NotesUIState, NotesWidgetView (+10 more)

### Community 11 - "Notes Scratchpad & Debounce Storage"
Cohesion: 0.07
Nodes (30): SettingsStore, .activeDashboardWidgets, .autoCollapseDelay, .clockDialStyle, .clockIs24Hour, .clockShowSeconds, .closeOnEsc, .closeOnOutsideClick (+22 more)

### Community 12 - "Clock Chronometer & Zero-Allocation Cache"
Cohesion: 0.18
Nodes (18): AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval, .timeZoneAbbreviation (+10 more)

### Community 13 - "File Studio & PDF Engine"
Cohesion: 0.10
Nodes (18): AppKit, ApplicationServices, AVFoundation, Combine, CoreImage, Foundation, IOKit.ps, PDFKit (+10 more)

### Community 14 - "MediaRemote Audio & Video Bridge"
Cohesion: 0.17
Nodes (15): NowPlayingAdaptiveWidgetView, .body, NowPlayingCompactTileView, .body, NowPlayingHomeCardView, .body, NowPlayingModule, .progress (+7 more)

### Community 15 - "Modular Bento Dashboard & Settings"
Cohesion: 0.12
Nodes (13): NSApplicationDelegate, NSHostingView, NSMenu, NSStatusItem, NSWindowDelegate, Selector, AppDelegate, .sharedDelegate (+5 more)

### Community 16 - "Clock Chronometer & Zero-Allocation Cache"
Cohesion: 0.15
Nodes (17): ObservableObject, DashboardSettingsUIState, DashboardSettingsView, .clockCustomizationSection, .layoutMiniPreviewSection, .layoutModeSelectionSection, DraggableWidgetPaletteCard, DropTargetState (+9 more)

### Community 17 - "Sources Modules"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 18 - "Modular Bento Dashboard & Settings"
Cohesion: 0.18
Nodes (10): Animation, .body, NotchShellCoordinator, .state, .transitionAnimation, Bool, DispatchWorkItem, NSRect (+2 more)

### Community 19 - "Notes Scratchpad & Debounce Storage"
Cohesion: 0.15
Nodes (14): DashboardWidgetType, calendar, clock, .icon, .id, mirror, notes, nowPlaying (+6 more)

### Community 20 - "Thock Mechanical Audio Engine"
Cohesion: 0.17
Nodes (9): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id, LocalUIState (+1 more)

### Community 22 - "Liquid Retina Glass & Dynamic Theme"
Cohesion: 0.14
Nodes (15): LinearGradient, DesignSystem, .accentColor, .canvasColor, .cardFill, .cardGradient, .currentTheme, .defaultHoverCollapseDelay (+7 more)

### Community 23 - "Modular Bento Dashboard & Settings"
Cohesion: 0.46
Nodes (4): ModularDashboardView, .body, Int, View

### Community 24 - "Battery & Power RunLoop Source"
Cohesion: 0.24
Nodes (6): CFRunLoopSource, BatteryModule, AnyView, Bool, Int, String

### Community 25 - "Notch Geometry & Window Coordinator"
Cohesion: 0.26
Nodes (8): NSPanel, NotchPanel, .canBecomeKey, .canBecomeMain, .isolated, Any, NSRect, NSScreen

### Community 26 - "Modular Bento Dashboard & Settings"
Cohesion: 0.27
Nodes (7): NSObjectProtocol, .dynamicVibrancy, DynamicThemeEngine, CGRect, NSImage, Set, URL

### Community 27 - "Notch Geometry & Window Coordinator"
Cohesion: 0.24
Nodes (6): NotchState, collapsed, expanded, Bool, .footerBar, Task

### Community 28 - "Notch Geometry & Window Coordinator"
Cohesion: 0.29
Nodes (4): Content, NSTrackingArea, NotchHostingView, NSEvent

### Community 29 - "Liquid Retina Glass & Dynamic Theme"
Cohesion: 0.42
Nodes (6): LiveEqualizerIndicator, .body, NotchGlassBackground, Bool, CGFloat, Color

### Community 30 - "Liquid Retina Glass & Dynamic Theme"
Cohesion: 0.31
Nodes (6): Configuration, ImageIO, ButtonStyle, .spring, SpringButtonStyle, Double

### Community 31 - "Battery & Power RunLoop Source"
Cohesion: 0.22
Nodes (9): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+1 more)

### Community 32 - "Modular Bento Dashboard & Settings"
Cohesion: 0.25
Nodes (7): CGFloat, DynamicVibrancy, balanced, .factor, .id, punchy, subtle

### Community 34 - "Modular Bento Dashboard & Settings"
Cohesion: 0.29
Nodes (7): DashboardLayoutFlow, adaptiveAuto, bentoQuad, horizontalStrip, .icon, .id, .title

### Community 35 - "Modular Bento Dashboard & Settings"
Cohesion: 0.48
Nodes (4): .widgetSpans, Int, .body, .body

### Community 37 - "Sources Notch"
Cohesion: 0.38
Nodes (5): NotchGeometry, Bool, CGFloat, CGRect, NSScreen

### Community 38 - "Liquid Retina Glass & Dynamic Theme"
Cohesion: 0.29
Nodes (7): GlassMaterialStyle, crystal, deepOLED, frosted, .id, luminous, .subtitle

### Community 39 - "Liquid Retina Glass & Dynamic Theme"
Cohesion: 0.29
Nodes (7): MotionPhysicsStyle, appleFluid, .damping, gentle, .id, .response, snappy

### Community 40 - "Telegram Direct Bot & Messaging"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 41 - "Clock Chronometer & Zero-Allocation Cache"
Cohesion: 0.33
Nodes (6): Identifiable, ClockDialStyle, analog, digital, .id, .title

### Community 42 - "Modular Bento Dashboard & Settings"
Cohesion: 0.33
Nodes (6): Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 43 - "AirDrop Direct Sharing Service"
Cohesion: 0.33
Nodes (4): Path, Shape, .body, CustomNotchShape

### Community 44 - "Thock Mechanical Audio Engine"
Cohesion: 0.33
Nodes (6): ThockSubSection, asmr, .icon, .id, keySound, terminal

### Community 45 - "Interactive Calendar & Agenda"
Cohesion: 0.40
Nodes (5): CaseIterable, CalendarSubsection, calendar, .id, schedule

## Knowledge Gaps
- **206 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `.themeColor`, `nowPlaying`, `calendar` (+201 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `Modular Bento Dashboard & Settings` to `File Studio & PDF Engine`, `Telegram Direct Bot & Messaging`, `Modular Bento Dashboard & Settings`, `Mirror Camera Live Preview`, `Notes Scratchpad & Debounce Storage`, `System Permissions & Finder Drag`, `System Permissions & Finder Drag`, `Interactive Calendar & Agenda`, `Notes Scratchpad & Debounce Storage`, `Clock Chronometer & Zero-Allocation Cache`, `File Studio & PDF Engine`, `MediaRemote Audio & Video Bridge`, `Clock Chronometer & Zero-Allocation Cache`, `Sources Modules`, `Thock Mechanical Audio Engine`, `Liquid Retina Glass & Dynamic Theme`, `Liquid Retina Glass & Dynamic Theme`?**
  _High betweenness centrality (0.144) - this node is a cross-community bridge._
- **Why does `NotchModule` connect `Modular Bento Dashboard & Settings` to `File Studio & PDF Engine`, `Telegram Direct Bot & Messaging`, `Mirror Camera Live Preview`, `Notes Scratchpad & Debounce Storage`, `System Permissions & Finder Drag`, `File Studio & PDF Engine`, `Clock Chronometer & Zero-Allocation Cache`, `Sources Modules`, `Notes Scratchpad & Debounce Storage`, `Battery & Power RunLoop Source`?**
  _High betweenness centrality (0.110) - this node is a cross-community bridge._
- **Why does `SettingsStore` connect `Notes Scratchpad & Debounce Storage` to `Modular Bento Dashboard & Settings`, `Modular Bento Dashboard & Settings`, `Modular Bento Dashboard & Settings`, `Liquid Retina Glass & Dynamic Theme`, `Liquid Retina Glass & Dynamic Theme`, `Telegram Direct Bot & Messaging`, `Clock Chronometer & Zero-Allocation Cache`, `Liquid Retina Glass & Dynamic Theme`, `File Studio & PDF Engine`, `Clock Chronometer & Zero-Allocation Cache`, `Notes Scratchpad & Debounce Storage`, `Thock Mechanical Audio Engine`, `Notch Geometry & Window Coordinator`, `Modular Bento Dashboard & Settings`, `Battery & Power RunLoop Source`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ThockModule` (e.g. with `.keySoundSectionView` and `.terminalSectionView`) actually correct?**
  _`ThockModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ShelfModule` (e.g. with `.body` and `.canRunActiveTool`) actually correct?**
  _`ShelfModule` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `.themeColor` to the rest of the system?**
  _206 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `File Studio & PDF Engine` be split into smaller, more focused modules?**
  _Cohesion score 0.0568986568986569 - nodes in this community are weakly interconnected._