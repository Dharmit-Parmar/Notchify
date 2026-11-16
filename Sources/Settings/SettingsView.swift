import SwiftUI
import AppKit

@MainActor
public enum SettingsInk {
    /// True when the current theme canvas is light (Sakura, Birch)
    public static var isLight: Bool {
        DesignSystem.isLightTheme
    }
    public static var primary: Color {
        isLight ? Color(red: 0.16, green: 0.09, blue: 0.12) : .white   // deep plum on light
    }
    public static var secondary: Color { primary.opacity(0.62) }
    public static var tertiary: Color  { primary.opacity(0.42) }
    /// Replacement for SettingsInk.tint(x): fills, borders, dividers
    public static func tint(_ o: Double) -> Color {
        (isLight ? Color.black : Color.white).opacity(isLight ? o * 0.7 : o)
    }
}

struct SettingsWindowAppearance: NSViewRepresentable {
    let isLight: Bool
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ v: NSView, context: Context) {
        DispatchQueue.main.async {
            v.window?.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
        }
    }
}

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case appearance = "Appearance"
    case geometry = "Geometry"
    case motion = "Motion"
    case modules = "Tab Modules"
    case feedback = "Feedback"
    case companion = "Companion"
    case permissions = "Permissions"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .appearance: return "paintpalette.fill"
        case .geometry: return "macbook.and.iphone"
        case .motion: return "waveform.path"
        case .modules: return "slider.horizontal.2.square.on.square"
        case .feedback: return "speaker.wave.2.fill"
        case .companion: return "pawprint.fill"
        case .permissions: return "hand.raised.fill"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .dashboard: return Color(red: 0.20, green: 0.60, blue: 1.00) // Electric Blue
        case .appearance: return Color(red: 0.22, green: 0.52, blue: 0.94) // Deep Azure
        case .geometry: return Color(red: 0.22, green: 0.74, blue: 0.98) // Electric Cyan
        case .motion: return Color(red: 0.98, green: 0.62, blue: 0.22) // Solar Amber
        case .modules: return Color(red: 0.32, green: 0.55, blue: 0.90) // Cobalt Blue
        case .feedback: return Color(red: 0.22, green: 0.84, blue: 0.65) // Emerald Teal
        case .companion: return Color(red: 1.00, green: 0.58, blue: 0.20) // Warm Amber
        case .permissions: return Color(red: 0.98, green: 0.42, blue: 0.42) // Sunset Coral
        }
    }
}

@MainActor
public final class SettingsNavigationState: ObservableObject {
    public static let shared = SettingsNavigationState()
    @Published public var selectedCategory: SettingsCategory = .dashboard
    @Published public var hasCopiedPath: Bool = false
    @Published public var showColorDiagnostics: Bool = false
    @Published public var expandedAdvancedSections: Set<String> = []
    
    public func isAdvancedExpanded(_ id: String) -> Bool {
        expandedAdvancedSections.contains(id)
    }
    
    public func toggleAdvanced(_ id: String) {
        if expandedAdvancedSections.contains(id) {
            expandedAdvancedSections.remove(id)
        } else {
            expandedAdvancedSections.insert(id)
        }
    }
}

// MARK: - Pointer Cursor View Modifier (Balanced & Leak-Proof)
@MainActor
private final class CursorTrackingState: ObservableObject {
    var isPushed = false
}

public struct PointerCursorModifier: ViewModifier {
    @StateObject private var state = CursorTrackingState()
    
    public func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside && !state.isPushed {
                    state.isPushed = true
                    NSCursor.pointingHand.push()
                } else if !inside && state.isPushed {
                    state.isPushed = false
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if state.isPushed {
                    state.isPushed = false
                    NSCursor.pop()
                }
            }
    }
}

public extension View {
    func pointerHoverCursor() -> some View {
        modifier(PointerCursorModifier())
    }
}

// MARK: - Reusable Advanced Collapsible Settings Section
public struct AdvancedSettingsSection<Content: View>: View {
    public let sectionID: String
    public let title: String
    public let description: String
    public let onReset: () -> Void
    @ViewBuilder public let content: () -> Content
    @ObservedObject private var nav = SettingsNavigationState.shared
    
    public init(
        sectionID: String,
        title: String,
        description: String,
        onReset: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionID = sectionID
        self.title = title
        self.description = description
        self.onReset = onReset
        self.content = content
    }
    
    public var body: some View {
        let isExpanded = nav.isAdvancedExpanded(sectionID)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    FeedbackManager.playClick()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        nav.toggleAdvanced(sectionID)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(SettingsInk.secondary)
                            .frame(width: 12)
                        
                        Text(title)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(SettingsInk.primary)
                        
                        Text("Advanced")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.orange.opacity(0.9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.orange.opacity(0.14)))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                
                Spacer()
                
                if isExpanded {
                    Button {
                        FeedbackManager.playClick()
                        onReset()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 8))
                            Text("Reset to recommended")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(SettingsInk.tint(0.06)))
                    }
                    .buttonStyle(.plain)
                    .pointerHoverCursor()
                    .help("Restore recommended defaults")
                }
            }
            
            Text(description)
                .font(.system(size: 9.5))
                .foregroundColor(SettingsInk.secondary)
                .padding(.leading, 19)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(SettingsInk.tint(0.08))
                    content()
                }
                .padding(.top, 4)
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SettingsInk.tint(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(SettingsInk.tint(0.06), lineWidth: 0.8)
        )
    }
}

public struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var registry = ModuleRegistry.shared
    @ObservedObject var themeEngine = DynamicThemeEngine.shared
    @ObservedObject var nav = SettingsNavigationState.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar Navigation
            sidebarNavigation
                .frame(width: 210)
                .background(DesignSystem.canvasColor.opacity(0.65))
            
            Divider().background(SettingsInk.tint(0.12))
            
            // Right Fluid Detail Stage
            VStack(spacing: 0) {
                // Detail Header Bar
                detailHeaderBar
                
                Divider().background(SettingsInk.tint(0.12))
                
                // Detail Scroll Area
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch nav.selectedCategory {
                        case .dashboard:
                            DashboardSettingsView()
                        case .appearance:
                            appearanceSection
                        case .geometry:
                            geometrySection
                        case .motion:
                            motionSection
                        case .modules:
                            modulesSection
                        case .feedback:
                            feedbackSection
                        case .companion:
                            companionSection
                        case .permissions:
                            permissionsSection
                        }
                    }
                    .padding(24)
                }
                .animation(DesignSystem.reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.9), value: nav.selectedCategory)
                
                Divider().background(SettingsInk.tint(0.12))
                
                // Footer Bar
                footerBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.canvasColor)
        }
        .background(DesignSystem.canvasColor)
        .tint(DesignSystem.accentColor)
        .background(SettingsWindowAppearance(isLight: store.currentTheme.isLight))
        .animation(DesignSystem.reduceMotion ? nil : .easeInOut(duration: 0.22), value: themeEngine.canvasColor)
        .frame(minWidth: 780, minHeight: 560)
        .onAppear {
            store.refreshAccessibility()
        }
    }
    
    // MARK: - Left Sidebar Navigation
    private var sidebarNavigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.accentColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Notch Island")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(SettingsInk.primary)
                    Text("Liquid Retina Workspace")
                        .font(.system(size: 9.5))
                        .foregroundColor(SettingsInk.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)
            
            Divider().background(SettingsInk.tint(0.08))
            
            // Categories List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(SettingsCategory.allCases) { category in
                        let isSelected = nav.selectedCategory == category
                        Button {
                            FeedbackManager.playClick()
                            withAnimation(DesignSystem.reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88)) {
                                nav.selectedCategory = category
                            }
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(category.tintColor.opacity(isSelected ? 0.9 : 0.18))
                                        .frame(width: 24, height: 24)
                                    Image(systemName: category.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(isSelected ? SettingsInk.primary : category.tintColor)
                                }
                                
                                Text(category.rawValue)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? SettingsInk.primary : SettingsInk.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? SettingsInk.tint(0.12) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerHoverCursor()
                        .accessibilityLabel(category.rawValue)
                        .accessibilityHint("Switches settings category to \(category.rawValue)")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            Divider().background(SettingsInk.tint(0.08))
            
            // Current Theme Footer Chip
            HStack(spacing: 8) {
                Circle()
                    .fill(themeEngine.accentColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ACTIVE THEME")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(SettingsInk.secondary)
                    Text(store.currentTheme.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SettingsInk.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Detail Header Bar
    private var detailHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(nav.selectedCategory.rawValue)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(SettingsInk.primary)
                Text(categorySubtitle(nav.selectedCategory))
                    .font(.system(size: 11))
                    .foregroundColor(SettingsInk.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(themeEngine.accentColor)
                    .frame(width: 7, height: 7)
                Text(store.currentTheme.displayName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(DesignSystem.isLightTheme ? SettingsInk.primary : themeEngine.accentColor)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(DesignSystem.structureColor.opacity(0.6)))
            .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(DesignSystem.canvasColor.opacity(0.5))
    }
    
    private func categorySubtitle(_ category: SettingsCategory) -> String {
        switch category {
        case .dashboard: return "Configure 4-slot modular widgets, layout presets, and auto-stretching"
        case .appearance: return "Glass styles, dynamic vibrancy, corner squircle radii, and theme palettes"
        case .geometry: return "MacBook camera notch padding, dimensions, and hover trigger width"
        case .motion: return "Apple fluid spring physics, collapse delays, and escape behavior"
        case .modules: return "Secondary tab order, compact indicator chips, and messaging bot"
        case .feedback: return "Haptic ticks, sound effects, and keyboard audio mechanics"
        case .companion: return "Ambient notch desktop creature (Bubu mascot), collectible skins & playful animations"
        case .permissions: return "macOS Accessibility and Input Monitoring security trust"
        }
    }
    
    // MARK: - Section 1: Appearance & Glass Style
    private func diagnosticsDataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundColor(SettingsInk.tint(0.6))
                .frame(width: 125, alignment: .leading)
            Text(value)
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundColor(SettingsInk.primary)
                .lineLimit(2)
            Spacer()
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Theme Palette (22 Themes)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                    if store.currentTheme.isDynamic {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(themeEngine.accentColor)
                                .frame(width: 6, height: 6)
                            Text("Dynamic: following \(themeEngine.paletteSource)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(SettingsInk.secondary)
                        }
                    }
                }
                Spacer()
                Text(store.currentTheme.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(SettingsInk.secondary)
            }
            
            // Sub-Section 1: Dynamic Living Themes
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SettingsCategory.appearance.tintColor)
                    Text("Dynamic Living Themes")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                    Spacer()
                    Text("Auto-adapting")
                        .font(.system(size: 9.5))
                        .foregroundColor(SettingsInk.secondary)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(AppTheme.allCases.filter { $0.isDynamic }) { theme in
                        let isSelected = store.currentTheme == theme
                        Button(action: {
                            FeedbackManager.playClick()
                            withAnimation(DesignSystem.reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                                store.currentTheme = theme
                                DynamicThemeEngine.shared.refreshColors()
                            }
                            NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                        }) {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(themeEngine.canvasColor)
                                        .frame(width: 32, height: 24)
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(themeEngine.structureColor)
                                        .frame(width: 18, height: 14)
                                    Circle()
                                        .fill(themeEngine.accentColor)
                                        .frame(width: 8, height: 8)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(theme.displayName)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(SettingsInk.primary)
                                        .lineLimit(1)
                                    Text(isSelected ? "Active" : theme.subtitle)
                                        .font(.system(size: 9))
                                        .foregroundColor(isSelected ? (DesignSystem.isLightTheme ? SettingsInk.primary : DesignSystem.accentColor) : SettingsInk.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(isSelected ? DesignSystem.structureColor.opacity(0.85) : SettingsInk.tint(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(isSelected ? DesignSystem.accentColor.opacity(0.9) : SettingsInk.tint(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DesignSystem.accentColor)
                                        .padding(6)
                                        .transition(.opacity)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .accessibilityLabel(theme.displayName)
                        .accessibilityHint("Activates dynamic living theme: \(theme.subtitle)")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Sub-Section 2: Curated Studio Presets
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SettingsCategory.appearance.tintColor)
                    Text("Studio Color Presets (18 Styles)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                    Spacer()
                    Text("Fixed 60-30-10 palettes")
                        .font(.system(size: 9.5))
                        .foregroundColor(SettingsInk.secondary)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(AppTheme.allCases.filter { !$0.isDynamic }) { theme in
                        let isSelected = store.currentTheme == theme
                        Button(action: {
                            FeedbackManager.playClick()
                            withAnimation(DesignSystem.reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                                store.currentTheme = theme
                                DynamicThemeEngine.shared.refreshColors()
                            }
                            NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                        }) {
                            HStack(spacing: 8) {
                                // 60-30-10 Swatch
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(theme.canvasColor)
                                        .frame(width: 32, height: 24)
                                    
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(theme.structureColor)
                                        .frame(width: 18, height: 14)
                                    
                                    Circle()
                                        .fill(theme.accentColor)
                                        .frame(width: 8, height: 8)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(theme.displayName)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(SettingsInk.primary)
                                        .lineLimit(1)
                                    Text(isSelected ? "Active" : theme.subtitle)
                                        .font(.system(size: 9))
                                        .foregroundColor(isSelected ? (theme.isLight ? SettingsInk.primary : theme.accentColor) : SettingsInk.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(isSelected ? theme.structureColor.opacity(0.85) : SettingsInk.tint(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(isSelected ? theme.accentColor.opacity(0.9) : SettingsInk.tint(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(theme.accentColor)
                                        .padding(6)
                                        .transition(.opacity)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .accessibilityLabel(theme.displayName)
                        .accessibilityHint("Activates studio color preset: \(theme.subtitle)")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Glass Material Style
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.2.layers.3d.top.filled")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SettingsCategory.appearance.tintColor)
                    Text("Glass Material Style")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                }
                
                HStack(spacing: 8) {
                    ForEach(GlassMaterialStyle.allCases) { style in
                        let isSelected = store.glassMaterialStyle == style
                        Button {
                            FeedbackManager.playClick()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                store.glassMaterialStyle = style
                            }
                            NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(style.rawValue)
                                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? SettingsInk.primary : SettingsInk.secondary)
                                Text(style.subtitle)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(isSelected ? DesignSystem.accentColor : SettingsInk.tint(0.35))
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? DesignSystem.structureColor : SettingsInk.tint(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? DesignSystem.accentColor : SettingsInk.tint(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .accessibilityLabel(style.rawValue)
                        .accessibilityHint(style.subtitle)
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Corner Curvature
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "square.dashed")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SettingsCategory.appearance.tintColor)
                    Text("Corner Geometry")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                }
                
                Picker("", selection: Binding(
                    get: { store.cornerStyle },
                    set: { newCorner in
                        store.cornerStyle = newCorner
                        NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                    }
                )) {
                    ForEach(NotchCornerStyle.allCases) { corner in
                        Text(corner.rawValue).tag(corner)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Per-Module vs Global Accent Color Switch
            Button {
                store.usePerModuleAccent.toggle()
                NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Per-Module Accent Colors")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(SettingsInk.primary)
                            Text(store.usePerModuleAccent ? "Per-Module" : "Global Accent")
                                .font(.system(size: 8.5))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(store.usePerModuleAccent ? DesignSystem.accentColor.opacity(0.25) : SettingsInk.tint(0.08)))
                                .foregroundColor(store.usePerModuleAccent ? DesignSystem.accentColor : SettingsInk.secondary)
                        }
                        Text("Use distinct signature colors for each module (e.g. green for Battery, blue for AirDrop) instead of the unified theme accent.")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.usePerModuleAccent },
                        set: { newVal in
                            store.usePerModuleAccent = newVal
                            NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                        }
                    ))
                    .labelsHidden()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SettingsInk.tint(0.03)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerHoverCursor()
            .accessibilityLabel("Per-Module Accent Colors")
            .accessibilityHint("Toggles between individual module colors and unified theme accent.")
            
            Divider()
                .padding(.vertical, 4)
            
            // Collapsed Advanced Section: Specular & Color Telemetry
            AdvancedSettingsSection(
                sectionID: "appearance_advanced",
                title: "Specular Glow & Color Telemetry",
                description: "Dynamic saturation boost, specular hairline reflection, and real-time wallpaper detection diagnostics.",
                onReset: {
                    store.dynamicVibrancy = .balanced
                    store.specularGlowEnabled = true
                    NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Dynamic Vibrancy Control
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Dynamic Color Vibrancy")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            Text("Default: Balanced")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        
                        Picker("", selection: Binding(
                            get: { store.dynamicVibrancy },
                            set: { newVib in
                                store.dynamicVibrancy = newVib
                                NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                            }
                        )) {
                            ForEach(DynamicVibrancy.allCases) { vib in
                                Text(vib.rawValue).tag(vib)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SettingsInk.tint(0.03)))
                    
                    // Specular Glow Toggle
                    Button {
                        store.specularGlowEnabled.toggle()
                        NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Specular Bevel Glow")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(SettingsInk.primary)
                                    Text("Default: ON")
                                        .font(.system(size: 8.5))
                                        .foregroundColor(Color.green)
                                }
                                Text("Dynamic accent reflection along outer notch hairline")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(SettingsInk.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.specularGlowEnabled },
                                set: { newGlow in
                                    store.specularGlowEnabled = newGlow
                                    NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerHoverCursor()
                    .accessibilityLabel("Specular Bevel Glow")
                    .accessibilityHint("Reflects dynamic accent specular lighting along the outer notch border.")
                    
                    // Real-Time Detection Status Line & Re-Detect Button
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(themeEngine.accentColor)
                                .frame(width: 6, height: 6)
                            Text(themeEngine.diagnostics.detectionStatus)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Spacer()
                        Button(action: {
                            FeedbackManager.playClick()
                            themeEngine.redetectColors()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 8.5, weight: .semibold))
                                Text("Re-detect")
                                    .font(.system(size: 9.5, weight: .medium))
                            }
                            .foregroundColor(DesignSystem.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(SettingsInk.tint(0.06)))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .pointerHoverCursor()
                        .help("Re-sample desktop wallpaper and foreground application icon")
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                nav.showColorDiagnostics.toggle()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: nav.showColorDiagnostics ? "chevron.up.circle.fill" : "info.circle")
                                    .font(.system(size: 9))
                                Text(nav.showColorDiagnostics ? "Hide" : "Diagnostics")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(SettingsInk.tint(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(SettingsInk.tint(0.04)))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .pointerHoverCursor()
                        .help("Show/hide real-time color detection telemetry readout")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SettingsInk.tint(0.03)))
                    
                    if nav.showColorDiagnostics {
                        VStack(alignment: .leading, spacing: 5) {
                            diagnosticsDataRow(label: "Wallpaper Source", value: themeEngine.diagnostics.wallpaperPath)
                            diagnosticsDataRow(label: "Screen & Notch", value: "\(themeEngine.diagnostics.targetScreenName) (\(themeEngine.diagnostics.targetScreenResolution)) • Notch: \(themeEngine.diagnostics.hasPhysicalNotch ? "Present" : "None")")
                            diagnosticsDataRow(label: "Per-Space Status", value: themeEngine.diagnostics.activeSpaceNote)
                            diagnosticsDataRow(label: "Frontmost App", value: "\(themeEngine.diagnostics.frontmostAppName) (\(themeEngine.diagnostics.frontmostBundleID))")
                            if let iconRGB = themeEngine.diagnostics.frontmostAppIconColor {
                                diagnosticsDataRow(label: "App Icon RGB", value: String(format: "(%.2f, %.2f, %.2f)", iconRGB.0, iconRGB.1, iconRGB.2))
                            }
                            if let wallRGB = themeEngine.diagnostics.sampledWallpaperRGB {
                                diagnosticsDataRow(label: "Wallpaper RGB", value: String(format: "(%.2f, %.2f, %.2f)", wallRGB.0, wallRGB.1, wallRGB.2))
                            }
                            if let sysRGB = themeEngine.diagnostics.systemAccentRGB {
                                diagnosticsDataRow(label: "System Accent", value: String(format: "(%.2f, %.2f, %.2f)", sysRGB.0, sysRGB.1, sysRGB.2))
                            }
                            diagnosticsDataRow(label: "Active Stage", value: themeEngine.diagnostics.activeFallbackStage)
                            diagnosticsDataRow(label: "Last Sampled", value: themeEngine.diagnostics.lastUpdateTime.formatted(date: .omitted, time: .standard))
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.35)))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SettingsInk.tint(0.08), lineWidth: 0.7))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            }
        }
        .settingsCard()
    }
    
    // MARK: - Section 2: Geometry & Sizing
    private var geometrySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: SettingsCategory.geometry.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsCategory.geometry.tintColor)
                Text("Spatial Geometry & Sizing")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsInk.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expanded Notch Width: \(Int(store.notchWidth)) pt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SettingsInk.primary)
                    Spacer()
                    Text("Default: 620 pt")
                        .font(.system(size: 9.5))
                        .foregroundColor(SettingsInk.secondary)
                }
                Slider(value: $store.notchWidth, in: 480...800, step: 20) { editing in
                    if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                }
                .tint(SettingsCategory.geometry.tintColor)
                .accessibilityLabel("Expanded Notch Width")
                .accessibilityHint("Adjusts the width of the expanded notch island from 480 to 800 points.")
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expanded Notch Height: \(Int(store.notchHeight)) pt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SettingsInk.primary)
                    Spacer()
                    Text("Default: 330 pt")
                        .font(.system(size: 9.5))
                        .foregroundColor(SettingsInk.secondary)
                }
                Slider(value: $store.notchHeight, in: 200...540, step: 10) { editing in
                    if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                }
                .tint(SettingsCategory.geometry.tintColor)
                .accessibilityLabel("Expanded Notch Height")
                .accessibilityHint("Adjusts the height of the expanded notch island from 200 to 420 points.")
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Collapsed Advanced Geometry Section
            AdvancedSettingsSection(
                sectionID: "geometry_advanced",
                title: "Hitbox & Inner Padding",
                description: "Hover sensor activation hitbox and internal content edge margins.",
                onReset: {
                    store.hoverTriggerHeight = 34.0
                    store.hoverTriggerWidth = 210.0
                    store.contentHorizontalPadding = 16.0
                    store.contentVerticalPadding = 12.0
                    NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                }
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hover Trigger Height: \(Int(store.hoverTriggerHeight)) pt")
                                .font(.system(size: 11.5))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            Text("Default: 34 pt")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Slider(value: $store.hoverTriggerHeight, in: 24...54, step: 2) { editing in
                            if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                        }
                        .tint(SettingsCategory.geometry.tintColor)
                        .accessibilityLabel("Hover Trigger Height")
                        .accessibilityHint("Fine-tunes the height of the activation sensor below the camera.")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hover Trigger Width: \(Int(store.hoverTriggerWidth)) pt")
                                .font(.system(size: 11.5))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            Text("Default: 210 pt")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Slider(value: $store.hoverTriggerWidth, in: 160...380, step: 10) { editing in
                            if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                        }
                        .tint(SettingsCategory.geometry.tintColor)
                        .accessibilityLabel("Hover Trigger Width")
                        .accessibilityHint("Fine-tunes the width of the activation zone centered on the physical notch.")
                    }
                    
                    Divider().background(SettingsInk.tint(0.06))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Horizontal Content Padding: \(Int(store.contentHorizontalPadding)) pt")
                                .font(.system(size: 11.5))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            Text("Default: 16 pt")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Slider(value: $store.contentHorizontalPadding, in: 12...32, step: 2)
                        .tint(SettingsCategory.geometry.tintColor)
                        .accessibilityLabel("Horizontal Content Padding")
                        .accessibilityHint("Internal left and right margin spacing.")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Vertical Content Padding: \(Int(store.contentVerticalPadding)) pt")
                                .font(.system(size: 11.5))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            Text("Default: 12 pt")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Slider(value: $store.contentVerticalPadding, in: 8...24, step: 2)
                        .tint(SettingsCategory.geometry.tintColor)
                        .accessibilityLabel("Vertical Content Padding")
                        .accessibilityHint("Internal top and bottom margin spacing.")
                    }
                }
            }
        }
        .settingsCard()
    }
    
    // MARK: - Section 3: Motion & Delays
    private var motionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: SettingsCategory.motion.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsCategory.motion.tintColor)
                Text("Apple Motion Physics")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsInk.primary)
            }
            
            HStack(spacing: 8) {
                ForEach(MotionPhysicsStyle.allCases) { motion in
                    let isSelected = store.motionPhysics == motion
                    Button {
                        FeedbackManager.playClick()
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            store.motionPhysics = motion
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(motion.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? SettingsInk.primary : SettingsInk.secondary)
                            Text("Resp: \(String(format: "%.2f", motion.response))s • Damp: \(String(format: "%.2f", motion.damping))")
                                .font(.system(size: 9))
                                .foregroundColor(isSelected ? DesignSystem.accentColor : SettingsInk.tint(0.35))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? DesignSystem.structureColor : SettingsInk.tint(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isSelected ? DesignSystem.accentColor : SettingsInk.tint(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.spring)
                    .pointerHoverCursor()
                    .accessibilityLabel(motion.rawValue)
                    .accessibilityHint("Sets motion profile to \(motion.rawValue)")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(spacing: 6) {
                Button {
                    store.keepOpenWhileSettingsActive.toggle()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Notch Open while Settings Active")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SettingsInk.primary)
                            Text("Prevents notch from collapsing so you can preview changes live in real-time")
                                .font(.system(size: 10))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $store.keepOpenWhileSettingsActive)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                .accessibilityLabel("Keep Notch Open while Settings Active")
                .accessibilityHint("Prevents the notch island from collapsing while this settings window is visible.")
                
                Divider().background(SettingsInk.tint(0.06))
                
                Button {
                    store.closeOnOutsideClick.toggle()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Close Notch on Outside Click")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SettingsInk.primary)
                            Text("Automatically collapse the notch when clicking anywhere outside on the screen")
                                .font(.system(size: 10))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $store.closeOnOutsideClick)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                .accessibilityLabel("Close Notch on Outside Click")
                .accessibilityHint("Collapses the notch whenever you click outside its window.")
                
                Divider().background(SettingsInk.tint(0.06))
                
                Button {
                    store.closeOnEsc.toggle()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dismiss Notch on Esc Key")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SettingsInk.primary)
                            Text("Press Esc at any time to instantly collapse the notch back into the hardware bezel")
                                .font(.system(size: 10))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $store.closeOnEsc)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                .accessibilityLabel("Dismiss Notch on Esc Key")
                .accessibilityHint("Allows pressing Escape to instantly collapse the notch.")
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Collapsed Advanced Motion Delays Section
            AdvancedSettingsSection(
                sectionID: "motion_advanced",
                title: "Interactive Timing Delays",
                description: "Fine-tune hover sensor trigger delays and auto-collapse grace periods.",
                onReset: {
                    store.hoverDelay = 0.10
                    store.autoCollapseDelay = 0.25
                }
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hover Expand Delay: \(store.hoverDelay, specifier: "%.2f") sec")
                                .font(.system(size: 11.5))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            Text("Default: 0.10s")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Slider(value: $store.hoverDelay, in: 0...0.6, step: 0.05)
                        .tint(SettingsCategory.motion.tintColor)
                        .accessibilityLabel("Hover Expand Delay")
                        .accessibilityHint("Amount of time the mouse must hover over the notch before expanding.")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Auto-Collapse Exit Delay: \(store.autoCollapseDelay, specifier: "%.2f") sec")
                                .font(.system(size: 11.5))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            Text("Default: 0.25s")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Slider(value: $store.autoCollapseDelay, in: 0.10...0.80, step: 0.05)
                        .tint(SettingsCategory.motion.tintColor)
                        .accessibilityLabel("Auto-Collapse Exit Delay")
                        .accessibilityHint("Grace period before collapsing after mouse exits the notch.")
                    }
                }
            }
        }
        .settingsCard()
    }
    
    // MARK: - Section 4: Modules & Dock
    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Collapsed Notch Indicator Style
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: SettingsCategory.modules.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(SettingsCategory.modules.tintColor)
                    Text("Collapsed Notch Indicator")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(CompactIndicatorStyle.allCases) { style in
                        let isSelected = store.compactIndicatorStyle == style
                        Button {
                            FeedbackManager.playClick()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                store.compactIndicatorStyle = style
                            }
                            NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: style.icon)
                                    .font(.system(size: 10))
                                    .foregroundColor(style.tintColor)
                                Text(style.rawValue)
                                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? style.tintColor.opacity(0.18) : SettingsInk.tint(0.04))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? style.tintColor.opacity(0.85) : SettingsInk.tint(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                            )
                            .foregroundColor(isSelected ? SettingsInk.primary : SettingsInk.secondary)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .accessibilityLabel(style.rawValue)
                        .accessibilityHint("Sets collapsed notch indicator to \(style.rawValue)")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Enabled Modules List with Distinct Theme Palette Icons
            VStack(alignment: .leading, spacing: 8) {
                Text("Enabled Header Modules & Tab Order")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsInk.primary)
                
                ForEach(Array(registry.allOrderedModules.enumerated()), id: \.element.id) { index, module in
                    HStack(spacing: 8) {
                        Button {
                            let nextVal = !module.isEnabled
                            if !nextVal && registry.activeModuleId == module.id {
                                registry.returnToHome()
                            }
                            module.isEnabled = nextVal
                            store.setModuleEnabled(module.id, enabled: nextVal)
                        } label: {
                            HStack(spacing: 8) {
                                Toggle("", isOn: Binding(
                                    get: { module.isEnabled },
                                    set: { newValue in
                                        if !newValue && registry.activeModuleId == module.id {
                                            registry.returnToHome()
                                        }
                                        module.isEnabled = newValue
                                        store.setModuleEnabled(module.id, enabled: newValue)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .allowsHitTesting(false)
                                
                                Image(systemName: module.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(module.themeColor)
                                Text(module.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(SettingsInk.primary)
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerHoverCursor()
                        .accessibilityLabel("\(module.title) Module")
                        .accessibilityHint("Toggles display of \(module.title) in the top dock tab bar.")
                        
                        HStack(spacing: 0) {
                            Button {
                                registry.moveModule(from: module.id, to: registry.allOrderedModules[index - 1].id)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.spring)
                            .pointerHoverCursor()
                            .disabled(index == 0)
                            .help("Move \(module.title) up")
                            .accessibilityLabel("Move \(module.title) up")
                            
                            Button {
                                registry.moveModule(from: module.id, to: registry.allOrderedModules[index + 1].id)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.spring)
                            .pointerHoverCursor()
                            .disabled(index == registry.allOrderedModules.count - 1)
                            .help("Move \(module.title) down")
                            .accessibilityLabel("Move \(module.title) down")
                        }
                        .padding(2)
                        .background(Capsule().fill(DesignSystem.surfaceFill))
                        .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.7))
                    }
                    .padding(.vertical, 2)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Collapsed Advanced Module Controls Section
            AdvancedSettingsSection(
                sectionID: "modules_advanced",
                title: "Advanced Module Controls",
                description: "Navigation breadcrumbs ribbon and direct Telegram bot API configuration.",
                onReset: {
                    store.showBreadcrumbs = true
                }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        store.showBreadcrumbs.toggle()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Show Navigation Breadcrumbs")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(SettingsInk.primary)
                                    Text("Default: ON")
                                        .font(.system(size: 8.5))
                                        .foregroundColor(Color.green)
                                }
                                Text("Displays path ribbon (Dashboard > Module) inside secondary tools")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(SettingsInk.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $store.showBreadcrumbs)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerHoverCursor()
                    .accessibilityLabel("Show Navigation Breadcrumbs")
                    .accessibilityHint("Shows or hides the top navigation breadcrumbs trail.")
                    
                    Divider().background(SettingsInk.tint(0.06))
                    
                    // Telegram Bot Direct Dispatch Configuration
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.cyan)
                            Text("Telegram Direct Bot API (Zero Windows)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(SettingsInk.primary)
                            Spacer()
                            if let token = KeychainHelper.shared.loadSecret(forKey: "telegram_bot_token"), !token.isEmpty {
                                Text("Active ✓")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                            }
                        }
                        
                        Text("Enable 100% silent background message sending without opening or closing the Telegram app window.")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.secondary)
                        
                        if let tg = registry.module(for: "telegram") as? TelegramModule {
                            TelegramSettingsBotRow(module: tg)
                        }
                    }
                    
                    Divider().background(SettingsInk.tint(0.06))
                    
                    // Local Share Configuration Card
                    LocalShareSettingsView()
                }
            }
        }
        .settingsCard()
    }
    
    // MARK: - Section 5: Sound & Haptics
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: SettingsCategory.feedback.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsCategory.feedback.tintColor)
                Text("Interactive Audio & Haptics")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsInk.primary)
            }
            
            Button {
                store.soundFeedbackEnabled.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(SettingsCategory.feedback.tintColor)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sound Feedback")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SettingsInk.primary)
                        Text("Play soft clicks, pop on pin, and whoosh on sent messages")
                            .font(.system(size: 10))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $store.soundFeedbackEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerHoverCursor()
            .accessibilityLabel("Sound Feedback")
            .accessibilityHint("Plays acoustic feedback sounds on interactive UI events.")
            
            Divider().background(SettingsInk.tint(0.06))
            
            Button {
                store.hapticFeedbackEnabled.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(SettingsCategory.feedback.tintColor)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Haptic Feedback")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SettingsInk.primary)
                        Text("Tactile trackpad pulses on hover, snapping, and pinning")
                            .font(.system(size: 10))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $store.hapticFeedbackEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerHoverCursor()
            .accessibilityLabel("Haptic Feedback")
            .accessibilityHint("Emits tactile trackpad feedback pulses on gestures and drop operations.")
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Test Audio Feedback")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(SettingsInk.primary)
                
                HStack(spacing: 8) {
                    Button("Click") { FeedbackManager.playClick() }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .controlSize(.small)
                    Button("Pin") { FeedbackManager.playPin() }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .controlSize(.small)
                    Button("Send") { FeedbackManager.playSend() }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .controlSize(.small)
                    Button("Drop") { FeedbackManager.playDrop() }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .controlSize(.small)
                    Button("Success") { FeedbackManager.playSuccess() }
                        .buttonStyle(.spring)
                        .pointerHoverCursor()
                        .controlSize(.small)
                }
            }
        }
        .settingsCard()
    }
    
    // MARK: - Section: Notch Animated Companion
    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Master Activation Card
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    store.isCompanionEnabled.toggle()
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 1.00, green: 0.58, blue: 0.20))
                            Text("Notch Companion (Bubu Mascot)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(SettingsInk.primary)
                        }
                        
                        Text("Zero-RAM when disabled")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(Color.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(Color.green.opacity(0.28), lineWidth: 0.7))
                        
                        Spacer()
                        
                        Toggle("", isOn: $store.isCompanionEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                            .labelsHidden()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                .accessibilityLabel("Notch Companion Bubu Mascot")
                .accessibilityHint("Toggles the Bubu animated desktop companion around the notch.")
                
                Text("When turned off, 0 MB is loaded into RAM. Turn on to bring Bubu to life around your MacBook notch with cute animations.")
                    .font(.system(size: 11))
                    .foregroundColor(SettingsInk.secondary)
                
                // Live Test & Action Bar
                if store.isCompanionEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEST ANIMATIONS & ACTIONS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(SettingsInk.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button("Peek Left") { CompanionCoordinator.shared.triggerPeek(side: .left) }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Peek Right") { CompanionCoordinator.shared.triggerPeek(side: .right) }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Walk from Left") { CompanionCoordinator.shared.triggerWalking(from: .left) }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Walk from Right") { CompanionCoordinator.shared.triggerWalking(from: .right) }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Crawl (Limb)") { CompanionCoordinator.shared.triggerCrawling() }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Hang & Pull-Up") { CompanionCoordinator.shared.executeSlipSequence(force: true) }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Think & Track") { CompanionCoordinator.shared.triggerThinking() }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Type Mimic") { CompanionCoordinator.shared.triggerTypingMimic() }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                                Button("Backflip") { CompanionCoordinator.shared.onCreatureClicked() }
                                    .buttonStyle(.spring)
                                    .pointerHoverCursor()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .settingsCard()
            
            if store.isCompanionEnabled {
                // Collectible Skin Picker
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Collectible Skins (6 Characters)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(SettingsInk.primary)
                            Text("Each skin features distinctive custom vector geometry, colors, ears, and accessories")
                                .font(.system(size: 10.5))
                                .foregroundColor(SettingsInk.secondary)
                        }
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CompanionSkin.allCases) { skin in
                            Button(action: {
                                store.companionSkin = skin
                                FeedbackManager.playClick()
                            }) {
                                HStack(spacing: 12) {
                                    // Mini Character Icon / Swatch
                                    ZStack {
                                        Circle()
                                            .fill(skin.bodyColor)
                                            .frame(width: 34, height: 34)
                                            .overlay(
                                                Circle().strokeBorder(skin.accentColor.opacity(0.6), lineWidth: 1.5)
                                            )
                                        
                                        // Mini eyes preview
                                        HStack(spacing: 6) {
                                            Circle().fill(skin.eyeColor).frame(width: 4, height: 4)
                                            Circle().fill(skin.eyeColor).frame(width: 4, height: 4)
                                        }
                                        .offset(y: -1)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(skin.displayName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(SettingsInk.primary)
                                        Text(skin.subtitle)
                                            .font(.system(size: 9.5))
                                            .foregroundColor(SettingsInk.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if store.companionSkin == skin {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color(red: 1.00, green: 0.58, blue: 0.20))
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(store.companionSkin == skin ? Color(red: 1.00, green: 0.58, blue: 0.20).opacity(0.12) : DesignSystem.structureColor.opacity(0.4))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(store.companionSkin == skin ? Color(red: 1.00, green: 0.58, blue: 0.20).opacity(0.5) : DesignSystem.cardBorder, lineWidth: 1)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointerHoverCursor()
                            .accessibilityLabel(skin.displayName)
                            .accessibilityHint("Selects \(skin.displayName) character skin: \(skin.subtitle)")
                            .accessibilityAddTraits(store.companionSkin == skin ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
                .settingsCard()
                
                // Collapsed Advanced Companion Behaviors & Rigging Section
                AdvancedSettingsSection(
                    sectionID: "companion_advanced",
                    title: "Companion Behaviors & Rigging",
                    description: "Activity frequency, ambient triggers, sleep rules, and kinematics bone overlay.",
                    onReset: {
                        store.companionActivityLevel = .balanced
                        store.companionMimicTyping = true
                        store.companionGrooveMusic = true
                        store.companionAllowSlips = true
                        store.companionSleepDuringDND = true
                        store.companionDebugSkeleton = false
                    }
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Activity Level Frequency
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Activity Frequency & Pacing")
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundColor(SettingsInk.primary)
                                        Text("Default: Balanced")
                                            .font(.system(size: 8.5))
                                            .foregroundColor(Color.green)
                                    }
                                    Text("Controls how frequently the creature emerges from the physical notch bezel")
                                        .font(.system(size: 9.5))
                                        .foregroundColor(SettingsInk.secondary)
                                }
                                Spacer()
                            }
                            
                            Picker("", selection: $store.companionActivityLevel) {
                                ForEach(CompanionActivityLevel.allCases) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            HStack {
                                Text(store.companionActivityLevel.description)
                                    .font(.system(size: 9.5))
                                    .foregroundColor(SettingsInk.secondary)
                                Spacer()
                            }
                        }
                        
                        Divider().background(SettingsInk.tint(0.06))
                        
                        // Interactive Behaviors Toggles
                        VStack(spacing: 10) {
                            // Mimic typing
                            Button {
                                store.companionMimicTyping.toggle()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Mimic Typing Cadence")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(SettingsInk.primary)
                                        Text("Whips out a miniature laptop and frantically taps paws while you type")
                                            .font(.system(size: 9.5))
                                            .foregroundColor(SettingsInk.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $store.companionMimicTyping)
                                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                                        .labelsHidden()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointerHoverCursor()
                            .accessibilityLabel("Mimic Typing Cadence")
                            .accessibilityHint("Plays cute typing animation when you type in any application.")
                            
                            Divider().background(SettingsInk.tint(0.06))
                            
                            // Music Groove
                            Button {
                                store.companionGrooveMusic.toggle()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Groove to Music & Audio")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(SettingsInk.primary)
                                        Text("Puts on tiny headphones and bobs head with floating notes when audio/video plays")
                                            .font(.system(size: 9.5))
                                            .foregroundColor(SettingsInk.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $store.companionGrooveMusic)
                                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                                        .labelsHidden()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointerHoverCursor()
                            .accessibilityLabel("Groove to Music")
                            .accessibilityHint("Reacts to playing media with headphones and head-bobbing animation.")
                            
                            Divider().background(SettingsInk.tint(0.06))
                            
                            // Ledge Slip & Dangle
                            Button {
                                store.companionAllowSlips.toggle()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Allow Ledge Slips & Dangles")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(SettingsInk.primary)
                                        Text("Occasionally slips off the bottom lip of the notch, dangles with kicking feet, and climbs back up")
                                            .font(.system(size: 9.5))
                                            .foregroundColor(SettingsInk.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $store.companionAllowSlips)
                                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                                        .labelsHidden()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointerHoverCursor()
                            .accessibilityLabel("Allow Ledge Slips & Dangles")
                            .accessibilityHint("Allows the creature to slip and hang from the bottom lip of the notch.")
                            
                            Divider().background(SettingsInk.tint(0.06))
                            
                            // Sleep during DND
                            Button {
                                store.companionSleepDuringDND.toggle()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Sleep During Focus & Do Not Disturb")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(SettingsInk.primary)
                                        Text("Curled up asleep under the camera with floating Zzz particles during focus sessions")
                                            .font(.system(size: 9.5))
                                            .foregroundColor(SettingsInk.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $store.companionSleepDuringDND)
                                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                                        .labelsHidden()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointerHoverCursor()
                            .accessibilityLabel("Sleep During Focus & Do Not Disturb")
                            .accessibilityHint("Puts the creature to sleep during active Do Not Disturb or Focus sessions.")
                            
                            Divider().background(SettingsInk.tint(0.06))
                            
                            // Debug Skeleton Rig Overlay
                            Button {
                                store.companionDebugSkeleton.toggle()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("Debug Skeleton Rig Overlay")
                                                .font(.system(size: 11.5, weight: .semibold))
                                                .foregroundColor(SettingsInk.primary)
                                            Text("Dev Mode")
                                                .font(.system(size: 8.5))
                                                .foregroundColor(Color.orange)
                                        }
                                        Text("Render kinematic bone lines and joint dots in real-time to verify anchor connection")
                                            .font(.system(size: 9.5))
                                            .foregroundColor(SettingsInk.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $store.companionDebugSkeleton)
                                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.20, green: 0.85, blue: 0.40)))
                                        .labelsHidden()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointerHoverCursor()
                            .accessibilityLabel("Debug Skeleton Rig Overlay")
                            .accessibilityHint("Draws skeletal joints and inverse kinematic vectors for animation verification.")
                        }
                    }
                }
                
                // Zero Resource Footprint Guarantee Card
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zero-RAM & Battery Drain Guarantee")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(SettingsInk.primary)
                        Text("When turned off, 0 MB is loaded into RAM (windows and views are fully deallocated). When resting inside the notch den, display timers pause with 0.00% CPU.")
                            .font(.system(size: 10))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 0.8)
                )
            }
        }
    }
    
    // MARK: - Section 6: Permissions
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: SettingsCategory.permissions.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(SettingsCategory.permissions.tintColor)
                    Text("System Permissions & macOS Privacy")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                }
                Spacer()
                Button(action: {
                    PermissionsHelper.revealAppInFinder()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                        Text("Reveal in Finder")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(SettingsCategory.permissions.tintColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Capsule().fill(SettingsCategory.permissions.tintColor.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(SettingsCategory.permissions.tintColor.opacity(0.3), lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .help("Reveal Notch application in Finder to drag directly into System Settings")
            }
            
            // Live Status Cards
            VStack(spacing: 8) {
                // Accessibility Status Card
                HStack(spacing: 12) {
                    Image(systemName: store.isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(store.isAccessibilityGranted ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Accessibility Permission")
                                .font(.system(size: 12, weight: .semibold))
                            Text(store.isAccessibilityGranted ? "Active" : "Action Required")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(store.isAccessibilityGranted ? .green : .orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill((store.isAccessibilityGranted ? Color.green : Color.orange).opacity(0.15)))
                        }
                        Text(store.isAccessibilityGranted ? "1-Click Direct Sending in WhatsApp & Telegram is active." : "Required for Notch to auto-send in WhatsApp/Telegram and window automation.")
                            .font(.system(size: 10))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    
                    Spacer()
                    
                    if !store.isAccessibilityGranted {
                        Button("Grant Access") {
                            DirectMessenger.requestAccessibilityPermission()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                store.refreshAccessibility()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("Open Settings") {
                            PermissionsHelper.openAccessibilitySettings()
                        }
                        .buttonStyle(.spring)
                        .controlSize(.small)
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.structureColor.opacity(0.5)))
                
                // Input Monitoring Status Card
                HStack(spacing: 12) {
                    Image(systemName: store.isInputMonitoringGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(store.isInputMonitoringGranted ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Input Monitoring Permission")
                                .font(.system(size: 12, weight: .semibold))
                            Text(store.isInputMonitoringGranted ? "Active" : "Required for Audio")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(store.isInputMonitoringGranted ? .green : .orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill((store.isInputMonitoringGranted ? Color.green : Color.orange).opacity(0.15)))
                        }
                        Text(store.isInputMonitoringGranted ? "Thock mechanical keyboard sound engine active." : "Required for Thock to play tactile key sounds as you type anywhere.")
                            .font(.system(size: 10))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    
                    Spacer()
                    
                    if !store.isInputMonitoringGranted {
                        Button("Grant Access") {
                            ThockModule.requestIOHIDListenAccess()
                            PermissionsHelper.openInputMonitoringSettings()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                store.refreshAccessibility()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("Open Settings") {
                            PermissionsHelper.openInputMonitoringSettings()
                        }
                        .buttonStyle(.spring)
                        .controlSize(.small)
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.structureColor.opacity(0.5)))
            }
            
            // Foolproof 3-Step Visual Drag-and-Drop Guide
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundColor(DesignSystem.accentColor)
                        .font(.system(size: 13))
                    Text("How to Grant Permission (Fast & Foolproof)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                }
                
                VStack(spacing: 12) {
                    // Step 1
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.accentColor)
                                .frame(width: 24, height: 24)
                            Text("1")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Click \"Reveal Notch in Finder\"")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(SettingsInk.primary)
                            Text("Finder opens directly to Applications with the **Notch** app highlighted and selected.")
                                .font(.system(size: 10))
                                .foregroundColor(SettingsInk.secondary)
                            
                            Button(action: {
                                PermissionsHelper.revealAppInFinder()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.up.right.square.fill")
                                    Text("Reveal Notch in Finder")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(DesignSystem.accentColor))
                                .foregroundColor(.black)
                            }
                            .buttonStyle(.spring)
                            .padding(.top, 2)
                        }
                        Spacer()
                    }
                    
                    Divider().background(SettingsInk.tint(0.1))
                    
                    // Step 2
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.accentColor)
                                .frame(width: 24, height: 24)
                            Text("2")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Drag the highlighted \"Notch\" icon into System Settings")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(SettingsInk.primary)
                            Text("Drag the highlighted **Notch** icon directly from the Finder window into the list in System Settings! (You don't even need to click +).")
                                .font(.system(size: 10))
                                .foregroundColor(SettingsInk.secondary)
                            
                            // ⌘⇧G Path Helper
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Alternatively, if using the (+) button: Press **⌘⇧G**, paste the path, and hit Return:")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(SettingsInk.tint(0.75))
                                
                                HStack(spacing: 8) {
                                    Text("/Applications/Notch.app")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(DesignSystem.accentColor)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.4)))
                                    
                                    Button(action: {
                                        PermissionsHelper.copyAppPathToClipboard()
                                        withAnimation {
                                            nav.hasCopiedPath = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                            withAnimation {
                                                nav.hasCopiedPath = false
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: nav.hasCopiedPath ? "checkmark" : "doc.on.doc")
                                            Text(nav.hasCopiedPath ? "Copied!" : "Copy Path to Clipboard (⌘⇧G)")
                                        }
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundColor(nav.hasCopiedPath ? .green : .white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3.5)
                                        .background(Capsule().fill(SettingsInk.tint(0.1)))
                                    }
                                    .buttonStyle(.spring)
                                }
                            }
                            .padding(.top, 2)
                        }
                        Spacer()
                    }
                    
                    Divider().background(SettingsInk.tint(0.1))
                    
                    // Step 3
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.accentColor)
                                .frame(width: 24, height: 24)
                            Text("3")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Toggle the switch to ON")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(SettingsInk.primary)
                            Text("Ensure the toggle switch next to **Notch** is turned ON (blue). Permissions take effect immediately.")
                                .font(.system(size: 10))
                                .foregroundColor(SettingsInk.secondary)
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    PermissionsHelper.openAccessibilitySettings()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.raised.fill")
                                        Text("Open Accessibility Settings")
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(SettingsInk.tint(0.08)))
                                    .foregroundColor(SettingsInk.primary)
                                }
                                .buttonStyle(.spring)
                                
                                Button(action: {
                                    PermissionsHelper.openInputMonitoringSettings()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "slider.horizontal.3")
                                        Text("Open Input Monitoring")
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(SettingsInk.tint(0.08)))
                                    .foregroundColor(SettingsInk.primary)
                                }
                                .buttonStyle(.spring)
                            }
                            .padding(.top, 2)
                        }
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(SettingsInk.tint(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.8))
        }
        .settingsCard()
        .onAppear {
            PermissionsHelper.ensureApplicationsSymlink()
            store.refreshAccessibility()
        }
    }
    
    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            Text("Notch Island • Native Liquid Retina")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(SettingsInk.secondary.opacity(0.7))
            
            Spacer()
            
            Button("Done") {
                FeedbackManager.playClick()
                AppDelegate.closeSettingsWindow()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.isLightTheme ? DesignSystem.primaryText : DesignSystem.accentColor)
            .controlSize(.regular)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(DesignSystem.canvasColor.opacity(0.6))
        .background(
            Group {
                Button("") {
                    AppDelegate.closeSettingsWindow()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("") {
                    AppDelegate.closeSettingsWindow()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }
}

private extension View {
    func settingsCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                    .fill(DesignSystem.cardFill.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
            )
    }
}

private struct TelegramSettingsBotRow: View {
    @ObservedObject var module: TelegramModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Bot Token from @BotFather", text: $module.botToken)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .textContentType(.none)
                    .autocorrectionDisabled(true)
                
                Button(action: {
                    module.testBotConnection()
                }) {
                    HStack(spacing: 3) {
                        if module.isTestingBot {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text("Test Token")
                    }
                    .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.spring)
                .controlSize(.small)
            }
            
            if let status = module.testBotStatus {
                Text(status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(status.contains("✓") ? .green : .orange)
            }
        }
    }
}
