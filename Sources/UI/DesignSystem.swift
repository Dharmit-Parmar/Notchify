import SwiftUI
import AppKit
import ImageIO
import AVFoundation

// NOTE / ENHANCEMENT:
// This file contains the updated high-performance DesignSystem, DynamicThemeEngine,
// and VisualEffectBlur implementations. It incorporates FIX (#1) through FIX (#9)
// (including circadian solar driver, equatable diagnostics to eliminate redraw storms,
// cached artwork sampling, single reduceMotion source of truth, and backdrop blur invalidation fix).
// Having this file properly homed in DesignSystem.swift prevents the ambiguous type lookup errors
// for MultiZonePalette, AppTheme, and VisualEffectBlur.

public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case adaptive = "Dynamic Wallpaper & App Glass"
    case activeApp = "Dynamic Active App"
    case circadian = "Dynamic Circadian Solar"
    case musicReactive = "Dynamic Music Aura"
    case midnight = "Midnight Azure"
    case cyberpunk = "Cyber Emerald"
    case sunset = "Sunset Crimson"
    case solar = "Solar Amber"
    case amethyst = "Deep Amethyst"
    case titanium = "Titanium Luxury"
    case aurora = "Aurora Borealis"
    case cupertino = "Cupertino Silver"
    case dune = "Dune Sandstone"
    case neonTokyo = "Tokyo Neon"
    case crimson = "Crimson Velvet"
    case slate = "Monochrome Slate"
    case nordic = "Nordic Glacier"
    case starlight = "Starlight Gold"
    case noir = "Minimalist Noir"
    case emerald = "Emerald Forest"
    case birch = "Birch Studio"
    case sakura = "Sakura Blossom"

    public var id: String { rawValue }

    public var isDynamic: Bool {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive:
            return true
        default:
            return false
        }
    }

    public var isLight: Bool {
        switch self {
        case .birch, .sakura:
            return true
        default:
            return false
        }
    }

    @MainActor
    public var primaryTextColor: Color {
        switch self {
        case .birch: return Color(red: 0.118, green: 0.118, blue: 0.118)
        case .sakura: return Color(red: 0.157, green: 0.094, blue: 0.125)
        default: return Color.white
        }
    }

    public var displayName: String {
        switch self {
        case .adaptive: "Wallpaper"
        case .activeApp: "Active App"
        case .circadian: "Circadian"
        case .musicReactive: "Music Aura"
        case .midnight: "Midnight"
        case .cyberpunk: "Forest"
        case .sunset: "Rose"
        case .solar: "Amber"
        case .amethyst: "Amethyst"
        case .titanium: "Graphite"
        case .aurora: "Aurora"
        case .cupertino: "Cupertino"
        case .dune: "Dune"
        case .neonTokyo: "Tokyo"
        case .crimson: "Crimson"
        case .slate: "Slate"
        case .nordic: "Glacier"
        case .starlight: "Starlight"
        case .noir: "Noir"
        case .emerald: "Emerald"
        case .birch: "Birch"
        case .sakura: "Sakura"
        }
    }

    public var subtitle: String {
        switch self {
        case .adaptive: "Wallpaper colors"
        case .activeApp: "Foreground app colors"
        case .circadian: "Time-of-day solar shift"
        case .musicReactive: "Album art living glow"
        case .aurora: "Northern lights"
        case .cupertino: "Apple electric blue"
        case .dune: "Warm desert gold"
        case .neonTokyo: "Cyberpunk magenta"
        case .crimson: "Deep dark ruby"
        case .slate: "Studio carbon"
        case .nordic: "Frosted polar silver"
        case .starlight: "Champagne gold luxury"
        case .noir: "Apple Pro deep contrast"
        case .emerald: "Lush forest jewel"
        case .birch: "Warm paper light studio"
        case .sakura: "Soft blossom light pastel"
        default: "Color preset"
        }
    }

    public var baseCanvasRGB: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive: return (0.05, 0.06, 0.08)
        case .midnight: return (0.04, 0.06, 0.10)
        case .cyberpunk: return (0.03, 0.07, 0.05)
        case .sunset: return (0.08, 0.04, 0.06)
        case .solar: return (0.07, 0.05, 0.03)
        case .amethyst: return (0.06, 0.03, 0.09)
        case .titanium: return (0.03, 0.03, 0.03)
        case .aurora: return (0.04, 0.07, 0.09)
        case .cupertino: return (0.05, 0.06, 0.08)
        case .dune: return (0.07, 0.05, 0.03)
        case .neonTokyo: return (0.06, 0.03, 0.08)
        case .crimson: return (0.08, 0.02, 0.04)
        case .slate: return (0.05, 0.05, 0.06)
        case .nordic: return (0.04, 0.06, 0.08)
        case .starlight: return (0.06, 0.05, 0.04)
        case .noir: return (0.02, 0.02, 0.02)
        case .emerald: return (0.03, 0.06, 0.04)
        case .birch: return (0.969, 0.961, 0.941)
        case .sakura: return (0.992, 0.965, 0.969)
        }
    }

    @MainActor
    public var canvasColor: Color {
        let rgb = baseCanvasRGB
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }

    public var baseStructureRGB: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive: return (0.13, 0.15, 0.20)
        case .midnight: return (0.11, 0.16, 0.25)
        case .cyberpunk: return (0.07, 0.13, 0.11)
        case .sunset: return (0.15, 0.08, 0.11)
        case .solar: return (0.14, 0.11, 0.07)
        case .amethyst: return (0.12, 0.08, 0.17)
        case .titanium: return (0.14, 0.14, 0.16)
        case .aurora: return (0.09, 0.16, 0.18)
        case .cupertino: return (0.12, 0.14, 0.19)
        case .dune: return (0.16, 0.12, 0.08)
        case .neonTokyo: return (0.16, 0.08, 0.20)
        case .crimson: return (0.18, 0.06, 0.10)
        case .slate: return (0.13, 0.13, 0.15)
        case .nordic: return (0.10, 0.15, 0.19)
        case .starlight: return (0.16, 0.14, 0.11)
        case .noir: return (0.10, 0.10, 0.10)
        case .emerald: return (0.08, 0.15, 0.10)
        case .birch: return (0.922, 0.906, 0.875)
        case .sakura: return (0.961, 0.898, 0.918)
        }
    }

    @MainActor
    public var structureColor: Color {
        let rgb = baseStructureRGB
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }

    public var baseAccentRGB: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive: return (0.22, 0.62, 1.0)
        case .midnight: return (0.32, 0.62, 0.90)
        case .cyberpunk: return (0.38, 0.76, 0.62)
        case .sunset: return (0.90, 0.42, 0.50)
        case .solar: return (0.91, 0.68, 0.34)
        case .amethyst: return (0.72, 0.54, 0.90)
        case .titanium: return (0.84, 0.88, 0.94)
        case .aurora: return (0.18, 0.83, 0.75)
        case .cupertino: return (0.04, 0.52, 1.00)
        case .dune: return (0.96, 0.62, 0.12)
        case .neonTokyo: return (0.96, 0.25, 0.44)
        case .crimson: return (0.88, 0.11, 0.28)
        case .slate: return (0.89, 0.91, 0.94)
        case .nordic: return (0.35, 0.78, 0.90)
        case .starlight: return (0.92, 0.78, 0.50)
        case .noir: return (0.98, 0.98, 0.98)
        case .emerald: return (0.20, 0.82, 0.45)
        case .birch: return (0.769, 0.490, 0.169)
        case .sakura: return (0.878, 0.427, 0.549)
        }
    }

    @MainActor
    public var accentColor: Color {
        let rgb = baseAccentRGB
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }

    public var baseSecondaryTextRGB: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive: return (0.75, 0.82, 0.92)
        case .midnight: return (0.65, 0.75, 0.88)
        case .cyberpunk: return (0.62, 0.80, 0.70)
        case .sunset: return (0.82, 0.68, 0.75)
        case .solar: return (0.82, 0.75, 0.65)
        case .amethyst: return (0.78, 0.68, 0.88)
        case .titanium: return (0.85, 0.85, 0.85)
        case .aurora: return (0.65, 0.85, 0.82)
        case .cupertino: return (0.72, 0.80, 0.90)
        case .dune: return (0.86, 0.78, 0.68)
        case .neonTokyo: return (0.88, 0.70, 0.82)
        case .crimson: return (0.85, 0.68, 0.72)
        case .slate: return (0.75, 0.77, 0.80)
        case .nordic: return (0.70, 0.84, 0.90)
        case .starlight: return (0.88, 0.82, 0.72)
        case .noir: return (0.80, 0.80, 0.80)
        case .emerald: return (0.65, 0.85, 0.72)
        case .birch: return (0.353, 0.337, 0.306)
        case .sakura: return (0.431, 0.333, 0.376)
        }
    }

    @MainActor
    public var secondaryTextColor: Color {
        let rgb = baseSecondaryTextRGB
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

// MARK: - Dynamic Theme Accent Vibrancy

public enum DynamicVibrancy: String, CaseIterable, Identifiable, Codable {
    case subtle = "Subtle"
    case balanced = "Balanced"
    case punchy = "Punchy"

    public var id: String { rawValue }

    public var factor: CGFloat {
        switch self {
        case .subtle: return 0.72
        case .balanced: return 1.0
        case .punchy: return 1.35
        }
    }
}

// MARK: - Customizable Glass Appearance Style

public enum GlassMaterialStyle: String, CaseIterable, Identifiable, Codable {
    case frosted = "Frosted Glass"
    case deepOLED = "Deep OLED"
    case luminous = "Luminous Tint"
    case crystal = "Crystal Clear"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .frosted: return "Translucent macOS liquid retina blur"
        case .deepOLED: return "High-contrast obsidian dark surface"
        case .luminous: return "Vibrant dynamic specular wash"
        case .crystal: return "Minimal ultra-clear backdrop"
        }
    }
}

