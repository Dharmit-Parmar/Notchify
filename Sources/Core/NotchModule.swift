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
    
    // Appearance & Glass Customization
    @Published public var glassMaterialStyle: GlassMaterialStyle = .frosted {
        didSet { UserDefaults.standard.set(glassMaterialStyle.rawValue, forKey: "NotchApp_GlassMaterialStyle") }
    }
    @Published public var cornerStyle: NotchCornerStyle = .continuous {
        didSet { UserDefaults.standard.set(cornerStyle.rawValue, forKey: "NotchApp_CornerStyle") }
    }
    @Published public var motionPhysics: MotionPhysicsStyle = .appleFluid {
        didSet { UserDefaults.standard.set(motionPhysics.rawValue, forKey: "NotchApp_MotionPhysics") }
    }
    @Published public var compactIndicatorStyle: CompactIndicatorStyle = .media {
        didSet { UserDefaults.standard.set(compactIndicatorStyle.rawValue, forKey: "NotchApp_CompactIndicatorStyle") }
    }
    @Published public var autoCollapseDelay: Double = 0.25 {
        didSet { UserDefaults.standard.set(autoCollapseDelay, forKey: "NotchApp_AutoCollapseDelay") }
    }
    @Published public var showBreadcrumbs: Bool = true {
        didSet { UserDefaults.standard.set(showBreadcrumbs, forKey: "NotchApp_ShowBreadcrumbs") }
    }
    @Published public var specularGlowEnabled: Bool = true {
        didSet { UserDefaults.standard.set(specularGlowEnabled, forKey: "NotchApp_SpecularGlowEnabled") }
    }
    @Published public var keepOpenWhileSettingsActive: Bool = false {
        didSet { UserDefaults.standard.set(keepOpenWhileSettingsActive, forKey: "NotchApp_KeepOpenWhileSettings") }
    }
    @Published public var closeOnOutsideClick: Bool = true {
        didSet { UserDefaults.standard.set(closeOnOutsideClick, forKey: "NotchApp_CloseOnOutsideClick") }
    }
    @Published public var closeOnEsc: Bool = true {
        didSet { UserDefaults.standard.set(closeOnEsc, forKey: "NotchApp_CloseOnEsc") }
    }
    @Published public var dynamicVibrancy: DynamicVibrancy = .balanced {
        didSet {
            UserDefaults.standard.set(dynamicVibrancy.rawValue, forKey: "NotchApp_DynamicVibrancy")
            DispatchQueue.main.async {
                DynamicThemeEngine.shared.refreshColors()
            }
        }
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
    @Published public var isInputMonitoringGranted: Bool = false
    
    @Published public var enabledModules: [String: Bool] = [
        "airdrop": true,
        "shelf": true,
        "thock": true,
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
        if let savedStyle = UserDefaults.standard.string(forKey: "NotchApp_GlassMaterialStyle"),
           let style = GlassMaterialStyle(rawValue: savedStyle) {
            self.glassMaterialStyle = style
        }
        if let savedCorner = UserDefaults.standard.string(forKey: "NotchApp_CornerStyle"),
           let corner = NotchCornerStyle(rawValue: savedCorner) {
            self.cornerStyle = corner
        }
        if let savedMotion = UserDefaults.standard.string(forKey: "NotchApp_MotionPhysics"),
           let motion = MotionPhysicsStyle(rawValue: savedMotion) {
            self.motionPhysics = motion
        }
        if let savedCompact = UserDefaults.standard.string(forKey: "NotchApp_CompactIndicatorStyle"),
           let compact = CompactIndicatorStyle(rawValue: savedCompact) {
            self.compactIndicatorStyle = compact
        }
        if UserDefaults.standard.object(forKey: "NotchApp_AutoCollapseDelay") != nil {
            self.autoCollapseDelay = min(0.8, max(0.1, UserDefaults.standard.double(forKey: "NotchApp_AutoCollapseDelay")))
        }
        if UserDefaults.standard.object(forKey: "NotchApp_ShowBreadcrumbs") != nil {
            self.showBreadcrumbs = UserDefaults.standard.bool(forKey: "NotchApp_ShowBreadcrumbs")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_SpecularGlowEnabled") != nil {
            self.specularGlowEnabled = UserDefaults.standard.bool(forKey: "NotchApp_SpecularGlowEnabled")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_KeepOpenWhileSettings") != nil {
            self.keepOpenWhileSettingsActive = UserDefaults.standard.bool(forKey: "NotchApp_KeepOpenWhileSettings")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_CloseOnOutsideClick") != nil {
            self.closeOnOutsideClick = UserDefaults.standard.bool(forKey: "NotchApp_CloseOnOutsideClick")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_CloseOnEsc") != nil {
            self.closeOnEsc = UserDefaults.standard.bool(forKey: "NotchApp_CloseOnEsc")
        }
        if let savedVibrancy = UserDefaults.standard.string(forKey: "NotchApp_DynamicVibrancy"),
           let vib = DynamicVibrancy(rawValue: savedVibrancy) {
            self.dynamicVibrancy = vib
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
        self.isInputMonitoringGranted = ThockModule.checkIOHIDListenAccess()
    }
    
    public func refreshAccessibility() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
        self.isInputMonitoringGranted = ThockModule.checkIOHIDListenAccess()
    }
    
    public func isModuleEnabled(_ id: String) -> Bool {
        return enabledModules[id] ?? true
    }
    
    public func setModuleEnabled(_ id: String, enabled: Bool) {
        enabledModules[id] = enabled
    }
}
