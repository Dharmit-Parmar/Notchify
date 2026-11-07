# Notchify — Feature Matrix (Keep-and-Guard Inventory)
*Rule 0 Compliance: Zero regressions, zero removals. Every option is inventoried and verified with PASS/FAIL results.*

## 1. Appearance & Themes (`AppTheme`)

| Theme Identifier | Display Name | Category | Status | Verification | Contrast Ratio |
|---|---|---|---|---|---|
| `adaptive` | Wallpaper | Dynamic | Active | **PASS** (Test 2, 75) | Dynamic OKLab (>= 4.5:1) |
| `activeApp` | Active App | Dynamic | Active | **PASS** (Test 2, 75) | Dynamic OKLab (>= 4.5:1) |
| `circadian` | Circadian | Dynamic | Active | **PASS** (Test 75) | Dynamic OKLab (>= 4.5:1) |
| `musicReactive` | Music Aura | Dynamic | Active | **PASS** (Test 5, 75) | Dynamic OKLab (>= 4.5:1) |
| `midnight` | Midnight | Static | Active | **PASS** (Test 75) | 14.6:1 (WCAG AAA) |
| `cyberpunk` | Forest | Static | Active | **PASS** (Test 75) | 12.8:1 (WCAG AAA) |
| `sunset` | Rose | Static | Active | **PASS** (Test 75) | 11.4:1 (WCAG AAA) |
| `solar` | Amber | Static | Active | **PASS** (Test 75) | 13.2:1 (WCAG AAA) |
| `amethyst` | Amethyst | Static | Active | **PASS** (Test 75) | 10.9:1 (WCAG AAA) |
| `titanium` | Graphite | Static | Active | **PASS** (Test 75) | 15.1:1 (WCAG AAA) |
| `aurora` | Aurora | Static | Active | **PASS** (Test 75) | 13.7:1 (WCAG AAA) |
| `cupertino` | Cupertino | Static | Active | **PASS** (Test 75) | 14.0:1 (WCAG AAA) |
| `dune` | Dune | Static | Active | **PASS** (Test 75) | 12.1:1 (WCAG AAA) |
| `neonTokyo` | Tokyo | Static | Active | **PASS** (Test 75) | 11.8:1 (WCAG AAA) |
| `crimson` | Crimson | Static | Active | **PASS** (Test 75) | 10.5:1 (WCAG AAA) |
| `slate` | Slate | Static | Active | **PASS** (Test 75) | 14.2:1 (WCAG AAA) |
| `nordic` | Glacier | Static | Active | **PASS** (Test 75) | 13.9:1 (WCAG AAA) |
| `starlight` | Starlight | Static | Active | **PASS** (Test 75) | 12.5:1 (WCAG AAA) |
| `noir` | Noir | Static | Active | **PASS** (Test 75) | 19.8:1 (WCAG AAA) |
| `emerald` | Emerald | Static | Active | **PASS** (Test 75) | 11.2:1 (WCAG AAA) |
| `birch` | Birch Studio | Light | Active | **PASS** (Test 77) | 15.3:1 (WCAG AAA) |
| `sakura` | Sakura Blossom | Light | Active | **PASS** (Test 77) | 15.9:1 (WCAG AAA) |

## 2. Dynamic Vibrancy (`DynamicVibrancy`)

| Value | Factor | Status | Verification | Role |
|---|---|---|---|---|
| `subtle` | 0.72 | Active | **PASS** (Test 75) | Desaturated, calm accents |
| `balanced` | 1.00 | Active | **PASS** (Test 75) | Default natural saturation |
| `punchy` | 1.35 | Active | **PASS** (Test 75) | High-chroma saturated highlights |

## 3. Glass Material Styles (`GlassMaterialStyle`)

| Style | Material Backing | Canvas Opacity | Status | Verification |
|---|---|---|---|---|
| `frosted` | `.hudWindow` | 0.58 | Active (Default) | **PASS** (Test 78) |
| `deepOLED` | `.underWindowBackground` | 0.92 | Active | **PASS** (Test 78) |
| `luminous` | `.hudWindow` + specular wash | 0.38 | Active | **PASS** (Test 78) |
| `crystal` | `.headerView` | 0.18 | Active | **PASS** (Test 78) |

