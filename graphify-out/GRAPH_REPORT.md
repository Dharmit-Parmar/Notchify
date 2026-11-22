# Graph Report - Notch  (2026-11-22)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 2524 nodes · 6528 edges · 120 communities (108 shown, 12 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 363 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ee7decb1`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

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
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101
- Community 102
- Community 103
- Community 104
- Community 105
- Community 106
- Community 107
- Community 108
- Community 109
- Community 110
- Community 111
- Community 112
- Community 113
- Community 114
- Community 115
- Community 116
- Community 117
- Community 118
- Community 119

## God Nodes (most connected - your core abstractions)
1. `SettingsStore` - 110 edges
2. `ThockModule` - 89 edges
3. `LocalShareServer` - 87 edges
4. `LocalShareModule` - 68 edges
5. `DesignSystem` - 67 edges
6. `ShelfModule` - 65 edges
7. `SkeletonPose` - 60 edges
8. `CGPoint` - 58 edges
9. `MediaRemoteBridge` - 52 edges
10. `AppTheme` - 49 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `CreatureRigView`  [INFERRED]
  Sources/Modules/Companion/CompanionWindow.swift → Sources/Modules/Companion/CreatureRigView.swift
- `.wordCount` --references--> `NoteStorageManager`  [INFERRED]
  Sources/Modules/Notes/NotesWidgetView.swift → Sources/Modules/Notes/NoteStorageManager.swift
- `.body` --calls--> `CGPoint`  [INFERRED]
  Sources/Modules/LocalShare/LocalShareExpandedView.swift → Sources/Modules/Companion/KinematicSkeleton.swift
- `ResultantPDFPreviewCard` --calls--> `LocalUIState`  [INFERRED]
  Sources/Modules/Shelf/ShelfModule.swift → Sources/UI/DesignSystem.swift
- `StagedFileChip` --calls--> `LocalUIState`  [INFERRED]
  Sources/Modules/Shelf/ShelfModule.swift → Sources/UI/DesignSystem.swift

## Import Cycles
- None detected.

## Communities (120 total, 12 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (56): ByteCountFormatter, CIContext, CoreImage, NSURL, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body (+48 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (35): LocalShareExpandedUIState, LocalShareExpandedView, .activeTransferProgressCard, .body, .dropStageBox, .messageComposerCard, .nearbyPeersSection, .selectedFilesSummary (+27 more)

### Community 2 - "Community 2"
Cohesion: 0.07
Nodes (37): NSHostingView, NSPanel, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any (+29 more)

### Community 3 - "Community 3"
Cohesion: 0.08
Nodes (29): CGEventPostToPidFunction, MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction, MRMediaRemoteSendCommandFunction, NSString, SHA256Digest (+21 more)

### Community 4 - "Community 4"
Cohesion: 0.08
Nodes (25): DispatchSourceTimer, LocalShareFileStreamWriter, Data, FileHandle, HTTPChunkDecoder, LocalShareCycleGuard, Int64, LocalShareFileProgress (+17 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (52): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .autoRotateCompanion, .clockDialStyle, .clockIs24Hour (+44 more)

### Community 6 - "Community 6"
Cohesion: 0.06
Nodes (32): NWListener, LocalShareAtomicFlag, LocalShareServer, .autoAcceptFavorites, .boundPort, .currentActiveConnections, .currentState, .favoriteFingerprints (+24 more)

### Community 7 - "Community 7"
Cohesion: 0.07
Nodes (24): AVCaptureSession, NSCoder, NSView, NSViewRepresentable, CameraHostingNSView, CameraLivePreview, CameraSessionManager, MirrorAdaptiveWidgetView (+16 more)

### Community 8 - "Community 8"
Cohesion: 0.08
Nodes (25): NSObject, NSSharingService, NSSharingServiceDelegate, NSSharingServicePicker, NSSharingServicePickerDelegate, AirDropExpandedView, .body, AirDropModule (+17 more)

### Community 9 - "Community 9"
Cohesion: 0.11
Nodes (28): AVFoundation, CGSize, ImageIO, PDFKit, QuickLookThumbnailing, FilePreviewAllCarouselCard, .body, FilePreviewCarouselItemView (+20 more)

### Community 10 - "Community 10"
Cohesion: 0.11
Nodes (18): DarwinBoolean, OSStatus, P256, sec_identity_t, SecAccess, SecIdentity, ASN1, KeychainInteractionGovernor (+10 more)

### Community 11 - "Community 11"
Cohesion: 0.10
Nodes (23): LocalShareHistoryItem, LocalSharePeerTrustState, blocked, certificateChanged, trusted, unverifiedFirstContact, LocalShareSettings, .autoAcceptFavorites (+15 more)

### Community 12 - "Community 12"
Cohesion: 0.12
Nodes (26): EventKit, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body (+18 more)

### Community 13 - "Community 13"
Cohesion: 0.12
Nodes (19): CGImage, ColorDetectionDiagnostics, CustomNotchShape, DynamicThemeEngine, .isolated, MultiZonePalette, NotchGlassBackground, .body (+11 more)

### Community 14 - "Community 14"
Cohesion: 0.15
Nodes (7): KinematicEngine, .ledgeY, .walkLedgeY, Bool, CGFloat, Double, Int

### Community 15 - "Community 15"
Cohesion: 0.13
Nodes (20): Sendable, LocalShareClient, LocalShareClientSession, .cancelled, LocalSharePeerPinningDelegate, Bool, Double, HTTPURLResponse (+12 more)

### Community 16 - "Community 16"
Cohesion: 0.05
Nodes (37): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+29 more)

