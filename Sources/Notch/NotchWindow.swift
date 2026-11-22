
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

        // Initial collapsed frame.
        // Only covers the configured notch interaction area.
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

        // Keep the notch above the menu bar and full-screen applications.
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

    // MARK: - Event Monitors

    private func setOutsideClickMonitorEnabled(_ enabled: Bool) {

        if enabled, outsideClickMonitor == nil {

            // Outside-click monitor.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in

                Task { @MainActor [weak self] in

                    guard let self = self else { return }

                    guard SettingsStore.shared.closeOnOutsideClick else {
                        return
                    }

                    // Do not collapse when interacting with Settings.
                    if AppDelegate.isSettingsOpen {
                        if let settingsWin = AppDelegate.settingsWindow,
                           settingsWin.frame.contains(NSEvent.mouseLocation) {
                            return
                        }
                    }

                    let mouseLocation = NSEvent.mouseLocation

                    if !self.frame.contains(mouseLocation),
                       NotchShellCoordinator.shared.state == .expanded,
                       !NotchShellCoordinator.shared.isLockedOpen,
                       !NotchShellCoordinator.shared.isMenuOrPopoverOpen {

                        if !NotchShellCoordinator.shared.isAppearancePreviewActive {
                            NotchShellCoordinator.shared.collapseImmediately(force: true)
                        }
                    }
                }
            }

            // Local Escape-key monitor.
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(
                matching: .keyDown
            ) { event in

                // Escape is key code 53.
                guard event.keyCode == 53 else {
                    return event
                }

                // Let Settings handle its own Escape key.
                if AppDelegate.isSettingsOpen {
                    return event
                }

                guard SettingsStore.shared.closeOnEsc else {
                    return event
                }

                Task { @MainActor in
                    NotchShellCoordinator.shared.collapseImmediately(force: true)
                }

                return nil
            }

            // Global Escape-key monitor.
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: .keyDown
            ) { event in

                // Ignore all keys except Escape.
                guard event.keyCode == 53 else {
                    return
                }

                Task { @MainActor in

                    if AppDelegate.isSettingsOpen {
                        return
                    }

                    guard SettingsStore.shared.closeOnEsc,
                          NotchShellCoordinator.shared.state == .expanded,
                          !NotchShellCoordinator.shared.isLockedOpen,
                          !NotchShellCoordinator.shared.isAppearancePreviewActive else {
                        return
                    }

                    NotchShellCoordinator.shared.collapseImmediately(force: true)
                }
            }

        } else if !enabled {

            // Remove monitors when the notch collapses.

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

    // MARK: - Window Activation

    public override var canBecomeKey: Bool {

        // Never steal focus while collapsed or while Settings is open.
        let isExpanded = NotchShellCoordinator.shared.state == .expanded
        let isSettingsOpen = AppDelegate.isSettingsOpen

        return isExpanded && !isSettingsOpen
    }

    public override var canBecomeMain: Bool {
        return false
    }

    // MARK: - Window Geometry

    public override func constrainFrameRect(
        _ frameRect: NSRect,
        to screen: NSScreen?
    ) -> NSRect {

        // Preserve the geometry calculated by NotchGeometry.
        return frameRect
    }

    public static func calculateFrame(
        for state: NotchState,
        store: SettingsStore,
        screen: NSScreen
    ) -> NSRect {

        if state == .expanded {

            // Expanded geometry has one source of truth.
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
                hoverTriggerWidth: store.hoverTriggerWidth,
                hoverTriggerHeight: store.hoverTriggerHeight,
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

    // MARK: - Multi-Display Support

    @discardableResult
    public func refreshScreenReference() -> NSScreen {

        // First attempt to find the original physical display.
        if let matching = NSScreen.screens.first(where: {

            if let id1 = $0.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID,

               let id2 = self.currentScreen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID {

                return id1 == id2
            }

            return $0 == self.currentScreen
        }) {

            self.currentScreen = matching
            return matching
        }

        // Original display was disconnected.
        // Choose a suitable remaining display.
        let fallback =
            NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? self.currentScreen

        self.currentScreen = fallback

        return fallback
    }

    // MARK: - Frame Updates

    public func updateFrame(
        for state: NotchState,
        animated: Bool
    ) {

        setOutsideClickMonitorEnabled(state == .expanded)

        let activeScreen = refreshScreenReference()

        let targetRect = NotchPanel.calculateFrame(
            for: state,
            store: SettingsStore.shared,
            screen: activeScreen
        )

        guard self.frame != targetRect else {
            return
        }

        if animated &&
            !DesignSystem.reduceMotion &&
            !EnvironmentState.shared.reduceMotion {

            let isLowPower =
                EnvironmentState.shared.isLowPowerMode ||
                EnvironmentState.shared.thermalState == .critical ||
                EnvironmentState.shared.thermalState == .serious

            let physics = isLowPower
                ? MotionPhysicsStyle.snappy
                : SettingsStore.shared.motionPhysics

            let duration = physics.response

            NSAnimationContext.runAnimationGroup { context in

                context.duration = duration

                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.20,
                    1.0,
                    0.32,
                    1.0
                )

                self.animator().setFrame(
                    targetRect,
                    display: true
                )
            }

        } else {

            NSAnimationContext.runAnimationGroup { context in

                context.duration = 0

                self.animator().setFrame(
                    targetRect,
                    display: false
                )
            }

            self.setFrame(
                targetRect,
                display: true
            )
        }
    }
}

// MARK: - Custom Hosting View

@MainActor
public final class NotchHostingView<Content: View>: NSHostingView<Content> {

    private var trackingArea: NSTrackingArea?

    // MARK: - Tracking Areas

    public override func updateTrackingAreas() {

        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(area)

        trackingArea = area
    }

    // MARK: - Hit Testing

    public override func hitTest(_ point: NSPoint) -> NSView? {

        let coordinator = NotchShellCoordinator.shared

        // While expanded, retain normal SwiftUI hit testing.
        // File dragging also requires normal hit testing.
        if coordinator.state == .collapsed &&
            !coordinator.isFileDraggingActive {

            guard let window = self.window else {
                return super.hitTest(point)
            }

            // IMPORTANT:
            // The point passed into hitTest belongs to THIS hosting view.
            // Convert directly from this view into the window's base coordinates.
            let pointInWindow = self.convert(point, to: nil)

            // Convert window coordinates into global screen coordinates.
            let pointOnScreen = window.convertPoint(
                toScreen: pointInWindow
            )

            // These layout rectangles are expressed in screen coordinates.
            let layout = coordinator.currentCollapsedLayout

            let isInsideHoverSensor =
                layout.hoverTriggerRect.contains(pointOnScreen)

            let isInsideVisibleWings =
                layout.isWingsVisible &&
                layout.contentRect.contains(pointOnScreen)

            // Ignore all screen areas outside the intentional
            // collapsed notch interaction region.
            guard isInsideHoverSensor || isInsideVisibleWings else {
                return nil
            }
        }

        return super.hitTest(point)
    }

    // MARK: - Mouse Events

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
