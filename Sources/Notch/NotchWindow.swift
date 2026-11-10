import AppKit
import SwiftUI

@MainActor
public final class NotchPanel: NSPanel {
    public private(set) var currentScreen: NSScreen
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    
    public init(screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        self.currentScreen = screen
        
        // Initial collapsed frame: ONLY covers the physical notch, leaving 100% of the screen clickable!
        let initialRect = NotchPanel.calculateFrame(
            for: .collapsed,
            store: SettingsStore.shared,
            screen: screen
        )
        
        super.init(
            contentRect: initialRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovable = false
        self.acceptsMouseMovedEvents = true
        
    }
    
    isolated deinit {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let keyMon = localKeyMonitor {
            NSEvent.removeMonitor(keyMon)
        }
        if let gKeyMon = globalKeyMonitor {
            NSEvent.removeMonitor(gKeyMon)
        }
    }
    
    private func setOutsideClickMonitorEnabled(_ enabled: Bool) {
        if enabled, outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    guard SettingsStore.shared.closeOnOutsideClick else { return }
                    if AppDelegate.isSettingsOpen {
                        if let settingsWin = AppDelegate.settingsWindow, settingsWin.frame.contains(NSEvent.mouseLocation) {
                            return
                        }
                    }
                    if !self.frame.contains(NSEvent.mouseLocation),
                       NotchShellCoordinator.shared.state == .expanded,
                       !NotchShellCoordinator.shared.isLockedOpen {
                        if !NotchShellCoordinator.shared.isAppearancePreviewActive {
                            NotchShellCoordinator.shared.collapseImmediately(force: true)
                        }
                    }
                }
            }
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC key
                    // If Settings window is currently open, DO NOT collapse notch on Esc — let Settings window handle Esc!
                    if AppDelegate.isSettingsOpen {
                        return event
                    }
                    if SettingsStore.shared.closeOnEsc {
                        Task { @MainActor in
                            NotchShellCoordinator.shared.collapseImmediately(force: true)
                        }
                        return nil
                    }
                }
                return event
            }
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in
                Task { @MainActor in
                    if AppDelegate.isSettingsOpen { return }
                    if SettingsStore.shared.closeOnEsc,
                       NotchShellCoordinator.shared.state == .expanded,
                       !NotchShellCoordinator.shared.isLockedOpen,
                       !NotchShellCoordinator.shared.isAppearancePreviewActive {
                        NotchShellCoordinator.shared.collapseImmediately(force: true)
                    }
                }
            }
        } else if !enabled {
            if let monitor = outsideClickMonitor {
                NSEvent.removeMonitor(monitor)
                outsideClickMonitor = nil
            }
            if let keyMon = localKeyMonitor {
                NSEvent.removeMonitor(keyMon)
                localKeyMonitor = nil
            }
            if let gKeyMon = globalKeyMonitor {
                NSEvent.removeMonitor(gKeyMon)
                globalKeyMonitor = nil
            }
        }
    }
    
    public override var canBecomeKey: Bool {
        // Never steal focus when collapsed or when settings window is open!
        let isExpanded = NotchShellCoordinator.shared.state == .expanded
        let isSettingsOpen = AppDelegate.isSettingsOpen
        return isExpanded && !isSettingsOpen
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public static func calculateFrame(for state: NotchState, store: SettingsStore, screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let geometry = NotchGeometry.current(for: screen)
        
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        
        if state == .expanded {
            if store.dashboardLayoutFlow == .horizontalStrip && store.activeDashboardWidgets.count >= 4 {
                targetWidth = max(store.notchWidth, 720.0)
            } else {
                targetWidth = store.notchWidth
            }
            
            // Adaptive target height based on active module and dashboard widget count
            if let activeId = ModuleRegistry.shared.activeModuleId {
                switch activeId {
                case "battery":
                    targetHeight = min(store.notchHeight, 220.0)
                case "airdrop":
                    targetHeight = min(store.notchHeight, 240.0)
                case "notifications":
                    targetHeight = min(store.notchHeight, 260.0)
                default:
                    targetHeight = store.notchHeight
                }
            } else {
                let activeWidgets = store.activeDashboardWidgets
                if activeWidgets.isEmpty {
                    targetHeight = 180.0
                } else if store.dashboardLayoutFlow == .horizontalStrip {
                    targetHeight = min(store.notchHeight, 225.0)
                } else if store.dashboardLayoutFlow == .bentoQuad {
                    let s2 = store.dashboardSlots.indices.contains(2) ? store.dashboardSlots[2] : nil
                    let s3 = store.dashboardSlots.indices.contains(3) ? store.dashboardSlots[3] : nil
                    if s2 == nil && s3 == nil {
                        targetHeight = min(store.notchHeight, 225.0)
                    } else {
                        targetHeight = store.notchHeight
                    }
                } else if store.dashboardLayoutFlow == .focusDominant && activeWidgets.count <= 2 {
                    targetHeight = min(store.notchHeight, 230.0)
                } else {
                    targetHeight = store.notchHeight
                }
            }
        } else {
            let baseWidth = geometry.physicalNotchWidth + 24.0
            if store.compactIndicatorStyle == .threeZoneStatusBar {
                if geometry.hasPhysicalNotch {
                    targetWidth = max(store.hoverTriggerWidth, geometry.physicalNotchWidth + 180.0)
                } else {
                    targetWidth = max(store.hoverTriggerWidth, 270.0)
                }
            } else {
                targetWidth = store.hoverTriggerWidth > 0 ? store.hoverTriggerWidth : baseWidth
            }
            targetHeight = store.hoverTriggerHeight
        }
        
        let x = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2.0
        let y = screenFrame.origin.y + screenFrame.height - targetHeight
        
        return NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }
    
    public func updateFrame(for state: NotchState, animated: Bool) {
        setOutsideClickMonitorEnabled(state == .expanded)

        let targetRect = NotchPanel.calculateFrame(
            for: state,
            store: SettingsStore.shared,
            screen: currentScreen
        )
        
        guard self.frame != targetRect else { return }
        
        if animated && !DesignSystem.reduceMotion && !EnvironmentState.shared.reduceMotion {
            let isLowPower = EnvironmentState.shared.isLowPowerMode || EnvironmentState.shared.thermalState == .critical || EnvironmentState.shared.thermalState == .serious
            let physics = isLowPower ? MotionPhysicsStyle.snappy : SettingsStore.shared.motionPhysics
            let duration = physics.response
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 1.0, 0.32, 1.0)
                self.animator().setFrame(targetRect, display: false)
            }
        } else {
            self.setFrame(targetRect, display: true)
        }
    }
}

@MainActor
public final class NotchHostingView<Content: View>: NSHostingView<Content> {
    private var trackingArea: NSTrackingArea?
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NotchShellCoordinator.shared.onMouseEnter()
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if !NotchShellCoordinator.shared.isHovered {
            NotchShellCoordinator.shared.onMouseEnter()
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NotchShellCoordinator.shared.onMouseExit()
    }
}