// MARK: - Organic Continuous Corner Style

public enum NotchCornerStyle: String, CaseIterable, Identifiable, Codable {
    case continuous = "Fluid Squircle"
    case compact = "Compact"
    case deep = "Deep Curve"

    public var id: String { rawValue }

    public var topRadius: CGFloat {
        switch self {
        case .continuous: return 14
        case .compact: return 10
        case .deep: return 18
        }
    }

    public var bottomRadius: CGFloat {
        switch self {
        case .continuous: return 34
        case .compact: return 22
        case .deep: return 42
        }
    }
}

// MARK: - Apple Fluid Motion Physics Style

public enum MotionPhysicsStyle: String, CaseIterable, Identifiable, Codable {
    case appleFluid = "Apple Fluid"
    case snappy = "Snappy"
    case gentle = "Gentle"

    public var id: String { rawValue }

    public var response: Double {
        switch self {
        case .appleFluid: return 0.32
        case .snappy: return 0.20
        case .gentle: return 0.44
        }
    }

    public var damping: Double {
        switch self {
        case .appleFluid: return 0.96
        case .snappy: return 1.0
        case .gentle: return 0.88
        }
    }
}

// MARK: - Apple Music Live Waveform Equalizer

public struct LiveEqualizerIndicator: View {
    @ObservedObject private var shell = NotchShellCoordinator.shared
    @ObservedObject private var env = EnvironmentState.shared
    let isPlaying: Bool
    var color: Color = DesignSystem.accentColor
    var barWidth: CGFloat = 2.0
    var maxHeight: CGFloat = 12.0

    // FIX (#9): paused "resting" bar heights as fractions of maxHeight.
    // The previous hard-coded values (6/11/7/9) could exceed maxHeight when
    // maxHeight was set below 11 (e.g. in the compact tile), overflowing the
    // frame and clipping the bars.
    private static let pausedFractions: [CGFloat] = [0.50, 0.92, 0.58, 0.75]

    public init(isPlaying: Bool, color: Color = DesignSystem.accentColor, barWidth: CGFloat = 2.0, maxHeight: CGFloat = 12.0) {
        self.isPlaying = isPlaying
        self.color = color
        self.barWidth = barWidth
        self.maxHeight = maxHeight
    }

    public var body: some View {
        let isExpanded = shell.state == .expanded
        let isPowerThrottled = env.isLowPowerMode || env.thermalState == .critical || env.thermalState == .serious
        TimelineView(.animation(minimumInterval: 0.20, paused: !isPlaying || !isExpanded || isPowerThrottled)) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 1.5) {
                ForEach(0..<4, id: \.self) { index in
                    let height: CGFloat = isPlaying
                        ? barHeight(offset: Double(index) * 0.9, time: date)
                        : maxHeight * Self.pausedFractions[index]
                    equalizerBar(height: height)
                }
            }
        }
    }

    private func equalizerBar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(color)
            .frame(width: barWidth, height: height)
    }

    private func barHeight(offset: Double, time: Double) -> CGFloat {
        let cycle = sin(time * 7.5 + offset)
        let normalized = (cycle + 1.0) / 2.0
        let minH: CGFloat = 3.0
        return minH + CGFloat(normalized) * (maxHeight - minH)
    }
}

// MARK: - Spring Button Style

public struct SpringButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    public var scaleAmount: CGFloat = 0.97
    public var response: Double = 0.22
    public var damping: Double = 1.0

    public init(scaleAmount: CGFloat = 0.97, response: Double = 0.22, damping: Double = 1.0) {
        self.scaleAmount = scaleAmount
        self.response = response
        self.damping = damping
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isEnabled && configuration.isPressed && !reduceMotion ? scaleAmount : 1.0)
            .opacity(!isEnabled ? 0.35 : (configuration.isPressed && !reduceMotion ? 0.88 : 1.0))
            .animation(reduceMotion ? nil : .spring(response: response, dampingFraction: damping), value: configuration.isPressed)
    }
}

@MainActor
public final class LocalUIState: ObservableObject {
    @Published public var isHovered: Bool = false
    @Published public var isTargeted: Bool = false
    @Published public var text: String = ""

    public init(text: String = "") {
        self.text = text
    }
}

extension ButtonStyle where Self == SpringButtonStyle {
    public static var spring: SpringButtonStyle { SpringButtonStyle() }
    public static func spring(scale: CGFloat) -> SpringButtonStyle { SpringButtonStyle(scaleAmount: scale) }
}

// MARK: - Multi-Zone Palette

public struct MultiZonePalette: Sendable, Equatable {
    public var shadowRGB: (CGFloat, CGFloat, CGFloat)
    public var midtoneRGB: (CGFloat, CGFloat, CGFloat)
    public var highlightRGB: (CGFloat, CGFloat, CGFloat)

    public init(
        shadowRGB: (CGFloat, CGFloat, CGFloat) = (0.05, 0.06, 0.08),
        midtoneRGB: (CGFloat, CGFloat, CGFloat) = (0.13, 0.15, 0.20),
        highlightRGB: (CGFloat, CGFloat, CGFloat) = (0.22, 0.62, 1.0)
    ) {
        self.shadowRGB = shadowRGB
        self.midtoneRGB = midtoneRGB
        self.highlightRGB = highlightRGB
    }

