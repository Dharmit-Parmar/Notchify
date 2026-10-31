import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var registry = ModuleRegistry.shared
    @ObservedObject var themeEngine = DynamicThemeEngine.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notch Preferences")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("A calmer, more personal notch")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Section 1: Themes & Dynamic Wallpaper Glass
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Theme & Glass Style")
                                    .font(.system(size: 13, weight: .bold))
                                if store.currentTheme == .adaptive || store.currentTheme == .activeApp {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(themeEngine.accentColor)
                                            .frame(width: 6, height: 6)
                                        Text("Following \(themeEngine.paletteSource)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(DesignSystem.secondaryText)
                                    }
                                }
                            }
                            Spacer()
                            Text(store.currentTheme.displayName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(DesignSystem.accentColor)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(AppTheme.allCases) { theme in
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
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isSelected ? theme.structureColor.opacity(0.85) : Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(isSelected ? theme.accentColor.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.7)
                                    )
                                    .overlay(alignment: .topTrailing) {
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(theme.accentColor)
                                                .padding(7)
                                                .transition(.opacity)
                                        }
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.spring)
                            }
                        }
                    }
                    .settingsCard()
                    
                    // Section 2: Direct Messaging & Accessibility
                    VStack(alignment: .leading, spacing: 10) {
                        Text("System Permissions & Direct Messaging")
                            .font(.system(size: 13, weight: .bold))
                        
                        HStack(spacing: 12) {
                            Image(systemName: store.isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(store.isAccessibilityGranted ? .green : .orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.isAccessibilityGranted ? "1-Click Direct Sending Enabled" : "Accessibility Permission Required")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(store.isAccessibilityGranted ? "WhatsApp and Telegram messages are dispatched directly without leaving drafts." : "Required for Notch to auto-press Enter in WhatsApp/Telegram and hide them back to background.")
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
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(DesignSystem.structureColor.opacity(0.5)))
                    }
                    .settingsCard()
                    
                    // Section 3: Audio & Haptic Feedback
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Interactive Feedback")
                            .font(.system(size: 13, weight: .bold))
                        
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
                    }
                    .settingsCard()
                    
                    // Section 4: Notch Sizing & Screen Position
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Spatial Geometry & Sizing")
                            .font(.system(size: 13, weight: .bold))
                        
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

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Expand Delay: \(store.hoverDelay, specifier: "%.2f") sec")
                                    .font(.system(size: 12))
                                Spacer()
                            }
                            Slider(value: $store.hoverDelay, in: 0...0.6, step: 0.05)
                        }
                    }
                    .settingsCard()
                    
                    // Section 5: Padding & Margins
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Padding & Margins")
                            .font(.system(size: 13, weight: .bold))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Content Horizontal Padding: \(Int(store.contentHorizontalPadding)) pt")
                                    .font(.system(size: 12))
                                Spacer()
                            }
                            Slider(value: $store.contentHorizontalPadding, in: 12...32, step: 2)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Content Vertical Padding: \(Int(store.contentVerticalPadding)) pt")
                                    .font(.system(size: 12))
                                Spacer()
                            }
                            Slider(value: $store.contentVerticalPadding, in: 8...24, step: 2)
                        }
                    }
                    .settingsCard()
                    
                    // Section 6: Enabled Modules
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enabled Modules")
                            .font(.system(size: 13, weight: .bold))

                        Text("Choose which tabs appear and set their order.")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.secondaryText)

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
                    .settingsCard()
                }
                .padding(24)
            }
            
            // Bottom Action Bar: Done Button
            Divider()
            HStack {
                Spacer()
                Button("Done") {
                    FeedbackManager.playClick()
                    NSApp.keyWindow?.performClose(nil)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(DesignSystem.canvasColor.opacity(0.5))
        }
        .background(DesignSystem.canvasColor)
        .tint(DesignSystem.accentColor)
        .animation(DesignSystem.reduceMotion ? nil : .easeInOut(duration: 0.22), value: themeEngine.canvasColor)
        .frame(width: 500, height: 600)
        .onAppear {
            store.refreshAccessibility()
        }
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
