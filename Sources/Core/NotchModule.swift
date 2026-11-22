import SwiftUI
import Combine
import ApplicationServices

@MainActor
public protocol NotchModule: AnyObject, ObservableObject {
    var id: String { get }
    var title: String { get }
    var iconName: String { get }
    var isEnabled: Bool { get set }
    var themeColor: Color { get }
    var preferredContentHeight: CGFloat { get }
    
    func start()
    func stop()
    func makeCompactView() -> AnyView
    func makeExpandedView() -> AnyView
}

public extension NotchModule {
    var themeColor: Color {
        switch id {
        case "airdrop": return Color(red: 0.20, green: 0.60, blue: 1.00) // AirDrop Blue
        case "localshare": return Color(red: 0.20, green: 0.78, blue: 0.85) // Local Share Cyan
        case "shelf": return Color(red: 0.98, green: 0.68, blue: 0.22) // Amber Studio
        case "thock": return Color(red: 0.25, green: 0.85, blue: 0.58) // Mechanical Emerald
        case "telegram": return Color(red: 0.22, green: 0.76, blue: 0.98) // Messages Cyan
        case "battery": return Color(red: 0.40, green: 0.88, blue: 0.45) // Battery Green
        case "mirror": return Color(red: 0.98, green: 0.42, blue: 0.65) // Camera Rose
        case "notifications": return Color(red: 0.98, green: 0.56, blue: 0.24) // Bell Orange
        default: return DesignSystem.accentColor
        }
    }
    
    var preferredContentHeight: CGFloat {
        switch id {
        case "thock": return 240.0
        case "shelf": return 290.0
        case "airdrop": return 250.0
        case "localshare": return 360.0
        case "telegram": return 340.0
        case "mirror": return 280.0
        case "battery": return 220.0
        case "notifications": return 280.0
        default: return 300.0
        }
    }
}

// MARK: - Dashboard Widget Models

public enum DashboardWidgetType: String, Codable, CaseIterable, Identifiable {
    case nowPlaying = "nowPlaying"
    case calendar = "calendar"
    case notes = "notes"
    case clock = "clock"
    case mirror = "mirror"
    case askAI = "askAI"
    case battery = "battery"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .calendar: return "Calendar"
        case .notes: return "Quick Notes"
        case .clock: return "Clock"
        case .mirror: return "Mirror"
        case .askAI: return "Ask AI"
        case .battery: return "Battery"
        }
    }
    
    public var icon: String {
        switch self {
        case .nowPlaying: return "music.note"
        case .calendar: return "calendar"
        case .notes: return "note.text"
        case .clock: return "clock.fill"
        case .mirror: return "camera.fill"
        case .askAI: return "sparkles"
        case .battery: return "battery.100.bolt"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .nowPlaying: return Color(red: 0.95, green: 0.32, blue: 0.45)
        case .calendar: return Color(red: 0.20, green: 0.60, blue: 1.00)
        case .notes: return Color(red: 0.98, green: 0.72, blue: 0.20)
        case .clock: return Color(red: 0.35, green: 0.85, blue: 0.65)
        case .mirror: return Color(red: 0.90, green: 0.40, blue: 0.85)
        case .askAI: return Color(red: 0.68, green: 0.42, blue: 0.98)
        case .battery: return Color(red: 0.35, green: 0.85, blue: 0.45)
        }
    }
    
    public var subtitle: String {
        switch self {
        case .nowPlaying: return "Live audio & video scrubber"
        case .calendar: return "Interactive month & agenda"
        case .notes: return "Instant scratchpad & memo"
        case .clock: return "Analog dial or digital display"
        case .mirror: return "Fast camera glance & preview"
        case .askAI: return "Siri, Gemini & ChatGPT Assistant"
        case .battery: return "Power state & charge status"
        }
    }
}

public enum ClockDialStyle: String, Codable, CaseIterable, Identifiable {
    case analog = "analog"
    case digital = "digital"
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .analog: return "Analog Dial"
        case .digital: return "Digital Display"
        }
    }
}