### Community 17 - "Community 17"
Cohesion: 0.10
Nodes (24): NowPlayingAdaptiveWidgetView, .body, NowPlayingCompactTileView, .body, .shouldShowSourcePill, .subtitleText, .transportDock, NowPlayingHomeCardView (+16 more)

### Community 18 - "Community 18"
Cohesion: 0.22
Nodes (12): CGAffineTransform, Gradient, GraphicsContext, CreatureRigView, .body, .engine, .skin, Bool (+4 more)

### Community 19 - "Community 19"
Cohesion: 0.13
Nodes (26): Codable, Decoder, Equatable, LocalShareConstants, LocalShareDeviceInfo, LocalShareDeviceType, desktop, headless (+18 more)

### Community 20 - "Community 20"
Cohesion: 0.10
Nodes (20): convention, AnyCancellable, Int, Int32, NSRegularExpression, pid_t, Set, UInt64 (+12 more)

### Community 21 - "Community 21"
Cohesion: 0.10
Nodes (14): DispatchSourceSignal, NSApplicationDelegate, NSMenu, NSStatusItem, NSWindowDelegate, AppDelegate, .sharedDelegate, Bool (+6 more)

### Community 22 - "Community 22"
Cohesion: 0.18
Nodes (18): AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval, .timeZoneAbbreviation (+10 more)

### Community 23 - "Community 23"
Cohesion: 0.13
Nodes (8): LocalShareModuleState, .selectedFiles, Bool, Double, Int64, String, URL, Void

### Community 24 - "Community 24"
Cohesion: 0.10
Nodes (20): CFRunLoopSource, IOKit.ps, BatteryExpandedView, .body, BatteryModule, .batteryColor, .batteryIconName, .formattedTimeEstimate (+12 more)

### Community 25 - "Community 25"
Cohesion: 0.17
Nodes (10): ModuleRegistry, .activeModuleId, .allOrderedModules, .isDashboardPinned, Bool, DispatchWorkItem, String, TimeInterval (+2 more)

### Community 26 - "Community 26"
Cohesion: 0.13
Nodes (21): .dashboardSlots, DashboardSettingsView, .availableWidgetsPaletteSection, .body, .clockCustomizationSection, .emptyPreviewPlaceholder, .layoutMiniPreviewSection, .layoutModeSelectionSection (+13 more)

### Community 27 - "Community 27"
Cohesion: 0.15
Nodes (7): AppKit, ApplicationServices, Combine, Darwin, SwiftUI, UniformTypeIdentifiers, UserNotifications

### Community 28 - "Community 28"
Cohesion: 0.15
Nodes (11): NWConnectionGroup, LocalShareDiscovery, .activePeers, .isDiscoveryActive, Bool, Date, String, UInt16 (+3 more)

### Community 29 - "Community 29"
Cohesion: 0.14
Nodes (13): LinearGradient, QuickControlsManager, CGRect, Double, Never, Task, .manualIPInputCard, .body (+5 more)

