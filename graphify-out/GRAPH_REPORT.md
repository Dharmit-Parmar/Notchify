# Graph Report - Notch  (2026-11-14)

## Corpus Check
- 132 files · ~848,703 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2989 nodes · 6322 edges · 158 communities (134 shown, 24 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 335 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `218cba50`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ShelfModule
- KinematicEngine
- TelegramModule
- SkeletonPose
- LocalShareModule
- MediaRemoteBridge
- MirrorModule
- ThockModule
- SkeletonPose
- ClockWidgetView
- LocalShareClientSession
- SettingsStore
- LocalShareSession
- EncryptedFileStore
- CollapsedLayout
- String
- LocalShareServer
- Notchify — Design Phase Execution Log (`DESIGN_LOG.md`)
- CompanionSkin
- Sendable
- LocalShareSettings
- .playClick
- LocalShareIdentityManager
- AppTheme
- AppDelegate
- ModuleRegistry
- NotchShellCoordinator
- AirDropModule
- SwiftUI
- View
- runAllVerificationTests
- LocalShareError
- SettingsCategory
- DynamicThemeEngine
- DesignSystem
- LocalShareFileManager
- BatteryModule
- .keySoundSectionView
- CompanionPanel
- Foundation
- CGFloat
- UniversalTabDropDelegate
- KeychainHelper
- DashboardSettingsView
- .tint
- Local Share Architecture & Design Specification (LocalSend Protocol Compatible)
- NotificationModule
- Local Share — Stage 3: Security, Privacy & Energy Audit Report
- Comprehensive Security Audit Report: Notchify (Notch) macOS
- Stage B: Small, Targeted Security Fixes (Per-Commit Execution)
- ObservableObject
- CalendarModule
- Identifiable
- NotchRootView
- ResponsiveTabContent
- PermissionsHelper
- 4. Technical Deep-Dive per Remediation
- Notchify — Feature Matrix (Keep-and-Guard Inventory)
- Notchify Comprehensive Engineering, Performance & Lifecycle Report (Round 5)
- LocalShareDiscoveryBootstrapDelegate
- NotchRootView.swift
- ScreenRouteStage
- Local Share — Stage 2: SwiftUI Module & Application Integration Report
- Bool
- LocalShareSettingsView
- CompactIndicatorStyle
- OKLabColor
- Architecture & Security Decisions (Stage D)
- 2. Per-Module Verification Checklist at Height = 200 pt
- main
- run_stage4_soak.py
- DottedDividerView
- measure_stage1.py
- AIProvider
- CompanionFrameStripStubs.swift
- Notch Animated Desktop Companion
- 3. Real User Complaints Resolution (C1 – C10)
- VisualEffectBlur
- verify_stage3.py
- Manual Check Guide: Battery Status Widget & Dashboard Layouts
- NotchPositionAttachment
- Manual Verification Guide — Stage B Security Fixes
- 1. Feature Area Threat Registers (STRIDE)
- DesignSystem.swift
- Notch Cartoon Companion Specifications
- benchmark_time_to_open.py
- CustomTextEditor
- Local Share — Stage 1 Protocol Core Completion Report
- EnvironmentState
- Notchify Static Code Audit Report
- measure_telemetry.py
- verify_stage2.py
- 3. Detailed Batch Breakdown
- test_thock_lifecycle.sh
- 3. Review Generator Scripts Audit (`review/scratch/*.py`)
- Module Group E: Feature Modules
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
- 2. Human Verification Test Plan (NEEDS HUMAN CHECK)
- Crawl Animation Strip
- Hanging Idle Animation Strip
- Clean Hang Animation Strip
- Left-Peek Animation Strip
- Pull-Up Animation Strip
- Standard Walk Cycle Strip
- Right Walk Animation Strip
- Creature Animation Rigidity Analysis
- Attack Surface & System Architecture Map
- Section 3 — Part 1: Per-File Review Findings
- Notchify Fix Execution Log
- Diagnostic Findings
- Diagnostic Findings
- Responsive Notch Tabs (200 pt) & Event-Driven Battery Widget Report
- 2. Specific Check Results
- Manual Verification Steps: Expanded Notch Layout & Geometry Synchronization
- Notchify Position & Bezel Integration Execution Log
- Round 2 Phase 1: Expanded Notch Single Source of Truth & Zero-Clipping Implementation
- Round 2 Phase 1: Expanded Notch Single Source of Truth & Zero-Clipping Implementation
- Notchify macOS Security Remediation Final Report
- Module Group A: App & Core
- Phase 1 Manual Verification Steps: Collapsed Notch Width Model & Event-Driven Wings
- Round 2 Phase 1: One Collapsed-Layout Model Implementation
- Responsive Notch & Battery Widget Implementation Log
- Manual Verification Guide — Stage C: Notes & Contacts At-Rest Encryption (SEC-A-1 & SEC-A-2)
- Phase 0 Coverage & Ingest Verification Report
- Batch B3 Manual Verification Steps
- Batch B4 Manual Verification Steps
- Round 2 Phase 0: Width Model & Indicator Sizing Diagnosis
- Phase 1: Root Cause Fix Implementation
- DynamicVibrancy
- 1. Connection Findings
- Module Group D: Settings & Dashboard
- Audit Errors & Misleading Findings Catalog
- Manual Verification Guide: Batch B1 (Data & Crash Safety)
- Manual Verification Guide: Batch B2 (Lag & Responsiveness)
- Batch B5 Manual Verification Steps
- Master Question Bank — Round 2 Closure Table
- Step 0 — Security Audit Skill Selection & Applicability
- Section 2 — Graph Inventory & Architecture Topology
- Batch B6 Manual Verification Steps
- Notchify Behavior & Invariant Contract (Stage A)
- .make
- TestBox
- Third-Party Notices & Protocol Compliance
- NOTICED_NOT_TOUCHED.md

## God Nodes (most connected - your core abstractions)
1. `SettingsStore` - 92 edges
2. `runAllVerificationTests()` - 90 edges
3. `ThockModule` - 86 edges
4. `ShelfModule` - 65 edges
5. `DesignSystem` - 58 edges
6. `LocalShareModule` - 50 edges
7. `AppTheme` - 48 edges
8. `LocalShareSession` - 47 edges
9. `KinematicEngine` - 46 edges
10. `LocalShareServer` - 39 edges

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

## Communities (158 total, 24 thin omitted)

### Community 0 - "ShelfModule"
Cohesion: 0.05
Nodes (57): ByteCountFormatter, CIContext, NSItemProvider, NSURL, PDFDocument, PDFPage, AirDropDropTargetCapsule, .body (+49 more)

### Community 1 - "KinematicEngine"
Cohesion: 0.06
Nodes (38): CompanionPanel, CompanionCoordinator, .creatureInteractiveRectInWindow, PeekSide, left, right, Any, Bool (+30 more)

### Community 2 - "TelegramModule"
Cohesion: 0.06
Nodes (38): Hashable, NSControl, NSRegularExpression, NSTextField, NSTextFieldDelegate, Bool, String, URLSession (+30 more)

### Community 3 - "SkeletonPose"
Cohesion: 0.06
Nodes (54): LimbBones, CompanionProductionPoseChecks, CGFloat, CGPoint, LimbBones, MouthShape, gasp, neutral (+46 more)

### Community 4 - "LocalShareModule"
Cohesion: 0.07
Nodes (24): LocalShareExpandedUIState, LocalShareExpandedView, .activeTransferProgressCard, .body, .dropStageBox, .manualIPInputCard, .nearbyPeersSection, .selectedFilesSummary (+16 more)

### Community 5 - "MediaRemoteBridge"
Cohesion: 0.06
Nodes (35): MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction, MRMediaRemoteGetNowPlayingApplicationPIDFunction, MRMediaRemoteGetNowPlayingArtworkFunction, MRMediaRemoteGetNowPlayingClientFunction, MRMediaRemoteGetNowPlayingInfoFunction, MRMediaRemoteRegisterFunction, MRMediaRemoteSendCommandFunction, NSString (+27 more)

### Community 6 - "MirrorModule"
Cohesion: 0.09
Nodes (20): AVCaptureSession, NSCoder, NSView, CameraHostingNSView, CameraLivePreview, CameraSessionManager, MirrorAdaptiveWidgetView, .body (+12 more)

### Community 7 - "ThockModule"
Cohesion: 0.08
Nodes (25): AnyCancellable, convention, pid_t, Pipe, Process, AnyView, Int, Int32 (+17 more)

### Community 8 - "SkeletonPose"
Cohesion: 0.06
Nodes (46): CGPoint, LimbBones, MouthShape, gasp, neutral, openW, sigh, smile (+38 more)

### Community 9 - "ClockWidgetView"
Cohesion: 0.18
Nodes (18): AnalogClockFace, .body, ClockFormatters, ClockWidgetView, .body, .isSweepingAnalog, .minimumInterval, .timeZoneAbbreviation (+10 more)

### Community 10 - "LocalShareClientSession"
Cohesion: 0.11
Nodes (21): HTTPURLResponse, NSObject, NSSharingServiceDelegate, NSSharingServicePickerDelegate, AirDropPickerDelegate, AirDropSharingDelegate, LocalShareClient, LocalShareClientSession (+13 more)

### Community 11 - "SettingsStore"
Cohesion: 0.04
Nodes (56): SettingsStore, .activeDashboardWidgets, .aiDefaultProvider, .aiSystemPrompt, .autoCollapseDelay, .autoRotateCompanion, .clockDialStyle, .clockIs24Hour (+48 more)

### Community 12 - "LocalShareSession"
Cohesion: 0.07
Nodes (34): FileHandle, LocalShareFileStreamWriter, Data, Int64, Date, Int64, LocalShareFileProgress, .fraction (+26 more)

### Community 13 - "EncryptedFileStore"
Cohesion: 0.09
Nodes (31): Error, KeyProvider, LocalizedError, EncryptedFileStore, .symmetricKey, EncryptedFileStoreError, corruptedData, .errorDescription (+23 more)

### Community 14 - "CollapsedLayout"
Cohesion: 0.17
Nodes (14): SettingsStore, ActiveNotchEvents, .hasAnyActiveEvent, CollapsedLayout, ExpandedLayout, NotchGeometry, Bool, CGFloat (+6 more)

### Community 15 - "String"
Cohesion: 0.12
Nodes (18): AskAIService, .currentLoginBadgeText, .hasAnyCloudLogin, .isCurrentProviderAuthenticated, Bool, AskAIWidgetUIState, AskAIWidgetView, .body (+10 more)

### Community 16 - "LocalShareServer"
Cohesion: 0.10
Nodes (27): NWConnection, NWListener, LocalShareHTTPRequest, LocalShareServer, .boundPort, .currentState, .isRunning, .trustedPeers (+19 more)

### Community 17 - "Notchify — Design Phase Execution Log (`DESIGN_LOG.md`)"
Cohesion: 0.05
Nodes (41): 10. Stage A: Stop the Lag and Regressions, 11. Resource Diet — Stage 1: Baseline and Floor, 12. Resource Diet — Stage 2: Eager-Load Purge, 13. Resource Diet — Stage 3: Sleep and Suspend, 14. Resource Diet — Stage 4: Deep Idle Soak, 15. Resource Diet — Stage 5: Guardrails and Check Script, 1. Full Installed Skill Inventory, 2. Selected Skills for Notchify Design Phase & Rationale (+33 more)

### Community 18 - "CompanionSkin"
Cohesion: 0.11
Nodes (39): CGAffineTransform, Gradient, GraphicsContext, BatteryWidgetView, .fourSpaceView, .oneSpaceView, .twoSpaceView, Int (+31 more)

### Community 19 - "Sendable"
Cohesion: 0.08
Nodes (37): Codable, Decoder, Equatable, NWConnectionGroup, Sendable, LocalShareDiscovery, .activePeers, .isDiscoveryActive (+29 more)

### Community 20 - "LocalShareSettings"
Cohesion: 0.11
Nodes (21): LocalShareHistoryItem, LocalSharePeerTrustState, blocked, certificateChanged, trusted, unverifiedFirstContact, LocalShareSettings, .autoAcceptFavorites (+13 more)

### Community 21 - ".playClick"
Cohesion: 0.14
Nodes (16): NotesUIState, .selectedProvider, NotesWidgetView, .body, .charCount, .fourSpaceView, .oneSpaceView, .twoSpaceView (+8 more)

### Community 22 - "LocalShareIdentityManager"
Cohesion: 0.14
Nodes (14): OSStatus, P256, sec_identity_t, SecIdentity, ASN1, LocalShareIdentityManager, .certificateDER, .certificateFingerprint (+6 more)

### Community 23 - "AppTheme"
Cohesion: 0.05
Nodes (37): AppTheme, .accentColor, activeApp, adaptive, amethyst, aurora, .baseAccentRGB, .baseCanvasRGB (+29 more)

### Community 24 - "AppDelegate"
Cohesion: 0.09
Nodes (16): DispatchSourceSignal, NSApplicationDelegate, NSMenu, NSStatusItem, NSWindowDelegate, Selector, AppDelegate, .sharedDelegate (+8 more)

### Community 25 - "ModuleRegistry"
Cohesion: 0.14
Nodes (16): AnyObject, ModuleRegistry, .activeModule, .activeModuleId, .allOrderedModules, .isDashboardPinned, .orderedModules, Bool (+8 more)

### Community 26 - "NotchShellCoordinator"
Cohesion: 0.08
Nodes (26): Animation, CFTimeInterval, NSTrackingArea, .body, NotchShellCoordinator, .cachedExpandedRect, .isExpanded, .state (+18 more)

### Community 27 - "AirDropModule"
Cohesion: 0.07
Nodes (24): NSSharingService, NSSharingServicePicker, NSTextView, AirDropExpandedView, .body, AirDropModule, AirDropRadarAnimation, .body (+16 more)

### Community 28 - "SwiftUI"
Cohesion: 0.14
Nodes (9): AppKit, ApplicationServices, Combine, Darwin, IOKit.ps, LocalShare, SwiftUI, UniformTypeIdentifiers (+1 more)

### Community 29 - "View"
Cohesion: 0.15
Nodes (18): DashboardWidgetType, askAI, battery, calendar, clock, .icon, .id, mirror (+10 more)

### Community 30 - "runAllVerificationTests"
Cohesion: 0.13
Nodes (10): LocalShareModuleState, Bool, Double, Int64, String, URL, Void, UUID (+2 more)

### Community 31 - "LocalShareError"
Cohesion: 0.11
Nodes (19): LocalShareError, blockedByAnotherSession, checksumMismatch, connectionFailed, .errorDescription, fileCountExceeded, fileTooLarge, insufficientDiskSpace (+11 more)

### Community 32 - "SettingsCategory"
Cohesion: 0.08
Nodes (28): NSViewRepresentable, CursorTrackingState, PointerCursorModifier, SettingsCategory, appearance, companion, dashboard, feedback (+20 more)

### Community 33 - "DynamicThemeEngine"
Cohesion: 0.12
Nodes (16): CGContext, CGImage, .dynamicVibrancy, ColorDetectionDiagnostics, DynamicThemeEngine, MultiZonePalette, CGRect, Date (+8 more)

### Community 34 - "DesignSystem"
Cohesion: 0.09
Nodes (24): LinearGradient, .recentTransfersSection, DesignSystem, .accentColor, .appAccentColor, .canvasColor, .cardBorder, .cardFill (+16 more)

### Community 35 - "LocalShareFileManager"
Cohesion: 0.11
Nodes (17): LocalShareFileManager, .activeReceiveDirectory, .defaultReceiveDirectory, Bool, String, URL, LocalShareRateLimiter, LocalShareSecurity (+9 more)

### Community 36 - "BatteryModule"
Cohesion: 0.07
Nodes (27): CFRunLoopSource, ClosedRange, BatteryExpandedView, .body, BatteryModule, .batteryColor, .batteryIconName, .formattedTimeEstimate (+19 more)

### Community 37 - ".keySoundSectionView"
Cohesion: 0.15
Nodes (3): Double, .asmrSectionView, .keySoundSectionView

### Community 38 - "CompanionPanel"
Cohesion: 0.13
Nodes (14): NSHostingView, NSPanel, NSPoint, CompanionClickPanel, CompanionPanel, CreatureClickTargetView, .body, CreatureContainerView (+6 more)

### Community 39 - "Foundation"
Cohesion: 0.16
Nodes (9): AVFoundation, CoreImage, CryptoKit, Foundation, IOKit, LocalAuthentication, Network, PDFKit (+1 more)

### Community 40 - "CGFloat"
Cohesion: 0.32
Nodes (6): CustomNotchShape, LiveEqualizerIndicator, .body, NotchGlassBackground, Bool, CGFloat

### Community 41 - "UniversalTabDropDelegate"
Cohesion: 0.19
Nodes (11): DropDelegate, NSDragOperation, ScrollViewProxy, SpringLoadManager, Binding, Bool, DispatchWorkItem, DropInfo (+3 more)

### Community 42 - "KeychainHelper"
Cohesion: 0.14
Nodes (16): GitHub Security & Sensitive Data Hardening Audit, Hardware-Bound AES-256-GCM Vault Architecture, KeychainHelper, Bool, LAContext, Never, String, Task (+8 more)

### Community 43 - "DashboardSettingsView"
Cohesion: 0.16
Nodes (18): DashboardSettingsUIState, DashboardSettingsView, .body, .clockCustomizationSection, .layoutMiniPreviewSection, .layoutModeSelectionSection, DraggableWidgetPaletteCard, .body (+10 more)

### Community 44 - ".tint"
Cohesion: 0.20
Nodes (13): AdvancedSettingsSection, .body, SettingsView, .appearanceSection, .body, .companionSection, .detailHeaderBar, .geometrySection (+5 more)

### Community 45 - "Local Share Architecture & Design Specification (LocalSend Protocol Compatible)"
Cohesion: 0.05
Nodes (40): 1.1 Overview & Version Negotiation, 1.2 Default Ports & Multicast Addressing, 1.3 Cryptographic Identity, TLS & Certificate Fingerprint, 1.4 Discovery Architecture, 1.5 File Transfer Workflow (Upload API, README.md Section 4), 1. Protocol Specification Summary & Network Architecture, 2.1 Existing AirDropModule Architecture, 2.2 Local Share Architecture & Reuse Plan (+32 more)

### Community 46 - "NotificationModule"
Cohesion: 0.18
Nodes (9): NotificationItem, NotificationModule, NotificationModuleExpandedView, .body, AnyView, Bool, Date, String (+1 more)

### Community 47 - "Local Share — Stage 3: Security, Privacy & Energy Audit Report"
Cohesion: 0.05
Nodes (37): 10. Test Audit & Existing Verification Gaps, 11. Confirmed Vulnerabilities & Defects, 12. Suspected Vulnerabilities & False Positives, 13. Recommended Remediation Priority, 14. Audit Verification Statement, 15. Stage 4 Remediation Resolution (Post-Audit Status), 1. Executive Summary, 2. Exact Branch & Working-Tree State (+29 more)

### Community 48 - "Comprehensive Security Audit Report: Notchify (Notch) macOS"
Cohesion: 0.05
Nodes (36): 10. Audit Metrics & Final Verification Verdict, 1. Executive Summary & Top Risks, 2. Security Skill Coverage Matrix, 3. Attack Surface & Threat Model Summary, 4. Claims Verification Table, 5. Security Findings (Sorted by Severity & Phase), 6. Secrets and Credential Rotation List, 7. NEEDS MANUAL CHECK Protocol (+28 more)

### Community 49 - "Stage B: Small, Targeted Security Fixes (Per-Commit Execution)"
Cohesion: 0.06
Nodes (32): Bug Reports, Commit 10: SEC-B-2 — Delimit Note Context and Cap Prompt Length, Commit 11: SEC-A-4 — Clean Up Legacy Vault Files Post-Keychain Migration, Commit 12: SEC-E-1 — Enforce 0700 Permissions and Cleanup on Temp Cache, Commit 13: SEC-C-4 — Guard Process Signaling with PID Start-Time Validation, Commit 14: SEC-D-4 — Verify Info.plist Usage Descriptions Against Active APIs, Commit 15: SEC-F-2 — Expand Security Audit Script Checks Without Loosening Gates, Commit 16: SEC-A-1 & SEC-A-2 — Encrypt Notes and Contacts at Rest with CryptoKit AES-GCM (+24 more)

### Community 50 - "ObservableObject"
Cohesion: 0.17
Nodes (9): ObservableObject, LazyNotchModule, .isEnabled, .isLoaded, .loadedInstance, AnyView, Color, MainActor (+1 more)

### Community 51 - "CalendarModule"
Cohesion: 0.12
Nodes (24): EventKit, CalendarAdaptiveWidgetView, .body, CalendarCellData, CalendarEventItem, .color, CalendarHomeCardView, .body (+16 more)

### Community 52 - "Identifiable"
Cohesion: 0.06
Nodes (39): CaseIterable, Identifiable, ClockDialStyle, analog, digital, .id, .title, DashboardLayoutFlow (+31 more)

### Community 53 - "NotchRootView"
Cohesion: 0.28
Nodes (6): NotchRootView, .currentBottomRadius, .currentTopRadius, .isExpanded, .moduleHasInternalVerticalScroll, CGFloat

### Community 54 - "ResponsiveTabContent"
Cohesion: 0.23
Nodes (13): EnvironmentKey, EnvironmentValues, .notchCompact, .notchContentHeight, .notchTight, NotchCompactKey, NotchContentHeightKey, NotchTightKey (+5 more)

### Community 55 - "PermissionsHelper"
Cohesion: 0.18
Nodes (8): PermissionsHelper, .appBundleURL, .dynamicProjectDirectory, .executableURL, .standardAppPath, String, URL, .permissionsSection

### Community 56 - "4. Technical Deep-Dive per Remediation"
Cohesion: 0.07
Nodes (29): 10. Stage 4B — Functional Recovery & Keychain Stabilization, 11. Final Verification & Regression Status, 1. Operating Rules & Constraints Compliance, 2. Skills Evaluated & Applied, 3. Remediated Defects & Commit Summary, 4. Technical Deep-Dive per Remediation, 5. Compiler Warning Analysis, 7. Reviewer Feedback Remediation & Hardening (Issues A, B, C) (+21 more)

### Community 57 - "Notchify — Feature Matrix (Keep-and-Guard Inventory)"
Cohesion: 0.15
Nodes (12): 10. Geometry & Interaction Settings (`SettingsStore`), 11. Companion Mascot Settings (`SettingsStore`), 1. Appearance & Themes (`AppTheme`), 2. Dynamic Vibrancy (`DynamicVibrancy`), 3. Glass Material Styles (`GlassMaterialStyle`), 4. Corner Radii Styles (`NotchCornerStyle`), 5. Motion Physics Profiles (`MotionPhysicsStyle`), 6. Collapsed Compact Indicator Styles (`CompactIndicatorStyle`) (+4 more)

### Community 58 - "Notchify Comprehensive Engineering, Performance & Lifecycle Report (Round 5)"
Cohesion: 0.15
Nodes (12): 1. Removal of CLI Terminal from Thock Module, 1. Skill & Auditor Execution Table, 2. Issues Addressed in Round 5, 2. Status & Permission Tags Cleanup (Single-Appearance & Dismiss Cross Button), 3. Empirical Proof: Thock Termination Across All 6 Exit Paths, 3. Modernization of Native Keychain (Zero Deprecation Warnings), 4. Ground-Truth Memory & Thermal Metrics, 5. Architectural Boundaries & Operational Notes (+4 more)

### Community 59 - "LocalShareDiscoveryBootstrapDelegate"
Cohesion: 0.22
Nodes (10): CertBox, LocalShareDiscoveryBootstrapDelegate, .capturedCertificateDER, .capturedFingerprint, Data, URLAuthenticationChallenge, URLCredential, URLSession (+2 more)

### Community 60 - "NotchRootView.swift"
Cohesion: 0.13
Nodes (19): CompactBatteryIndicator, .body, CompactMediaIndicator, .body, CompactNotchIndicator, .body, .circadianIndicator, .dateTimeIndicator (+11 more)

### Community 61 - "ScreenRouteStage"
Cohesion: 0.18
Nodes (10): CoreGraphics, ScreenRouteStage, approachNotch, climbOntoRightLedge, farCornerPeek, leftWalk, lowerToHang, monkeyBarTraversal (+2 more)

### Community 62 - "Local Share — Stage 2: SwiftUI Module & Application Integration Report"
Cohesion: 0.10
Nodes (20): 10. Popover Lifecycle & Auto-Collapse Protection, 11. Energy & Resource Lifecycle, 12. Verification Tests Executed, 13. Compiler Warnings Audit, 14. Remaining Defects or Edge Cases, 15. Blockers & Decisions for User, 16. Manual Verification Instructions (Zero Automation / No App Launch), 17. Claims & Prohibited Terms Check (+12 more)

### Community 63 - "Bool"
Cohesion: 0.22
Nodes (7): AsmrLayerCard, .body, Bool, Color, Void, ThockPackMeta, .id

### Community 64 - "LocalShareSettingsView"
Cohesion: 0.33
Nodes (5): LocalShareSettingsUIState, LocalShareSettingsView, .body, Bool, String

### Community 65 - "CompactIndicatorStyle"
Cohesion: 0.20
Nodes (10): CompactIndicatorStyle, battery, circadian, dateTime, .icon, .id, media, minimal (+2 more)

### Community 66 - "OKLabColor"
Cohesion: 0.38
Nodes (3): ContrastGuard, OKLabColor, CGFloat

### Community 67 - "Architecture & Security Decisions (Stage D)"
Cohesion: 0.10
Nodes (20): Architecture & Security Decisions (Stage D), Context, Context, Context, Context & Risk, Context & Threat Model, Decision 1: App Sandbox Evaluation (SEC-D-1), Decision 2: Code Signing & Hardened Runtime (SEC-D-2 & SEC-F-1) (+12 more)

### Community 68 - "2. Per-Module Verification Checklist at Height = 200 pt"
Cohesion: 0.10
Nodes (19): 1. Height Sizing Sweep (Preferences > Geometry > Expanded Notch Height), 2. Per-Module Verification Checklist at Height = 200 pt, 3. First Hover vs Second Hover Verification, 4. Theme & Appearance Verification, 5. Needs Manual Check (Hardware / OS Dependent), A. Dashboard Home (`ModularDashboardView`), B. Thock Module (`ThockExpandedView`), C. Shelf & File Studio (`ShelfModuleExpandedView`) (+11 more)

### Community 69 - "main"
Cohesion: 0.47
Nodes (8): get_footprint(), get_top_stats(), main(), measure_time_to_open(), post_mouse_click(), post_mouse_move(), start(), stop()

### Community 70 - "run_stage4_soak.py"
Cohesion: 0.44
Nodes (8): get_footprint(), get_rss(), get_top_stats(), main(), post_mouse_click(), post_mouse_move(), start(), stop()

### Community 71 - "DottedDividerView"
Cohesion: 0.20
Nodes (10): Shape, DividerUIState, DottedDividerView, .body, FocusCompanionRotationManager, LineShape, Bool, CGFloat (+2 more)

### Community 72 - "measure_stage1.py"
Cohesion: 0.50
Nodes (7): format_agg(), get_process_metrics(), main(), post_mouse_click(), post_mouse_move(), start_notch(), stop_notch()

### Community 73 - "AIProvider"
Cohesion: 0.14
Nodes (17): AIChatMessage, AIProvider, .displayName, gemini, gpt, .icon, .id, .shortName (+9 more)

### Community 74 - "CompanionFrameStripStubs.swift"
Cohesion: 0.16
Nodes (9): CompanionClickPanel, CompanionCoordinator, CompanionPanel, .screen, .shared, SettingsStore, Bool, NSScreen (+1 more)

### Community 75 - "Notch Animated Desktop Companion"
Cohesion: 0.29
Nodes (7): Comprehensive Codebase Analysis Report, Notch Animated Desktop Companion, Zero-Overhead & 100% Privacy Invariants, Companion Behavior State Machine, Procedural SwiftUI Vector Animation Engine, Modular 4-Slot Bento Dashboard, Notchify macOS System Hub

### Community 76 - "3. Real User Complaints Resolution (C1 – C10)"
Cohesion: 0.12
Nodes (16): 1. Static Audit Discrepancies & Audit Errors Discovered, 2. Root-Cause Batch Evidence Matrix, 3. Real User Complaints Resolution (C1 – C10), 4. Human Verification Guide Index, 5. Skills & Standards Applied, C10: Old bugs came back after redesign (idle CPU, memory growth), C1: App is laggy/heavy; notch and Settings feel unresponsive, C2: Elements go past the notch panel border; big empty area at the bottom (+8 more)

### Community 77 - "VisualEffectBlur"
Cohesion: 0.48
Nodes (4): NSVisualEffectView, Context, NSView, VisualEffectBlur

### Community 79 - "Manual Check Guide: Battery Status Widget & Dashboard Layouts"
Cohesion: 0.12
Nodes (15): 1. Widget Span Verification (1, 2, and 4 Spaces), 2. Layout Flow & Preset Integration, 3. Hardware States & Desktop Mac Fallback, 4. Accessibility & Theme Compliance, Desktop Mac Test (Mac mini, Mac Studio, Mac Pro, iMac), Layout Flow Modes, Low Power Mode Test, MacBook Charger Connect / Disconnect Test (+7 more)

### Community 80 - "NotchPositionAttachment"
Cohesion: 0.12
Nodes (18): .displayPositionProfiles, NSScreen, CollapsedNotchMode, alwaysShowWings, hideBehindNotch, .icon, .id, .subtitle (+10 more)

### Community 81 - "Manual Verification Guide — Stage B Security Fixes"
Cohesion: 0.12
Nodes (15): 10. Note Context Delimitation & Length Capping (SEC-B-2), 11. Legacy Vault Migration & Cleanup (SEC-A-4), 12. Temp Directory Permissions & Purge (SEC-E-1), 13. Process Start-Time PID Reuse Guard (SEC-C-4), 14. Info.plist TCC Privacy Verification (SEC-D-4), 1. Applications Symlink Safety (SEC-E-2), 2. Child Process Environment Isolation (SEC-C-1), 3. Thock Cargo Build Supply-Chain Lock (SEC-C-2) (+7 more)

### Community 82 - "1. Feature Area Threat Registers (STRIDE)"
Cohesion: 0.13
Nodes (14): 1. Feature Area Threat Registers (STRIDE), 2. Verification of Claimed Mitigations (Code vs Claims), Area 10: Contacts & Calendar (`TelegramModule.swift`, `CalendarModule.swift`), Area 11: Build, Signing & Packaging (`run_notch.sh`), Area 1: Notes (`NoteStorageManager.swift`), Area 2: Ask AI (`AskAIService.swift`), Area 3: Telegram & Direct Messaging (`TelegramModule.swift`), Area 4: Thock Audio Engine (`ThockModule.swift`) (+6 more)

### Community 83 - "DesignSystem.swift"
Cohesion: 0.16
Nodes (12): Configuration, ImageIO, ButtonStyle, .spring, NotchCornerStyle, .bottomRadius, compact, continuous (+4 more)

### Community 84 - "Notch Cartoon Companion Specifications"
Cohesion: 0.33
Nodes (6): Climb-Over Animation Strip, Monkey-Bar Traversal Animation Strip, Clean Left-Peek Animation Strip, Clean Den Sleep Animation Strip, Clean Right Walk Animation Strip, Notch Cartoon Companion Specifications

### Community 85 - "benchmark_time_to_open.py"
Cohesion: 0.67
Nodes (5): get_window_height(), measure_open(), post_mouse_move(), start_notch(), stop_notch()

### Community 86 - "CustomTextEditor"
Cohesion: 0.21
Nodes (7): NSScrollView, NSTextViewDelegate, Coordinator, CustomTextEditor, Context, Coordinator, Notification

### Community 87 - "Local Share — Stage 1 Protocol Core Completion Report"
Cohesion: 0.15
Nodes (12): 1. Executive Summary, 2. Mandatory Skill Workflow Evaluation, 3. Protocol Specification Compliance, 4. Production Code Architecture, 5. Threat Model & Security Mitigations, 6. Verification Test Suite & Results, 7. Claims & Verification Matrix, 8. Stage 1 Sign-Off & Stage 2 Readiness (+4 more)

### Community 88 - "EnvironmentState"
Cohesion: 0.21
Nodes (9): ProcessInfo, EnvironmentState, .isolated, Bool, CGRect, NSObjectProtocol, String, NSScreen (+1 more)

### Community 89 - "Notchify Static Code Audit Report"
Cohesion: 0.17
Nodes (11): Concluding Summary, Flow 1: Notch Expansion Flow, Flow 2: Notch Collapse Flow, Notchify Static Code Audit Report, Section 10 — Unknowns & Required Context, Section 5 — Part 3: Global Module-to-Module Lifecycle Flows, Section 6 — Alternatives (Optimisation Thinking), Section 7 — Needs Manual Check List (+3 more)

### Community 90 - "measure_telemetry.py"
Cohesion: 0.70
Nodes (4): cleanup_notch(), main(), measure_scenario(), run_top_sample()

### Community 92 - "3. Detailed Batch Breakdown"
Cohesion: 0.17
Nodes (11): 1. Lag Analysis from Code (Addressing C1 & C10), 2. Interference Matrix (Batch x File x Shared State x Singleton), 3. Detailed Batch Breakdown, 4. Execution Sequence Checkpoint, Batch B1: Data and Crash Safety, Batch B2: Lag & Responsiveness (C1, C10), Batch B3: Correctness (C8, C9), Batch B4: Look & Layout (C2–C5) (+3 more)

### Community 93 - "test_thock_lifecycle.sh"
Cohesion: 0.83
Nodes (3): cleanup_all(), count_thock(), test_thock_lifecycle.sh script

### Community 94 - "3. Review Generator Scripts Audit (`review/scratch/*.py`)"
Cohesion: 0.17
Nodes (11): 1. Known Audit Input Files Status, 2. All Markdown Files under Repo Root & `review/`, 3. Review Generator Scripts Audit (`review/scratch/*.py`), Question Sources Inventory & Audit Trail, `review/scratch/build_better_way.py` (3 Hardcoded Finding Lines), `review/scratch/build_connections.py` (41 Hardcoded Finding Lines), `review/scratch/build_global.py` (5 Hardcoded Finding Lines), `review/scratch/build_hidden_edges.py` (0 Hardcoded Finding Lines) (+3 more)

### Community 95 - "Module Group E: Feature Modules"
Cohesion: 0.18
Nodes (11): File: `Sources/Modules/AI/AskAIWidgetView.swift`, File: `Sources/Modules/Companion/CompanionWindow.swift`, File: `Sources/Modules/NowPlaying/MediaRemoteBridge.swift`, File: `Sources/Modules/Shelf/ShelfModule.swift`, File: `Sources/Modules/Thock/ThockModule.swift`, Finding P1-AI-1: Plain SwiftUI `TextField` Lacks Key Window Focus and Hover Hold, Finding P1-COMP-1: Forceful `contentView = nil` in `CompanionPanel.teardown()`, Finding P1-MEDIA-1: Data Race on Mutable Artwork and Icon Caches in `@unchecked Sendable` Class (+3 more)

### Community 111 - "2. Human Verification Test Plan (NEEDS HUMAN CHECK)"
Cohesion: 0.20
Nodes (9): 1. Summary of Structural Changes Implemented, 2. Human Verification Test Plan (NEEDS HUMAN CHECK), 3. Metric Claims & Status, Manual Human Checks - Round 2 (Batches 1 & 2), Test Case 1: Notch Over Menu Bar & Full-Screen Spaces (Batch 1), Test Case 2: Settings Window Minimization & Non-Overlap (Batch 1), Test Case 3: Keychain Asynchronous Debounce (Batch 2), Test Case 4: Shelf Background Compression & Cancellation (Batch 2) (+1 more)

### Community 120 - "Attack Surface & System Architecture Map"
Cohesion: 0.20
Nodes (9): 1. Secrets & Credentials Inventory, 2. Data at Rest, 3. Data Leaving the Device (Egress Network & IPC), 4. Child Processes & Execution Table, 5. Dynamic Code & Framework Loading, 6. macOS Permissions & System Hooks, 7. File System Impact & Symlink Surface, 8. Build, Signing, and Hardening Configuration (+1 more)

### Community 121 - "Section 3 — Part 1: Per-File Review Findings"
Cohesion: 0.22
Nodes (9): File: `Sources/Notch/NotchShellCoordinator.swift`, File: `Sources/Notch/NotchWindow.swift`, File: `Sources/UI/DesignSystem.swift`, Finding P1-SHELL-1: Dead Appearance Preview Calls When Settings Window Is Open, Finding P1-UI-1: Incomplete Light Theme Adoption (164+ Hardcoded `.white` Literals Across Views), Finding P1-WIN-1: Local Key Monitor Never Receives Esc Key When Notch Is Hover-Expanded, Module Group B: UI & Theme System, Module Group C: Notch Shell & Windowing (+1 more)

### Community 122 - "Notchify Fix Execution Log"
Cohesion: 0.22
Nodes (8): Batch B1 Entry: Data & Crash Safety, Batch B2 Entry: Lag & Responsiveness, Batch B3 Entry: Correctness, Batch B4 Entry: Look & Layout, Batch B5 Entry: Interactions & Dividers, Batch B6 Entry: Cleanup & Verification, Notchify Fix Execution Log, Skills Re-Pick Log

### Community 123 - "Diagnostic Findings"
Cohesion: 0.22
Nodes (9): a. Expanded Width/Height Computation: `calculateFrame` vs `NotchRootView`, b. Physical Notch Inset & Top Padding Derivation, c. First-Hover Trace in `onMouseEnter` & `cachedExpandedRect`, d. First-Hover vs Second-Hover Path Comparison, Diagnostic Findings, e. Animated Frame Change & Intermediate Layouts, f. Content with Fixed Height That Can Overflow, Round 2 Phase 0 (Expanded Notch Layout & Geometry Diagnosis) (+1 more)

### Community 124 - "Diagnostic Findings"
Cohesion: 0.22
Nodes (9): a. Expanded Width/Height Computation: `calculateFrame` vs `NotchRootView`, b. Physical Notch Inset & Top Padding Derivation, c. First-Hover Trace in `onMouseEnter` & `cachedExpandedRect`, d. First-Hover vs Second-Hover Path Comparison, Diagnostic Findings, e. Animated Frame Change & Intermediate Layouts, f. Content with Fixed Height That Can Overflow, Round 2 Phase 0 (Expanded Notch Layout & Geometry Diagnosis) (+1 more)

### Community 125 - "Responsive Notch Tabs (200 pt) & Event-Driven Battery Widget Report"
Cohesion: 0.22
Nodes (8): 1. Root Causes of 200 pt Clipping (Pre-Fix Analysis), 2. Exact File Changes & Line Counts, 3. Test Evidence, 4. Known Compromises & Deliberate Architectural Decisions, Phase 1: Shared Responsive Container & Tab Adaptation (Commit `59f49d0`), Phase 2: Event-Driven Battery Status Widget & Presets (Commit `d6eba95`), Phase 3: Headless Verification Tests & Knowledge Graph, Responsive Notch Tabs (200 pt) & Event-Driven Battery Widget Report

### Community 126 - "2. Specific Check Results"
Cohesion: 0.22
Nodes (8): 1. Findings Verification Matrix, 2. Specific Check Results, Check 1: SEC-D-4 (Contacts & Microphone), Check 2: SEC-B-1 (Telegram Bot Token Exposure), Check 3: SEC-D-1 (App Sandbox Breakage Inventory), Check 4: SEC-E-2 (Destructive Applications Symlinking), Check 5: Git History Diff & Secret Scan, Verified Security Findings Table (Stage 0 Re-Verification)

### Community 127 - "Manual Verification Steps: Expanded Notch Layout & Geometry Synchronization"
Cohesion: 0.25
Nodes (7): Check 1: First Hover vs Second Hover Layout Parity, Check 2: Top Bezel & Camera Cutout Clear Zone (No Top Clipping), Check 3: Calendar Widget Full 6-Row Visibility (No Bottom Clipping), Check 4: Settings Width & Height Extremes Follow-Through, Check 5: Secondary Module Tabs (Shelf, Notes, AirDrop, Battery, Notifications), Check 6: Display Without a Hardware Notch (External Monitor / iMac), Manual Verification Steps: Expanded Notch Layout & Geometry Synchronization

### Community 128 - "Notchify Position & Bezel Integration Execution Log"
Cohesion: 0.25
Nodes (7): 1. Window Inventory & B4 Git Diff, 2. Frame Math Tracing, 3. Hypothesis Confirmation & Root Cause, 4. Consumers of Notch Position, Notchify Position & Bezel Integration Execution Log, Phase 0: Diagnosis Notes, Skills Re-Pick Log

### Community 129 - "Round 2 Phase 1: Expanded Notch Single Source of Truth & Zero-Clipping Implementation"
Cohesion: 0.25
Nodes (8): 1. Pure Function: `NotchGeometry.expandedLayout`, 2. Elimination of Hardcoded 225pt Clamps, 3. First-Hover Sizing & Layout Race Elimination, 4. Zero Calendar Clipping & Adaptive Card Layout, 5. Invalidation & Observer Refresh, 6. Verification Status, Round 2 Phase 1: Expanded Notch Single Source of Truth & Zero-Clipping Implementation, Skills Re-Pick Log

### Community 130 - "Round 2 Phase 1: Expanded Notch Single Source of Truth & Zero-Clipping Implementation"
Cohesion: 0.25
Nodes (8): 1. Pure Function: `NotchGeometry.expandedLayout`, 2. Elimination of Hardcoded 225pt Clamps, 3. First-Hover Sizing & Layout Race Elimination, 4. Zero Calendar Clipping & Adaptive Card Layout, 5. Invalidation & Observer Refresh, 6. Verification Status, Round 2 Phase 1: Expanded Notch Single Source of Truth & Zero-Clipping Implementation, Skills Re-Pick Log

### Community 131 - "Notchify macOS Security Remediation Final Report"
Cohesion: 0.25
Nodes (7): Architectural Security Invariants Established, Associated Security Artifacts, Detailed Findings & Fix Verification Matrix, Executive Summary, Notchify macOS Security Remediation Final Report, Remediation Summary & Commits, Test Verification Summary

### Community 132 - "Module Group A: App & Core"
Cohesion: 0.29
Nodes (7): File: `Sources/App/AppDelegate.swift`, File: `Sources/Core/ModuleRegistry.swift`, File: `Sources/Core/PermissionsHelper.swift`, Finding P1-APP-1: Non-Persistent Instances for Secondary Lazy Modules, Finding P1-PERM-1: Dangerous Attempted Symlink Deletion in System `/Applications` on Every Launch, Finding P1-REG-1: `orderedModules` Excludes Disabled Modules Causing Permanent Disappearance in Settings, Module Group A: App & Core

### Community 133 - "Phase 1 Manual Verification Steps: Collapsed Notch Width Model & Event-Driven Wings"
Cohesion: 0.29
Nodes (6): Check 1: Default "Hide Behind Notch" Mode (Zero Visible Pixels Outside Cutout), Check 2: Pass-Through Hit-Testing (Menu Bar Items Beside Notch Are Fully Clickable), Check 3: "Wings on Events" Dynamic Slide-Out and Retraction, Check 4: "Always Show Wings" & Elimination of Opposing-Pole Empty Void, Check 5: Display Without a Hardware Notch (External Display / iMac), Phase 1 Manual Verification Steps: Collapsed Notch Width Model & Event-Driven Wings

### Community 134 - "Round 2 Phase 1: One Collapsed-Layout Model Implementation"
Cohesion: 0.29
Nodes (7): 1. Pure Function: `NotchGeometry.collapsedLayout`, 2. Collapsed Notch Modes Supported, 3. Keep-and-Guard All 6 Compact Styles, 4. Zero Click-Blocking Hit Testing, 5. Verification Status, Round 2 Phase 1: One Collapsed-Layout Model Implementation, Skills Re-Pick Log

### Community 135 - "Responsive Notch & Battery Widget Implementation Log"
Cohesion: 0.29
Nodes (6): Phase 0 - Skill Selection & Diagnosis Logging, Phase 1 - Skill Selection & Implementation Logging, Phase 2 - Skill Selection & Implementation Logging, Phase 2 - Skill Selection & Implementation Logging, Phase 3 - Skill Selection & Headless Verification Logging, Responsive Notch & Battery Widget Implementation Log

### Community 136 - "Manual Verification Guide — Stage C: Notes & Contacts At-Rest Encryption (SEC-A-1 & SEC-A-2)"
Cohesion: 0.29
Nodes (6): 1. At-Rest Encryption Verification (SEC-A-1: Notes), 2. At-Rest Encryption Verification (SEC-A-2: Contacts), 3. Seamless Legacy Plaintext Migration, 4. Tamper Detection & Integrity Verification, 5. Keychain Key Protection, Manual Verification Guide — Stage C: Notes & Contacts At-Rest Encryption (SEC-A-1 & SEC-A-2)

### Community 137 - "Phase 0 Coverage & Ingest Verification Report"
Cohesion: 0.33
Nodes (5): 1. Executive Metrics, 2. Source File Resolution Audit, 3. Random Sample Verification Audit (10 QIDs Re-opened from Disk), 4. Key Phase 0 Ground Truth Deductions, Phase 0 Coverage & Ingest Verification Report

### Community 138 - "Batch B3 Manual Verification Steps"
Cohesion: 0.33
Nodes (5): Batch B3 Manual Verification Steps, Check 1: Settings Module Visibility & Toggle Responsiveness (P1-REG-1, P1-SET-1), Check 2: Esc Key Dismissal (P1-WIN-1, C8), Check 3: Notes & Ask AI Keyboard Focus & Auto-Collapse Inhibition (C8), Check 4: Thock Process Lifecycle & Rapid Toggle Race (P1-THOCK-1, C9)

### Community 139 - "Batch B4 Manual Verification Steps"
Cohesion: 0.33
Nodes (5): Batch B4 Manual Verification Steps, Check 1: Panel Boundary Containment & Adaptive Content Height (C2), Check 2: Sakura and Birch Light Themes Readability (C3), Check 3: Visually Distinct Glass Styles (C4), Check 4: Settings Window Minimization & Notch Leveling (C5)

### Community 140 - "Round 2 Phase 0: Width Model & Indicator Sizing Diagnosis"
Cohesion: 0.33
Nodes (6): 1. Table of Collapsed Window Width and Height (Phase 0.1), 2. Root Cause of the Wide Pill with Opposing Poles (Phase 0.2), 3. Window Sizing, Hit-Testing, Menu Bar Blocking & Mascot Collision (Phase 0.3), 4. Inventory of All Consumers of the Collapsed Rect (Phase 0.4), Round 2 Phase 0: Width Model & Indicator Sizing Diagnosis, Skills Re-Pick Log

### Community 141 - "Phase 1: Root Cause Fix Implementation"
Cohesion: 0.33
Nodes (6): 1. Window Level & Frame Constraints, 2. Settings Window Decoupling & Focus Overlap Prevention, 3. Hardware Notch Centering & Flush Top Math, 4. Bezel Merging Shape & Compact Wings, 5. Verification Status, Phase 1: Root Cause Fix Implementation

### Community 142 - "DynamicVibrancy"
Cohesion: 0.33
Nodes (6): DynamicVibrancy, balanced, .factor, .id, punchy, subtle

### Community 143 - "1. Connection Findings"
Cohesion: 0.40
Nodes (5): 1. Connection Findings, 2. Suspicious Pattern Analysis ("If This Line Exists, This Bug Must Exist"), Finding P2-CONN-1: `SettingsView.swift` -> `ModuleRegistry.swift`, Finding P2-CONN-2: `NotchShellCoordinator.swift` -> `MirrorModule.swift`, Section 4 — Part 2: File-to-File Connections & Suspicious Patterns

### Community 144 - "Module Group D: Settings & Dashboard"
Cohesion: 0.40
Nodes (5): File: `Sources/Notch/ModularDashboardView.swift`, File: `Sources/Settings/SettingsView.swift`, Finding P1-DASH-1: 120-Line `DottedDividerView` Completely Unused in View Hierarchy, Finding P1-SET-1: Interactive Toggles Wrapped Inside Button Actions Producing Double-Flip, Module Group D: Settings & Dashboard

### Community 145 - "Audit Errors & Misleading Findings Catalog"
Cohesion: 0.40
Nodes (4): 1. Path & Line Citation Errors in `review/BETTER_WAY.md`, 2. Erroneous / Exaggerated Claims in `AUDIT_REPORT.md`, 3. Templated / Hardcoded Finding Text in Review Generator Scripts, Audit Errors & Misleading Findings Catalog

### Community 146 - "Manual Verification Guide: Batch B1 (Data & Crash Safety)"
Cohesion: 0.40
Nodes (4): Check 1: User QuickNotes Preservation During Test Runs, Check 2: Zero Keystroke Freezes on AI Key / Bot Token Entry, Check 3: Companion Panel Teardown Without AppKit Crash, Manual Verification Guide: Batch B1 (Data & Crash Safety)

### Community 147 - "Manual Verification Guide: Batch B2 (Lag & Responsiveness)"
Cohesion: 0.40
Nodes (4): Check 1: Idle CPU & Energy Consumption with Dormant Mascot, Check 2: App Launch Speed & Zero Startup Hang, Check 3: Immediate Companion Wakeup on Notch Expand, Manual Verification Guide: Batch B2 (Lag & Responsiveness)

### Community 148 - "Batch B5 Manual Verification Steps"
Cohesion: 0.40
Nodes (4): Batch B5 Manual Verification Steps, Check 1: Slot Width Adjustment in Settings Canvas ONLY (C6), Check 2: Direct Dock Tab Drag-to-Reorder in Live Notch (C7), Check 3: File Drops & Spring-Loaded Hover Preservation

### Community 149 - "Master Question Bank — Round 2 Closure Table"
Cohesion: 0.40
Nodes (4): 1. Per-Source Extraction Counts, 2. Master Closure Table, 3. NOT FIXED Backlog (Direct Inputs for Round 2 Batches), Master Question Bank — Round 2 Closure Table

### Community 150 - "Step 0 — Security Audit Skill Selection & Applicability"
Cohesion: 0.40
Nodes (4): 1. Primary Security Skills & macOS Applicability, 2. Supporting Technical Skills Chosen, Security Skill Log, Step 0 — Security Audit Skill Selection & Applicability

### Community 151 - "Section 2 — Graph Inventory & Architecture Topology"
Cohesion: 0.50
Nodes (4): 1. File & Module Count, 2. God Objects Identified by Graph Fan-In / Fan-Out, 3. Active Runtime Primitives, Section 2 — Graph Inventory & Architecture Topology

### Community 152 - "Batch B6 Manual Verification Steps"
Cohesion: 0.50
Nodes (3): Batch B6 Manual Verification Steps, Check 1: Smooth Single Teardown on Notch Collapse, Check 2: Clean Launch Without Permissions Errors

### Community 153 - "Notchify Behavior & Invariant Contract (Stage A)"
Cohesion: 0.50
Nodes (3): 1. Finding-to-Contract Mapping Matrix, 2. Baseline Test Suite Verification Record, Notchify Behavior & Invariant Contract (Stage A)

## Knowledge Gaps
- **986 isolated node(s):** `PackageDescription`, `.sharedDelegate`, `keyMissing`, `keychainSaveFailed`, `verificationFailed` (+981 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `View` to `ShelfModule`, `TelegramModule`, `LocalShareModule`, `MediaRemoteBridge`, `MirrorModule`, `ThockModule`, `SkeletonPose`, `ClockWidgetView`, `String`, `CompanionSkin`, `.playClick`, `ModuleRegistry`, `AirDropModule`, `SettingsCategory`, `BatteryModule`, `CompanionPanel`, `CGFloat`, `DashboardSettingsView`, `.tint`, `NotificationModule`, `CalendarModule`, `NotchRootView`, `ResponsiveTabContent`, `NotchRootView.swift`, `Bool`, `LocalShareSettingsView`, `DottedDividerView`, `DesignSystem.swift`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Why does `LocalShareModule` connect `LocalShareModule` to `LocalShareClientSession`, `LocalShareSession`, `Sendable`, `LocalShareSettings`, `ModuleRegistry`, `SwiftUI`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Why does `NotchModule` connect `ModuleRegistry` to `ShelfModule`, `TelegramModule`, `BatteryModule`, `LocalShareModule`, `MirrorModule`, `ThockModule`, `UniversalTabDropDelegate`, `NotificationModule`, `ObservableObject`, `NotchRootView`, `AirDropModule`, `SwiftUI`, `View`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Are the 70 inferred relationships involving `runAllVerificationTests()` (e.g. with `CIContext` and `NSPoint`) actually correct?**
  _`runAllVerificationTests()` has 70 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `.sharedDelegate`, `keyMissing` to the rest of the system?**
  _986 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ShelfModule` be split into smaller, more focused modules?**
  _Cohesion score 0.051831501831501835 - nodes in this community are weakly interconnected._
- **Should `KinematicEngine` be split into smaller, more focused modules?**
  _Cohesion score 0.0626858842370167 - nodes in this community are weakly interconnected._