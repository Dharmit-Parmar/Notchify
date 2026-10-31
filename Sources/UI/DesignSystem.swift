import SwiftUI
import AppKit
import ImageIO

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
    
    public var id: String { rawValue }

    public var isDynamic: Bool {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive:
            return true
        default:
            return false
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
        default: "Color preset"
        }
    }
    
    // 60% Dominant Canvas / Glass Tint
    @MainActor
    public var canvasColor: Color {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive:
            return DynamicThemeEngine.shared.canvasColor
        case .midnight:
            return Color(red: 0.04, green: 0.06, blue: 0.10)
        case .cyberpunk:
            return Color(red: 0.03, green: 0.07, blue: 0.05)
        case .sunset:
            return Color(red: 0.08, green: 0.04, blue: 0.06)
        case .solar:
            return Color(red: 0.07, green: 0.05, blue: 0.03)
        case .amethyst:
            return Color(red: 0.06, green: 0.03, blue: 0.09)
        case .titanium:
            return Color(red: 0.03, green: 0.03, blue: 0.03)
        case .aurora:
            return Color(red: 0.04, green: 0.07, blue: 0.09)
        case .cupertino:
            return Color(red: 0.05, green: 0.06, blue: 0.08)
        case .dune:
            return Color(red: 0.07, green: 0.05, blue: 0.03)
        case .neonTokyo:
            return Color(red: 0.06, green: 0.03, blue: 0.08)
        case .crimson:
            return Color(red: 0.08, green: 0.02, blue: 0.04)
        case .slate:
            return Color(red: 0.05, green: 0.05, blue: 0.06)
        case .nordic:
            return Color(red: 0.04, green: 0.06, blue: 0.08)
        case .starlight:
            return Color(red: 0.06, green: 0.05, blue: 0.04)
        case .noir:
            return Color(red: 0.02, green: 0.02, blue: 0.02)
        case .emerald:
            return Color(red: 0.03, green: 0.06, blue: 0.04)
        }
    }
    
    // 30% Structural Secondary (Surfaces, Cards, Inactive Pills, Dividers)
    @MainActor
    public var structureColor: Color {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive:
            return DynamicThemeEngine.shared.structureColor
        case .midnight:
            return Color(red: 0.11, green: 0.16, blue: 0.25)
        case .cyberpunk:
            return Color(red: 0.07, green: 0.13, blue: 0.11)
        case .sunset:
            return Color(red: 0.15, green: 0.08, blue: 0.11)
        case .solar:
            return Color(red: 0.14, green: 0.11, blue: 0.07)
        case .amethyst:
            return Color(red: 0.12, green: 0.08, blue: 0.17)
        case .titanium:
            return Color(red: 0.14, green: 0.14, blue: 0.16)
        case .aurora:
            return Color(red: 0.09, green: 0.16, blue: 0.18)
        case .cupertino:
            return Color(red: 0.12, green: 0.14, blue: 0.19)
        case .dune:
            return Color(red: 0.16, green: 0.12, blue: 0.08)
        case .neonTokyo:
            return Color(red: 0.16, green: 0.08, blue: 0.20)
        case .crimson:
            return Color(red: 0.18, green: 0.06, blue: 0.10)
        case .slate:
            return Color(red: 0.13, green: 0.13, blue: 0.15)
        case .nordic:
            return Color(red: 0.10, green: 0.15, blue: 0.19)
        case .starlight:
            return Color(red: 0.16, green: 0.14, blue: 0.11)
        case .noir:
            return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .emerald:
            return Color(red: 0.08, green: 0.15, blue: 0.10)
        }
    }
    
    // 10% Accent Pop Color (Active states, Focus, Highlights, Primary Badges)
    @MainActor
    public var accentColor: Color {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive:
            return DynamicThemeEngine.shared.accentColor
        case .midnight:
            return Color(red: 0.32, green: 0.62, blue: 0.90)
        case .cyberpunk:
            return Color(red: 0.38, green: 0.76, blue: 0.62)
        case .sunset:
            return Color(red: 0.90, green: 0.42, blue: 0.50)
        case .solar:
            return Color(red: 0.91, green: 0.68, blue: 0.34)
        case .amethyst:
            return Color(red: 0.72, green: 0.54, blue: 0.90)
        case .titanium:
            return Color(red: 0.84, green: 0.88, blue: 0.94)
        case .aurora:
            return Color(red: 0.18, green: 0.83, blue: 0.75)
        case .cupertino:
            return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .dune:
            return Color(red: 0.96, green: 0.62, blue: 0.12)
        case .neonTokyo:
            return Color(red: 0.96, green: 0.25, blue: 0.44)
        case .crimson:
            return Color(red: 0.88, green: 0.11, blue: 0.28)
        case .slate:
            return Color(red: 0.89, green: 0.91, blue: 0.94)
        case .nordic:
            return Color(red: 0.35, green: 0.78, blue: 0.90)
        case .starlight:
            return Color(red: 0.92, green: 0.78, blue: 0.50)
        case .noir:
            return Color(red: 0.98, green: 0.98, blue: 0.98)
        case .emerald:
            return Color(red: 0.20, green: 0.82, blue: 0.45)
        }
    }
    
    @MainActor
    public var secondaryTextColor: Color {
        switch self {
        case .adaptive, .activeApp, .circadian, .musicReactive:
            return DynamicThemeEngine.shared.secondaryTextColor
        case .midnight:
            return Color(red: 0.65, green: 0.75, blue: 0.88)
        case .cyberpunk:
            return Color(red: 0.62, green: 0.80, blue: 0.70)
        case .sunset:
            return Color(red: 0.82, green: 0.68, blue: 0.75)
        case .solar:
            return Color(red: 0.82, green: 0.75, blue: 0.65)
        case .amethyst:
            return Color(red: 0.78, green: 0.68, blue: 0.88)
        case .titanium:
            return Color.white.opacity(0.65)
        case .aurora:
            return Color(red: 0.65, green: 0.85, blue: 0.82)
        case .cupertino:
            return Color(red: 0.72, green: 0.80, blue: 0.90)
        case .dune:
            return Color(red: 0.86, green: 0.78, blue: 0.68)
        case .neonTokyo:
            return Color(red: 0.88, green: 0.70, blue: 0.82)
        case .crimson:
            return Color(red: 0.85, green: 0.68, blue: 0.72)
        case .slate:
            return Color(red: 0.75, green: 0.77, blue: 0.80)
        case .nordic:
            return Color(red: 0.70, green: 0.84, blue: 0.90)
        case .starlight:
            return Color(red: 0.88, green: 0.82, blue: 0.72)
        case .noir:
            return Color.white.opacity(0.60)
        case .emerald:
            return Color(red: 0.65, green: 0.85, blue: 0.72)
        }
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
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .media: return "music.note"
        case .minimal: return "circle.fill"
        case .battery: return "battery.100.bolt"
        case .dateTime: return "clock.fill"
        case .circadian: return "sun.max.fill"
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
        TimelineView(.animation(minimumInterval: 0.12, paused: !isPlaying)) { timeline in
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
    public var response: Double = 0.24
    public var damping: Double = 1.0
    
    public init(scaleAmount: CGFloat = 0.97, response: Double = 0.24, damping: Double = 1.0) {
        self.scaleAmount = scaleAmount
        self.response = response
        self.damping = damping
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        SpringButtonLabel(
            label: configuration.label,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion,
            isEnabled: isEnabled,
            scaleAmount: scaleAmount,
            response: response,
            damping: damping
        )
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

private final class SpringButtonHoverState: ObservableObject {
    @Published var isHovered = false
}

private struct SpringButtonLabel<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let reduceMotion: Bool
    let isEnabled: Bool
    let scaleAmount: CGFloat
    let response: Double
    let damping: Double
    @StateObject private var hoverState = SpringButtonHoverState()

    var body: some View {
        label
            .scaleEffect(isEnabled && isPressed && !reduceMotion ? scaleAmount : (isEnabled && hoverState.isHovered && !reduceMotion ? 1.015 : 1))
            .opacity(!isEnabled ? 0.35 : (isPressed && !reduceMotion ? 0.88 : 1))
            .animation(reduceMotion ? nil : .spring(response: response, dampingFraction: damping), value: isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hoverState.isHovered)
            .onHover { hoverState.isHovered = isEnabled && $0 }
    }
}

extension ButtonStyle where Self == SpringButtonStyle {
    public static var spring: SpringButtonStyle { SpringButtonStyle() }
    public static func spring(scale: CGFloat) -> SpringButtonStyle { SpringButtonStyle(scaleAmount: scale) }
}

@MainActor
public final class DynamicThemeEngine: ObservableObject {
    public static let shared = DynamicThemeEngine()
    
    @Published public var canvasColor: Color = Color(red: 0.05, green: 0.06, blue: 0.08)
    @Published public var structureColor: Color = Color(red: 0.13, green: 0.15, blue: 0.20)
    @Published public var accentColor: Color = Color(red: 0.22, green: 0.62, blue: 1.0)
    @Published public var secondaryTextColor: Color = Color(red: 0.75, green: 0.82, blue: 0.92)
    @Published public var paletteSource = "Wallpaper"
    
    private var sampledWallpaperURL: URL?
    private var sampledWallpaperColor: (CGFloat, CGFloat, CGFloat)?
    private var sampledAppColors: [String: (CGFloat, CGFloat, CGFloat)] = [:]
    private var samplingAppBundleIDs: Set<String> = []
    private var isSamplingWallpaper = false
    private var activationObserver: NSObjectProtocol?

    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshColors()
        }
    }
    
    public func refreshColors() {
        let theme = SettingsStore.shared.currentTheme
        guard theme.isDynamic else {
            if let activationObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
                self.activationObserver = nil
            }
            return
        }

        if activationObserver == nil {
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if NotchShellCoordinator.shared.state == .expanded || NotchShellCoordinator.shared.isHovered {
                        self.refreshColors()
                    }
                }
            }
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        
        var hue: CGFloat = 0.60
        var saturation: CGFloat = 0.72
        var sourceName = "Dynamic"
        var avgR: CGFloat = 0.14
        var avgG: CGFloat = 0.15
        var avgB: CGFloat = 0.18
        
        if let imageURL = screen.flatMap({ NSWorkspace.shared.desktopImageURL(for: $0) }),
           sampledWallpaperURL != imageURL, !isSamplingWallpaper {
            isSamplingWallpaper = true
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let color = Self.sampleWallpaperColor(at: imageURL)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isSamplingWallpaper = false
                    self.sampledWallpaperURL = imageURL
                    self.sampledWallpaperColor = color
                    if SettingsStore.shared.currentTheme == .adaptive || SettingsStore.shared.currentTheme == .activeApp { self.refreshColors() }
                }
            }
        }

        switch theme {
        case .circadian:
            let cal = Calendar.current
            let now = Date()
            let hour = cal.component(.hour, from: now)
            let minute = cal.component(.minute, from: now)
            let timeFrac = Double(hour) + Double(minute) / 60.0
            
            if timeFrac >= 5.0 && timeFrac < 8.5 {
                hue = 0.98
                saturation = 0.65
                sourceName = "Solar Dawn"
            } else if timeFrac >= 8.5 && timeFrac < 17.0 {
                hue = 0.58
                saturation = 0.70
                sourceName = "Daylight Sky"
            } else if timeFrac >= 17.0 && timeFrac < 20.5 {
                hue = 0.08
                saturation = 0.82
                sourceName = "Golden Hour"
            } else {
                hue = 0.62
                saturation = 0.55
                sourceName = "Starlight Night"
            }
            
        case .musicReactive:
            if let art = NowPlayingModule.shared.artwork,
               let color = Self.sampleImageColor(art) {
                let nsColor = NSColor(red: color.0, green: color.1, blue: color.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
                nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                if s >= 0.12 {
                    hue = h
                    saturation = max(0.40, s)
                    sourceName = "Now Playing Aura"
                } else {
                    hue = 0.58
                    saturation = 0.65
                    sourceName = "Now Playing (Ambient)"
                }
            } else if NowPlayingModule.shared.hasActiveMedia {
                hue = 0.80
                saturation = 0.75
                sourceName = "Now Playing"
            } else {
                hue = 0.58
                saturation = 0.60
                sourceName = "Music Aura"
            }
            
        case .adaptive, .activeApp:
            let followsActiveApp = theme == .activeApp
            if let sampledWallpaperColor {
                (avgR, avgG, avgB) = sampledWallpaperColor
            }
            let wallpaper = NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
            var wallHue: CGFloat = 0, wallSat: CGFloat = 0, wallBri: CGFloat = 0, wallAlpha: CGFloat = 1
            wallpaper.getHue(&wallHue, saturation: &wallSat, brightness: &wallBri, alpha: &wallAlpha)
            hue = wallHue
            saturation = wallSat
            sourceName = "Wallpaper"

        if followsActiveApp || saturation < 0.16 {
            let app = NSWorkspace.shared.frontmostApplication
            let bundleID = app?.bundleIdentifier
            let appColor: (CGFloat, CGFloat, CGFloat)?
            if let bundleID, let cached = sampledAppColors[bundleID] {
                appColor = cached
            } else {
                appColor = nil
                if let bundleID, let icon = app?.icon, !samplingAppBundleIDs.contains(bundleID) {
                    samplingAppBundleIDs.insert(bundleID)
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        let color = Self.sampleImageColor(icon)
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.samplingAppBundleIDs.remove(bundleID)
                            if self.sampledAppColors.count > 50 { self.sampledAppColors.removeAll() }
                            if let color { self.sampledAppColors[bundleID] = color }
                            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID,
                               SettingsStore.shared.currentTheme == .activeApp || SettingsStore.shared.currentTheme == .adaptive {
                                self.refreshColors()
                            }
                        }
                    }
                }
            }

            if let appColor {
                let appImageColor = NSColor(red: appColor.0, green: appColor.1, blue: appColor.2, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
                var appHue: CGFloat = 0, appSaturation: CGFloat = 0, appBrightness: CGFloat = 0, appAlpha: CGFloat = 1
                appImageColor.getHue(&appHue, saturation: &appSaturation, brightness: &appBrightness, alpha: &appAlpha)
                if appSaturation >= 0.16 {
                    hue = appHue
                    saturation = appSaturation
                    sourceName = app?.localizedName ?? "Application"
                }
            }
        }

            if saturation < 0.16 {
                hue = 0.60
                saturation = 0.72
                sourceName = "Default"
            }
        default:
            break
        }

        let vibrancy = SettingsStore.shared.dynamicVibrancy.factor
        saturation = min(0.95, saturation * vibrancy)

        if paletteSource != sourceName { paletteSource = sourceName }

        let canvas = Color(hue: hue, saturation: min(0.36, saturation * 0.55), brightness: 0.075)
        if canvasColor != canvas { canvasColor = canvas }
        let structure = Color(hue: hue, saturation: min(0.48, saturation * 0.68), brightness: 0.20)
        if structureColor != structure { structureColor = structure }
        let accent = Color(hue: hue, saturation: min(0.85, max(0.40, saturation * 0.85)), brightness: 0.94)
        if accentColor != accent { accentColor = accent }
        let secondaryText = Color.white.opacity(0.68)
        if secondaryTextColor != secondaryText { secondaryTextColor = secondaryText }
    }

    nonisolated private static func sampleImageColor(_ image: NSImage) -> (CGFloat, CGFloat, CGFloat)? {
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

    nonisolated private static func sampleWallpaperColor(at imageURL: URL) -> (CGFloat, CGFloat, CGFloat)? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 128
        ]
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let rep = NSBitmapImageRep(cgImage: thumbnail)
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        let sampleXStart = Int(Double(width) * 0.20)
        let sampleXEnd = Int(Double(width) * 0.80)
        let sampleYStart = Int(Double(height) * 0.20)
        let sampleYEnd = max(sampleYStart + 1, Int(Double(height) * 0.80))
        let stepX = max(1, (sampleXEnd - sampleXStart) / 16)
        let stepY = max(1, (sampleYEnd - sampleYStart) / 8)
        var hueWeights = Array(repeating: CGFloat.zero, count: 24)
        var reds = hueWeights, greens = hueWeights, blues = hueWeights
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0, count: CGFloat = 0

        for y in stride(from: sampleYStart, to: sampleYEnd, by: stepY) {
            for x in stride(from: sampleXStart, to: sampleXEnd, by: stepX) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let red = color.redComponent, green = color.greenComponent, blue = color.blueComponent
                totalR += red; totalG += green; totalB += blue; count += 1

                var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 1
                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                guard saturation >= 0.12 else { continue }
                let weight = saturation * max(0.25, brightness)
                let bin = min(23, Int(hue * 24))
                hueWeights[bin] += weight
                reds[bin] += red * weight
                greens[bin] += green * weight
                blues[bin] += blue * weight
            }
        }

        guard count > 0 else { return nil }
        if let dominantBin = hueWeights.indices.max(by: { hueWeights[$0] < hueWeights[$1] }), hueWeights[dominantBin] > 0 {
            let weight = hueWeights[dominantBin]
            return (reds[dominantBin] / weight, greens[dominantBin] / weight, blues[dominantBin] / weight)
        }
        return (totalR / count, totalG / count, totalB / count)
    }
}