    public static func == (lhs: MultiZonePalette, rhs: MultiZonePalette) -> Bool {
        return lhs.shadowRGB.0 == rhs.shadowRGB.0 &&
               lhs.shadowRGB.1 == rhs.shadowRGB.1 &&
               lhs.shadowRGB.2 == rhs.shadowRGB.2 &&
               lhs.midtoneRGB.0 == rhs.midtoneRGB.0 &&
               lhs.midtoneRGB.1 == rhs.midtoneRGB.1 &&
               lhs.midtoneRGB.2 == rhs.midtoneRGB.2 &&
               lhs.highlightRGB.0 == rhs.highlightRGB.0 &&
               lhs.highlightRGB.1 == rhs.highlightRGB.1 &&
               lhs.highlightRGB.2 == rhs.highlightRGB.2
    }
}

// MARK: - Color Detection Diagnostics

// FIX (#3): ColorDetectionDiagnostics is Equatable so the published property
// can skip re-publishing on refreshes that didn't meaningfully change state,
// which was previously firing @Published on every refreshColors() call and
// invalidating every observer (diagnostic panel, status indicators, …).
// `lastUpdateTime` is deliberately excluded from equality: it changes on every
// refresh and is informational only — including it would defeat the purpose.
public struct ColorDetectionDiagnostics: Sendable, Equatable {
    public var wallpaperURL: URL? = nil
    public var wallpaperPath: String = "None"
    public var wallpaperModDate: Date? = nil
    public var targetScreenName: String = "None"
    public var targetScreenResolution: String = "0x0"
    public var hasPhysicalNotch: Bool = false
    public var activeSpaceNote: String = "Active Space Tracking"
    public var frontmostAppName: String = "None"
    public var frontmostBundleID: String = "None"
    public var frontmostAppIconColor: (CGFloat, CGFloat, CGFloat)? = nil
    public var sampledWallpaperRGB: (CGFloat, CGFloat, CGFloat)? = nil
    public var systemAccentRGB: (CGFloat, CGFloat, CGFloat)? = nil
    public var activeFallbackStage: String = "Initializing"
    public var detectionStatus: String = "Idle"
    public var lastUpdateTime: Date = Date()

    public init() {}

    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Tuple optionals compare by their fields; no way around spelling them
        // out unless we wrap the RGB tuple in a conforming value type.
        func eqRGB(_ a: (CGFloat, CGFloat, CGFloat)?, _ b: (CGFloat, CGFloat, CGFloat)?) -> Bool {
            switch (a, b) {
            case (nil, nil): return true
            case let (.some(x), .some(y)):
                return x.0 == y.0 && x.1 == y.1 && x.2 == y.2
            default: return false
            }
        }
        return lhs.wallpaperURL == rhs.wallpaperURL
            && lhs.wallpaperPath == rhs.wallpaperPath
            && lhs.wallpaperModDate == rhs.wallpaperModDate
            && lhs.targetScreenName == rhs.targetScreenName
            && lhs.targetScreenResolution == rhs.targetScreenResolution
            && lhs.hasPhysicalNotch == rhs.hasPhysicalNotch
            && lhs.activeSpaceNote == rhs.activeSpaceNote
            && lhs.frontmostAppName == rhs.frontmostAppName
            && lhs.frontmostBundleID == rhs.frontmostBundleID
            && eqRGB(lhs.frontmostAppIconColor, rhs.frontmostAppIconColor)
            && eqRGB(lhs.sampledWallpaperRGB, rhs.sampledWallpaperRGB)
            && eqRGB(lhs.systemAccentRGB, rhs.systemAccentRGB)
            && lhs.activeFallbackStage == rhs.activeFallbackStage
            && lhs.detectionStatus == rhs.detectionStatus
        // Intentionally skip lastUpdateTime.
    }
}

// MARK: - Dynamic Theme Engine

@MainActor
public final class DynamicThemeEngine: ObservableObject {
    public static let shared = DynamicThemeEngine()

    @Published public var canvasColor: Color = Color(red: 0.05, green: 0.06, blue: 0.08)
    @Published public var structureColor: Color = Color(red: 0.13, green: 0.15, blue: 0.20)
    @Published public var accentColor: Color = Color(red: 0.22, green: 0.62, blue: 1.0)
    // FIX (Bug 1): `appAccentColor` was dead — never updated after init, so any
    // view that read it got the bootstrap blue forever. It is now kept in sync
    // with `accentColor` in both branches of `refreshColors()`.
    @Published public var appAccentColor: Color = Color(red: 0.22, green: 0.62, blue: 1.0)
    @Published public var secondaryTextColor: Color = Color(red: 0.75, green: 0.82, blue: 0.92)
    @Published public var paletteSource = "Wallpaper"
    @Published public var diagnostics = ColorDetectionDiagnostics()
    @Published public var multiZonePalette = MultiZonePalette()

    private var currentCanvasOKLab = OKLabColor(l: 0.08, a: 0.0, b: 0.0)
    private var currentStructureOKLab = OKLabColor(l: 0.16, a: 0.0, b: 0.0)
    private var currentAccentOKLab = OKLabColor(l: 0.65, a: 0.0, b: -0.15)

    private var sampledWallpaperURL: URL?
    private var sampledWallpaperModDate: Date?
    private var sampledWallpaperPalette: MultiZonePalette?
    private var sampledWallpaperColor: (CGFloat, CGFloat, CGFloat)?
    private var sampledAppColors: [String: (CGFloat, CGFloat, CGFloat)] = [:]
    private var samplingAppBundleIDs: Set<String> = []
    private var isSamplingWallpaper = false
    private var wallpaperSampleGeneration = UUID()
    private var inFlightWallpaperURL: URL?
    private var inFlightWallpaperModDate: Date?

    private var activationObserver: NSObjectProtocol?
    private var spaceChangeObserver: NSObjectProtocol?
    private var displayChangeObserver: NSObjectProtocol?

    // FIX (#1): .circadian theme needs a driver. Previously the solar phase
    // was frozen at the value sampled when refreshColors() was last called
    // (typically app activation), so users saw the wrong palette for hours.
    private var circadianTimer: Timer?
    private var circadianClockObserver: NSObjectProtocol?

