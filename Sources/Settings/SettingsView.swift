import SwiftUI

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case geometry = "Geometry"
    case motion = "Motion"
    case modules = "Modules"
    case feedback = "Feedback"
    case permissions = "Permissions"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .appearance: return "paintpalette.fill"
        case .geometry: return "macbook.and.iphone"
        case .motion: return "waveform.path"
        case .modules: return "square.grid.2x2.fill"
        case .feedback: return "speaker.wave.2.fill"
        case .permissions: return "hand.raised.fill"
        }
    }
}

@MainActor
public final class SettingsNavigationState: ObservableObject {
    public static let shared = SettingsNavigationState()
    @Published public var selectedCategory: SettingsCategory = .appearance
}

public struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var registry = ModuleRegistry.shared
    @ObservedObject var themeEngine = DynamicThemeEngine.shared
    @ObservedObject var nav = SettingsNavigationState.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            // Category Navigation Segmented Bar
            categoryNavigationBar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(DesignSystem.canvasColor.opacity(0.4))
            
            Divider()
            
            // Tab Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    switch nav.selectedCategory {
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
                    case .permissions:
                        permissionsSection
                    }
                }
                .padding(20)
            }
            .animation(DesignSystem.reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.9), value: nav.selectedCategory)
            
            Divider()
            
            // Footer Bar
            footerBar
        }
        .background(DesignSystem.canvasColor)
        .tint(DesignSystem.accentColor)
        .animation(DesignSystem.reduceMotion ? nil : .easeInOut(duration: 0.22), value: themeEngine.canvasColor)
        .frame(width: 540, height: 620)
        .onAppear {
            store.refreshAccessibility()
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DesignSystem.accentColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Notch Preferences")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Crafted native macOS liquid retina experience")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(store.currentTheme.accentColor)
                    .frame(width: 8, height: 8)
                Text(store.currentTheme.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignSystem.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(DesignSystem.structureColor.opacity(0.6)))
            .overlay(Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(DesignSystem.canvasColor.opacity(0.8))
    }
    
    // MARK: - Category Navigation
    private var categoryNavigationBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsCategory.allCases) { category in
                let isSelected = nav.selectedCategory == category
                Button {
                    FeedbackManager.playClick()
                    withAnimation(DesignSystem.reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88)) {
                        nav.selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSelected ? DesignSystem.structureColor : Color.clear)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? DesignSystem.accentColor.opacity(0.8) : Color.white.opacity(0.06), lineWidth: isSelected ? 1.2 : 0.6)
                    )
                    .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
            }
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
                        .foregroundColor(DesignSystem.accentColor)
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
                
                Picker("", selection: $store.dynamicVibrancy) {
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
                Text("Glass Material Style")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    ForEach(GlassMaterialStyle.allCases) { style in
                        let isSelected = store.glassMaterialStyle == style
                        Button {
                            FeedbackManager.playClick()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                store.glassMaterialStyle = style
                            }
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
                    Text("Corner Geometry")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    Picker("", selection: $store.cornerStyle) {
                        ForEach(NotchCornerStyle.allCases) { corner in
                            Text(corner.rawValue).tag(corner)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Toggle(isOn: $store.specularGlowEnabled) {
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
            Text("Spatial Geometry & Sizing")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expanded Notch Width: \(Int(store.notchWidth)) pt")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.notchWidth, in: 480...800, step: 20)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expanded Notch Height: \(Int(store.notchHeight)) pt")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.notchHeight, in: 310...420, step: 10)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hover Trigger Height: \(Int(store.hoverTriggerHeight)) pt (Near Camera)")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.hoverTriggerHeight, in: 24...54, step: 2)
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
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Vertical Padding: \(Int(store.contentVerticalPadding)) pt")
                        .font(.system(size: 12))
                    Spacer()
                }
                Slider(value: $store.contentVerticalPadding, in: 8...24, step: 2)
            }
        }
        .settingsCard()
    }
    
    // MARK: - Section 3: Motion & Delays
    private var motionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apple Motion Physics")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
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
                Text("Collapsed Notch Indicator")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    ForEach(CompactIndicatorStyle.allCases) { style in
                        let isSelected = store.compactIndicatorStyle == style
                        Button {
                            FeedbackManager.playClick()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                store.compactIndicatorStyle = style
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: style.icon)
                                    .font(.system(size: 10))
                                Text(style.rawValue)
                                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? DesignSystem.structureColor : Color.white.opacity(0.04))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
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
            
            // Enabled Modules List
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
                                    .foregroundColor(DesignSystem.accentColor)
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
        }
        .settingsCard()
    }
    
    // MARK: - Section 5: Sound & Haptics
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Interactive Audio & Haptics")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            Toggle(isOn: $store.soundFeedbackEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(DesignSystem.accentColor)
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
                        .foregroundColor(DesignSystem.accentColor)
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
    
    // MARK: - Section 6: Permissions
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Permissions & macOS Privacy")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
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
                    .foregroundColor(DesignSystem.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignSystem.accentColor.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(DesignSystem.accentColor.opacity(0.3), lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .help("Reveal NotchApp binary in Finder to drag directly into System Settings (+)")
            }
            
            // Accessibility Status Card
            HStack(spacing: 12) {
                Image(systemName: store.isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(store.isAccessibilityGranted ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isAccessibilityGranted ? "Accessibility Permission Granted" : "Accessibility Permission Required")
                        .font(.system(size: 12, weight: .semibold))
                    Text(store.isAccessibilityGranted ? "1-Click Direct Sending in WhatsApp & Telegram is active." : "Required for Notch to auto-send in WhatsApp/Telegram and hide them back to background.")
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
                    Button("Settings") {
                        PermissionsHelper.openAccessibilitySettings()
                    }
                    .buttonStyle(.spring)
                    .controlSize(.small)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(DesignSystem.structureColor.opacity(0.5)))

            // Helper Guide
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(DesignSystem.accentColor)
                        .font(.system(size: 12))
                    Text("How to add NotchApp in System Settings (+)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("• Method 1: Click (+) in System Settings, choose NotchApp directly from Applications.")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
                    Text("• Method 2: Click 'Reveal in Finder' below, then drag NotchApp directly into System Settings.")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
                    Text("• Method 3: In the (+) file dialog, press ⌘⇧G, paste copied path, and press Return.")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
                }

                HStack(spacing: 8) {
                    Button(action: {
                        PermissionsHelper.revealAppInFinder()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Reveal in Finder")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(DesignSystem.accentColor))
                        .foregroundColor(.black)
                    }
                    .buttonStyle(.spring)

                    Button(action: {
                        PermissionsHelper.copyAppPathToClipboard()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy App Path")
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
                        HStack(spacing: 3) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Input Monitoring")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.spring)

                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7))
        }
        .settingsCard()
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
