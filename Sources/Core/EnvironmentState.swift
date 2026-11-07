import SwiftUI
import AppKit
import Combine

@MainActor
public final class EnvironmentState: ObservableObject {
    public static let shared = EnvironmentState()
    
    // System Energy & Power (Event-Driven)
    @Published public private(set) var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published public private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    
    // Accessibility Preferences (Event-Driven)
    @Published public private(set) var reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    @Published public private(set) var reduceTransparency: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    @Published public private(set) var increaseContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    @Published public private(set) var isDarkMode: Bool = true
    
    // Display & Notch Hardware Geometry
    @Published public private(set) var geometry: NotchGeometry = NotchGeometry.current()
    @Published public private(set) var hasPhysicalNotch: Bool = false
    
    // Spaces & Full-Screen State
    @Published public private(set) var isFullScreenSpace: Bool = false
    @Published public private(set) var activeSpaceTag: String = "Active"
    
    // Real-Time Interaction States
    @Published public var isFileDraggingActive: Bool = false
    @Published public var mascotOccupiedZone: CGRect = .zero
    
    // Detection & Fallback Health
    @Published public var colorDetectionStatus: String = "Idle"
    @Published public var activeFallbackStage: String = "Initializing"
    
    private var observerTokens: [NSObjectProtocol] = []
    
    private init() {
        refreshAll()
        setupEventObservers()
    }
    
    public func refreshAll() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        geometry = NotchGeometry.current()
        hasPhysicalNotch = geometry.hasPhysicalNotch
        isDarkMode = (NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    }
    
    private func setupEventObservers() {
        // 1. Low Power Mode Changes
        let powerToken = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                DynamicThemeEngine.shared.refreshColors()
            }
        }
        observerTokens.append(powerToken)
        
        // 2. Thermal State Notifications
        let thermalToken = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.thermalState = ProcessInfo.processInfo.thermalState
            }
        }
        observerTokens.append(thermalToken)
        
        // 3. Accessibility Display Options (Reduce Motion, Transparency, Contrast)
        let a11yToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                self.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
                self.increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                DynamicThemeEngine.shared.refreshColors()
            }
        }
        observerTokens.append(a11yToken)
        
        // 4. Screen Geometry & Display Parameters
        let screenToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.geometry = NotchGeometry.current()
                self.hasPhysicalNotch = self.geometry.hasPhysicalNotch
            }
        }
        observerTokens.append(screenToken)
        
        // 5. Active Space Changes
        let spaceToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeSpaceTag = "SpaceChanged_\(Date().timeIntervalSinceReferenceDate)"
            }
        }
        observerTokens.append(spaceToken)
    }
    
    isolated deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }
}
