import SwiftUI
import AppKit

// MARK: - Geometry Measurement Preference Key
public struct QuickControlsFramePreferenceKey: PreferenceKey {
    public static let defaultValue: CGRect = .zero
    public static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

// MARK: - Quick Controls Main Section View
public struct QuickControlsSectionView: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var manager = QuickControlsManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            // 1. Specular Top Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 4)
            
            // 2. Interactive Disclosure Bar
            QuickControlsDisclosureRow()
            
            // 3. System Controls Panel (Revealed on Hover Preview, Pinned, or Interacting)
            if manager.state.isPanelVisible {
                QuickControlsPanelView()
                    .transition(
                        reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        )
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(manager.state.isPanelVisible ? Color.white.opacity(0.03) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(manager.state.isPanelVisible ? Color.white.opacity(0.06) : Color.clear, lineWidth: 0.8)
        )
        // Measure global screen interaction frame accurately across dynamic window resizing
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: QuickControlsFramePreferenceKey.self,
                        value: geo.frame(in: .global)
                    )
            }
        )
        .onPreferenceChange(QuickControlsFramePreferenceKey.self) { windowRect in
            if let window = NotchShellCoordinator.shared.panel {
                let screenRect = window.convertToScreen(windowRect)
                manager.updateInteractionRegion(screenRect)
            }
        }
        // Single authoritative hover handler covering the entire unified interaction region
        .onHover { isHovered in
            if isHovered {
                manager.onPointerEnteredRegion()
            } else {
                manager.onPointerExitedRegion()
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85), value: manager.state)
    }
}

// MARK: - Quick Controls Disclosure Row
public struct QuickControlsDisclosureRow: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var manager = QuickControlsManager.shared
    
    public init() {}
    
    private func toggleExpansion() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            if manager.state.isPanelVisible {
                if !store.quickControlsPinned {
                    manager.state = .closed
                }
            } else {
                manager.state = .hoverPreview
            }
        }
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Left Title + Icon Target
            Button(action: {
                toggleExpansion()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(manager.state.isPanelVisible ? DesignSystem.accentColor : Color.white.opacity(0.75))
                    
                    Text("Quick Controls")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(manager.state.isPanelVisible ? .white : Color.white.opacity(0.85))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle Quick Controls, currently \(manager.state.isPanelVisible ? "Expanded" : "Collapsed")")
            
            Spacer()
            
            // Pin Toggle Button
            Button(action: {
                manager.togglePin()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: store.quickControlsPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: store.quickControlsPinned ? .bold : .medium))
                        .foregroundColor(store.quickControlsPinned ? DesignSystem.accentColor : Color.white.opacity(0.55))
                    
                    if store.quickControlsPinned {
                        Text("Pinned")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(store.quickControlsPinned ? DesignSystem.accentColor.opacity(0.18) : Color.white.opacity(0.06))
                        .overlay(
                            Capsule()
                                .strokeBorder(store.quickControlsPinned ? DesignSystem.accentColor.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(store.quickControlsPinned ? "Unpin Quick Controls" : "Pin Quick Controls Open")
            .accessibilityLabel(store.quickControlsPinned ? "Unpin Quick Controls" : "Pin Quick Controls")
            
            // Chevron Expansion Indicator
            Button(action: {
                toggleExpansion()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(manager.state.isPanelVisible ? 180 : 0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: manager.state.isPanelVisible)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Expand or collapse controls")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Quick Controls Panel View
public struct QuickControlsPanelView: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var manager = QuickControlsManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            ForEach(store.enabledQuickControls) { kind in
                switch kind {
                case .volume:
                    VolumeControlRow()
                case .brightness:
                    BrightnessControlRow()
                case .keyboardBacklight:
                    KeyboardBacklightControlRow()
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }
}

// MARK: - System Volume Control Row
public struct VolumeControlRow: View {
    @ObservedObject private var manager = QuickControlsManager.shared
    
    public init() {}
    
    private var volumeIcon: String {
        if manager.isMuted || manager.volume <= 0.001 {
            return "speaker.slash.fill"
        } else if manager.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if manager.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            // Header Row
            HStack(spacing: 8) {
                // Mute / Speaker Toggle Icon Button
                Button(action: {
                    manager.toggleMute()
                    FeedbackManager.playClick()
                }) {
                    ZStack {
                        Circle()
                            .fill(manager.isMuted ? Color.red.opacity(0.20) : Color.white.opacity(0.08))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: volumeIcon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(manager.isMuted ? Color.red : (manager.volume > 0 ? DesignSystem.accentColor : Color.white.opacity(0.6)))
                    }
                }
                .buttonStyle(.plain)
                .help(manager.isMuted ? "Unmute Audio" : "Mute Audio")
                .accessibilityLabel(manager.isMuted ? "Unmute Audio" : "Mute Audio")
                
                // Title and Device Subtitle
                VStack(alignment: .leading, spacing: 1) {
                    Text("System Volume")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(manager.activeAudioDeviceName)
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Percentage Display
                Text(manager.isMuted ? "Muted" : "\(Int(round(manager.volume * 100)))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(manager.isMuted ? Color.red : .white)
                    .frame(width: 48, alignment: .trailing)
            }
            
            // Interactive Direct-Manipulation Slider Track
            GeometryReader { geo in
                let width = geo.size.width
                let currentVal = manager.isMuted ? 0.0 : manager.volume
                let progressWidth = max(0, min(width, width * CGFloat(currentVal)))
                
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)
                    
                    // Filled Track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: manager.isMuted
                                ? [Color.red.opacity(0.6), Color.red.opacity(0.8)]
                                : [DesignSystem.accentColor.opacity(0.85), DesignSystem.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth, height: 6)
                    
                    // Thumb Pill Indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 13, height: 13)
                        .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                        .offset(x: max(0, min(width - 13, progressWidth - 6.5)))
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            manager.onSliderDragStarted()
                            guard width > 0 else { return }
                            let newRatio = Double(max(0.0, min(1.0, value.location.x / width)))
                            manager.setVolumeValue(newRatio)
                        }
                        .onEnded { _ in
                            manager.onSliderDragEnded()
                        }
                )
            }
            .frame(height: 16)
            .focusable()
            .onKeyPress(.leftArrow) {
                manager.setVolumeValue(max(0.0, manager.volume - 0.05))
                return .handled
            }
            .onKeyPress(.rightArrow) {
                manager.setVolumeValue(min(1.0, manager.volume + 0.05))
                return .handled
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("System Volume Slider")
            .accessibilityValue(manager.isMuted ? "Muted" : "\(Int(round(manager.volume * 100))) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    manager.setVolumeValue(min(1.0, manager.volume + 0.05))
                case .decrement:
                    manager.setVolumeValue(max(0.0, manager.volume - 0.05))
                @unknown default:
                    break
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.8)
        )
    }
}

// MARK: - Display Brightness Control Row (Honest Capability Detection & Native Action Route)
public struct BrightnessControlRow: View {
    @ObservedObject private var manager = QuickControlsManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            // Header Row
            HStack(spacing: 8) {
                // Sun Icon Badge
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.78, blue: 0.18).opacity(0.14))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.18))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Display Brightness")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(manager.brightnessAvailability.isUsable ? "Hardware Synchronized" : "Built-in Display · Use F1 / F2 keys")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if manager.brightnessAvailability.isUsable {
                    Text("\(Int(round(manager.brightness * 100)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 48, alignment: .trailing)
                } else {
                    // Clean Native Settings Action Pill
                    Button(action: {
                        manager.openSystemDisplaysSettings()
                        FeedbackManager.playClick()
                    }) {
                        HStack(spacing: 4) {
                            Text("Displays...")
                                .font(.system(size: 9.5, weight: .semibold))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(DesignSystem.accentColor.opacity(0.14))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(DesignSystem.accentColor.opacity(0.28), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open macOS Displays Settings")
                    .accessibilityLabel("Open macOS Displays Settings")
                }
            }
            
            // Interactive Slider Track (Rendered ONLY when Usable / Supported)
            if manager.brightnessAvailability.isUsable {
                GeometryReader { geo in
                    let width = geo.size.width
                    let progressWidth = max(0, min(width, width * CGFloat(manager.brightness)))
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.78, blue: 0.18).opacity(0.85), Color(red: 1.0, green: 0.78, blue: 0.18)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: 6)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 13, height: 13)
                            .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                            .offset(x: max(0, min(width - 13, progressWidth - 6.5)))
                    }
                    .frame(height: 16)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                manager.onSliderDragStarted()
                                guard width > 0 else { return }
                                let newRatio = Double(max(0.0, min(1.0, value.location.x / width)))
                                manager.setBrightnessValue(newRatio)
                            }
                            .onEnded { _ in
                                manager.onSliderDragEnded()
                            }
                    )
                }
                .frame(height: 16)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Display Brightness Slider")
                .accessibilityValue("\(Int(round(manager.brightness * 100))) percent")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.8)
        )
    }
}