@MainActor
public class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    private var isInitializing: Bool = true
    
    // Modular Dashboard Configuration (4 Slots)
    @Published public var dashboardSlots: [DashboardWidgetType?] = [.nowPlaying, .calendar, .notes, nil] {
        didSet {
            let serialized = dashboardSlots.map { $0?.rawValue ?? "empty" }
            UserDefaults.standard.set(serialized, forKey: "NotchApp_DashboardSlots")
        }
    }
    
    // Quick Controls Configuration (Beneath Dashboard)
    @Published public var showQuickControls: Bool = true {
        didSet {
            UserDefaults.standard.set(showQuickControls, forKey: "NotchApp_ShowQuickControls")
            if !isInitializing {
                NotchShellCoordinator.shared.onQuickControlsLayoutChanged(animated: !DesignSystem.reduceMotion)
            }
        }
    }
    
    @Published public var quickControlsPinned: Bool = false {
        didSet {
            UserDefaults.standard.set(quickControlsPinned, forKey: "NotchApp_QuickControlsPinned")
            if !isInitializing {
                NotchShellCoordinator.shared.onQuickControlsLayoutChanged(animated: !DesignSystem.reduceMotion)
            }
        }
    }
    
    @Published public var enabledQuickControls: [QuickControlKind] = [.volume, .brightness, .keyboardBacklight] {
        didSet {
            let serialized = enabledQuickControls.map { $0.rawValue }
            UserDefaults.standard.set(serialized, forKey: "NotchApp_EnabledQuickControls")
            if !isInitializing {
                NotchShellCoordinator.shared.onQuickControlsLayoutChanged(animated: !DesignSystem.reduceMotion)
            }
        }
    }
    
    public func resetQuickControlsSettings() {
        self.showQuickControls = true
        self.quickControlsPinned = false
        self.enabledQuickControls = [.volume, .brightness, .keyboardBacklight]
    }
    
    // Dashboard Layout Orientation Flow
    @Published public var dashboardLayoutFlow: DashboardLayoutFlow = .adaptiveAuto {
        didSet { UserDefaults.standard.set(dashboardLayoutFlow.rawValue, forKey: "NotchApp_DashboardLayoutFlow") }
    }
    
    // Live Drag Proportional Split Ratio (0.20 ... 0.80, default 0.50)
    @Published public var dashboardSplitRatio: CGFloat = 0.50 {
        didSet { UserDefaults.standard.set(Double(dashboardSplitRatio), forKey: "NotchApp_DashboardSplitRatio") }
    }
    
    // Auto-Rotate Companion Widget for Focus Layout (default: false, max once per 30s while collapsed)
    @Published public var autoRotateCompanion: Bool = false {
        didSet { UserDefaults.standard.set(autoRotateCompanion, forKey: "NotchApp_AutoRotateCompanion") }
    }
    
    // Primary Dominant Slot Index for Focus Layout (default: 0)
    @Published public var focusDominantSlotIndex: Int = 0 {
        didSet { UserDefaults.standard.set(focusDominantSlotIndex, forKey: "NotchApp_FocusDominantSlotIndex") }
    }
    
    // Per-Widget Custom Spans (1 or 2 spaces)
    @Published public var widgetSpans: [String: Int] = [
        "nowPlaying": 2,
        "calendar": 2,
        "notes": 1,
        "clock": 1,
        "mirror": 1,
        "askAI": 1,
        "battery": 1
    ] {
        didSet { UserDefaults.standard.set(widgetSpans, forKey: "NotchApp_WidgetSpans") }
    }
    
    // Clock Widget Options
    @Published public var clockDialStyle: ClockDialStyle = .analog {
        didSet { UserDefaults.standard.set(clockDialStyle.rawValue, forKey: "NotchApp_ClockDialStyle") }
    }
    @Published public var clockIs24Hour: Bool = false {
        didSet { UserDefaults.standard.set(clockIs24Hour, forKey: "NotchApp_ClockIs24Hour") }
    }
    @Published public var clockShowSeconds: Bool = true {
        didSet { UserDefaults.standard.set(clockShowSeconds, forKey: "NotchApp_ClockShowSeconds") }
    }
    
    // Quick Notes Persistence & AI Integration
    public var quickNotesText: String {
        get { NoteStorageManager.shared.text }
        set { NoteStorageManager.shared.text = newValue }
    }
    @Published public var isNotesAIEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isNotesAIEnabled, forKey: "NotchApp_IsNotesAIEnabled") }
    }
    
    // Ask AI (Gemini, GPT, Siri) Assistant Settings
    @Published public var aiDefaultProvider: AIProvider = .gemini {
        didSet { UserDefaults.standard.set(aiDefaultProvider.rawValue, forKey: "NotchApp_AIDefaultProvider") }
    }
    // Secure Hardware-Backed Storage for AI Credentials (Keychain AES-256)
    @Published public var geminiApiKey: String = "" {
        didSet { KeychainHelper.shared.saveSecretAsync(geminiApiKey, forKey: "gemini_api_key") }
    }
    @Published public var openAIApiKey: String = "" {
        didSet { KeychainHelper.shared.saveSecretAsync(openAIApiKey, forKey: "openai_api_key") }
    }
    @Published public var connectedGoogleEmail: String = "" {
        didSet { KeychainHelper.shared.saveSecretAsync(connectedGoogleEmail, forKey: "google_account_email") }
    }
    @Published public var geminiModel: String = "gemini-1.5-flash" {
        didSet { UserDefaults.standard.set(geminiModel, forKey: "NotchApp_GeminiModel") }
    }
    @Published public var gptModel: String = "gpt-4o-mini" {
        didSet { UserDefaults.standard.set(gptModel, forKey: "NotchApp_GPTModel") }
    }
    @Published public var aiSystemPrompt: String = "You are a concise, helpful assistant integrated into macOS Notch Island scratchpad. Answer clearly and concisely." {
        didSet { UserDefaults.standard.set(aiSystemPrompt, forKey: "NotchApp_AISystemPrompt") }
    }
    
    // Geometry & Layout: allow generous breathing room for tools and calendar
    @Published public var notchWidth: CGFloat = 620.0 {
        didSet {
            UserDefaults.standard.set(Double(notchWidth), forKey: "NotchApp_NotchWidth")
            if !isInitializing {
                NotchShellCoordinator.shared.onQuickControlsLayoutChanged(animated: !DesignSystem.reduceMotion)
            }
        }
    }
    @Published public var notchHeight: CGFloat = 330.0 {
        didSet {
            let clamped = min(540.0, max(200.0, notchHeight))
            if notchHeight != clamped {
                notchHeight = clamped
                return
            }
            UserDefaults.standard.set(Double(clamped), forKey: "NotchApp_NotchHeight")
            if !isInitializing {
                NotchShellCoordinator.shared.onQuickControlsLayoutChanged(animated: !DesignSystem.reduceMotion)
            }
        }
    }
    @Published public var hoverTriggerHeight: CGFloat = NotchDimensionLimits.defaultHoverHeight {
        didSet {
            let clamped = min(NotchDimensionLimits.maxHoverHeight, max(NotchDimensionLimits.minHoverHeight, hoverTriggerHeight))
            if hoverTriggerHeight != clamped {
                hoverTriggerHeight = clamped
                return
            }
            UserDefaults.standard.set(Double(clamped), forKey: "NotchApp_HoverTriggerHeight")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    @Published public var hoverTriggerWidth: CGFloat = NotchDimensionLimits.defaultHoverWidth {
        didSet {
            let clamped = min(NotchDimensionLimits.maxHoverWidth, max(NotchDimensionLimits.minHoverWidth, hoverTriggerWidth))
            if hoverTriggerWidth != clamped {
                hoverTriggerWidth = clamped
                return
            }
            UserDefaults.standard.set(Double(clamped), forKey: "NotchApp_HoverTriggerWidth")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    
    // Collapsed Notch Width Model & Position Architecture (Phase 1 & 2)
    @Published public var collapsedNotchMode: CollapsedNotchMode = .hideBehindNotch {
        didSet {
            UserDefaults.standard.set(collapsedNotchMode.rawValue, forKey: "NotchApp_CollapsedNotchMode")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    @Published public var positionAttachment: NotchPositionAttachment = .hardwareNotch {
        didSet {
            UserDefaults.standard.set(positionAttachment.rawValue, forKey: "NotchApp_PositionAttachment")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    @Published public var wingWidth: CGFloat = 56.0 {
        didSet {
            UserDefaults.standard.set(Double(wingWidth), forKey: "NotchApp_WingWidth")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    @Published public var collapsedNotchHeight: CGFloat = 34.0 {
        didSet {
            UserDefaults.standard.set(Double(collapsedNotchHeight), forKey: "NotchApp_CollapsedNotchHeight")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    @Published public var horizontalNotchOffset: CGFloat = 0.0 {
        didSet {
            UserDefaults.standard.set(Double(horizontalNotchOffset), forKey: "NotchApp_HorizontalNotchOffset")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    @Published public var verticalNotchOffset: CGFloat = 0.0 {
        didSet {
            UserDefaults.standard.set(Double(verticalNotchOffset), forKey: "NotchApp_VerticalNotchOffset")
            if !isInitializing {
                NotchShellCoordinator.shared.refreshLayouts()
            }
        }
    }
    @Published public var displayPositionProfiles: [String: DisplayPositionProfile] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(displayPositionProfiles) {
                UserDefaults.standard.set(data, forKey: "NotchApp_DisplayPositionProfiles")
            }
        }
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
    // Notch Surface Custom Opacity Override
    @Published public var useCustomNotchOpacity: Bool = false {
        didSet {
            UserDefaults.standard.set(useCustomNotchOpacity, forKey: "NotchApp_UseCustomNotchOpacity")
            if !isInitializing {
                NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
            }
        }
    }
    @Published public var customNotchOpacity: Double = 1.0 {
        didSet {
            let clamped = min(1.0, max(0.5, customNotchOpacity))
            if customNotchOpacity != clamped {
                customNotchOpacity = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: "NotchApp_CustomNotchOpacity")
        }
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
            if !isInitializing {
                DispatchQueue.main.async {
                    DynamicThemeEngine.shared.refreshColors()
                }
            }
        }
    }
    
    // Themes & Dynamic Wallpaper Glass Customization
    @Published public var currentTheme: AppTheme = .adaptive {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "NotchApp_CurrentTheme")
        }
    }
    
    // Global vs Per-Module Accent Colors (default: false)
    @Published public var usePerModuleAccent: Bool = false {
        didSet {
            UserDefaults.standard.set(usePerModuleAccent, forKey: "NotchApp_UsePerModuleAccent")
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
    
    // Notch Companion Desktop Pet Options
    @Published public var isCompanionEnabled: Bool = false {
        didSet { UserDefaults.standard.set(isCompanionEnabled, forKey: "NotchApp_IsCompanionEnabled") }
    }
    @Published public var companionSkin: CompanionSkin = .bubu {
        didSet { UserDefaults.standard.set(companionSkin.rawValue, forKey: "NotchApp_CompanionSkin") }
    }
    @Published public var companionActivityLevel: CompanionActivityLevel = .balanced {
        didSet { UserDefaults.standard.set(companionActivityLevel.rawValue, forKey: "NotchApp_CompanionActivityLevel") }
    }
    @Published public var companionMimicTyping: Bool = true {
        didSet { UserDefaults.standard.set(companionMimicTyping, forKey: "NotchApp_CompanionMimicTyping") }
    }
    @Published public var companionGrooveMusic: Bool = true {
        didSet { UserDefaults.standard.set(companionGrooveMusic, forKey: "NotchApp_CompanionGrooveMusic") }
    }
    @Published public var companionAllowSlips: Bool = true {
        didSet { UserDefaults.standard.set(companionAllowSlips, forKey: "NotchApp_CompanionAllowSlips") }
    }
    @Published public var companionSleepDuringDND: Bool = true {
        didSet { UserDefaults.standard.set(companionSleepDuringDND, forKey: "NotchApp_CompanionSleepDuringDND") }
    }
    @Published public var companionDebugSkeleton: Bool = false {
        didSet { UserDefaults.standard.set(companionDebugSkeleton, forKey: "NotchApp_CompanionDebugSkeleton") }
    }
    
    @Published public var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published public var isInputMonitoringGranted: Bool = false
    
    @Published public var enabledModules: [String: Bool] = [
        "airdrop": true,
        "localshare": true,
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
            let rawHeight = CGFloat(defaults.double(forKey: "NotchApp_NotchHeight"))
            let clampedHeight = min(540, max(200, rawHeight))
            self.notchHeight = clampedHeight
            if rawHeight != clampedHeight {
                // Migration: Persist clamped value if saved height was out of bounds (< 200 or > 540)
                defaults.set(Double(clampedHeight), forKey: "NotchApp_NotchHeight")
            }
        }
        if defaults.object(forKey: "NotchApp_HoverTriggerHeight") != nil {
            let raw = CGFloat(defaults.double(forKey: "NotchApp_HoverTriggerHeight"))
            self.hoverTriggerHeight = min(NotchDimensionLimits.maxHoverHeight, max(NotchDimensionLimits.minHoverHeight, raw))
        }
        if defaults.object(forKey: "NotchApp_HoverTriggerWidth") != nil {
            let raw = CGFloat(defaults.double(forKey: "NotchApp_HoverTriggerWidth"))
            self.hoverTriggerWidth = min(NotchDimensionLimits.maxHoverWidth, max(NotchDimensionLimits.minHoverWidth, raw))
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
        if defaults.object(forKey: "NotchApp_UsePerModuleAccent") != nil {
            self.usePerModuleAccent = defaults.bool(forKey: "NotchApp_UsePerModuleAccent")
        }
        if let savedStyle = UserDefaults.standard.string(forKey: "NotchApp_GlassMaterialStyle"),
           let style = GlassMaterialStyle(rawValue: savedStyle) {
            self.glassMaterialStyle = style
        }
        if let savedCorner = UserDefaults.standard.string(forKey: "NotchApp_CornerStyle"),
           let corner = NotchCornerStyle(rawValue: savedCorner) {
            self.cornerStyle = corner
        }
        if defaults.object(forKey: "NotchApp_UseCustomNotchOpacity") != nil {
            self.useCustomNotchOpacity = defaults.bool(forKey: "NotchApp_UseCustomNotchOpacity")
        }
        if defaults.object(forKey: "NotchApp_CustomNotchOpacity") != nil {
            let rawOpacity = defaults.double(forKey: "NotchApp_CustomNotchOpacity")
            self.customNotchOpacity = min(1.0, max(0.5, rawOpacity))
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
        if let rawSlots = UserDefaults.standard.stringArray(forKey: "NotchApp_DashboardSlots"), rawSlots.count == 4 {
            self.dashboardSlots = rawSlots.map { raw in
                if raw == "empty" { return nil }
                return DashboardWidgetType(rawValue: raw)
            }
        }
        if UserDefaults.standard.object(forKey: "NotchApp_ShowQuickControls") != nil {
            self.showQuickControls = UserDefaults.standard.bool(forKey: "NotchApp_ShowQuickControls")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_QuickControlsPinned") != nil {
            self.quickControlsPinned = UserDefaults.standard.bool(forKey: "NotchApp_QuickControlsPinned")
        }
        if let rawControls = UserDefaults.standard.stringArray(forKey: "NotchApp_EnabledQuickControls") {
            let parsed = rawControls.compactMap { QuickControlKind(rawValue: $0) }
            if !parsed.isEmpty {
                self.enabledQuickControls = parsed
            }
        }
        if let savedClockStyle = UserDefaults.standard.string(forKey: "NotchApp_ClockDialStyle"),
           let style = ClockDialStyle(rawValue: savedClockStyle) {
            self.clockDialStyle = style
        }
        if UserDefaults.standard.object(forKey: "NotchApp_ClockIs24Hour") != nil {
            self.clockIs24Hour = UserDefaults.standard.bool(forKey: "NotchApp_ClockIs24Hour")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_ClockShowSeconds") != nil {
            self.clockShowSeconds = UserDefaults.standard.bool(forKey: "NotchApp_ClockShowSeconds")
        }
        if let savedFlow = UserDefaults.standard.string(forKey: "NotchApp_DashboardLayoutFlow"),
           let flow = DashboardLayoutFlow(rawValue: savedFlow) {
            self.dashboardLayoutFlow = flow
        }
        if UserDefaults.standard.object(forKey: "NotchApp_DashboardSplitRatio") != nil {
            let ratio = CGFloat(UserDefaults.standard.double(forKey: "NotchApp_DashboardSplitRatio"))
            self.dashboardSplitRatio = min(0.80, max(0.20, ratio))
        }
        if UserDefaults.standard.object(forKey: "NotchApp_AutoRotateCompanion") != nil {
            self.autoRotateCompanion = UserDefaults.standard.bool(forKey: "NotchApp_AutoRotateCompanion")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_FocusDominantSlotIndex") != nil {
            self.focusDominantSlotIndex = UserDefaults.standard.integer(forKey: "NotchApp_FocusDominantSlotIndex")
        }
        if let savedSpans = UserDefaults.standard.dictionary(forKey: "NotchApp_WidgetSpans") as? [String: Int] {
            self.widgetSpans.merge(savedSpans, uniquingKeysWith: { _, saved in saved })
        }
        if let notes = UserDefaults.standard.string(forKey: "NotchApp_QuickNotesText") {
            self.quickNotesText = notes
        }
        if UserDefaults.standard.object(forKey: "NotchApp_IsNotesAIEnabled") != nil {
            self.isNotesAIEnabled = UserDefaults.standard.bool(forKey: "NotchApp_IsNotesAIEnabled")
        }
        if let aiRaw = UserDefaults.standard.string(forKey: "NotchApp_AIDefaultProvider"),
           let provider = AIProvider(rawValue: aiRaw) {
            self.aiDefaultProvider = provider
        }
        
        // Secure Keychain Secret Retrieval & Automatic Validated Legacy Plist Migration
        let keychainGemini = KeychainHelper.shared.loadSecret(forKey: "gemini_api_key")
        let legacyGemini = UserDefaults.standard.string(forKey: "NotchApp_GeminiApiKey")
        if let key = keychainGemini, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.geminiApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.removeObject(forKey: "NotchApp_GeminiApiKey")
        } else if let legacy = legacyGemini, !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let clean = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
            self.geminiApiKey = clean
            let saved = KeychainHelper.shared.saveSecret(clean, forKey: "gemini_api_key")
            if saved, let verified = KeychainHelper.shared.loadSecret(forKey: "gemini_api_key"), verified == clean {
                UserDefaults.standard.removeObject(forKey: "NotchApp_GeminiApiKey")
            }
        }
        
        let keychainGPT = KeychainHelper.shared.loadSecret(forKey: "openai_api_key")
        let legacyGPT = UserDefaults.standard.string(forKey: "NotchApp_OpenAIApiKey")
        if let key = keychainGPT, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.openAIApiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.removeObject(forKey: "NotchApp_OpenAIApiKey")
        } else if let legacy = legacyGPT, !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let clean = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
            self.openAIApiKey = clean
            let saved = KeychainHelper.shared.saveSecret(clean, forKey: "openai_api_key")
            if saved, let verified = KeychainHelper.shared.loadSecret(forKey: "openai_api_key"), verified == clean {
                UserDefaults.standard.removeObject(forKey: "NotchApp_OpenAIApiKey")
            }
        }
        
        if let email = KeychainHelper.shared.loadSecret(forKey: "google_account_email") {
            self.connectedGoogleEmail = email
        }
        if let geminiMod = UserDefaults.standard.string(forKey: "NotchApp_GeminiModel") {
            self.geminiModel = geminiMod
        }
        if let gptMod = UserDefaults.standard.string(forKey: "NotchApp_GPTModel") {
            self.gptModel = gptMod
        }
        if let prompt = UserDefaults.standard.string(forKey: "NotchApp_AISystemPrompt") {
            self.aiSystemPrompt = prompt
        }
        if let rawComp = UserDefaults.standard.object(forKey: "NotchApp_IsCompanionEnabled") as? Bool {
            self.isCompanionEnabled = rawComp
        }
        if let rawSkin = UserDefaults.standard.string(forKey: "NotchApp_CompanionSkin"),
           let skin = CompanionSkin(rawValue: rawSkin) {
            self.companionSkin = skin
        }
        if let rawAct = UserDefaults.standard.string(forKey: "NotchApp_CompanionActivityLevel"),
           let act = CompanionActivityLevel(rawValue: rawAct) {
            self.companionActivityLevel = act
        }
        if let rawMimic = UserDefaults.standard.object(forKey: "NotchApp_CompanionMimicTyping") as? Bool {
            self.companionMimicTyping = rawMimic
        }
        if let rawGroove = UserDefaults.standard.object(forKey: "NotchApp_CompanionGrooveMusic") as? Bool {
            self.companionGrooveMusic = rawGroove
        }
        if let rawSlips = UserDefaults.standard.object(forKey: "NotchApp_CompanionAllowSlips") as? Bool {
            self.companionAllowSlips = rawSlips
        }
        if let rawDND = UserDefaults.standard.object(forKey: "NotchApp_CompanionSleepDuringDND") as? Bool {
            self.companionSleepDuringDND = rawDND
        }
        if let rawDebug = UserDefaults.standard.object(forKey: "NotchApp_CompanionDebugSkeleton") as? Bool {
            self.companionDebugSkeleton = rawDebug
        }
        
        // Collapsed Notch Width Model & Position Architecture Loading (Phase 1 & 2)
        if let savedMode = defaults.string(forKey: "NotchApp_CollapsedNotchMode"),
           let mode = CollapsedNotchMode(rawValue: savedMode) {
            self.collapsedNotchMode = mode
        }
        if let savedAttachment = defaults.string(forKey: "NotchApp_PositionAttachment"),
           let attachment = NotchPositionAttachment(rawValue: savedAttachment) {
            self.positionAttachment = attachment
        }
        if defaults.object(forKey: "NotchApp_WingWidth") != nil {
            self.wingWidth = min(160, max(0, CGFloat(defaults.double(forKey: "NotchApp_WingWidth"))))
        }
        if defaults.object(forKey: "NotchApp_CollapsedNotchHeight") != nil {
            self.collapsedNotchHeight = min(60, max(24, CGFloat(defaults.double(forKey: "NotchApp_CollapsedNotchHeight"))))
        }
        if defaults.object(forKey: "NotchApp_HorizontalNotchOffset") != nil {
            self.horizontalNotchOffset = CGFloat(defaults.double(forKey: "NotchApp_HorizontalNotchOffset"))
        }
        if defaults.object(forKey: "NotchApp_VerticalNotchOffset") != nil {
            self.verticalNotchOffset = CGFloat(defaults.double(forKey: "NotchApp_VerticalNotchOffset"))
        }
        if let data = defaults.data(forKey: "NotchApp_DisplayPositionProfiles"),
           let profiles = try? JSONDecoder().decode([String: DisplayPositionProfile].self, from: data) {
            self.displayPositionProfiles = profiles
        }
        
        self.isAccessibilityGranted = AXIsProcessTrusted()
        self.isInputMonitoringGranted = ThockModule.checkIOHIDListenAccess()
        self.isInitializing = false
    }
    
    // MARK: - Per-Display Position & Size Profile Helpers
    
    public func screenKey(for screen: NSScreen) -> String {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "Screen_\(num.intValue)"
        }
        return screen.localizedName
    }
    
    public func positionProfile(for screen: NSScreen) -> DisplayPositionProfile {
        let key = screenKey(for: screen)
        if let profile = displayPositionProfiles[key] {
            return profile
        }
        let geom = NotchGeometry.current(for: screen)
        let defaultProfile = DisplayPositionProfile(
            version: 1,
            wingMode: collapsedNotchMode,
            attachment: positionAttachment,
            wingWidth: wingWidth,
            collapsedHeight: geom.hasPhysicalNotch ? geom.physicalNotchHeight : 32.0,
            horizontalOffset: horizontalNotchOffset,
            verticalOffset: verticalNotchOffset
        )
        return defaultProfile
    }
    
    public func updatePositionProfile(_ profile: DisplayPositionProfile, for screen: NSScreen) {
        let key = screenKey(for: screen)
        displayPositionProfiles[key] = profile
        // Sync active state variables for currently active display
        self.collapsedNotchMode = profile.wingMode
        self.positionAttachment = profile.attachment
        self.wingWidth = profile.wingWidth
        self.collapsedNotchHeight = profile.collapsedHeight
        self.horizontalNotchOffset = profile.horizontalOffset
        self.verticalNotchOffset = profile.verticalOffset
    }
    
    public func resetPositionProfile(for screen: NSScreen) {
        let geom = NotchGeometry.current(for: screen)
        let defaultProfile = DisplayPositionProfile(
            version: 1,
            wingMode: .hideBehindNotch,
            attachment: .hardwareNotch,
            wingWidth: 56.0,
            collapsedHeight: geom.hasPhysicalNotch ? geom.physicalNotchHeight : 32.0,
            horizontalOffset: 0.0,
            verticalOffset: 0.0
        )
        updatePositionProfile(defaultProfile, for: screen)
    }
    
    // MARK: - Dashboard Slot Helpers
    
    public func span(for widget: DashboardWidgetType) -> Int {
        return widgetSpans[widget.rawValue] ?? 1
    }
    
    public func setSpan(_ span: Int, for widget: DashboardWidgetType) {
        widgetSpans[widget.rawValue] = max(1, min(2, span))
    }
    
    /// Returns the unique active widgets currently placed in any slot
    public var activeDashboardWidgets: [DashboardWidgetType] {
        var result: [DashboardWidgetType] = []
        for slot in dashboardSlots {
            if let widget = slot, !result.contains(widget) {
                result.append(widget)
            }
        }
        return result
    }
    
    public func setDashboardSlot(at index: Int, widget: DashboardWidgetType?) {
        guard index >= 0 && index < 4 else { return }
        // If widget is already in another slot, clear that slot to avoid duplicates
        if let widget = widget {
            for i in 0..<dashboardSlots.count where i != index && dashboardSlots[i] == widget {
                dashboardSlots[i] = nil
            }
        }
        dashboardSlots[index] = widget
    }
    
    public func removeDashboardWidget(_ widget: DashboardWidgetType) {
        for i in 0..<dashboardSlots.count where dashboardSlots[i] == widget {
            dashboardSlots[i] = nil
        }
    }
    
    public func applyPresetDashboard(slots: [DashboardWidgetType?]) {
        var newSlots: [DashboardWidgetType?] = [nil, nil, nil, nil]
        for (i, item) in slots.prefix(4).enumerated() {
            newSlots[i] = item
        }
        self.dashboardSlots = newSlots
    }
    
    public func refreshAccessibility() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
        self.isInputMonitoringGranted = ThockModule.checkIOHIDListenAccess()
        print("[SettingsStore] init end"); fflush(stdout)
    }
    
    public func isModuleEnabled(_ id: String) -> Bool {
        return enabledModules[id] ?? true
    }
    
    public func setModuleEnabled(_ id: String, enabled: Bool) {
        enabledModules[id] = enabled
    }
}
