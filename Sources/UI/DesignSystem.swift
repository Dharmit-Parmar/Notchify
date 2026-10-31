import SwiftUI
import AppKit
import ImageIO

public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case adaptive = "Dynamic Wallpaper & App Glass"
    case activeApp = "Dynamic Active App"
    case midnight = "Midnight Azure"
    case cyberpunk = "Cyber Emerald"
    case sunset = "Sunset Crimson"
    case solar = "Solar Amber"
    case amethyst = "Deep Amethyst"
    case titanium = "Titanium Luxury"
    
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .adaptive: "Wallpaper"
        case .activeApp: "Active App"
        case .midnight: "Midnight"
        case .cyberpunk: "Forest"
        case .sunset: "Rose"
        case .solar: "Amber"
        case .amethyst: "Amethyst"
        case .titanium: "Graphite"
        }
    }

    public var subtitle: String {
        switch self {
        case .adaptive: "Wallpaper colors"
        case .activeApp: "Foreground app colors"
        default: "Color preset"
        }
    }
    
    // 60% Dominant Canvas / Glass Tint
    @MainActor
    public var canvasColor: Color {
        switch self {
        case .adaptive, .activeApp:
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
        }
    }
    
    // 30% Structural Secondary (Surfaces, Cards, Inactive Pills, Dividers)
    @MainActor
    public var structureColor: Color {
        switch self {
        case .adaptive, .activeApp:
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
        }
    }
    
    // 10% Accent Pop Color (Active states, Focus, Highlights, Primary Badges)
    @MainActor
    public var accentColor: Color {
        switch self {
        case .adaptive, .activeApp:
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
        }
    }
    
    @MainActor
    public var secondaryTextColor: Color {
        switch self {
        case .adaptive, .activeApp:
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
        }
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
        refreshColors()
    }
    
    public func refreshColors() {
        let followsActiveApp = SettingsStore.shared.currentTheme == .activeApp
        if SettingsStore.shared.currentTheme == .adaptive || followsActiveApp {
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
        } else {
            if let activationObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
                self.activationObserver = nil
            }
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        
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

        if let sampledWallpaperColor {
            (avgR, avgG, avgB) = sampledWallpaperColor
        }
        let wallpaper = NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1).usingColorSpace(.deviceRGB) ?? .systemBlue
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 1
        wallpaper.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        var sourceName = "Wallpaper"

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
        if paletteSource != sourceName { paletteSource = sourceName }

        let canvas = Color(hue: hue, saturation: min(0.36, saturation * 0.55), brightness: 0.075)
        if canvasColor != canvas { canvasColor = canvas }
        let structure = Color(hue: hue, saturation: min(0.48, saturation * 0.68), brightness: 0.20)
        if structureColor != structure { structureColor = structure }
        let accent = Color(hue: hue, saturation: min(0.72, max(0.40, saturation * 0.82)), brightness: 0.92)
        if accentColor != accent { accentColor = accent }
        let secondaryText = Color.white.opacity(0.68)
        if secondaryTextColor != secondaryText { secondaryTextColor = secondaryText }
    }

    nonisolated private static func sampleImageColor(_ image: NSImage) -> (CGFloat, CGFloat, CGFloat)? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return nil }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, count: CGFloat = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: max(1, rep.pixelsHigh / 12)) {
            for x in stride(from: 0, to: rep.pixelsWide, by: max(1, rep.pixelsWide / 12)) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                red += color.redComponent; green += color.greenComponent; blue += color.blueComponent; count += 1
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
    public static let springResponse: Double = 0.32
    public static let springDamping: Double = 1.0
    public static let notchTransitionDuration: Double = 0.28
    public static let defaultHoverCollapseDelay: Double = 0.25
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
        ZStack {
            if showsMaterial && !reduceTransparency {
                if #available(macOS 26.0, *) {
                    CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                        .fill(.clear)
                        .glassEffect(.regular.tint(DesignSystem.canvasColor.opacity(0.18)), in: CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                        .transition(.opacity)
                } else {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                        .overlay(CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius).fill(DesignSystem.canvasColor.opacity(0.58)))
                        .transition(.opacity)
                }
            } else {
                CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                    .fill(DesignSystem.canvasColor.opacity(0.94))
                    .transition(.opacity)
            }
            
            // Machined Specular Glass Hairline (Crisp bevel, no outer drop shadow)
            CustomNotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            DesignSystem.accentColor.opacity(0.24),
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