// MARK: - Keyboard Backlight Control Row (Honest Capability Detection & Native Action Route)
public struct KeyboardBacklightControlRow: View {
    @ObservedObject private var manager = QuickControlsManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            // Header Row
            HStack(spacing: 8) {
                // Keyboard Icon Badge
                ZStack {
                    Circle()
                        .fill(Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.14))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.45, green: 0.75, blue: 1.0))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Keyboard Backlight")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(manager.keyboardBrightnessAvailability.isUsable ? "Hardware Synchronized" : "Ambient Light · Use F5 / F6 keys")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if manager.keyboardBrightnessAvailability.isUsable {
                    Text("\(Int(round(manager.keyboardBrightness * 100)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 48, alignment: .trailing)
                } else {
                    // Clean Native Settings Action Pill
                    Button(action: {
                        manager.openSystemKeyboardSettings()
                        FeedbackManager.playClick()
                    }) {
                        HStack(spacing: 4) {
                            Text("Keyboard...")
                                .font(.system(size: 9.5, weight: .semibold))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(DesignSystem.accentColor.opacity(0.14))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(DesignSystem.accentColor.opacity(0.28), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open macOS Keyboard Settings")
                    .accessibilityLabel("Open macOS Keyboard Settings")
                }
            }
            
            // Interactive Slider Track (Rendered ONLY when Usable / Supported)
            if manager.keyboardBrightnessAvailability.isUsable {
                GeometryReader { geo in
                    let width = geo.size.width
                    let progressWidth = max(0, min(width, width * CGFloat(manager.keyboardBrightness)))
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.85), Color(red: 0.45, green: 0.75, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: 6)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 13, height: 13)
                            .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                            .offset(x: max(0, min(width - 13, progressWidth - 6.5)))
                    }
                    .frame(height: 16)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                manager.onSliderDragStarted()
                                guard width > 0 else { return }
                                let newRatio = Double(max(0.0, min(1.0, value.location.x / width)))
                                manager.setKeyboardBrightnessValue(newRatio)
                            }
                            .onEnded { _ in
                                manager.onSliderDragEnded()
                            }
                    )
                }
                .frame(height: 16)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Keyboard Backlight Slider")
                .accessibilityValue("\(Int(round(manager.keyboardBrightness * 100))) percent")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.8)
        )
    }
}