### Community 30 - "Community 30"
Cohesion: 0.09
Nodes (23): .body, SettingsCategory, appearance, companion, dashboard, feedback, geometry, .icon (+15 more)

### Community 31 - "Community 31"
Cohesion: 0.16
Nodes (12): .activeVerificationCode, LocalShareRateLimiter, LocalShareSecurity, Bool, Data, Date, Int, Int64 (+4 more)

### Community 32 - "Community 32"
Cohesion: 0.14
Nodes (15): Animation, CFTimeInterval, NotchShellCoordinator, .activeContentHeight, .cachedExpandedRect, .isExpanded, .quickControlsExpandedHeight, .transitionAnimation (+7 more)

### Community 33 - "Community 33"
Cohesion: 0.18
Nodes (9): Float, MockQuickControlsService, QuickControlAvailability, available, .isUsable, readOnly, .statusDescription, unsupported (+1 more)

### Community 34 - "Community 34"
Cohesion: 0.23
Nodes (6): AskAIService, .currentLoginBadgeText, .hasAnyCloudLogin, .isCurrentProviderAuthenticated, Bool, String

### Community 35 - "Community 35"
Cohesion: 0.15
Nodes (14): .useCustomNotchOpacity, AdvancedSettingsSection, CursorTrackingState, PointerCursorModifier, SettingsView, .appearanceSection, .detailHeaderBar, .feedbackSection (+6 more)

### Community 36 - "Community 36"
Cohesion: 0.09
Nodes (23): .recentTransfersSection, DesignSystem, .accentColor, .accentInkColor, .appAccentColor, .canvasColor, .cardBorder, .cardFill (+15 more)

### Community 37 - "Community 37"
Cohesion: 0.12
Nodes (19): DashboardWidgetType, askAI, battery, calendar, clock, .icon, .id, mirror (+11 more)

### Community 38 - "Community 38"
Cohesion: 0.09
Nodes (20): SkeletonPose, .chest, .head, .leftElbow, .leftFoot, .leftFootPlanted, .leftHand, .leftHandPlanted (+12 more)

### Community 39 - "Community 39"
Cohesion: 0.17
Nodes (6): FailedPinState, Bool, Date, Double, Int, String

### Community 40 - "Community 40"
Cohesion: 0.15
Nodes (15): NoteSaveState, failed, saved, saving, NoteStorageManager, .storageURL, .text, Bool (+7 more)

### Community 41 - "Community 41"
Cohesion: 0.17
Nodes (14): NotesUIState, NotesWidgetView, .body, .charCount, .fourSpaceView, .oneSpaceView, .saveStatusIndicator, .twoSpaceView (+6 more)

### Community 42 - "Community 42"
Cohesion: 0.20
Nodes (13): ActiveNotchEvents, .hasAnyActiveEvent, CollapsedLayout, ExpandedLayout, NotchDimensionLimits, NotchGeometry, Bool, CGFloat (+5 more)

### Community 43 - "Community 43"
Cohesion: 0.15
Nodes (9): DispatchSourceMemoryPressure, T, ProcessMemoryGovernor, .isSystemPanelActive, Bool, Date, Int, String (+1 more)

### Community 44 - "Community 44"
Cohesion: 0.30
Nodes (4): NWConnection, LocalShareHTTPRequest, Data, T

### Community 45 - "Community 45"
Cohesion: 0.12
Nodes (18): AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id, .shortName (+10 more)

### Community 46 - "Community 46"
Cohesion: 0.10
Nodes (21): LocalShareError, blockedByAnotherSession, checksumMismatch, connectionFailed, .errorDescription, fileCountExceeded, fileExists, fileTooLarge (+13 more)

### Community 47 - "Community 47"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 48 - "Community 48"
Cohesion: 0.26
Nodes (8): DividerUIState, DottedDividerView, ModularDashboardView, .body, Bool, CGFloat, Int, View

### Community 49 - "Community 49"
Cohesion: 0.15
Nodes (10): Configuration, .currentAccentColor, ButtonStyle, .spring, LiveEqualizerIndicator, .body, LocalUIState, SpringButtonStyle (+2 more)

### Community 50 - "Community 50"
Cohesion: 0.20
Nodes (9): CryptoKit, Foundation, LocalAuthentication, Network, Security, SafeEnvironment, LocalShareServerBind, localNetwork (+1 more)

