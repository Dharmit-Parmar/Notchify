import SwiftUI
import Combine

public enum NotchState {
    case collapsed
    case expanded
}

@MainActor
public final class NotchShellCoordinator: ObservableObject {
    public static let shared = NotchShellCoordinator()
    
    @Published public var state: NotchState = .collapsed {
        didSet {
            guard state != oldValue else { return }
            if state == .expanded && !isLockedOpen {
                startExpandedWatchdog()
            } else if state == .collapsed {
                stopExpandedWatchdog()
                MirrorModule.shared.stop()
                ModuleRegistry.shared.stopAll()
                ModuleRegistry.shared.unloadInactiveModules()
                NowPlayingModule.shared.evictArtworkOnCollapse()
                NoteStorageManager.shared.saveImmediately()
            }
        }
    }
    public var isExpanded: Bool { state == .expanded }
    @Published public var isHovered: Bool = false
    @Published public var isLockedOpen: Bool = false
    @Published public var isFileDragTargeted = false
    @Published public var isFileDraggingActive = false
    @Published public var isMenuOrPopoverOpen: Bool = false
    @Published public var isTypingInWidget: Bool = false
    private var popoverCount = 0
    public var fileDropWasAccepted = false
    @Published public var geometry: NotchGeometry = NotchGeometry.current()
    
    public weak var panel: NotchPanel?
    
    private var hoverWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var expandedWatchdog: Timer?
    private var cachedExpandedRect: NSRect = .zero
    private var screenObserver: NSObjectProtocol?
    