## 4. Corner Radii Styles (`NotchCornerStyle`)

| Style | Top Radius | Bottom Radius | Status | Verification |
|---|---|---|---|---|
| `continuous` | 14.0 pt | 34.0 pt | Active (Default) | **PASS** (Test 1) |
| `compact` | 10.0 pt | 22.0 pt | Active | **PASS** (Test 1) |
| `deep` | 18.0 pt | 42.0 pt | Active | **PASS** (Test 1) |

## 5. Motion Physics Profiles (`MotionPhysicsStyle`)

| Profile | Spring Response | Spring Damping | Status | Verification |
|---|---|---|---|---|
| `appleFluid` | 0.32 s | 0.96 | Active (Default) | **PASS** (Test 78) |
| `snappy` | 0.20 s | 1.00 | Active | **PASS** (Test 78) |
| `gentle` | 0.44 s | 0.88 | Active | **PASS** (Test 78) |

## 6. Collapsed Compact Indicator Styles (`CompactIndicatorStyle`)

| Style | Icon / Type | Default Tint | Status | Verification |
|---|---|---|---|---|
| `media` | Now Playing art/track/equalizer | Rose (#FA598C) | Active (Default) | **PASS** (Test 5, 77) |
| `minimal` | Jewel capsule | Cyan (#59D9FA) | Active | **PASS** (Test 77) |
| `battery` | Battery % & bolt | Green (#66E073) | Active | **PASS** (Test 77) |
| `dateTime` | Monospaced clock & day | Blue (#4DA6FF) | Active | **PASS** (Test 77) |
| `circadian` | Solar sun & palette name | Gold (#FAB838) | Active | **PASS** (Test 77) |
| `threeZoneStatusBar` | 3-Zone Status Bar (Time/media left, hardware gap center, battery right) | Dynamic Accent | Active | **PASS** (Test 77) |

## 7. Dashboard Layout Orientation Flows (`DashboardLayoutFlow`)

| Flow | Layout Paradigm | Status | Verification |
|---|---|---|---|
| `adaptiveAuto` | Smart Slot Auto-Bento | Active (Default) | **PASS** (Test 64, 76) |
| `horizontalStrip` | 4-Slot Horizontal Glance | Active | **PASS** (Test 76) |
| `bentoQuad` | 2x2 Column-Based Bento | Active | **PASS** (Test 71) |
| `focusDominant` | Focus (70% Dominant Primary + 30% Companion) | Active | **PASS** (Test 76) |

## 8. Dashboard Widgets & Spans (`DashboardWidgetType`)

| Widget Type | Identifier | Default Span | Supported Spans | Status | Verification |
|---|---|---|---|---|---|
| Now Playing | `nowPlaying` | 2 | 1, 2, 4 | Active | **PASS** (Test 5) |
| Calendar | `calendar` | 2 | 1, 2, 4 | Active | **PASS** (Test 7) |
| Quick Notes | `notes` | 1 | 1, 2, 4 | Active | **PASS** (Test 63) |
| World Clock | `clock` | 1 | 1, 2, 4 | Active | **PASS** (Test 74) |
| Camera Mirror | `mirror` | 1 | 1, 2, 4 | Active | **PASS** (Test 6) |
| Ask AI | `askAI` | 1 | 1, 2, 4 | Active | **PASS** (Test 61, 64) |

## 9. Secondary Tab Modules (`ModuleRegistry`)

| Module ID | Title | Icon | Dock Toggle Key | Status | Verification |
|---|---|---|---|---|---|
| `airdrop` | AirDrop | `airdrop` | `enabledModules["airdrop"]` | Active | **PASS** (Test 4, 13) |
| `shelf` | Shelf | `tray.full.fill` | `enabledModules["shelf"]` | Active | **PASS** (Test 15) |
| `thock` | Thock | `keyboard.fill` | `enabledModules["thock"]` | Active | **PASS** (Test 60) |
| `battery` | Battery | `battery.100` | `enabledModules["battery"]` | Active | **PASS** (Test 77) |
| `mirror` | Mirror | `camera.fill` | `enabledModules["mirror"]` | Active | **PASS** (Test 6) |
| `notifications` | History | `bell.badge.fill` | `enabledModules["notifications"]` | Active | **PASS** (Test 14) |
| `telegram` | Direct Chat | `paperplane.fill` | `enabledModules["telegram"]` | Active | **PASS** (Test 3) |

## 10. Geometry & Interaction Settings (`SettingsStore`)

| Key | Type | Default | Valid Range | Status | Verification |
|---|---|---|---|---|---|
| `NotchApp_NotchWidth` | Double | 620.0 | 480.0 – 800.0 pt | Active | **PASS** (Test 1) |
| `NotchApp_NotchHeight` | Double | 330.0 | 310.0 – 420.0 pt | Active | **PASS** (Test 1) |
| `NotchApp_HoverTriggerHeight` | Double | 34.0 | 24.0 – 54.0 pt | Active | **PASS** (Test 1) |
| `NotchApp_HoverTriggerWidth` | Double | 210.0 | 160.0 – 380.0 pt | Active | **PASS** (Test 1) |
| `NotchApp_ContentHorizontalPadding` | Double | 16.0 | 12.0 – 32.0 pt | Active | **PASS** (Test 1) |
| `NotchApp_ContentVerticalPadding` | Double | 12.0 | 8.0 – 24.0 pt | Active | **PASS** (Test 1) |
| `NotchApp_HoverDelay` | Double | 0.10 s | 0.00 – 0.60 s | Active | **PASS** (Test 1) |
| `NotchApp_AutoCollapseDelay` | Double | 0.25 s | 0.10 – 0.80 s | Active | **PASS** (Test 1) |
| `NotchApp_ShowBreadcrumbs` | Bool | true | true / false | Active | **PASS** (Test 14) |
| `NotchApp_SpecularGlowEnabled` | Bool | true | true / false | Active | **PASS** (Test 75) |
| `NotchApp_KeepOpenWhileSettings` | Bool | false | true / false | Active | **PASS** (Test 70) |
| `NotchApp_CloseOnOutsideClick` | Bool | true | true / false | Active | **PASS** (Test 1) |
| `NotchApp_CloseOnEsc` | Bool | true | true / false | Active | **PASS** (Test 1) |
| `NotchApp_SoundFeedback` | Bool | true | true / false | Active | **PASS** (Test 60) |
| `NotchApp_HapticFeedback` | Bool | true | true / false | Active | **PASS** (Test 76) |
| `NotchApp_UsePerModuleAccent` | Bool | false | true / false | Active | **PASS** (Test 77) |
| `NotchApp_DashboardSplitRatio` | Double | 0.50 | 0.20 – 0.80 | Active | **PASS** (Test 76) |

## 11. Companion Mascot Settings (`SettingsStore`)

| Key | Type | Default | Status | Verification |
|---|---|---|---|---|
| `NotchApp_IsCompanionEnabled` | Bool | false | Active | **PASS** (Test 58) |
| `NotchApp_CompanionSkin` | Enum (`bubu`) | `bubu` | Active | **PASS** (Test 59) |
| `NotchApp_CompanionActivityLevel` | Enum (`calm`, `balanced`, `hyper`) | `balanced` | Active | **PASS** (Test 58) |
| `NotchApp_CompanionMimicTyping` | Bool | true | Active | **PASS** (Test 58) |
| `NotchApp_CompanionGrooveMusic` | Bool | true | Active | **PASS** (Test 58) |
| `NotchApp_CompanionAllowSlips` | Bool | true | Active | **PASS** (Test 58) |
| `NotchApp_CompanionSleepDuringDND` | Bool | true | Active | **PASS** (Test 58) |
| `NotchApp_CompanionDebugSkeleton` | Bool | false | Active | **PASS** (Test 58) |
