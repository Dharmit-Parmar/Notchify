import SwiftUI
import Combine
import ApplicationServices

@MainActor
public protocol NotchModule: AnyObject, ObservableObject {
    var id: String { get }
    var title: String { get }
    var iconName: String { get }
    var isEnabled: Bool { get set }
    
    func start()
    func stop()
    func makeCompactView() -> AnyView
    func makeExpandedView() -> AnyView
}

@MainActor
public class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    // Geometry & Layout: allow generous breathing room for tools and calendar
    @Published public var notchWidth: CGFloat = 620.0 {
        didSet { UserDefaults.standard.set(Double(notchWidth), forKey: "NotchApp_NotchWidth") }
    }
    @Published public var notchHeight: CGFloat = 330.0 {
        didSet { UserDefaults.standard.set(Double(notchHeight), forKey: "NotchApp_NotchHeight") }
    }
    @Published public var hoverTriggerHeight: CGFloat = 34.0 {
        didSet { UserDefaults.standard.set(Double(hoverTriggerHeight), forKey: "NotchApp_HoverTriggerHeight") }
    }
    @Published public var contentHorizontalPadding: CGFloat = 16.0 {
        didSet { UserDefaults.standard.set(Double(contentHorizontalPadding), forKey: "NotchApp_ContentHorizontalPadding") }
    }
    @Published public var contentVerticalPadding: CGFloat = 12.0 {
        didSet { UserDefaults.standard.set(Double(contentVerticalPadding), forKey: "NotchApp_ContentVerticalPadding") }
    }
    
    // Behavior & Dynamics
    @Published public var hoverDelay: Double = 0.10 {
        didSet { UserDefaults.standard.set(hoverDelay, forKey: "NotchApp_HoverDelay") }
    }
    
    // Themes & Dynamic Wallpaper Glass Customization
    @Published public var currentTheme: AppTheme = .adaptive {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "NotchApp_CurrentTheme")
        }
    }
    
    // Feedback Dynamics
    @Published public var soundFeedbackEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(soundFeedbackEnabled, forKey: "NotchApp_SoundFeedback")
        }
    }
    @Published public var hapticFeedbackEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "NotchApp_HapticFeedback")
        }
    }
    
    @Published public var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    
    @Published public var enabledModules: [String: Bool] = [
        "airdrop": true,
        "shelf": true,
        "battery": true,
        "mirror": true,
        "notifications": true,
        "telegram": true
    ] {
        didSet { UserDefaults.standard.set(enabledModules, forKey: "NotchApp_EnabledModules") }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "NotchApp_NotchWidth") != nil {
            self.notchWidth = min(800, max(480, CGFloat(defaults.double(forKey: "NotchApp_NotchWidth"))))
        }
        if defaults.object(forKey: "NotchApp_NotchHeight") != nil {
            self.notchHeight = min(420, max(310, CGFloat(defaults.double(forKey: "NotchApp_NotchHeight"))))
        }
        if defaults.object(forKey: "NotchApp_HoverTriggerHeight") != nil {
            self.hoverTriggerHeight = min(54, max(24, CGFloat(defaults.double(forKey: "NotchApp_HoverTriggerHeight"))))
        }
        if defaults.object(forKey: "NotchApp_ContentHorizontalPadding") != nil {
            self.contentHorizontalPadding = min(32, max(12, CGFloat(defaults.double(forKey: "NotchApp_ContentHorizontalPadding"))))
        }
        if defaults.object(forKey: "NotchApp_ContentVerticalPadding") != nil {
            self.contentVerticalPadding = min(24, max(8, CGFloat(defaults.double(forKey: "NotchApp_ContentVerticalPadding"))))
        }
        if let savedTheme = UserDefaults.standard.string(forKey: "NotchApp_CurrentTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        }
        if UserDefaults.standard.object(forKey: "NotchApp_SoundFeedback") != nil {
            self.soundFeedbackEnabled = UserDefaults.standard.bool(forKey: "NotchApp_SoundFeedback")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_HapticFeedback") != nil {
            self.hapticFeedbackEnabled = UserDefaults.standard.bool(forKey: "NotchApp_HapticFeedback")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_HoverDelay") != nil {
            self.hoverDelay = min(0.6, max(0, UserDefaults.standard.double(forKey: "NotchApp_HoverDelay")))
        }
        if let savedModules = UserDefaults.standard.dictionary(forKey: "NotchApp_EnabledModules") as? [String: Bool] {
            self.enabledModules.merge(savedModules, uniquingKeysWith: { _, saved in saved })
        }
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }
    
    public func refreshAccessibility() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }
    
    public func isModuleEnabled(_ id: String) -> Bool {
        return enabledModules[id] ?? true
    }
    
    public func setModuleEnabled(_ id: String, enabled: Bool) {
        enabledModules[id] = enabled
    }
}