    private init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.geometry = NotchGeometry.current()
                self.panel?.updateFrame(for: self.state, animated: false)
            }
        }
    }
    
    public var transitionAnimation: Animation? {
        if DesignSystem.reduceMotion || EnvironmentState.shared.reduceMotion { return nil }
        let isLowPower = EnvironmentState.shared.isLowPowerMode || EnvironmentState.shared.thermalState == .critical || EnvironmentState.shared.thermalState == .serious
        let physics = isLowPower ? MotionPhysicsStyle.snappy : SettingsStore.shared.motionPhysics
        return .spring(response: physics.response, dampingFraction: physics.damping)
    }
    
    // MARK: - Resettable 4s Idle Dimming Governor (Zero-Allocation Deadline Model)
    @Published public var isIdleDimmed: Bool = false
    private var idleDeadline: CFTimeInterval = 0
    private var idleDimWorkItem: DispatchWorkItem?
    
    public func resetIdleTimer() {
        idleDeadline = CACurrentMediaTime() + 4.0
        if isIdleDimmed {
            withAnimation(DesignSystem.reduceMotion ? nil : .easeInOut(duration: 0.20)) {
                isIdleDimmed = false
            }
        }
        guard state == .expanded, !isLockedOpen, !isFileDraggingActive, !isMenuOrPopoverOpen else {
            idleDimWorkItem?.cancel()
            idleDimWorkItem = nil
            return
        }
        if idleDimWorkItem != nil {
            // Already scheduled! Zero allocations on mouse moves
            return
        }
        scheduleIdleDeadlineCheck()
    }
    
    private func scheduleIdleDeadlineCheck() {
        let remaining = max(0.2, idleDeadline - CACurrentMediaTime())
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.idleDimWorkItem = nil
                guard self.state == .expanded, !self.isLockedOpen, !self.isFileDraggingActive, !self.isMenuOrPopoverOpen else { return }
                let now = CACurrentMediaTime()
                if now >= self.idleDeadline {
                    withAnimation(DesignSystem.reduceMotion ? nil : .easeInOut(duration: 0.60)) {
                        self.isIdleDimmed = true
                    }
                } else {
                    self.scheduleIdleDeadlineCheck()
                }
            }
        }
        idleDimWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: item)
    }
    
    private var appearancePreviewWorkItem: DispatchWorkItem?
    public private(set) var isAppearancePreviewActive: Bool = false
    
    /// Provides visual feedback when appearance settings change by smoothly opening and closing the notch
    public func triggerAppearancePropagationPreview() {
        guard !isFileDraggingActive else { return }
        if let panel = self.panel {
            cachedExpandedRect = NotchPanel.calculateFrame(
                for: .expanded,
                store: SettingsStore.shared,
                screen: panel.currentScreen
            )
        }
        appearancePreviewWorkItem?.cancel()
        isAppearancePreviewActive = true
        
        if state != .expanded {
            withAnimation(transitionAnimation) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
        }
        
        FeedbackManager.playHover()
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isAppearancePreviewActive = false
            guard !self.isHovered, !self.isLockedOpen, !self.isFileDraggingActive,
                  !self.isMenuOrPopoverOpen else { return }
            self.stopExpandedWatchdog()
            self.idleDimWorkItem?.cancel(); self.idleDimWorkItem = nil
            self.isIdleDimmed = false
            withAnimation(self.transitionAnimation) { self.state = .collapsed }
            self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
        }
        appearancePreviewWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15, execute: item)
    }
    
    /// Previews the current live notch dashboard on the screen for a set duration
    public func previewDashboard(duration: TimeInterval = 3.5) {
        guard !isFileDraggingActive else { return }
        appearancePreviewWorkItem?.cancel()
        isAppearancePreviewActive = true
        
        withAnimation(transitionAnimation) {
            self.state = .expanded
        }
        self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
        FeedbackManager.playHover()
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isAppearancePreviewActive = false
            guard !self.isHovered && !self.isLockedOpen && !self.isFileDraggingActive && !self.isMenuOrPopoverOpen else { return }
            self.stopExpandedWatchdog()
            self.idleDimWorkItem?.cancel()
            self.idleDimWorkItem = nil
            self.isIdleDimmed = false
            withAnimation(self.transitionAnimation) {
                self.state = .collapsed
            }
            self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
        }
        appearancePreviewWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }
    
    private func startExpandedWatchdog() {
        stopExpandedWatchdog()
        guard state == .expanded, !isLockedOpen else { return }
        
        if let panel = self.panel {
            cachedExpandedRect = NotchPanel.calculateFrame(
                for: .expanded,
                store: SettingsStore.shared,
                screen: panel.currentScreen
            )
        }
        
        // 0.15s interval: highly responsive to cursor without thrashing CPU
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                guard self.state == .expanded, !self.isLockedOpen, !self.isFileDraggingActive, !self.isTypingInWidget else {
                    if !self.isTypingInWidget && (self.state != .expanded || self.isLockedOpen || self.isFileDraggingActive) {
                        self.stopExpandedWatchdog()
                    }
                    return
                }
                guard let panel = self.panel else { return }
                let mouseLoc = NSEvent.mouseLocation
                let effectiveBounds = panel.frame.union(self.cachedExpandedRect)
                let containsMouse = effectiveBounds.contains(mouseLoc)
                
                if !containsMouse {
                    if !self.isTypingInWidget && (self.isHovered || self.collapseWorkItem == nil) {
                        self.onMouseExit()
                    }
                } else {
                    if !self.isAppearancePreviewActive {
                        if !self.isHovered || self.collapseWorkItem != nil {
                            self.onMouseEnter()
                        }
                    }
                }
            }
        }
        
        RunLoop.main.add(timer, forMode: .common)
        expandedWatchdog = timer
    }
    
    private func stopExpandedWatchdog() {
        expandedWatchdog?.invalidate()
        expandedWatchdog = nil
    }
    
    public func onFileDragEntered() {
        isFileDraggingActive = true
        fileDropWasAccepted = false
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        
        if state != .expanded {
            withAnimation(transitionAnimation) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            MirrorModule.shared.resumeIfViewed()
        }
        if ModuleRegistry.shared.activeModuleId == nil {
            ModuleRegistry.shared.selectFileDropTarget()
        }
    }
    
    public func onFileDragExited() {
        isFileDraggingActive = false
        if !isHovered && !isLockedOpen {
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.collapseWorkItem = nil
                guard !self.isFileDraggingActive else { return }
                self.stopExpandedWatchdog()
                withAnimation(self.transitionAnimation) {
                    self.state = .collapsed
                }
                self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
                ModuleRegistry.shared.stopAll()
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + SettingsStore.shared.autoCollapseDelay, execute: item)
        }
    }
    
    public func onFileDropFinished() {
        isFileDraggingActive = false
        fileDropWasAccepted = true
        // Allow user to see what was dropped, then schedule normal hover collapse if mouse left
        if !isHovered && !isLockedOpen {
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.collapseWorkItem = nil
                guard !self.isHovered, !self.isLockedOpen else { return }
                self.collapseImmediately()
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
        }
    }
    
    public func onMouseEnter() {
        if state == .expanded {
            if isAppearancePreviewActive && AppDelegate.isSettingsOpen {
                return // Do not trap preview in expanded state when clicking settings
            }
            isHovered = true
            resetIdleTimer()
            if collapseWorkItem != nil {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
            }
            if expandedWatchdog == nil && !isLockedOpen {
                startExpandedWatchdog()
            }
            return
        }
        
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        isHovered = true
        
        guard state != .expanded else { return }
        hoverWorkItem?.cancel()
        
        let delay = max(0.06, min(0.50, SettingsStore.shared.hoverDelay))
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isHovered else { return }
            self.hoverWorkItem = nil
            withAnimation(self.transitionAnimation) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            self.resetIdleTimer()
            NowPlayingModule.shared.refreshMediaState()
            ModuleRegistry.shared.activeModule?.start()
            MirrorModule.shared.resumeIfViewed()
            if self.expandedWatchdog == nil && !self.isLockedOpen {
                self.startExpandedWatchdog()
            }
        }
        hoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    public func onMouseExit() {
        if SettingsStore.shared.keepOpenWhileSettingsActive && AppDelegate.isSettingsOpen { return }
        
        if let panel = self.panel {
            let mouseLoc = NSEvent.mouseLocation
            let expandedRect = cachedExpandedRect
            let effectiveBounds = (state == .expanded)
                ? panel.frame.union(expandedRect).insetBy(dx: -24, dy: -14)
                : panel.frame.insetBy(dx: -20, dy: -10)
            if effectiveBounds.contains(mouseLoc) {
                // The cursor is physically still inside or adjacent to the notch window!
                return
            }
        }
        
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        isHovered = false
        
        guard !isLockedOpen, !isFileDraggingActive, !isMenuOrPopoverOpen, !isTypingInWidget, state != .collapsed else { return }
        
        if collapseWorkItem != nil { return }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.collapseWorkItem = nil
            if let panel = self.panel {
                let mouseLoc = NSEvent.mouseLocation
                let expandedRect = self.cachedExpandedRect
                let effectiveBounds = (self.state == .expanded)
                    ? panel.frame.union(expandedRect).insetBy(dx: -24, dy: -14)
                    : panel.frame.insetBy(dx: -20, dy: -10)
                if effectiveBounds.contains(mouseLoc) {
                    self.isHovered = true
                    return
                }
            }
            guard !self.isHovered, !self.isLockedOpen, !self.isFileDraggingActive, !self.isMenuOrPopoverOpen, !self.isTypingInWidget else { return }
            
            self.stopExpandedWatchdog()
            self.idleDimWorkItem?.cancel()
            self.idleDimWorkItem = nil
            self.isIdleDimmed = false
            withAnimation(self.transitionAnimation) {
                self.state = .collapsed
            }
            self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
        }
        collapseWorkItem = item
        let collapseDelay = AppDelegate.isSettingsOpen ? 0.30 : SettingsStore.shared.autoCollapseDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.25, collapseDelay), execute: item)
    }
    
    public func registerPopoverOpened() {
        popoverCount += 1
        isMenuOrPopoverOpen = true
        collapseWorkItem?.cancel(); collapseWorkItem = nil
    }
    
    public func registerPopoverClosed() {
        popoverCount = max(0, popoverCount - 1)
        guard popoverCount == 0 else { return }
        isMenuOrPopoverOpen = false
        onMouseExit()
    }
    
    public func collapseImmediately(force: Bool = false) {
        if force {
            isLockedOpen = false
            isFileDraggingActive = false
            isMenuOrPopoverOpen = false
            popoverCount = 0
        }
        isAppearancePreviewActive = false
        stopExpandedWatchdog()
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        appearancePreviewWorkItem?.cancel()
        appearancePreviewWorkItem = nil
        idleDimWorkItem?.cancel()
        idleDimWorkItem = nil
        isIdleDimmed = false
        
        guard force || (!isLockedOpen && !isFileDraggingActive && !isMenuOrPopoverOpen) else { return }
        if isHovered { isHovered = false }
        withAnimation(transitionAnimation) {
            self.state = .collapsed
        }
        panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
    }
    
    public func toggleLock() {
        isLockedOpen.toggle()
        if isLockedOpen {
            stopExpandedWatchdog()
            withAnimation(transitionAnimation) {
                state = .expanded
            }
            panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.activeModule?.start()
            MirrorModule.shared.resumeIfViewed()
        } else if !isHovered {
            stopExpandedWatchdog()
            withAnimation(transitionAnimation) {
                state = .collapsed
            }
            panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
        } else {
            panel?.updateFrame(for: .expanded, animated: false)
            startExpandedWatchdog()
        }
    }
}