    // FIX (#7): cache artwork sampling so the 2 s NowPlaying poll in
    // .musicReactive doesn't re-render the same art every tick.
    private var lastSampledArtworkID: ObjectIdentifier?
    private var lastSampledArtworkColor: (CGFloat, CGFloat, CGFloat)?

    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshColors()
        }
    }

    // NOTE / WHY THIS IS RUNNING NOW (Error Fix):
    // In Swift 6 concurrency, accessing @MainActor properties of non-Sendable types
    // (circadianTimer: Timer?, circadianClockObserver: (any NSObjectProtocol)?) from nonisolated deinit caused:
    //   "error: cannot access property 'circadianTimer' with a non-Sendable type 'Timer?' from nonisolated deinit"
    // Marking deinit as `isolated deinit` executes deallocation cleanup on the @MainActor.
    isolated deinit {
        circadianTimer?.invalidate()
        if let obs = circadianClockObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    public func redetectColors() {
        invalidateWallpaperSample(clearCachedPalette: true)
        sampledAppColors.removeAll()
        refreshColors()
    }

    private func invalidateWallpaperSample(clearCachedPalette: Bool) {
        wallpaperSampleGeneration = UUID()
        isSamplingWallpaper = false
        inFlightWallpaperURL = nil
        inFlightWallpaperModDate = nil

        if clearCachedPalette {
            sampledWallpaperURL = nil
            sampledWallpaperModDate = nil
            sampledWallpaperColor = nil
            sampledWallpaperPalette = nil
        }
    }

    /// FIX (#1): start or stop the circadian update timer + clock-change observer.
    /// Called on every `refreshColors()`; idempotent.
    private func updateCircadianTimer(for theme: AppTheme) {
        if theme == .circadian {
            if circadianTimer == nil {
                let timer = Timer(timeInterval: 600, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.refreshColors()
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                circadianTimer = timer
            }
            if circadianClockObserver == nil {
                circadianClockObserver = NotificationCenter.default.addObserver(
                    forName: .NSSystemClockDidChange,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.refreshColors()
                    }
                }
            }
        } else {
            circadianTimer?.invalidate()
            circadianTimer = nil
            if let obs = circadianClockObserver {
                NotificationCenter.default.removeObserver(obs)
                circadianClockObserver = nil
            }
        }
    }

    // FIX (Bug 2): thread the theme's light-ness through so the contrast guard
    // uses the correct foreground luminance. Previously this method always
    // passed `forTextLuminance: 1.0` (white text), which happens to be correct
    // for all *currently*-dynamic themes (they're all dark). The moment a
    // light dynamic theme is added, the canvas would be force-darkened to
    // satisfy a 4.5:1 contrast against text that isn't even there.
    private func applyCurrentOKLabColors(lightTheme: Bool) {
        let cRGB = currentCanvasOKLab.toRGB()
        let sRGB = currentStructureOKLab.toRGB()
        let aRGB = currentAccentOKLab.toRGB()

        let safeCanvas = ContrastGuard.ensureContrast(
            background: cRGB,
            forTextLuminance: lightTheme ? 0.05 : 1.0,
            minRatio: 4.5
        )

        self.canvasColor = Color(red: safeCanvas.0, green: safeCanvas.1, blue: safeCanvas.2)
        self.structureColor = Color(red: sRGB.0, green: sRGB.1, blue: sRGB.2)
        self.accentColor = Color(red: aRGB.0, green: aRGB.1, blue: aRGB.2)
    }

    private func transitionTo(
        targetCanvas: OKLabColor,
        targetStructure: OKLabColor,
        targetAccent: OKLabColor,
        lightTheme: Bool
    ) {
        let isCollapsed = (NotchShellCoordinator.shared.state == .collapsed)
        let isPowerThrottled = EnvironmentState.shared.isLowPowerMode
            || EnvironmentState.shared.thermalState == .critical
            || EnvironmentState.shared.thermalState == .serious
        // FIX (#6): use EnvironmentState's reduceMotion (which already ORs in
        // the OS accessibility setting), rather than reading the OS value
        // ad-hoc. Behaviourally identical today but keeps one source of truth.
        let reduceMotion = EnvironmentState.shared.reduceMotion

        currentCanvasOKLab = targetCanvas
        currentStructureOKLab = targetStructure
        currentAccentOKLab = targetAccent

        if isCollapsed || reduceMotion || isPowerThrottled {
            applyCurrentOKLabColors(lightTheme: lightTheme)
        } else {
            let motion = SettingsStore.shared.motionPhysics
            withAnimation(.spring(response: motion.response, dampingFraction: motion.damping)) {
                applyCurrentOKLabColors(lightTheme: lightTheme)
            }
        }
    }

    public static func systemAccentRGB() -> (CGFloat, CGFloat, CGFloat) {
        let accent = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? .systemBlue
        return (accent.redComponent, accent.greenComponent, accent.blueComponent)
    }

    public static func timeOfDaySolarRGB() -> (CGFloat, CGFloat, CGFloat) {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())
        let timeFrac = Double(hour) + Double(minute) / 60.0
        if timeFrac >= 5.0 && timeFrac < 8.5 {
            return (0.95, 0.45, 0.35)
        } else if timeFrac >= 8.5 && timeFrac < 17.0 {
            return (0.25, 0.65, 0.95)
        } else if timeFrac >= 17.0 && timeFrac < 20.5 {
            return (0.96, 0.65, 0.22)
        } else {
            return (0.45, 0.55, 0.85)
        }
    }

    public func refreshColors() {
        let theme = SettingsStore.shared.currentTheme
        updateCircadianTimer(for: theme)

        if !theme.isDynamic {
            if let activationObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
                self.activationObserver = nil
            }
            if let spaceChangeObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(spaceChangeObserver)
                self.spaceChangeObserver = nil
            }
            if let displayChangeObserver {
                NotificationCenter.default.removeObserver(displayChangeObserver)
                self.displayChangeObserver = nil
            }

            // FIX (#4): cancel any in-flight wallpaper sample so its completion
            // cannot resurrect dynamic state after the user switched away.
            wallpaperSampleGeneration = UUID()
            isSamplingWallpaper = false
            inFlightWallpaperURL = nil
            inFlightWallpaperModDate = nil

            // FIX (#5): reset multiZonePalette so external consumers on a
            // static theme don't accidentally read the last dynamic palette.
            // (Internal .adaptive logic reads sampledWallpaperPalette
            // directly and is unaffected.)
            if multiZonePalette != MultiZonePalette() {
                multiZonePalette = MultiZonePalette()
            }

            let vibrancy = SettingsStore.shared.dynamicVibrancy.factor

            let baseAccent = theme.baseAccentRGB
            let nsAccent = NSColor(red: baseAccent.0, green: baseAccent.1, blue: baseAccent.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
            var ah: CGFloat = 0, asat: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 1
            nsAccent.getHue(&ah, saturation: &asat, brightness: &ab, alpha: &aa)
            let adjustedAccentSat = min(1.0, max(0.05, asat * vibrancy))
            let newAccent = Color(hue: ah, saturation: adjustedAccentSat, brightness: ab)

            let baseStruct = theme.baseStructureRGB
            let nsStruct = NSColor(red: baseStruct.0, green: baseStruct.1, blue: baseStruct.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .darkGray
            var sh: CGFloat = 0, ss: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 1
            nsStruct.getHue(&sh, saturation: &ss, brightness: &sb, alpha: &sa)
            let adjustedStructSat = min(1.0, max(0.02, ss * vibrancy))
            let newStruct = Color(hue: sh, saturation: adjustedStructSat, brightness: sb)

            let baseCanvas = theme.baseCanvasRGB
            let nsCanvas = NSColor(red: baseCanvas.0, green: baseCanvas.1, blue: baseCanvas.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .black
            var ch: CGFloat = 0, cs: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 1
            nsCanvas.getHue(&ch, saturation: &cs, brightness: &cb, alpha: &ca)
            let adjustedCanvasSat = min(1.0, max(0.01, cs * vibrancy))
            let newCanvas = Color(hue: ch, saturation: adjustedCanvasSat, brightness: cb)

            let baseSec = theme.baseSecondaryTextRGB
            let newSec = Color(red: baseSec.0, green: baseSec.1, blue: baseSec.2)

            if accentColor != newAccent { accentColor = newAccent }
            // FIX (Bug 1): keep appAccentColor in sync with the active theme.
            if appAccentColor != newAccent { appAccentColor = newAccent }
            if structureColor != newStruct { structureColor = newStruct }
            if canvasColor != newCanvas { canvasColor = newCanvas }
            if secondaryTextColor != newSec { secondaryTextColor = newSec }
            if paletteSource != theme.displayName { paletteSource = theme.displayName }

            var d = self.diagnostics
            d.detectionStatus = "Static theme: \(theme.displayName)"
            d.activeFallbackStage = "Static Preset"
            if self.diagnostics != d { self.diagnostics = d }
            return
        }

        if activationObserver == nil {
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshColors()
                }
            }
        }

        if spaceChangeObserver == nil {
            spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.invalidateWallpaperSample(clearCachedPalette: true)
                    self.refreshColors()
                }
            }
        }

        if displayChangeObserver == nil {
            displayChangeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.invalidateWallpaperSample(clearCachedPalette: true)
                    self.refreshColors()
                }
            }
        }

        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first else {
            var d = self.diagnostics
            d.detectionStatus = "Waiting for an available display"
            d.activeFallbackStage = "Display Unavailable"
            if self.diagnostics != d { self.diagnostics = d }
            return
        }
        let screenFrame = screen.frame
        let hasNotch = screen.safeAreaInsets.top > 0

        var d = self.diagnostics
        d.targetScreenName = screen.localizedName
        d.targetScreenResolution = "\(Int(screenFrame.width))x\(Int(screenFrame.height))"
        d.hasPhysicalNotch = hasNotch
        d.activeSpaceNote = "Space tracking active"
        d.systemAccentRGB = Self.systemAccentRGB()
        d.lastUpdateTime = Date()

        var hue: CGFloat = 0.58
        var saturation: CGFloat = 0.65
        var sourceName = "Dynamic"
        var activeStage = "Initializing"

        let imageURL = NSWorkspace.shared.desktopImageURL(for: screen)
        d.wallpaperURL = imageURL
        d.wallpaperPath = imageURL?.path ?? "None (Dynamic or Aerial Video)"

        let fileModDate = imageURL.flatMap { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate }
        d.wallpaperModDate = fileModDate

        if isSamplingWallpaper,
           (inFlightWallpaperURL != imageURL || inFlightWallpaperModDate != fileModDate) {
            invalidateWallpaperSample(clearCachedPalette: false)
        }

        if sampledWallpaperURL != imageURL || sampledWallpaperModDate != fileModDate {
            sampledWallpaperURL = nil
            sampledWallpaperModDate = nil
            sampledWallpaperColor = nil
            sampledWallpaperPalette = nil
        }

        let isCacheValid = imageURL != nil
            && sampledWallpaperURL == imageURL
            && sampledWallpaperModDate == fileModDate

        // FIX (#2): only sample the wallpaper for themes that actually use
        // the result. .circadian and .musicReactive previously kicked off a
        // full thumbnail + palette extraction that was then discarded.
        let needsWallpaperSample = (theme == .adaptive || theme == .activeApp)
        if needsWallpaperSample, let imageURL = imageURL, !isCacheValid, !isSamplingWallpaper {
            let generation = UUID()
            wallpaperSampleGeneration = generation
            inFlightWallpaperURL = imageURL
            inFlightWallpaperModDate = fileModDate
            isSamplingWallpaper = true

            DispatchQueue.global(qos: .utility).async { [weak self] in
                let palette = Self.sampleWallpaperPalette(at: imageURL)
                let color = palette?.highlightRGB ?? Self.sampleWallpaperColor(at: imageURL)
                Task { @MainActor [weak self] in
                    guard let self,
                          self.wallpaperSampleGeneration == generation else {
                        return
                    }

                    self.isSamplingWallpaper = false
                    self.inFlightWallpaperURL = nil
                    self.inFlightWallpaperModDate = nil
                    self.sampledWallpaperURL = imageURL
                    self.sampledWallpaperModDate = fileModDate
                    self.sampledWallpaperColor = color
                    self.sampledWallpaperPalette = palette

                    // FIX (#8): only .adaptive consumes multiZonePalette.
                    // Gate the assignment so other themes don't publish a
                    // palette their color logic will never read.
                    if SettingsStore.shared.currentTheme == .adaptive, let pal = palette {
                        self.multiZonePalette = pal
                    }
                    if SettingsStore.shared.currentTheme == .adaptive
                        || SettingsStore.shared.currentTheme == .activeApp {
                        self.refreshColors()
                    }
                }
            }
        }

        d.sampledWallpaperRGB = sampledWallpaperColor

        switch theme {
        case .circadian:
            let cal = Calendar.current
            let now = Date()
            let hour = cal.component(.hour, from: now)
            let minute = cal.component(.minute, from: now)
            let timeFrac = Double(hour) + Double(minute) / 60.0

            if timeFrac >= 5.0 && timeFrac < 8.5 {
                hue = 0.98; saturation = 0.65; sourceName = "Solar Dawn"
            } else if timeFrac >= 8.5 && timeFrac < 17.0 {
                hue = 0.58; saturation = 0.70; sourceName = "Daylight Sky"
            } else if timeFrac >= 17.0 && timeFrac < 20.5 {
                hue = 0.08; saturation = 0.82; sourceName = "Golden Hour"
            } else {
                hue = 0.62; saturation = 0.55; sourceName = "Starlight Night"
            }
            activeStage = "Circadian Solar Phase (\(sourceName))"
            d.detectionStatus = "✓ Circadian Solar Active"

        case .musicReactive:
            // FIX (#7): reuse the last sampled artwork color while the
            // artwork object is unchanged. The 2 s NowPlaying poll previously
            // caused sampleImageColor to run 2× per second on the same image.
            var artworkColor: (CGFloat, CGFloat, CGFloat)?
            if let art = NowPlayingModule.shared.artwork {
                let id = ObjectIdentifier(art)
                if lastSampledArtworkID != id {
                    lastSampledArtworkColor = Self.sampleImageColor(art)
                    lastSampledArtworkID = id
                }
                artworkColor = lastSampledArtworkColor
            } else {
                lastSampledArtworkID = nil
                lastSampledArtworkColor = nil
            }

            if let color = artworkColor {
                let nsColor = NSColor(red: color.0, green: color.1, blue: color.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
                nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                if s >= 0.12 {
                    hue = h; saturation = max(0.40, s); sourceName = "Now Playing Aura"
                } else {
                    hue = 0.58; saturation = 0.65; sourceName = "Now Playing (Ambient)"
                }
            } else if NowPlayingModule.shared.hasActiveMedia {
                hue = 0.80; saturation = 0.75; sourceName = "Now Playing"
            } else {
                hue = 0.58; saturation = 0.60; sourceName = "Music Aura"
            }
            activeStage = "Media Artwork Aura (\(sourceName))"
            d.detectionStatus = "✓ Music Reactive Active"

        case .adaptive, .activeApp:
            let followsActiveApp = (theme == .activeApp)

            // STAGE 1: Sampled wallpaper
            if let sampled = sampledWallpaperColor {
                let wallpaper = NSColor(red: sampled.0, green: sampled.1, blue: sampled.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
                var wallHue: CGFloat = 0, wallSat: CGFloat = 0, wallBri: CGFloat = 0, wallAlpha: CGFloat = 1
                wallpaper.getHue(&wallHue, saturation: &wallSat, brightness: &wallBri, alpha: &wallAlpha)
                if wallSat >= 0.12 && wallBri >= 0.08 {
                    hue = wallHue
                    saturation = wallSat
                    sourceName = "Wallpaper"
                    activeStage = "Wallpaper File Extraction"
                }
            }

            // STAGE 2: Frontmost app icon (if .activeApp, or wallpaper desaturated)
            let frontmost = NSWorkspace.shared.frontmostApplication
            let bundleID = frontmost?.bundleIdentifier ?? ""
            d.frontmostAppName = frontmost?.localizedName ?? "None"
            d.frontmostBundleID = bundleID

            let isOwnApp = bundleID.isEmpty
                || bundleID == Bundle.main.bundleIdentifier
                || bundleID.contains("NotchApp")
                || bundleID == "com.apple.dock"

            if !isOwnApp {
                let appRGB = sampledAppColors[bundleID]
                if appRGB == nil, let icon = frontmost?.icon, !samplingAppBundleIDs.contains(bundleID) {
                    samplingAppBundleIDs.insert(bundleID)
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        let color = Self.sampleImageColor(icon)
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.samplingAppBundleIDs.remove(bundleID)
                            if self.sampledAppColors.count > 50 { self.sampledAppColors.removeAll() }
                            if let color = color { self.sampledAppColors[bundleID] = color }
                            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
                                self.refreshColors()
                            }
                        }
                    }
                }

                d.frontmostAppIconColor = appRGB

                if (followsActiveApp || activeStage == "Initializing"), let appColor = appRGB {
                    let nsApp = NSColor(red: appColor.0, green: appColor.1, blue: appColor.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
                    var aH: CGFloat = 0, aS: CGFloat = 0, aB: CGFloat = 0, aA: CGFloat = 1
                    nsApp.getHue(&aH, saturation: &aS, brightness: &aB, alpha: &aA)
                    if aS >= 0.14 && aB >= 0.10 {
                        hue = aH
                        saturation = aS
                        sourceName = frontmost?.localizedName ?? "Application"
                        activeStage = "Frontmost App Icon (\(sourceName))"
                    }
                }
            }

            // STAGE 3: macOS system accent
            if activeStage == "Initializing" {
                let sysAccent = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? .systemBlue
                var sH: CGFloat = 0, sS: CGFloat = 0, sB: CGFloat = 0, sA: CGFloat = 1
                sysAccent.getHue(&sH, saturation: &sS, brightness: &sB, alpha: &sA)
                if sS >= 0.10 && sB >= 0.12 {
                    hue = sH
                    saturation = sS
                    sourceName = "System Accent"
                    activeStage = "macOS System Accent Fallback"
                }
            }

            // STAGE 4: Circadian solar
            if activeStage == "Initializing" {
                let cal = Calendar.current
                let now = Date()
                let hour = cal.component(.hour, from: now)
                let minute = cal.component(.minute, from: now)
                let timeFrac = Double(hour) + Double(minute) / 60.0
                if timeFrac >= 5.0 && timeFrac < 8.5 {
                    hue = 0.98; saturation = 0.65; sourceName = "Solar Dawn"
                } else if timeFrac >= 8.5 && timeFrac < 17.0 {
                    hue = 0.58; saturation = 0.70; sourceName = "Daylight Sky"
                } else if timeFrac >= 17.0 && timeFrac < 20.5 {
                    hue = 0.08; saturation = 0.82; sourceName = "Golden Hour"
                } else {
                    hue = 0.62; saturation = 0.55; sourceName = "Starlight Night"
                }
                activeStage = "Time-of-Day Circadian Fallback"
            }

            d.detectionStatus = "✓ Active: \(activeStage)"

        default:
            activeStage = "Static Preset (\(theme.displayName))"
            d.detectionStatus = "Static Theme Selected"
        }

        d.activeFallbackStage = activeStage
        // FIX (#3): guard assignment so we don't re-publish on no-op refreshes.
        if self.diagnostics != d { self.diagnostics = d }

        let vibrancy = SettingsStore.shared.dynamicVibrancy.factor
        saturation = min(0.95, saturation * vibrancy)

        if paletteSource != sourceName { paletteSource = sourceName }

        let targetCanvasRGB: (CGFloat, CGFloat, CGFloat)
        let targetStructureRGB: (CGFloat, CGFloat, CGFloat)
        let targetAccentRGB: (CGFloat, CGFloat, CGFloat)

        if theme == .adaptive, let pal = sampledWallpaperPalette {
            targetCanvasRGB = pal.shadowRGB
            targetStructureRGB = pal.midtoneRGB
            let hRGB = pal.highlightRGB
            let nsH = NSColor(red: hRGB.0, green: hRGB.1, blue: hRGB.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
            var hh: CGFloat = 0, hs: CGFloat = 0, hb: CGFloat = 0, ha: CGFloat = 1
            nsH.getHue(&hh, saturation: &hs, brightness: &hb, alpha: &ha)
            let adjS = min(1.0, max(0.20, hs * vibrancy))
            let adjH = NSColor(hue: hh, saturation: adjS, brightness: max(0.60, hb), alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
            targetAccentRGB = (adjH.redComponent, adjH.greenComponent, adjH.blueComponent)
        } else if !theme.isDynamic {
            targetCanvasRGB = theme.baseCanvasRGB
            targetStructureRGB = theme.baseStructureRGB
            targetAccentRGB = theme.baseAccentRGB
        } else {
            let nsCanvas = NSColor(hue: hue, saturation: min(0.36, saturation * 0.55), brightness: 0.075, alpha: 1).usingColorSpace(.deviceRGB) ?? .black
            let nsStruct = NSColor(hue: hue, saturation: min(0.48, saturation * 0.68), brightness: 0.20, alpha: 1).usingColorSpace(.deviceRGB) ?? .darkGray
            let nsAccent = NSColor(hue: hue, saturation: min(0.85, max(0.40, saturation * 0.85)), brightness: 0.94, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
            targetCanvasRGB = (nsCanvas.redComponent, nsCanvas.greenComponent, nsCanvas.blueComponent)
            targetStructureRGB = (nsStruct.redComponent, nsStruct.greenComponent, nsStruct.blueComponent)
            targetAccentRGB = (nsAccent.redComponent, nsAccent.greenComponent, nsAccent.blueComponent)
        }

        let safeCanvasRGB = theme.isLight
            ? ContrastGuard.ensureContrast(background: targetCanvasRGB, forTextLuminance: 0.05, minRatio: 4.5)
            : ContrastGuard.ensureContrast(background: targetCanvasRGB, forTextLuminance: 1.0, minRatio: 4.5)

        let tCanvasOKLab = OKLabColor.from(rgb: safeCanvasRGB)
        let tStructureOKLab = OKLabColor.from(rgb: targetStructureRGB)
        let tAccentOKLab = OKLabColor.from(rgb: targetAccentRGB)

        // FIX (Bug 2): pass the theme's light-ness into transitionTo so the
        // inner contrast guard uses the correct foreground luminance.
        transitionTo(
            targetCanvas: tCanvasOKLab,
            targetStructure: tStructureOKLab,
            targetAccent: tAccentOKLab,
            lightTheme: theme.isLight
        )

        let secondaryText = theme.isLight ? theme.secondaryTextColor : Color.white.opacity(0.68)
        if secondaryTextColor != secondaryText { secondaryTextColor = secondaryText }

        // FIX (Bug 1): keep appAccentColor in sync with the dynamic accent so
        // it isn't stuck at the bootstrap blue forever. Runs after transitionTo
        // so it sees the final accent value.
        if appAccentColor != accentColor { appAccentColor = accentColor }
    }

    // MARK: - Static sampling helpers (nonisolated, called off-main)

    nonisolated private static func sampleImageColor(_ image: NSImage) -> (CGFloat, CGFloat, CGFloat)? {
        autoreleasepool {
            let size = CGSize(width: 16, height: 16)
            var rawData = [UInt8](repeating: 0, count: 16 * 16 * 4)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: &rawData,
                width: 16,
                height: 16,
                bitsPerComponent: 8,
                bytesPerRow: 16 * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }

            var proposedRect = CGRect(origin: .zero, size: size)
            if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
                ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
            } else if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let cg = rep.cgImage {
                ctx.draw(cg, in: CGRect(origin: .zero, size: size))
            } else {
                return nil
            }

            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, count: CGFloat = 0
            for i in stride(from: 0, to: 16 * 16 * 4, by: 4) {
                let a = CGFloat(rawData[i + 3]) / 255.0
                if a > 0.15 {
                    red += (CGFloat(rawData[i]) / 255.0) / a
                    green += (CGFloat(rawData[i + 1]) / 255.0) / a
                    blue += (CGFloat(rawData[i + 2]) / 255.0) / a
                    count += 1
                }
            }
            return count > 0 ? (red / count, green / count, blue / count) : nil
        }
    }

    nonisolated private static func sampleWallpaperColor(at imageURL: URL) -> (CGFloat, CGFloat, CGFloat)? {
        let ext = imageURL.pathExtension.lowercased()
        if ["mov", "mp4", "m4v"].contains(ext) {
            let asset = AVURLAsset(url: imageURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 64, height: 64)
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                return sampleCGImageTopCenter(cgImage)
            }
        }

        return autoreleasepool { () -> (CGFloat, CGFloat, CGFloat)? in
            let sourceOpts: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
                kCGImageSourceShouldCacheImmediately: false
            ]
            guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, sourceOpts as CFDictionary) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceShouldCache: false
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return sampleCGImageTopCenter(thumbnail)
        }
    }

    nonisolated private static func sampleCGImageTopCenter(_ cgImage: CGImage) -> (CGFloat, CGFloat, CGFloat)? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else { return nil }

        let size = CGSize(width: width, height: height)
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        let xStart = Int(Double(width) * 0.30)
        let xEnd = max(xStart + 1, Int(Double(width) * 0.70))
        let yStart = 0
        let yEnd = max(1, Int(Double(height) * 0.35))

        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0, count: CGFloat = 0
        for y in yStart..<yEnd {
            for x in xStart..<xEnd {
                let offset = (y * width + x) * 4
                guard offset + 3 < rawData.count else { continue }
                let a = CGFloat(rawData[offset + 3]) / 255.0
                if a > 0.15 {
                    totalR += (CGFloat(rawData[offset]) / 255.0) / a
                    totalG += (CGFloat(rawData[offset + 1]) / 255.0) / a
                    totalB += (CGFloat(rawData[offset + 2]) / 255.0) / a
                    count += 1
                }
            }
        }

        if count > 0 {
            return (totalR / count, totalG / count, totalB / count)
        }

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let a = CGFloat(rawData[i + 3]) / 255.0
            if a > 0.15 {
                totalR += (CGFloat(rawData[i]) / 255.0) / a
                totalG += (CGFloat(rawData[i + 1]) / 255.0) / a
                totalB += (CGFloat(rawData[i + 2]) / 255.0) / a
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return (totalR / count, totalG / count, totalB / count)
    }

    nonisolated public static func sampleWallpaperPalette(at imageURL: URL) -> MultiZonePalette? {
        let ext = imageURL.pathExtension.lowercased()
        if ["mov", "mp4", "m4v"].contains(ext) {
            let asset = AVURLAsset(url: imageURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 64, height: 64)
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                return sampleMultiZonePalette(from: cgImage)
            }
        }

        return autoreleasepool { () -> MultiZonePalette? in
            let sourceOpts: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
                kCGImageSourceShouldCacheImmediately: false
            ]
            guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, sourceOpts as CFDictionary) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceShouldCache: false
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return sampleMultiZonePalette(from: thumbnail)
        }
    }

    nonisolated public static func sampleMultiZonePalette(from cgImage: CGImage) -> MultiZonePalette {
        let sourceWidth = cgImage.width
        let sourceHeight = cgImage.height
        guard sourceWidth > 0 && sourceHeight > 0 else { return MultiZonePalette() }

        let scale = min(1.0, 64.0 / CGFloat(max(sourceWidth, sourceHeight)))
        let width = max(1, Int((CGFloat(sourceWidth) * scale).rounded(.down)))
        let height = max(1, Int((CGFloat(sourceHeight) * scale).rounded(.down)))
        let size = CGSize(width: width, height: height)
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return MultiZonePalette() }

        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        struct SamplePixel {
            let r: CGFloat
            let g: CGFloat
            let b: CGFloat
            let lum: CGFloat
            let sat: CGFloat
        }

        var pixels: [SamplePixel] = []
        pixels.reserveCapacity(width * height)

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let a = CGFloat(rawData[i + 3]) / 255.0
            if a > 0.15 {
                let r = min(1, max(0, (CGFloat(rawData[i]) / 255.0) / a))
                let g = min(1, max(0, (CGFloat(rawData[i + 1]) / 255.0) / a))
                let b = min(1, max(0, (CGFloat(rawData[i + 2]) / 255.0) / a))
                let lum = ContrastGuard.relativeLuminance(r: r, g: g, b: b)
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let sat = maxC > 0.001 ? (maxC - minC) / maxC : 0
                pixels.append(SamplePixel(r: r, g: g, b: b, lum: lum, sat: sat))
            }
        }

        guard !pixels.isEmpty else { return MultiZonePalette() }

        pixels.sort { $0.lum < $1.lum }

        let shadowCount = min(pixels.count, max(1, Int(Double(pixels.count) * 0.35)))
        var sR: CGFloat = 0, sG: CGFloat = 0, sB: CGFloat = 0
        for i in 0..<shadowCount {
            sR += pixels[i].r
            sG += pixels[i].g
            sB += pixels[i].b
        }
        let shadowRaw = (sR / CGFloat(shadowCount), sG / CGFloat(shadowCount), sB / CGFloat(shadowCount))
        let shadowSafe = ContrastGuard.ensureContrast(background: shadowRaw, forTextLuminance: 1.0, minRatio: 4.5)

        let midStart = min(shadowCount, pixels.count)
        let midEnd = min(pixels.count, max(midStart, Int(Double(pixels.count) * 0.75)))
        var mR: CGFloat = 0, mG: CGFloat = 0, mB: CGFloat = 0, mCount: CGFloat = 0
        if midStart < midEnd {
            for i in midStart..<midEnd {
                mR += pixels[i].r
                mG += pixels[i].g
                mB += pixels[i].b
                mCount += 1
            }
        }
        let midtone = mCount > 0 ? (mR / mCount, mG / mCount, mB / mCount) : shadowRaw

        let candidates = pixels.filter { $0.lum >= 0.10 && $0.lum <= 0.95 }
            .sorted { $0.sat > $1.sat }
        let top = candidates.prefix(max(1, candidates.count / 20))
        let highlight: (CGFloat, CGFloat, CGFloat)
        if let first = top.first, first.sat >= 0.10 {
            let n = CGFloat(top.count)
            highlight = (top.reduce(0) { $0 + $1.r } / n,
                         top.reduce(0) { $0 + $1.g } / n,
                         top.reduce(0) { $0 + $1.b } / n)
        } else if let last = pixels.last {
            highlight = (last.r, last.g, last.b)
        } else {
            highlight = (0.22, 0.62, 1.0)
        }

        return MultiZonePalette(
            shadowRGB: shadowSafe,
            midtoneRGB: midtone,
            highlightRGB: highlight
        )
    }
}

