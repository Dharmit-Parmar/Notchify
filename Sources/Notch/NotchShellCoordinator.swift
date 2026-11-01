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
    
    /// Provides visual feedback when appearance settings change by smoothly opening and closing the notch
    public func triggerAppearancePropagationPreview() {
        guard !isFileDraggingActive else { return }
        appearancePreviewWorkItem?.cancel()
        
        if state != .expanded {
            withAnimation(transitionAnimation) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
        }
        
        FeedbackManager.playHover()
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isLockedOpen && !self.isHovered && !self.isFileDraggingActive {
                withAnimation(self.transitionAnimation) {
                    self.state = .collapsed
                }
                self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
            }
        }
        appearancePreviewWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: item)
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
                    if !self.isHovered || self.collapseWorkItem != nil {
                        self.onMouseEnter()
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
        
        // While settings is active, stay gracefully in compact notch state to avoid obscuring the settings panel,
        // unless the user specifically opted into keepOpenWhileSettingsActive
        if AppDelegate.isSettingsOpen && !SettingsStore.shared.keepOpenWhileSettingsActive {
            return
        }
        guard state != .expanded, hoverWorkItem == nil else { return }
        
        let delay = SettingsStore.shared.hoverDelay
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isHovered else { return }
            if AppDelegate.isSettingsOpen && !SettingsStore.shared.keepOpenWhileSettingsActive { return }
            withAnimation(self.transitionAnimation) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            NowPlayingModule.shared.refreshMediaState()
            ModuleRegistry.shared.activeModule?.start()
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
            let effectiveBounds = (state == .expanded) ? panel.frame.union(expandedRect) : panel.frame
            if effectiveBounds.contains(mouseLoc) {
                // The cursor is physically still inside the notch window!
                // Spurious exit event from subview transition; ignore completely.
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
                let effectiveBounds = (self.state == .expanded) ? panel.frame.union(expandedRect) : panel.frame
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
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + SettingsStore.shared.autoCollapseDelay, execute: item)
    }
    
    public func collapseImmediately(force: Bool = false) {
        if force {
            isLockedOpen = false
            isFileDraggingActive = false
        }
        stopExpandedWatchdog()
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        guard force || (!isLockedOpen && !isFileDraggingActive) else { return }
        if isHovered { isHovered = false }
        withAnimation(transitionAnimation) {
            self.state = .collapsed
        }
        panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
        ModuleRegistry.shared.stopAll()
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
