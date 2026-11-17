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
            // 1. Specular Divider Above Quick Controls
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 4)
            
            // 2. Disclosure Bar
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
                .fill(manager.state.isPanelVisible ? Color.white.opacity(0.04) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(manager.state.isPanelVisible ? Color.white.opacity(0.08) : Color.clear, lineWidth: 0.8)
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
            // Left Title + Icon Target (Unambiguous Button)
            Button(action: {
                toggleExpansion()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(manager.state.isPanelVisible ? DesignSystem.accentColor : Color.white.opacity(0.75))
                    
                    Text("Quick Controls")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(manager.state.isPanelVisible ? .white : Color.white.opacity(0.85))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle Quick Controls, currently \(manager.state.isPanelVisible ? "Expanded" : "Collapsed")")
            
            Spacer()
            
            // Pin Button Target (Dedicated Unambiguous Hit Target)
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
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(store.quickControlsPinned ? "Unpin Quick Controls" : "Pin Quick Controls Open")
            .accessibilityLabel(store.quickControlsPinned ? "Unpin Quick Controls" : "Pin Quick Controls")
            
            // Chevron Indicator Button
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
        VStack(spacing: 8) {
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
                .fill(Color.black.opacity(0.25))
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
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Mute / Speaker Toggle Icon Button
                Button(action: {
                    manager.toggleMute()
                    FeedbackManager.playClick()
                }) {
                    ZStack {
                        Circle()
                            .fill(manager.isMuted ? Color.red.opacity(0.2) : Color.white.opacity(0.08))
                            .frame(width: 22, height: 22)
                        
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
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(manager.activeAudioDeviceName)
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Percentage Display
                Text(manager.isMuted ? "Muted" : "\(Int(round(manager.volume * 100)))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(manager.isMuted ? Color.red : .white)
                    .frame(width: 44, alignment: .trailing)
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
                        .frame(height: 7)
                    
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
                        .frame(width: progressWidth, height: 7)
                    
                    // Thumb Pill Indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 13, height: 13)
                        .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                        .offset(x: max(0, min(width - 13, progressWidth - 6.5)))
                }
                .frame(height: 18)
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
            .frame(height: 18)
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
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Display Brightness Control Row (Honest Capability Detection & System Route)
public struct BrightnessControlRow: View {
    @ObservedObject private var manager = QuickControlsManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Sun Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.18))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Display Brightness")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(manager.brightnessAvailability.isUsable ? "Hardware Synchronized" : "System Managed (F1 / F2)")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if manager.brightnessAvailability.isUsable {
                    Text("\(Int(round(manager.brightness * 100)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 44, alignment: .trailing)
                } else {
                    // System Settings Route Button
                    Button(action: {
                        manager.openSystemDisplaysSettings()
                        FeedbackManager.playClick()
                    }) {
                        HStack(spacing: 3) {
                            Text("Displays...")
                                .font(.system(size: 9.5, weight: .semibold))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.accentColor.opacity(0.14))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open macOS Displays Settings (Direct brightness control restricted to system SPI)")
                    .accessibilityLabel("Open macOS Displays Settings")
                }
            }
            
            // Slider Track (Active when usable, Gracefully Disabled when restricted)
            GeometryReader { geo in
                let width = geo.size.width
                
                if manager.brightnessAvailability.isUsable {
                    let progressWidth = max(0, min(width, width * CGFloat(manager.brightness)))
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 7)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.78, blue: 0.18).opacity(0.85), Color(red: 1.0, green: 0.78, blue: 0.18)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: 7)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 13, height: 13)
                            .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                            .offset(x: max(0, min(width - 13, progressWidth - 6.5)))
                    }
                    .frame(height: 18)
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
                } else {
                    // Gracefully Disabled Rail with Honest Public-API State Indicator
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 7)
                        
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                            .frame(height: 7)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 7))
                                .foregroundColor(Color.white.opacity(0.35))
                            Text("Managed by macOS Displays Settings & Control Center")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .padding(.leading, 6)
                    }
                    .frame(height: 18)
                    .help("Direct brightness requires private DisplayServices framework. Use F1/F2 keys or click Displays... above.")
                }
            }
            .frame(height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Display Brightness Control, \(manager.brightnessAvailability.isUsable ? "\(Int(round(manager.brightness * 100))) percent" : "Managed by macOS Displays Settings")")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Keyboard Backlight Control Row (Honest Capability Detection & Hardware Route)
public struct KeyboardBacklightControlRow: View {
    @ObservedObject private var manager = QuickControlsManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Keyboard Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.5, green: 0.8, blue: 1.0))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Keyboard Backlight")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(manager.keyboardBrightnessAvailability.isUsable ? "Hardware Synchronized" : "Hardware Managed (F5 / F6)")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if manager.keyboardBrightnessAvailability.isUsable {
                    Text("\(Int(round(manager.keyboardBrightness * 100)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 44, alignment: .trailing)
                } else {
                    // System Keyboard Settings Route Button
                    Button(action: {
                        manager.openSystemKeyboardSettings()
                        FeedbackManager.playClick()
                    }) {
                        HStack(spacing: 3) {
                            Text("Keyboard...")
                                .font(.system(size: 9.5, weight: .semibold))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.accentColor.opacity(0.14))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open macOS Keyboard Settings (Direct keyboard backlight control restricted to system SPI)")
                    .accessibilityLabel("Open macOS Keyboard Settings")
                }
            }
            
            // Slider Track (Active when usable, Gracefully Disabled when restricted)
            GeometryReader { geo in
                let width = geo.size.width
                
                if manager.keyboardBrightnessAvailability.isUsable {
                    let progressWidth = max(0, min(width, width * CGFloat(manager.keyboardBrightness)))
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 7)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.5, green: 0.8, blue: 1.0).opacity(0.85), Color(red: 0.5, green: 0.8, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: 7)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 13, height: 13)
                            .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                            .offset(x: max(0, min(width - 13, progressWidth - 6.5)))
                    }
                    .frame(height: 18)
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
                } else {
                    // Gracefully Disabled Rail with Honest Public-API State Indicator
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 7)
                        
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                            .frame(height: 7)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 7))
                                .foregroundColor(Color.white.opacity(0.35))
                            Text("Managed by macOS Keyboard Settings & Hardware Keys")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .padding(.leading, 6)
                    }
                    .frame(height: 18)
                    .help("Direct keyboard backlight requires private CoreBrightness framework. Use F5/F6 keys or click Keyboard... above.")
                }
            }
            .frame(height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Keyboard Backlight Control, \(manager.keyboardBrightnessAvailability.isUsable ? "\(Int(round(manager.keyboardBrightness * 100))) percent" : "Managed by macOS Keyboard Settings")")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