### Community 51 - "Community 51"
Cohesion: 0.29
Nodes (9): KeyProvider, EncryptedFileStore, .symmetricKey, Bool, Data, String, URL, KeychainManaging (+1 more)

### Community 52 - "Community 52"
Cohesion: 0.23
Nodes (13): CGPoint, LimbBones, Result, Bool, CGFloat, TorsoBones, .leftHipAnchor, .leftShoulderAnchor (+5 more)

### Community 53 - "Community 53"
Cohesion: 0.19
Nodes (8): LocalShareFileManager, .activeReceiveDirectory, .defaultReceiveDirectory, Bool, Int64, String, URL, .customReceivePath

### Community 54 - "Community 54"
Cohesion: 0.15
Nodes (12): Bool, HTTPURLResponse, String, URLRequest, URLSession, URLSessionTask, Void, TelegramClient (+4 more)

### Community 55 - "Community 55"
Cohesion: 0.15
Nodes (17): CompactBatteryIndicator, .body, CompactMediaIndicator, .body, CompactNotchIndicator, .body, .circadianIndicator, .dateTimeIndicator (+9 more)

### Community 56 - "Community 56"
Cohesion: 0.18
Nodes (11): NotchState, collapsed, expanded, NotchPanel, .canBecomeKey, .canBecomeMain, .isolated, Any (+3 more)

### Community 57 - "Community 57"
Cohesion: 0.19
Nodes (11): DropDelegate, NSDragOperation, ScrollViewProxy, SpringLoadManager, Binding, Bool, DispatchWorkItem, DropInfo (+3 more)

### Community 58 - "Community 58"
Cohesion: 0.24
Nodes (8): KeychainHelper, Bool, LAContext, Never, String, Task, URL, Void

### Community 59 - "Community 59"
Cohesion: 0.17
Nodes (8): AnyView, DateFormatter, URL, TelegramModule, .contactsFileURL, .selectedContact, TelegramModuleExpandedView, .body

### Community 60 - "Community 60"
Cohesion: 0.12
Nodes (17): CompanionSkin, .accentColor, boba, .bodyColor, bubu, cyber, .darkAccentColor, .displayName (+9 more)

### Community 61 - "Community 61"
Cohesion: 0.29
Nodes (8): Hashable, Identifiable, ChatContact, ChatMessage, ContactSafetyValidator, Bool, String, UUID

### Community 62 - "Community 62"
Cohesion: 0.18
Nodes (8): NSScrollView, NSTextViewDelegate, Coordinator, CustomTextEditor, Context, Coordinator, Notification, String

### Community 63 - "Community 63"
Cohesion: 0.18
Nodes (6): Pipe, Process, String, URL, .isInstalled, .projectDir

### Community 65 - "Community 65"
Cohesion: 0.19
Nodes (11): .displayPositionProfiles, NSScreen, CollapsedNotchMode, alwaysShowWings, hideBehindNotch, .icon, .id, .subtitle (+3 more)

### Community 66 - "Community 66"
Cohesion: 0.24
Nodes (5): .oneSpaceView, .twoSpaceView, .selectedProvider, .aiAssistantCustomizationSection, .notesCustomizationSection

### Community 67 - "Community 67"
Cohesion: 0.18
Nodes (11): AskAIWidgetUIState, AskAIWidgetView, .activeProviderNeedsSetup, .body, Bool, Int, MainActor, Never (+3 more)

### Community 68 - "Community 68"
Cohesion: 0.23
Nodes (13): EnvironmentKey, EnvironmentValues, .notchCompact, .notchContentHeight, .notchTight, NotchCompactKey, NotchContentHeightKey, NotchTightKey (+5 more)

### Community 69 - "Community 69"
Cohesion: 0.17
Nodes (10): NSControl, NSTextFieldDelegate, Selector, Coordinator, PasteableTextField, Binding, Coordinator, Notification (+2 more)

### Community 70 - "Community 70"
Cohesion: 0.21
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 72 - "Community 72"
Cohesion: 0.22
Nodes (8): ObservableObject, LazyNotchModule, .isEnabled, .isLoaded, .loadedInstance, AnyView, Color, MainActor

### Community 73 - "Community 73"
Cohesion: 0.29
Nodes (7): MotionPhysicsStyle, appleFluid, .damping, gentle, .id, .response, snappy

