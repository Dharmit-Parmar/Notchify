import SwiftUI
import Combine

public enum NotchState {
    case collapsed
    case expanded
}

@MainActor
public final class NotchShellCoordinator: ObservableObject {
    public static let shared = NotchShellCoordinator()
    
    @Published public var state: NotchState = .collapsed
    @Published public var isHovered: Bool = false
    @Published public var isLockedOpen: Bool = false
    @Published public var isFileDragTargeted = false
    @Published public var isFileDraggingActive = false
    public var fileDropWasAccepted = false
    @Published public var geometry: NotchGeometry = NotchGeometry.current()
    
    public weak var panel: NotchPanel?
    
    private var hoverWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    
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
    
    private var transitionAnimation: Animation? {
        if DesignSystem.reduceMotion { return nil }
        return .spring(
            response: DesignSystem.springResponse,
            dampingFraction: DesignSystem.springDamping
        )
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
                withAnimation(self.transitionAnimation) {
                    self.state = .collapsed
                }
                self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
                ModuleRegistry.shared.stopAll()
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.defaultHoverCollapseDelay, execute: item)
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
        if state == .expanded && isHovered {
            if collapseWorkItem != nil {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
            }
            return
        }
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        isHovered = true
        
        guard state != .expanded, hoverWorkItem == nil else { return }
        
        let delay = SettingsStore.shared.hoverDelay
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isHovered else { return }
            withAnimation(self.transitionAnimation) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.activeModule?.start()
        }
        hoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    public func onMouseExit() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        isHovered = false
        
        guard !isLockedOpen, !isFileDraggingActive, state != .collapsed else { return }
        if AppDelegate.isSettingsOpen && SettingsStore.shared.keepOpenWhileSettingsActive {
            return
        }
        
        collapseWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if AppDelegate.isSettingsOpen && SettingsStore.shared.keepOpenWhileSettingsActive {
                return
            }
            if let panel = self.panel, panel.frame.contains(NSEvent.mouseLocation) {
                self.isHovered = true
                return
            }
            guard !self.isHovered, !self.isLockedOpen, !self.isFileDraggingActive else { return }
            
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
            withAnimation(transitionAnimation) {
                state = .expanded
            }
            panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.activeModule?.start()
        } else if !isHovered {
            withAnimation(transitionAnimation) {
                state = .collapsed
            }
            panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.stopAll()
        } else {
            panel?.updateFrame(for: .expanded, animated: false)
        }
    }
}
