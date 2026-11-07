import SwiftUI
import AppKit
import ImageIO
import AVFoundation

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
        case .birch: return Color(red: 0.118, green: 0.118, blue: 0.118) // #1E1E1E Dark Charcoal
        case .sakura: return Color(red: 0.157, green: 0.094, blue: 0.125) // #281820 Deep Plum
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
        case .birch: return (0.969, 0.961, 0.941) // #F7F5F0 Warm Paper
        case .sakura: return (0.992, 0.965, 0.969) // #FDF6F7 Soft Pastel
        }
    }

    // 60% Dominant Canvas / Glass Tint
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
        case .birch: return (0.922, 0.906, 0.875) // #EBE7DF
        case .sakura: return (0.961, 0.898, 0.918) // #F5E5EA
        }
    }

    // 30% Structural Secondary (Surfaces, Cards, Inactive Pills, Dividers)
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
        case .birch: return (0.769, 0.490, 0.169) // #C47D2B Amber Accent
        case .sakura: return (0.878, 0.427, 0.549) // #E06D8C Blossom Pink Accent
        }
    }

    // 10% Accent Pop Color (Active states, Focus, Highlights, Primary Badges)
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
        case .birch: return (0.353, 0.337, 0.306) // #5A564E Dark Charcoal Gray
        case .sakura: return (0.431, 0.333, 0.376) // #6E5560 Deep Plum Gray
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

// MARK: - Collapsed Notch Indicator Style
public enum CompactIndicatorStyle: String, CaseIterable, Identifiable, Codable {
    case media = "Now Playing"
    case minimal = "Minimal Jewel"
    case battery = "Battery"
    case dateTime = "Clock"
    case circadian = "Solar Status"
    case threeZoneStatusBar = "3-Zone Status Bar"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .minimal: return "circle.fill"
        case .battery: return "battery.100.bolt"
        case .dateTime: return "clock.fill"
        case .circadian: return "sun.max.fill"
        case .threeZoneStatusBar: return "menubar.rectangle"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .media: return Color(red: 0.98, green: 0.35, blue: 0.55) // Living Rose
        case .minimal: return Color(red: 0.35, green: 0.85, blue: 0.98) // Cyan Jewel
        case .battery: return Color(red: 0.40, green: 0.88, blue: 0.45) // Lime Green
        case .dateTime: return Color(red: 0.30, green: 0.65, blue: 1.00) // Electric Blue
        case .circadian: return Color(red: 0.98, green: 0.72, blue: 0.22) // Solar Gold
        case .threeZoneStatusBar: return Color(red: 0.35, green: 0.78, blue: 0.98) // Sky Cyan
        }
    }
}

// MARK: - Apple Music Live Waveform Equalizer
public struct LiveEqualizerIndicator: View {
    let isPlaying: Bool
    var color: Color = DesignSystem.accentColor
    var barWidth: CGFloat = 2.0
    var maxHeight: CGFloat = 12.0
    
    public init(isPlaying: Bool, color: Color = DesignSystem.accentColor, barWidth: CGFloat = 2.0, maxHeight: CGFloat = 12.0) {
        self.isPlaying = isPlaying
        self.color = color
        self.barWidth = barWidth
        self.maxHeight = maxHeight
    }
    