### Community 74 - "Community 74"
Cohesion: 0.21
Nodes (9): ProcessInfo, EnvironmentState, .isolated, Bool, CGRect, NSObjectProtocol, String, NSScreen (+1 more)

### Community 75 - "Community 75"
Cohesion: 0.19
Nodes (12): .activeModule, .orderedModules, NotchModule, .preferredContentHeight, .themeColor, DraggableTabChip, .chipBackground, .chipBorder (+4 more)

### Community 76 - "Community 76"
Cohesion: 0.15
Nodes (12): ClockDialStyle, analog, digital, .id, .title, CGFloat, DynamicVibrancy, balanced (+4 more)

### Community 77 - "Community 77"
Cohesion: 0.22
Nodes (10): CertBox, LocalShareDiscoveryBootstrapDelegate, .capturedCertificateDER, .capturedFingerprint, Data, URLAuthenticationChallenge, URLCredential, URLSession (+2 more)

### Community 78 - "Community 78"
Cohesion: 0.29
Nodes (4): AudioDeviceID, AudioObjectPropertyListenerBlock, Void, SystemControlsService

### Community 79 - "Community 79"
Cohesion: 0.23
Nodes (6): NSPoint, NSTrackingArea, NotchHostingView, Content, NSEvent, NSView

### Community 80 - "Community 80"
Cohesion: 0.36
Nodes (3): ContrastGuard, OKLabColor, CGFloat

### Community 81 - "Community 81"
Cohesion: 0.18
Nodes (10): CoreGraphics, ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang, monkeyBarTraversal (+2 more)

### Community 82 - "Community 82"
Cohesion: 0.18
Nodes (11): Error, LocalizedError, EncryptedFileStoreError, corruptedData, .errorDescription, invalidEncoding, keychainSaveFailed, keyMissing (+3 more)

### Community 83 - "Community 83"
Cohesion: 0.25
Nodes (6): NSTextView, FocusTextView, .acceptsFirstResponder, Bool, NSEvent, NSWindow

### Community 84 - "Community 84"
Cohesion: 0.22
Nodes (7): NotchRootView, .currentBottomRadius, .currentTopRadius, .isExpanded, .moduleHasInternalVerticalScroll, CGFloat, Color

### Community 85 - "Community 85"
Cohesion: 0.20
Nodes (8): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id, .body

### Community 86 - "Community 86"
Cohesion: 0.31
Nodes (5): LocalShareSettingsUIState, LocalShareSettingsView, .body, Bool, String

### Community 89 - "Community 89"
Cohesion: 0.18
Nodes (11): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+3 more)

### Community 90 - "Community 90"
Cohesion: 0.20
Nodes (9): ClosedRange, CompanionActivityLevel, balanced, calm, .displayName, .id, .intervalRange, playful (+1 more)

### Community 92 - "Community 92"
Cohesion: 0.24
Nodes (7): SecureAPITaskDelegate, HTTPURLResponse, Set, URLRequest, URLSession, URLSessionTask, Void

### Community 93 - "Community 93"
Cohesion: 0.20
Nodes (10): LocalShareSessionState, accepted, cancelled, completed, failed, idle, .isActive, offered (+2 more)

### Community 95 - "Community 95"
Cohesion: 0.22
Nodes (8): AudioToolbox, CoreAudio, QuickControlsState, closed, hoverPreview, interacting, .isPanelVisible, pinned

### Community 96 - "Community 96"
Cohesion: 0.42
Nodes (4): DirectMessenger, .isAccessibilityGranted, MainActor, Sendable

### Community 97 - "Community 97"
Cohesion: 0.22
Nodes (9): DashboardLayoutFlow, adaptiveAuto, bentoQuad, focusDominant, horizontalStrip, .icon, .id, .subtitle (+1 more)

### Community 98 - "Community 98"
Cohesion: 0.18
Nodes (7): BrightnessControlRow, KeyboardBacklightControlRow, QuickControlsPanelView, .body, String, VolumeControlRow, .volumeIcon

### Community 99 - "Community 99"
Cohesion: 0.32
Nodes (4): NSTextField, CustomPasteableNSTextField, Context, NSEvent

### Community 100 - "Community 100"
Cohesion: 0.36
Nodes (7): BatteryWidgetView, .fourSpaceView, .oneSpaceView, .twoSpaceView, Int, .cartoonStrokeStyle, StrokeStyle

