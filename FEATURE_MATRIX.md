# Notchify — Feature Matrix (Keep-and-Guard Inventory)
*Rule 0 Compliance: Zero regressions, zero removals. Every option is inventoried and verified.*

## 1. Appearance & Themes (`AppTheme`)

| Theme Identifier | Display Name | Category | Status | Notes |
|---|---|---|---|---|
| `adaptive` | Wallpaper | Dynamic | Active | Dynamic Wallpaper & App Glass |
| `activeApp` | Active App | Dynamic | Active | Foreground app icon colors |
| `circadian` | Circadian | Dynamic | Active | Solar cycle (Dawn, Day, Golden, Night) |
| `musicReactive` | Music Aura | Dynamic | Active | Real-time album art palette |
| `midnight` | Midnight | Static | Active | Deep blue obsidian |
| `cyberpunk` | Forest | Static | Active | Emerald cyber tone |
| `sunset` | Rose | Static | Active | Crimson sunset |
| `solar` | Amber | Static | Active | Golden solar tone |
| `amethyst` | Amethyst | Static | Active | Deep purple violet |
| `titanium` | Graphite | Static | Active | Industrial monochrome |
| `aurora` | Aurora | Static | Active | Polar teal aurora |
| `cupertino` | Cupertino | Static | Active | Apple system electric blue |
| `dune` | Dune | Static | Active | Desert warm sandstone |
| `neonTokyo` | Tokyo | Static | Active | High-contrast magenta |
| `crimson` | Crimson | Static | Active | Velvet deep red |
| `slate` | Slate | Static | Active | Neutral studio slate |
| `nordic` | Glacier | Static | Active | Frosted polar cyan |
| `starlight` | Starlight | Static | Active | Champagne warm gold |
| `noir` | Noir | Static | Active | High-contrast OLED dark |
| `emerald` | Emerald | Static | Active | Deep forest jewel |
| `birch` | Birch Studio | Light | Active | Warm paper (#F7F5F0), charcoal text, amber accent (Contrast 15.3:1) |
| `sakura` | Sakura Blossom | Light | Active | Soft pastel (#FDF6F7), plum text, blossom accent (Contrast 15.9:1) |

## 2. Dynamic Vibrancy (`DynamicVibrancy`)

| Value | Factor | Status | Role |
|---|---|---|---|
| `subtle` | 0.72 | Active | Desaturated, calm accents |
| `balanced` | 1.00 | Active | Default natural saturation |
| `punchy` | 1.35 | Active | High-chroma saturated highlights |

## 3. Glass Material Styles (`GlassMaterialStyle`)

| Style | Material Backing | Canvas Opacity | Status |
|---|---|---|---|
| `frosted` | `.hudWindow` | 0.58 | Active (Default) |
| `deepOLED` | `.underWindowBackground` | 0.92 | Active |
| `luminous` | `.hudWindow` + specular wash | 0.38 | Active |
| `crystal` | `.headerView` | 0.18 | Active |

## 4. Corner Radii Styles (`NotchCornerStyle`)

| Style | Top Radius | Bottom Radius | Status |
|---|---|---|---|
| `continuous` | 14.0 pt | 34.0 pt | Active (Default) |
| `compact` | 10.0 pt | 22.0 pt | Active |
| `deep` | 18.0 pt | 42.0 pt | Active |

## 5. Motion Physics Profiles (`MotionPhysicsStyle`)

| Profile | Spring Response | Spring Damping | Status |
|---|---|---|---|
| `appleFluid` | 0.32 s | 0.96 | Active (Default) |
| `snappy` | 0.20 s | 1.00 | Active |
| `gentle` | 0.44 s | 0.88 | Active |

## 6. Collapsed Compact Indicator Styles (`CompactIndicatorStyle`)

| Style | Icon / Type | Default Tint | Status |
|---|---|---|---|
| `media` | Now Playing art/track/equalizer | Rose (#FA598C) | Active (Default) |
| `minimal` | Jewel capsule | Cyan (#59D9FA) | Active |
| `battery` | Battery % & bolt | Green (#66E073) | Active |
| `dateTime` | Monospaced clock & day | Blue (#4DA6FF) | Active |
| `circadian` | Solar sun & palette name | Gold (#FAB838) | Active |
| `threeZoneStatusBar` | 3-Zone Status Bar (Time/media left, hardware gap center, battery right) | Dynamic Accent | Active |

## 7. Dashboard Layout Orientation Flows (`DashboardLayoutFlow`)

| Flow | Layout Paradigm | Status |
|---|---|---|
| `adaptiveAuto` | Smart Slot Auto-Bento | Active (Default) |
| `horizontalStrip` | 4-Slot Horizontal Glance | Active |
| `bentoQuad` | 2x2 Column-Based Bento | Active |
| `focusDominant` | Focus (70% Dominant Primary + 30% Companion) | Active |

## 8. Dashboard Widgets & Spans (`DashboardWidgetType`)

| Widget Type | Identifier | Default Span | Supported Spans | Status |
|---|---|---|---|---|
| Now Playing | `nowPlaying` | 2 | 1, 2, 4 | Active |
| Calendar | `calendar` | 2 | 1, 2, 4 | Active |
| Quick Notes | `notes` | 1 | 1, 2, 4 | Active |
| World Clock | `clock` | 1 | 1, 2, 4 | Active |
| Camera Mirror | `mirror` | 1 | 1, 2, 4 | Active |
| Ask AI | `askAI` | 1 | 1, 2, 4 | Active |

## 9. Secondary Tab Modules (`ModuleRegistry`)

| Module ID | Title | Icon | Dock Toggle Key | Status |
|---|---|---|---|---|
| `airdrop` | AirDrop | `airdrop` | `enabledModules["airdrop"]` | Active |
| `shelf` | Shelf | `tray.full.fill` | `enabledModules["shelf"]` | Active |
| `thock` | Thock | `keyboard.fill` | `enabledModules["thock"]` | Active |
| `battery` | Battery | `battery.100` | `enabledModules["battery"]` | Active |
| `mirror` | Mirror | `camera.fill` | `enabledModules["mirror"]` | Active |
| `notifications` | History | `bell.badge.fill` | `enabledModules["notifications"]` | Active |
| `telegram` | Direct Chat | `paperplane.fill` | `enabledModules["telegram"]` | Active |

## 10. Geometry & Interaction Settings (`SettingsStore`)

| Key | Type | Default | Valid Range | Status |
|---|---|---|---|---|
| `NotchApp_NotchWidth` | Double | 620.0 | 480.0 – 800.0 pt | Active |
| `NotchApp_NotchHeight` | Double | 330.0 | 310.0 – 420.0 pt | Active |
| `NotchApp_HoverTriggerHeight` | Double | 34.0 | 24.0 – 54.0 pt | Active |
| `NotchApp_HoverTriggerWidth` | Double | 210.0 | 160.0 – 380.0 pt | Active |
| `NotchApp_ContentHorizontalPadding` | Double | 16.0 | 12.0 – 32.0 pt | Active |
| `NotchApp_ContentVerticalPadding` | Double | 12.0 | 8.0 – 24.0 pt | Active |
| `NotchApp_HoverDelay` | Double | 0.10 s | 0.00 – 0.60 s | Active |
| `NotchApp_AutoCollapseDelay` | Double | 0.25 s | 0.10 – 0.80 s | Active |
| `NotchApp_ShowBreadcrumbs` | Bool | true | true / false | Active |
| `NotchApp_SpecularGlowEnabled` | Bool | true | true / false | Active |
| `NotchApp_KeepOpenWhileSettings` | Bool | false | true / false | Active |
| `NotchApp_CloseOnOutsideClick` | Bool | true | true / false | Active |
| `NotchApp_CloseOnEsc` | Bool | true | true / false | Active |
| `NotchApp_SoundFeedback` | Bool | true | true / false | Active |
| `NotchApp_HapticFeedback` | Bool | true | true / false | Active |
| `NotchApp_UsePerModuleAccent` | Bool | false | true / false | Active |
| `NotchApp_DashboardSplitRatio` | Double | 0.50 | 0.20 – 0.80 | Active |

## 11. Companion Mascot Settings (`SettingsStore`)

| Key | Type | Default | Status |
|---|---|---|---|
| `NotchApp_IsCompanionEnabled` | Bool | false | Active |
| `NotchApp_CompanionSkin` | Enum (`bubu`) | `bubu` | Active |
| `NotchApp_CompanionActivityLevel` | Enum (`calm`, `balanced`, `hyper`) | `balanced` | Active |
| `NotchApp_CompanionMimicTyping` | Bool | true | Active |
| `NotchApp_CompanionGrooveMusic` | Bool | true | Active |
| `NotchApp_CompanionAllowSlips` | Bool | true | Active |
| `NotchApp_CompanionSleepDuringDND` | Bool | true | Active |
| `NotchApp_CompanionDebugSkeleton` | Bool | false | Active |