@MainActor
public struct DesignSystem {
    public static var currentTheme: AppTheme {
        SettingsStore.shared.currentTheme
    }
    
    // 60-30-10 Rule Dynamic Colors
    public static var canvasColor: Color { currentTheme.canvasColor }
    public static var structureColor: Color { currentTheme.structureColor }
    public static var accentColor: Color { currentTheme.accentColor }
    public static var secondaryText: Color { currentTheme.secondaryTextColor }
    public static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    
    public static let primaryText = Color.white
    public static let tertiaryText = Color.white.opacity(0.40)
    public static let subtleBorder = Color.white.opacity(0.12)
    public static let surfaceFill = Color.white.opacity(0.08)
    public static var cardFill: Color { structureColor.opacity(0.62) }
    public static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [structureColor.opacity(0.72), canvasColor.opacity(0.58)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    public static let cardBorder = Color.white.opacity(0.09)
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
    public var topRadius: CGFloat
    public var bottomRadius: CGFloat
    public var showsMaterial: Bool
    
    public init(topRadius: CGFloat = 14, bottomRadius: CGFloat = 34, showsMaterial: Bool = true) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        self.showsMaterial = showsMaterial
    }
    
    public var body: some View {
        let glassStyle = SettingsStore.shared.glassMaterialStyle
        let glowEnabled = SettingsStore.shared.specularGlowEnabled
        
        ZStack {
            if showsMaterial && !reduceTransparency {
                if #available(macOS 26.0, *) {
                    CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                        .fill(.clear)
                        .glassEffect(.regular.tint(DesignSystem.canvasColor.opacity(0.18)), in: CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                        .transition(.opacity)
                } else {
                    let material: NSVisualEffectView.Material = (glassStyle == .crystal) ? .hudWindow : .headerView
                    let canvasOpacity: Double = {
                        switch glassStyle {
                        case .frosted: return 0.58
                        case .deepOLED: return 0.92
                        case .luminous: return 0.42
                        case .crystal: return 0.22
                        }
                    }()
                    
                    VisualEffectBlur(material: material, blendingMode: .behindWindow)
                        .clipShape(CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                        .overlay(
                            CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                                .fill(DesignSystem.canvasColor.opacity(canvasOpacity))
                        )
                        .overlay(
                            Group {
                                if glassStyle == .luminous {
                                    CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    DesignSystem.accentColor.opacity(0.16),
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
                }
            } else {
                CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                    .fill(DesignSystem.canvasColor.opacity(0.95))
                    .transition(.opacity)
            }
            
            // Machined Specular Glass Hairline (Crisp bevel, dynamic accent reflection)
            CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(glowEnabled ? 0.32 : 0.18),
                            DesignSystem.accentColor.opacity(glowEnabled ? 0.35 : 0.15),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )
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
