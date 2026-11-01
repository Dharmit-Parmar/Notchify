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
            }
        }
    }
    @Published public var isHovered: Bool = false
    @Published public var isLockedOpen: Bool = false
    @Published public var isFileDragTargeted = false
    @Published public var isFileDraggingActive = false
    public var fileDropWasAccepted = false
    @Published public var geometry: NotchGeometry = NotchGeometry.current()
    
    public weak var panel: NotchPanel?
    
    private var hoverWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var expandedWatchdog: Timer?
    
    private init() {
        NotificationCenter.default.addObserver(
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
        if DesignSystem.reduceMotion { return nil }
        let duration = SettingsStore.shared.motionPhysics.response
        return .easeOut(duration: duration)
    }
    
    private var appearancePreviewWorkItem: DispatchWorkItem?
    public private(set) var isAppearancePreviewActive: Bool = false
    
    /// Provides visual feedback when appearance settings change by smoothly opening and closing the notch
    public func triggerAppearancePropagationPreview() {
        guard !isFileDraggingActive else { return }
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
            self.isHovered = false
            guard !self.isLockedOpen && !self.isFileDraggingActive else { return }
            self.stopExpandedWatchdog()
            withAnimation(self.transitionAnimation) {
                self.state = .collapsed
            }
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
            guard !self.isHovered && !self.isLockedOpen && !self.isFileDraggingActive else { return }
            self.stopExpandedWatchdog()
            withAnimation(self.transitionAnimation) {
                self.state = .collapsed
            }
            self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
            if ThockModule.shared.isRunning {
                ThockModule.shared.stopEngine()
            }
        }
        appearancePreviewWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }
    
    private func startExpandedWatchdog() {
        stopExpandedWatchdog()
        guard state == .expanded, !isLockedOpen else { return }
        
        // 0.15s interval: highly responsive to cursor without thrashing CPU
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                guard self.state == .expanded, !self.isLockedOpen, !self.isFileDraggingActive else {
                    self.stopExpandedWatchdog()
                    return
                }
                guard let panel = self.panel else { return }
                let mouseLoc = NSEvent.mouseLocation
                let expandedRect = NotchPanel.calculateFrame(
                    for: .expanded,
                    store: SettingsStore.shared,
                    screen: panel.currentScreen
                )
                let effectiveBounds = panel.frame.union(expandedRect)
                let containsMouse = effectiveBounds.contains(mouseLoc)
                
                if !containsMouse {
                    if self.isHovered || self.collapseWorkItem == nil {
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
        }
        if ModuleRegistry.shared.activeModuleId == nil {
            ModuleRegistry.shared.selectFileDropTarget()
        }
    }
    
    public func onFileDragExited() {
        isFileDraggingActive = false
        if !isHovered && !isLockedOpen {
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isFileDraggingActive else { return }
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
                guard let self = self, !self.isHovered, !self.isLockedOpen else { return }
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
        
        let delay = max(0.02, min(0.08, SettingsStore.shared.hoverDelay))
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isHovered else { return }
            self.hoverWorkItem = nil
            withAnimation(self.transitionAnimation) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            NowPlayingModule.shared.refreshMediaState()
            ModuleRegistry.shared.activeModule?.start()
            if self.expandedWatchdog == nil && !self.isLockedOpen {
                self.startExpandedWatchdog()
            }
        }
        hoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    public func onMouseExit() {
        if let panel = self.panel {
            let mouseLoc = NSEvent.mouseLocation
            let expandedRect = NotchPanel.calculateFrame(
                for: .expanded,
                store: SettingsStore.shared,
                screen: panel.currentScreen
            )
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
        
        guard !isLockedOpen, !isFileDraggingActive, state != .collapsed else { return }
        
        if collapseWorkItem != nil { return }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.collapseWorkItem = nil
            if let panel = self.panel {
                let mouseLoc = NSEvent.mouseLocation
                let expandedRect = NotchPanel.calculateFrame(
                    for: .expanded,
                    store: SettingsStore.shared,
                    screen: panel.currentScreen
                )
                let effectiveBounds = (self.state == .expanded)
                    ? panel.frame.union(expandedRect).insetBy(dx: -24, dy: -14)
                    : panel.frame.insetBy(dx: -20, dy: -10)
                if effectiveBounds.contains(mouseLoc) {
                    self.isHovered = true
                    return
                }
            }
            guard !self.isHovered, !self.isLockedOpen, !self.isFileDraggingActive else { return }
            
            self.stopExpandedWatchdog()
            withAnimation(self.transitionAnimation) {
                self.state = .collapsed
            }
            self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.stopAll()
            if ThockModule.shared.isRunning {
                ThockModule.shared.stopEngine()
            }
        }
        collapseWorkItem = item
        let collapseDelay = AppDelegate.isSettingsOpen ? 0.30 : SettingsStore.shared.autoCollapseDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.25, collapseDelay), execute: item)
    }
    
    public func collapseImmediately(force: Bool = false) {
        if force {
            isLockedOpen = false
            isFileDraggingActive = false
        }
        isAppearancePreviewActive = false
        stopExpandedWatchdog()
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        appearancePreviewWorkItem?.cancel()
        appearancePreviewWorkItem = nil
        
        guard force || (!isLockedOpen && !isFileDraggingActive) else { return }
        if isHovered { isHovered = false }
        withAnimation(transitionAnimation) {
            self.state = .collapsed
        }
        panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
        ModuleRegistry.shared.stopAll()
        if ThockModule.shared.isRunning {
            ThockModule.shared.stopEngine()
        }
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
        } else if !isHovered {
            stopExpandedWatchdog()
            withAnimation(transitionAnimation) {
                state = .collapsed
            }
            panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.stopAll()
        } else {
            panel?.updateFrame(for: .expanded, animated: false)
            startExpandedWatchdog()
        }
    }
}