    public var body: some View {
        let isExpanded = NotchShellCoordinator.shared.state == .expanded
        TimelineView(.animation(minimumInterval: 0.20, paused: !isPlaying || !isExpanded)) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 1.5) {
                equalizerBar(height: isPlaying ? barHeight(offset: 0.0, time: date) : 6)
                equalizerBar(height: isPlaying ? barHeight(offset: 0.9, time: date) : 11)
                equalizerBar(height: isPlaying ? barHeight(offset: 1.8, time: date) : 7)
                equalizerBar(height: isPlaying ? barHeight(offset: 2.7, time: date) : 9)
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

// Spring Button Style for Organic, Tactile Physics
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

// MARK: - Multi-Zone Palette (Shadow, Midtone, Highlight)
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

// MARK: - Color Detection Diagnostics & Telemetry
public struct ColorDetectionDiagnostics: Sendable {
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
}

@MainActor
public final class DynamicThemeEngine: ObservableObject {
    public static let shared = DynamicThemeEngine()
    
    @Published public var canvasColor: Color = Color(red: 0.05, green: 0.06, blue: 0.08)
    @Published public var structureColor: Color = Color(red: 0.13, green: 0.15, blue: 0.20)
    @Published public var accentColor: Color = Color(red: 0.22, green: 0.62, blue: 1.0)
    @Published public var appAccentColor: Color = Color(red: 0.22, green: 0.62, blue: 1.0)
    @Published public var secondaryTextColor: Color = Color(red: 0.75, green: 0.82, blue: 0.92)
    @Published public var paletteSource = "Wallpaper"
    @Published public var diagnostics = ColorDetectionDiagnostics()
    @Published public var multiZonePalette = MultiZonePalette()
    
    private var currentCanvasOKLab = OKLabColor(l: 0.08, a: 0.0, b: 0.0)
    private var currentStructureOKLab = OKLabColor(l: 0.16, a: 0.0, b: 0.0)
    private var currentAccentOKLab = OKLabColor(l: 0.65, a: 0.0, b: -0.15)
    private var transitionTask: Task<Void, Never>?
    
    private var sampledWallpaperURL: URL?
    private var sampledWallpaperModDate: Date?
    private var sampledWallpaperPalette: MultiZonePalette?
    private var sampledWallpaperColor: (CGFloat, CGFloat, CGFloat)?
    private var sampledAppColors: [String: (CGFloat, CGFloat, CGFloat)] = [:]
    private var samplingAppBundleIDs: Set<String> = []
    private var isSamplingWallpaper = false
    private var activationObserver: NSObjectProtocol?
    private var spaceChangeObserver: NSObjectProtocol?
    private var displayChangeObserver: NSObjectProtocol?

    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshColors()
        }
    }
    
    public func redetectColors() {
        sampledWallpaperURL = nil
        sampledWallpaperModDate = nil
        sampledWallpaperColor = nil
        sampledWallpaperPalette = nil
        sampledAppColors.removeAll()
        refreshColors()
    }
    
    private func applyCurrentOKLabColors() {
        let cRGB = currentCanvasOKLab.toRGB()
        let sRGB = currentStructureOKLab.toRGB()
        let aRGB = currentAccentOKLab.toRGB()
        
        // Guarantee contrast on final rendered canvas color
        let safeCanvas = ContrastGuard.ensureContrast(background: cRGB, forTextLuminance: 1.0, minRatio: 4.5)
        
        self.canvasColor = Color(red: safeCanvas.0, green: safeCanvas.1, blue: safeCanvas.2)
        self.structureColor = Color(red: sRGB.0, green: sRGB.1, blue: sRGB.2)
        self.accentColor = Color(red: aRGB.0, green: aRGB.1, blue: aRGB.2)
    }
    
    private func transitionTo(targetCanvas: OKLabColor, targetStructure: OKLabColor, targetAccent: OKLabColor) {
        let isCollapsed = (NotchShellCoordinator.shared.state == .collapsed)
        let reduceMotion = EnvironmentState.shared.reduceMotion || SettingsStore.shared.motionPhysics == .snappy
        
        transitionTask?.cancel()
        transitionTask = nil
        
        if isCollapsed || reduceMotion {
            // Instant transition when notch is collapsed or Reduce Motion is active
            currentCanvasOKLab = targetCanvas
            currentStructureOKLab = targetStructure
            currentAccentOKLab = targetAccent
            applyCurrentOKLabColors()
            return
        }
        
        // Smooth interruptible OKLab transition
        let startCanvas = currentCanvasOKLab
        let startStructure = currentStructureOKLab
        let startAccent = currentAccentOKLab
        
        transitionTask = Task { @MainActor [weak self] in
            let steps = 12
            let duration: TimeInterval = 0.30
            let interval = duration / Double(steps)
            for step in 1...steps {
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                let t = CGFloat(step) / CGFloat(steps)
                let easeT = sin(t * .pi / 2.0)
                guard let self else { break }
                self.currentCanvasOKLab = OKLabColor.blend(startCanvas, targetCanvas, progress: easeT)
                self.currentStructureOKLab = OKLabColor.blend(startStructure, targetStructure, progress: easeT)
                self.currentAccentOKLab = OKLabColor.blend(startAccent, targetAccent, progress: easeT)
                self.applyCurrentOKLabColors()
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
            if structureColor != newStruct { structureColor = newStruct }
            if canvasColor != newCanvas { canvasColor = newCanvas }
            if secondaryTextColor != newSec { secondaryTextColor = newSec }
            if paletteSource != theme.displayName { paletteSource = theme.displayName }
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
                    self.sampledWallpaperURL = nil
                    self.sampledWallpaperColor = nil
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
                    self.sampledWallpaperURL = nil
                    self.sampledWallpaperColor = nil
                    self.refreshColors()
                }
            }
        }

        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
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
        