// MARK: - Design System

@MainActor
public struct DesignSystem {
    public static var currentTheme: AppTheme {
        SettingsStore.shared.currentTheme
    }

    public static var canvasColor: Color { DynamicThemeEngine.shared.canvasColor }
    public static var structureColor: Color { DynamicThemeEngine.shared.structureColor }
    public static var accentColor: Color { DynamicThemeEngine.shared.accentColor }
    public static var appAccentColor: Color { DynamicThemeEngine.shared.appAccentColor }
    public static var secondaryText: Color { DynamicThemeEngine.shared.secondaryTextColor }

    // FIX (#6): single source of truth for reduceMotion across the app.
    public static var reduceMotion: Bool {
        EnvironmentState.shared.reduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    public static var isLightTheme: Bool { currentTheme.isLight }
    public static var increaseContrastEnabled: Bool { EnvironmentState.shared.increaseContrast }

    public static var primaryText: Color {
        currentTheme.isLight ? currentTheme.primaryTextColor : Color.white
    }
    public static var tertiaryText: Color {
        let opacity = increaseContrastEnabled ? 0.62 : 0.40
        return currentTheme.isLight
            ? currentTheme.primaryTextColor.opacity(increaseContrastEnabled ? 0.78 : 0.55)
            : Color.white.opacity(opacity)
    }
    public static func fill(_ opacity: Double) -> Color {
        let value = min(1.0, max(0.0, opacity))
        return currentTheme.isLight ? Color.black.opacity(value * 0.6) : Color.white.opacity(value)
    }
    public static func ink(_ o: Double = 1) -> Color { primaryText.opacity(o) }
    // NOTE / WHY THIS IS RUNNING NOW (Error Fix):
    // Fixes compiler error in NowPlayingModule.swift:
    // "error: type 'DesignSystem' has no member 'accentInkColor'"
    // Provides high-contrast foreground color on accent-colored buttons across both dark and light themes.
    public static var accentInkColor: Color {
        currentTheme.isLight ? Color.black : Color.white
    }
    public static var subtleBorder: Color {
        let opacity = increaseContrastEnabled ? 0.20 : 0.08
        return currentTheme.isLight ? Color.black.opacity(opacity) : Color.white.opacity(increaseContrastEnabled ? 0.24 : 0.12)
    }
    public static var surfaceFill: Color {
        let opacity = increaseContrastEnabled ? 0.10 : 0.05
        return currentTheme.isLight ? Color.black.opacity(opacity) : Color.white.opacity(increaseContrastEnabled ? 0.14 : 0.08)
    }
    public static var cardFill: Color { structureColor.opacity(0.62) }
    public static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [structureColor.opacity(0.72), canvasColor.opacity(0.58)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    public static var cardBorder: Color {
        currentTheme.isLight
            ? Color.black.opacity(increaseContrastEnabled ? 0.18 : 0.08)
            : Color.white.opacity(increaseContrastEnabled ? 0.22 : 0.09)
    }
    public static let defaultCornerRadius: CGFloat = 18.0
    public static var springResponse: Double {
        SettingsStore.shared.motionPhysics.response
    }
    public static var springDamping: Double {
        SettingsStore.shared.motionPhysics.damping
    }
    public static let notchTransitionDuration: Double = 0.28
    public static var defaultHoverCollapseDelay: Double {
        SettingsStore.shared.autoCollapseDelay
    }
    public static let maxNotificationCards: Int = 50

    public static let widgetCornerRadius: CGFloat = 16.0
    public static let widgetInnerPadding: CGFloat = 10.0
    public static let widgetHorizontalPadding: CGFloat = 12.0
    public static let widgetVerticalPadding: CGFloat = 10.0
    public static let widgetHeaderSpacing: CGFloat = 6.0
    public static let widgetHeaderIconSize: CGFloat = 12.0
    public static let widgetHeaderFontSize: CGFloat = 11.5
    public static let widgetMinInteractiveTouchTarget: CGFloat = 24.0

    public static func moduleAccentColor(for moduleId: String) -> Color {
        if SettingsStore.shared.usePerModuleAccent {
            if let mod = ModuleRegistry.shared.modules.first(where: { $0.id == moduleId }) {
                return mod.themeColor
            }
        }
        return accentColor
    }
}

// MARK: - Feedback

@MainActor
public struct FeedbackManager {
    public static func playHover() {
        guard SettingsStore.shared.hapticFeedbackEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    public static func playClick() {
        if SettingsStore.shared.soundFeedbackEnabled {
            NSSound(named: "Tink")?.play()
        }
        if SettingsStore.shared.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }

    public static func playPin() {
        if SettingsStore.shared.soundFeedbackEnabled {
            NSSound(named: "Pop")?.play()
        }
        if SettingsStore.shared.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }

    public static func playSend() {
        if SettingsStore.shared.soundFeedbackEnabled {
            if !(NSSound(named: "Purr")?.play() ?? false) {
                _ = NSSound(named: "Glass")?.play()
            }
        }
        if SettingsStore.shared.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }

    public static func playDelete() {
        if SettingsStore.shared.soundFeedbackEnabled {
            NSSound(named: "Basso")?.play()
        }
        if SettingsStore.shared.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }

    public static func playSuccess() {
        if SettingsStore.shared.soundFeedbackEnabled {
            if !(NSSound(named: "Ping")?.play() ?? false) {
                _ = NSSound(named: "Glass")?.play()
            }
        }
        if SettingsStore.shared.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }

    public static func playDrop() {
        if SettingsStore.shared.soundFeedbackEnabled {
            NSSound(named: "Pop")?.play()
        }
        if SettingsStore.shared.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }

    public static func playProcess() {
        if SettingsStore.shared.soundFeedbackEnabled {
            NSSound(named: "Morse")?.play()
        }
        if SettingsStore.shared.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }
}

// MARK: - Notch Shape

public struct CustomNotchShape: Shape {
    public var topRadius: CGFloat
    public var bottomRadius: CGFloat

    public init(topRadius: CGFloat = 14, bottomRadius: CGFloat = 34) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
    }

    public func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: topRadius,
                bottomLeading: bottomRadius,
                bottomTrailing: bottomRadius,
                topTrailing: topRadius
            ),
            style: .continuous
        ).path(in: rect)
    }
}

