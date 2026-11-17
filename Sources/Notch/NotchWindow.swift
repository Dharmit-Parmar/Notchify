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
        // Keep notch above menu bar and over full-screen apps (popUpMenu sits above mainMenu 24 and statusBar 25)
        self.level = .popUpMenu
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
                       !NotchShellCoordinator.shared.isLockedOpen,
                       !NotchShellCoordinator.shared.isMenuOrPopoverOpen {
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
    
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // Return frameRect strictly unmodified so AppKit never pushes the panel below screen.visibleFrame.maxY
        return frameRect
    }
    
    public static func calculateFrame(for state: NotchState, store: SettingsStore, screen: NSScreen) -> NSRect {
        if state == .expanded {
            // Sole source of truth for expanded geometry, incorporating current screen and Quick Controls height
            return NotchShellCoordinator.shared.currentExpandedLayout.windowRect
        } else {
            let geometry = NotchGeometry.current(for: screen)
            let layout = NotchGeometry.collapsedLayout(
                geometry: geometry,
                style: store.compactIndicatorStyle,
                mode: store.collapsedNotchMode,
                attachment: store.positionAttachment,
                wingWidth: store.wingWidth,
                collapsedHeight: store.collapsedNotchHeight,
                horizontalOffset: store.horizontalNotchOffset,
                verticalOffset: store.verticalNotchOffset,
                activeEvents: ActiveNotchEvents(
                    isMediaPlaying: NowPlayingModule.shared.hasActiveMedia,
                    isCharging: BatteryModule.shared.isCharging
                )
            )
            return layout.windowRect
        }
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
                self.animator().setFrame(targetRect, display: true)
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
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let c = NotchShellCoordinator.shared
        if c.state == .collapsed && !c.isFileDraggingActive {
            let inWindow = superview?.convert(point, to: nil) ?? point
            let onScreen = window?.convertPoint(toScreen: inWindow) ?? inWindow
            guard c.currentCollapsedLayout.hoverTriggerRect.contains(onScreen) else { return nil }
        }
        return super.hitTest(point)
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