        let isCacheValid = (imageURL != nil && sampledWallpaperURL == imageURL && sampledWallpaperModDate == fileModDate && sampledWallpaperColor != nil)
        
        if let imageURL = imageURL, !isCacheValid, !isSamplingWallpaper {
            isSamplingWallpaper = true
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let palette = Self.sampleWallpaperPalette(at: imageURL)
                let color = palette?.highlightRGB ?? Self.sampleWallpaperColor(at: imageURL)
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isSamplingWallpaper = false
                    self.sampledWallpaperURL = imageURL
                    self.sampledWallpaperModDate = fileModDate
                    self.sampledWallpaperColor = color
                    self.sampledWallpaperPalette = palette
                    if let pal = palette {
                        self.multiZonePalette = pal
                    }
                    if SettingsStore.shared.currentTheme == .adaptive || SettingsStore.shared.currentTheme == .activeApp {
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
            if let art = NowPlayingModule.shared.artwork,
               let color = Self.sampleImageColor(art) {
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
            
            // STAGE 1: Sampled Wallpaper File
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
            
            // STAGE 2: Frontmost App Icon (if activeApp theme OR wallpaper is desaturated/gray)
            let frontmost = NSWorkspace.shared.frontmostApplication
            let bundleID = frontmost?.bundleIdentifier ?? ""
            d.frontmostAppName = frontmost?.localizedName ?? "None"
            d.frontmostBundleID = bundleID
            
            let isOwnApp = bundleID.isEmpty || bundleID == Bundle.main.bundleIdentifier || bundleID.contains("NotchApp") || bundleID == "com.apple.dock"
            
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
            
            // STAGE 3: macOS System Accent Color Fallback
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
            
            // STAGE 4: Circadian Solar Time-of-Day Fallback
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
        self.diagnostics = d

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
        
        transitionTo(targetCanvas: tCanvasOKLab, targetStructure: tStructureOKLab, targetAccent: tAccentOKLab)
        
        let secondaryText = theme.isLight ? theme.secondaryTextColor : Color.white.opacity(0.68)
        if secondaryTextColor != secondaryText { secondaryTextColor = secondaryText }
    }

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
        
        // Sample top-center notch region (X: 30% to 70%, Y: top 35% of image)
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
        
        // Fallback to full thumbnail average if top-center was transparent
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
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else { return MultiZonePalette() }
        
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
                let r = (CGFloat(rawData[i]) / 255.0) / a
                let g = (CGFloat(rawData[i + 1]) / 255.0) / a
                let b = (CGFloat(rawData[i + 2]) / 255.0) / a
                let lum = ContrastGuard.relativeLuminance(r: r, g: g, b: b)
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let sat = maxC > 0.001 ? (maxC - minC) / maxC : 0
                pixels.append(SamplePixel(r: r, g: g, b: b, lum: lum, sat: sat))
            }
        }
        
        guard !pixels.isEmpty else { return MultiZonePalette() }
        
        pixels.sort { $0.lum < $1.lum }
        
        // 1. Shadow Zone: lowest 35% luminance
        let shadowCount = max(1, Int(Double(pixels.count) * 0.35))
        var sR: CGFloat = 0, sG: CGFloat = 0, sB: CGFloat = 0
        for i in 0..<shadowCount {
            sR += pixels[i].r
            sG += pixels[i].g
            sB += pixels[i].b
        }
        let shadowRaw = (sR / CGFloat(shadowCount), sG / CGFloat(shadowCount), sB / CGFloat(shadowCount))
        let shadowSafe = ContrastGuard.ensureContrast(background: shadowRaw, forTextLuminance: 1.0, minRatio: 4.5)
        
