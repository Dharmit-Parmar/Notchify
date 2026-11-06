import SwiftUI

import SwiftUI

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
        case .appearance: return Color(red: 0.76, green: 0.44, blue: 0.98) // Royal Purple
        case .geometry: return Color(red: 0.22, green: 0.74, blue: 0.98) // Electric Cyan
        case .motion: return Color(red: 0.98, green: 0.62, blue: 0.22) // Solar Amber
        case .modules: return Color(red: 0.48, green: 0.52, blue: 0.98) // Indigo
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
            
            Divider().background(Color.white.opacity(0.12))
            
            // Right Fluid Detail Stage
            VStack(spacing: 0) {
                // Detail Header Bar
                detailHeaderBar
                
                Divider().background(Color.white.opacity(0.12))
                
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
                
                Divider().background(Color.white.opacity(0.12))
                
                // Footer Bar
                footerBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.canvasColor)
        }
        .background(DesignSystem.canvasColor)
        .tint(DesignSystem.accentColor)
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
                        .foregroundColor(.white)
                    Text("Liquid Retina Workspace")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)
            
            Divider().background(Color.white.opacity(0.08))
            
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
                                        .foregroundColor(isSelected ? .white : category.tintColor)
                                }
                                
                                Text(category.rawValue)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            Divider().background(Color.white.opacity(0.08))
            
            // Current Theme Footer Chip
            HStack(spacing: 8) {
                Circle()
                    .fill(themeEngine.accentColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ACTIVE THEME")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(DesignSystem.secondaryText)
                    Text(store.currentTheme.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
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
                    .foregroundColor(.white)
                Text(categorySubtitle(nav.selectedCategory))
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(themeEngine.accentColor)
                    .frame(width: 7, height: 7)
                Text(store.currentTheme.displayName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(themeEngine.accentColor)
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
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Theme Palette (20 Themes)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    if store.currentTheme.isDynamic {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(themeEngine.accentColor)
                                .frame(width: 6, height: 6)
                            Text("Dynamic: following \(themeEngine.paletteSource)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                    }
                }
                Spacer()
                Text(store.currentTheme.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            // Sub-Section 1: Dynamic Living Themes
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SettingsCategory.appearance.tintColor)
                    Text("Dynamic Living Themes")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Auto-adapting")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
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
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(isSelected ? "Active" : theme.subtitle)
                                        .font(.system(size: 9))
                                        .foregroundColor(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.4))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(isSelected ? DesignSystem.structureColor.opacity(0.85) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(isSelected ? DesignSystem.accentColor.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
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
                    }
                }
            }
            
            // Dynamic Vibrancy Control
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Dynamic Color Vibrancy")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Scales saturation for dynamic glass")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
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
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.03)))
            
            Divider()
                .padding(.vertical, 2)
            
            // Sub-Section 2: Curated Studio Presets
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SettingsCategory.appearance.tintColor)
                    Text("Studio Color Presets (16 Styles)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Fixed 60-30-10 palettes")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
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
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(isSelected ? "Active" : theme.subtitle)
                                        .font(.system(size: 9))
                                        .foregroundColor(isSelected ? theme.accentColor : Color.white.opacity(0.4))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(isSelected ? theme.structureColor.opacity(0.85) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(isSelected ? theme.accentColor.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
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
                        .foregroundColor(.white)
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
                                    .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                                Text(style.subtitle)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.35))
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? DesignSystem.structureColor : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                            )
                        }
                        .buttonStyle(.spring)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Corner Curvature & Specular Glow
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(SettingsCategory.appearance.tintColor)
                        Text("Corner Geometry")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
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
                
                Toggle(isOn: Binding(
                    get: { store.specularGlowEnabled },
                    set: { newGlow in
                        store.specularGlowEnabled = newGlow
                        NotchShellCoordinator.shared.triggerAppearancePropagationPreview()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Specular Bevel Glow")
                            .font(.system(size: 12, weight: .bold))
                        Text("Dynamic accent reflection on hairline")
                            .font(.system(size: 9.5))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
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
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expanded Notch Width: \(Int(store.notchWidth)) pt")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.notchWidth, in: 480...800, step: 20) { editing in
                    if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                }
                .tint(SettingsCategory.geometry.tintColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expanded Notch Height: \(Int(store.notchHeight)) pt")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.notchHeight, in: 310...420, step: 10) { editing in
                    if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                }
                .tint(SettingsCategory.geometry.tintColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hover Trigger Height: \(Int(store.hoverTriggerHeight)) pt (Near Camera)")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.hoverTriggerHeight, in: 24...54, step: 2) { editing in
                    if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                }
                .tint(SettingsCategory.geometry.tintColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hover Trigger Width: \(Int(store.hoverTriggerWidth)) pt (Activation Zone)")
                        .font(.system(size: 12))
                    Spacer()
                    Text("Physical: \(Int(NotchGeometry.current().physicalNotchWidth)) pt")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                Slider(value: $store.hoverTriggerWidth, in: 160...380, step: 10) { editing in
                    if !editing { NotchShellCoordinator.shared.triggerAppearancePropagationPreview() }
                }
                .tint(SettingsCategory.geometry.tintColor)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Text("Internal Content Padding")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Horizontal Padding: \(Int(store.contentHorizontalPadding)) pt")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.contentHorizontalPadding, in: 12...32, step: 2)
                .tint(SettingsCategory.geometry.tintColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Vertical Padding: \(Int(store.contentVerticalPadding)) pt")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.contentVerticalPadding, in: 8...24, step: 2)
                .tint(SettingsCategory.geometry.tintColor)
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
                    .foregroundColor(.white)
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
                                .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                            Text("Resp: \(String(format: "%.2f", motion.response))s • Damp: \(String(format: "%.2f", motion.damping))")
                                .font(.system(size: 9))
                                .foregroundColor(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? DesignSystem.structureColor : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                        )
                    }
                    .buttonStyle(.spring)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Text("Interactive Delays")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hover Expand Delay: \(store.hoverDelay, specifier: "%.2f") sec")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.hoverDelay, in: 0...0.6, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Auto-Collapse Exit Delay: \(store.autoCollapseDelay, specifier: "%.2f") sec")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.autoCollapseDelay, in: 0.10...0.80, step: 0.05)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Toggle(isOn: $store.keepOpenWhileSettingsActive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Notch Open while Settings Active")
                        .font(.system(size: 12, weight: .medium))
                    Text("Prevents notch from collapsing so you can preview changes live in real-time")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            Toggle(isOn: $store.closeOnOutsideClick) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Close Notch on Outside Click")
                        .font(.system(size: 12, weight: .medium))
                    Text("Automatically collapse the notch when clicking anywhere outside on the screen")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            Toggle(isOn: $store.closeOnEsc) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dismiss Notch on Esc Key")
                        .font(.system(size: 12, weight: .medium))
                    Text("Press Esc at any time to instantly collapse the notch back into the hardware bezel")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
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
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
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
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? style.tintColor.opacity(0.18) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? style.tintColor.opacity(0.85) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                            )
                            .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                        }
                        .buttonStyle(.spring)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Toggle(isOn: $store.showBreadcrumbs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Navigation Breadcrumbs")
                        .font(.system(size: 12, weight: .medium))
                    Text("Displays path ribbon (Dashboard > Module) inside secondary tools")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            Divider()
                .padding(.vertical, 4)
            
            // Enabled Modules List with Distinct Theme Palette Icons
            VStack(alignment: .leading, spacing: 8) {
                Text("Enabled Header Modules & Tab Order")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(Array(registry.orderedModules.enumerated()), id: \.element.id) { index, module in
                    HStack(spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { module.isEnabled },
                            set: { newValue in
                                if !newValue && registry.activeModuleId == module.id {
                                    registry.returnToHome()
                                }
                                module.isEnabled = newValue
                                store.setModuleEnabled(module.id, enabled: newValue)
                            }
                        )) {
                            HStack(spacing: 8) {
                                Image(systemName: module.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(module.themeColor)
                                Text(module.title)
                                    .font(.system(size: 12))
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        HStack(spacing: 0) {
                            Button {
                                registry.moveModule(from: module.id, to: registry.orderedModules[index - 1].id)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.spring)
                            .disabled(index == 0)
                            .help("Move \(module.title) up")
                            .accessibilityLabel("Move \(module.title) up")
                            
                            Button {
                                registry.moveModule(from: module.id, to: registry.orderedModules[index + 1].id)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.spring)
                            .disabled(index == registry.orderedModules.count - 1)
                            .help("Move \(module.title) down")
                            .accessibilityLabel("Move \(module.title) down")
                        }
                        .padding(2)
                        .background(Capsule().fill(DesignSystem.surfaceFill))
                        .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.7))
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Telegram Bot Direct Dispatch Configuration
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.cyan)
                    Text("Telegram Direct Bot API (Zero Windows)")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if let token = KeychainHelper.shared.loadSecret(forKey: "telegram_bot_token"), !token.isEmpty {
                        Text("Active ✓")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                }
                
                Text("Enable 100% silent background message sending without opening or closing the Telegram app window.")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.secondaryText)
                
                if let tg = registry.module(for: "telegram") as? TelegramModule {
                    TelegramSettingsBotRow(module: tg)
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
                    .foregroundColor(.white)
            }
            
            Toggle(isOn: $store.soundFeedbackEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(SettingsCategory.feedback.tintColor)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sound Feedback")
                            .font(.system(size: 12, weight: .medium))
                        Text("Play soft clicks, pop on pin, and whoosh on sent messages")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            Toggle(isOn: $store.hapticFeedbackEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(SettingsCategory.feedback.tintColor)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Haptic Feedback")
                            .font(.system(size: 12, weight: .medium))
                        Text("Tactile trackpad pulses on hover, snapping, and pinning")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Test Audio Feedback")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Button("Click") { FeedbackManager.playClick() }
                        .buttonStyle(.spring)
                        .controlSize(.small)
                    Button("Pin") { FeedbackManager.playPin() }
                        .buttonStyle(.spring)
                        .controlSize(.small)
                    Button("Send") { FeedbackManager.playSend() }
                        .buttonStyle(.spring)
                        .controlSize(.small)
                    Button("Drop") { FeedbackManager.playDrop() }
                        .buttonStyle(.spring)
                        .controlSize(.small)
                    Button("Success") { FeedbackManager.playSuccess() }
                        .buttonStyle(.spring)
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
                HStack(alignment: .center, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 1.00, green: 0.58, blue: 0.20))
                        Text("Notch Companion (Bubu Mascot)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
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
                }
                
                Text("When turned off, 0 MB is loaded into RAM. Turn on to bring Bubu to life around your MacBook notch with cute animations.")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.secondaryText)
                
                // Live Test & Action Bar
                if store.isCompanionEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEST ANIMATIONS & ACTIONS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button("Peek Left") { CompanionCoordinator.shared.triggerPeek(side: .left) }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Peek Right") { CompanionCoordinator.shared.triggerPeek(side: .right) }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Walk from Left") { CompanionCoordinator.shared.triggerWalking(from: .left) }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Walk from Right") { CompanionCoordinator.shared.triggerWalking(from: .right) }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Crawl (Limb)") { CompanionCoordinator.shared.triggerCrawling() }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Hang & Pull-Up") { CompanionCoordinator.shared.executeSlipSequence(force: true) }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Think & Track") { CompanionCoordinator.shared.triggerThinking() }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Type Mimic") { CompanionCoordinator.shared.triggerTypingMimic() }
                                    .buttonStyle(.spring)
                                    .controlSize(.small)
                                Button("Backflip") { CompanionCoordinator.shared.onCreatureClicked() }
                                    .buttonStyle(.spring)
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
                                .foregroundColor(.white)
                            Text("Each skin features distinctive custom vector geometry, colors, ears, and accessories")
                                .font(.system(size: 10.5))
                                .foregroundColor(DesignSystem.secondaryText)
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
                                            .foregroundColor(.white)
                                        Text(skin.subtitle)
                                            .font(.system(size: 9.5))
                                            .foregroundColor(DesignSystem.secondaryText)
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
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .settingsCard()
                
                // Activity Level Frequency
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Activity Frequency & Pacing")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("Controls how frequently the creature emerges from the physical notch bezel")
                                .font(.system(size: 10.5))
                                .foregroundColor(DesignSystem.secondaryText)
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
                            .font(.system(size: 10.5))
                            .foregroundColor(DesignSystem.secondaryText)
                        Spacer()
                    }
                }
                .settingsCard()
                
                // Interactive Behaviors Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Interactive Ambient Behaviors")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        // Mimic typing
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mimic Typing Cadence")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Whips out a miniature laptop and frantically taps paws while you type")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            Spacer()
                            Toggle("", isOn: $store.companionMimicTyping)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                        }
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        // Music Groove
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Groove to Music & Audio")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Puts on tiny headphones and bobs head with floating notes when audio/video plays")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            Spacer()
                            Toggle("", isOn: $store.companionGrooveMusic)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                        }
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        // Ledge Slip & Dangle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Allow Ledge Slips & Dangles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Occasionally slips off the bottom lip of the notch, dangles with kicking feet, and climbs back up")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            Spacer()
                            Toggle("", isOn: $store.companionAllowSlips)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                        }
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        // Sleep during DND
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sleep During Focus & Do Not Disturb")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Curled up asleep under the camera with floating Zzz particles during focus sessions")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            Spacer()
                            Toggle("", isOn: $store.companionSleepDuringDND)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.00, green: 0.58, blue: 0.20)))
                        }
                        
                        Divider().background(DesignSystem.cardBorder)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Debug Skeleton Rig Overlay")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Render kinematic bone lines and joint dots in real-time to verify anchor connection")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            Spacer()
                            Toggle("", isOn: $store.companionDebugSkeleton)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.20, green: 0.85, blue: 0.40)))
                        }
                    }
                }
                .settingsCard()
                
                // Zero Resource Footprint Guarantee Card
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zero-RAM & Battery Drain Guarantee")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                        Text("When turned off, 0 MB is loaded into RAM (windows and views are fully deallocated). When resting inside the notch den, display timers pause with 0.00% CPU.")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.secondaryText)
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
                        .foregroundColor(.white)
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
                            .foregroundColor(DesignSystem.secondaryText)
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
                            .foregroundColor(DesignSystem.secondaryText)
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
                        .foregroundColor(.white)
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
                                .foregroundColor(.white)
                            Text("Finder opens directly to Applications with the **Notch** app highlighted and selected.")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.secondaryText)
                            
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
                    
                    Divider().background(Color.white.opacity(0.1))
                    
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
                                .foregroundColor(.white)
                            Text("Drag the highlighted **Notch** icon directly from the Finder window into the list in System Settings! (You don't even need to click +).")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.secondaryText)
                            
                            // ⌘⇧G Path Helper
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Alternatively, if using the (+) button: Press **⌘⇧G**, paste the path, and hit Return:")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(Color.white.opacity(0.75))
                                
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
                                        .background(Capsule().fill(Color.white.opacity(0.1)))
                                    }
                                    .buttonStyle(.spring)
                                }
                            }
                            .padding(.top, 2)
                        }
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
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
                                .foregroundColor(.white)
                            Text("Ensure the toggle switch next to **Notch** is turned ON (blue). Permissions take effect immediately.")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.secondaryText)
                            
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
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                    .foregroundColor(.white)
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
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                    .foregroundColor(.white)
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
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8))
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
                .foregroundColor(DesignSystem.secondaryText.opacity(0.7))
            
            Spacer()
            
            Button("Done") {
                FeedbackManager.playClick()
                AppDelegate.closeSettingsWindow()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
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