// MARK: - Notch Glass Background

public struct NotchGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var themeEngine = DynamicThemeEngine.shared
    // FIX (Observation): observe NotchShellCoordinator so `hasPhysicalNotch`
    // changes (e.g. moving the notch to an external display) re-evaluate the
    // bezel-blend branch. Previously it was a static read on `.shared`.
    @ObservedObject private var shell = NotchShellCoordinator.shared

    public var topRadius: CGFloat
    public var bottomRadius: CGFloat
    public var showsMaterial: Bool

    public init(topRadius: CGFloat = 14, bottomRadius: CGFloat = 34, showsMaterial: Bool = true) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        self.showsMaterial = showsMaterial
    }

    public var body: some View {
        let glassStyle = store.glassMaterialStyle
        let glowEnabled = store.specularGlowEnabled

        ZStack {
            if showsMaterial && !reduceTransparency {
                let material: NSVisualEffectView.Material = {
                    switch glassStyle {
                    case .frosted: return .hudWindow
                    case .deepOLED: return .underWindowBackground
                    case .luminous: return .popover
                    case .crystal: return .headerView
                    }
                }()
                let canvasOpacity: Double = {
                    switch glassStyle {
                    case .frosted: return 0.55
                    case .deepOLED: return 0.96
                    case .luminous: return 0.25
                    case .crystal: return 0.08
                    }
                }()

                VisualEffectBlur(material: material, blendingMode: .behindWindow)
                    .clipShape(CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                    .overlay(
                        CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                            .fill(themeEngine.canvasColor.opacity(canvasOpacity))
                    )
                    .overlay(
                        Group {
                            if glassStyle == .deepOLED {
                                CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                                    .fill(Color.black.opacity(0.85))
                            }
                            if glassStyle == .luminous {
                                CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeEngine.accentColor.opacity(0.35),
                                                themeEngine.accentColor.opacity(0.08),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            if glassStyle == .crystal {
                                CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.20),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            }
                        }
                    )
                    .transition(.opacity)
            } else {
                CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                    .fill(themeEngine.canvasColor.opacity(0.95))
                    .transition(.opacity)
            }

            CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(glowEnabled ? 0.38 : 0.18),
                            themeEngine.accentColor.opacity(glowEnabled ? 0.42 : 0.14),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )

            // FIX (Observation): read from the observed `shell` instance.
            if store.currentTheme.isLight && shell.geometry.hasPhysicalNotch {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.35),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.16)
                )
                .clipShape(CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                .allowsHitTesting(false)
            }
        }
        .opacity(store.useCustomNotchOpacity ? store.customNotchOpacity : 1.0)
    }
}

// MARK: - Visual effect blur

public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        // NOTE / WHY THIS IS RUNNING NOW (Error Fix):
        // Previously written as `view.state = .followsWindow`, which produced:
        //   "error: type 'NSVisualEffectView.State' has no member 'followsWindow'"
        // The correct AppKit enum case is `NSVisualEffectView.State.followsWindowActiveState`.
        view.state = .followsWindowActiveState
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        // FIX: only touch the view when the properties actually differ, to
        // avoid invalidating the blur backdrop on every SwiftUI update pass.
        guard let effectView = nsView as? NSVisualEffectView else { return }
        if effectView.material != material { effectView.material = material }
        if effectView.blendingMode != blendingMode { effectView.blendingMode = blendingMode }
    }
}