### Community 101 - "Community 101"
Cohesion: 0.48
Nodes (4): NSVisualEffectView, Context, NSView, VisualEffectBlur

### Community 102 - "Community 102"
Cohesion: 0.29
Nodes (6): .enabledQuickControls, .notchHeight, .notchWidth, .quickControlsPinned, .showQuickControls, .state

### Community 103 - "Community 103"
Cohesion: 0.15
Nodes (13): CaseIterable, QuickControlKind, brightness, .iconName, .id, keyboardBacklight, .title, volume (+5 more)

### Community 104 - "Community 104"
Cohesion: 0.29
Nodes (7): NotchPositionAttachment, belowMenuBar, custom, hardwareNotch, .icon, .id, .subtitle

### Community 105 - "Community 105"
Cohesion: 0.29
Nodes (7): GlassMaterialStyle, crystal, deepOLED, frosted, .id, luminous, .subtitle

### Community 106 - "Community 106"
Cohesion: 0.29
Nodes (7): NotchCornerStyle, .bottomRadius, compact, continuous, deep, .id, .topRadius

### Community 107 - "Community 107"
Cohesion: 0.33
Nodes (5): Shape, .body, LineShape, CGRect, Path

### Community 108 - "Community 108"
Cohesion: 0.33
Nodes (5): TimeInterval, .connectedGoogleEmail, .geminiApiKey, .openAIApiKey, .botToken

### Community 109 - "Community 109"
Cohesion: 0.33
Nodes (6): MouthShape, gasp, neutral, openW, sigh, smile

### Community 110 - "Community 110"
Cohesion: 0.33
Nodes (6): State, finished, readingCRLF, readingData, readingSize, readingTrailers

### Community 111 - "Community 111"
Cohesion: 0.53
Nodes (3): FocusCompanionRotationManager, Date, Timer

### Community 112 - "Community 112"
Cohesion: 0.50
Nodes (3): PreferenceKey, QuickControlsFramePreferenceKey, CGRect

### Community 113 - "Community 113"
Cohesion: 0.40
Nodes (5): KeyField, geminiKey, geminiModel, openAIKey, openAIModel

## Knowledge Gaps
- **494 isolated node(s):** `LocalShareEndpoints`, `CoreImage`, `.actionTitle`, `airdrop`, `compress` (+489 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `Community 48` to `Community 0`, `Community 1`, `Community 2`, `Community 7`, `Community 8`, `Community 9`, `Community 12`, `Community 13`, `Community 17`, `Community 18`, `Community 22`, `Community 24`, `Community 26`, `Community 29`, `Community 35`, `Community 41`, `Community 42`, `Community 45`, `Community 47`, `Community 49`, `Community 54`, `Community 55`, `Community 59`, `Community 62`, `Community 66`, `Community 67`, `Community 68`, `Community 75`, `Community 84`, `Community 85`, `Community 86`, `Community 87`, `Community 91`, `Community 98`, `Community 100`?**
  _High betweenness centrality (0.095) - this node is a cross-community bridge._
- **Why does `LocalShareServer` connect `Community 6` to `Community 4`, `Community 39`, `Community 11`, `Community 44`, `Community 15`, `Community 50`, `Community 31`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `SettingsStore` connect `Community 5` to `Community 2`, `Community 16`, `Community 25`, `Community 26`, `Community 27`, `Community 29`, `Community 34`, `Community 35`, `Community 37`, `Community 45`, `Community 48`, `Community 56`, `Community 60`, `Community 65`, `Community 72`, `Community 73`, `Community 76`, `Community 85`, `Community 89`, `Community 90`, `Community 97`, `Community 102`, `Community 103`, `Community 104`, `Community 105`, `Community 106`, `Community 108`, `Community 111`, `Community 114`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Are the 10 inferred relationships involving `SettingsStore` (e.g. with `.togglePin()` and `.evaluateRotation()`) actually correct?**
  _`SettingsStore` has 10 INFERRED edges - model-reasoned connections that need verification._
- **What connects `LocalShareEndpoints`, `CoreImage`, `.actionTitle` to the rest of the system?**
  _494 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05235103750237959 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.059644322845417236 - nodes in this community are weakly interconnected._