        // 2. Midtone Zone: 35% to 75% luminance
        let midStart = shadowCount
        let midEnd = max(midStart + 1, Int(Double(pixels.count) * 0.75))
        var mR: CGFloat = 0, mG: CGFloat = 0, mB: CGFloat = 0, mCount: CGFloat = 0
        for i in midStart..<midEnd {
            mR += pixels[i].r
            mG += pixels[i].g
            mB += pixels[i].b
            mCount += 1
        }
        let midtone = mCount > 0 ? (mR / mCount, mG / mCount, mB / mCount) : (0.13, 0.15, 0.20)
        
        // 3. Highlight Zone: pixel with highest saturation
        var maxSatPixel = pixels[0]
        for p in pixels {
            if p.sat > maxSatPixel.sat && p.lum >= 0.10 && p.lum <= 0.95 {
                maxSatPixel = p
            }
        }
        let highlight = maxSatPixel.sat >= 0.10 ? (maxSatPixel.r, maxSatPixel.g, maxSatPixel.b) : (pixels.last!.r, pixels.last!.g, pixels.last!.b)
        
        return MultiZonePalette(
            shadowRGB: shadowSafe,
            midtoneRGB: midtone,
            highlightRGB: highlight
        )
    }
}

@MainActor
public struct DesignSystem {
    public static var currentTheme: AppTheme {
        SettingsStore.shared.currentTheme
    }
    
    // 60-30-10 Rule Dynamic Colors
    public static var canvasColor: Color { DynamicThemeEngine.shared.canvasColor }
    public static var structureColor: Color { DynamicThemeEngine.shared.structureColor }
    public static var accentColor: Color { DynamicThemeEngine.shared.accentColor }
    public static var appAccentColor: Color { DynamicThemeEngine.shared.appAccentColor }
    public static var secondaryText: Color { DynamicThemeEngine.shared.secondaryTextColor }
    public static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    
    public static var primaryText: Color {
        currentTheme.isLight ? currentTheme.primaryTextColor : Color.white
    }
    public static var tertiaryText: Color {
        currentTheme.isLight ? Color.black.opacity(0.38) : Color.white.opacity(0.40)
    }
    public static var subtleBorder: Color {
        currentTheme.isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.12)
    }
    public static var surfaceFill: Color {
        currentTheme.isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.08)
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
        currentTheme.isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.09)
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
    
    // Global vs Per-Module Signature Accent Color
    public static func moduleAccentColor(for moduleId: String) -> Color {
        if SettingsStore.shared.usePerModuleAccent {
            if let mod = ModuleRegistry.shared.modules.first(where: { $0.id == moduleId }) {
                return mod.themeColor
            }
        }
        return accentColor
    }
}

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

// Organic Continuous Squircle Shape (Deep radius, seamless with MacBook Notch)
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

// Clean Glass Background (No outer shadow, crisp specular hairline reflection)
public struct NotchGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var themeEngine = DynamicThemeEngine.shared
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
                    case .luminous: return .hudWindow
                    case .crystal: return .headerView
                    }
                }()
                let canvasOpacity: Double = {
                    switch glassStyle {
                    case .frosted: return 0.58
                    case .deepOLED: return 0.92
                    case .luminous: return 0.38
                    case .crystal: return 0.18
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
                            if glassStyle == .luminous {
                                CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeEngine.accentColor.opacity(0.24),
                                                themeEngine.accentColor.opacity(0.04),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
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
            
            // Machined Specular Glass Hairline (Crisp bevel, dynamic accent reflection)
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
            
            // Top Camera Bezel Blend for Light Themes: Blends into MacBook bezel without a white halo
            if store.currentTheme.isLight && NotchGeometry.current().hasPhysicalNotch {
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
    }
}

public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material = .hudWindow,
                blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        if let effectView = nsView as? NSVisualEffectView {
            effectView.material = material
            effectView.blendingMode = blendingMode
        }
    }
}
