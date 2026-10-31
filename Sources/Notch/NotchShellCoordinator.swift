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
    
    public func onFileDragEntered() {
        isFileDraggingActive = true
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        
        if state != .expanded {
            withAnimation(DesignSystem.reduceMotion ? nil : .easeOut(duration: DesignSystem.notchTransitionDuration)) {
                self.state = .expanded
            }
            self.panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
        }
        ModuleRegistry.shared.selectFileDropTarget()
    }
    
    public func onFileDragExited() {
        isFileDraggingActive = false
        if !isHovered && !isLockedOpen {
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isFileDraggingActive else { return }
                withAnimation(DesignSystem.reduceMotion ? nil : .easeOut(duration: DesignSystem.notchTransitionDuration)) {
                    self.state = .collapsed
                }
                self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
                ModuleRegistry.shared.stopAll()
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.defaultHoverCollapseDelay, execute: item)
        }
    }
    
    public func onMouseEnter() {
        guard !isHovered else { return }
        isHovered = true
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        guard state != .expanded, hoverWorkItem == nil else { return }
        
        let delay = SettingsStore.shared.hoverDelay
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            withAnimation(DesignSystem.reduceMotion ? nil : .easeOut(duration: DesignSystem.notchTransitionDuration)) {
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
        if isHovered { isHovered = false }
        
        guard !isLockedOpen, !isFileDraggingActive, state != .collapsed else { return }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isFileDraggingActive else { return }
            withAnimation(DesignSystem.reduceMotion ? nil : .easeOut(duration: DesignSystem.notchTransitionDuration)) {
                self.state = .collapsed
            }
            self.panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.stopAll()
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.defaultHoverCollapseDelay, execute: item)
    }
    
    public func collapseImmediately() {
        guard !isFileDraggingActive else { return }
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        guard !isLockedOpen else { return }
        if isHovered { isHovered = false }
        withAnimation(DesignSystem.reduceMotion ? nil : .easeOut(duration: DesignSystem.notchTransitionDuration)) {
            self.state = .collapsed
        }
        panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
        ModuleRegistry.shared.stopAll()
    }
    
    public func toggleLock() {
        isLockedOpen.toggle()
        if isLockedOpen {
            withAnimation(DesignSystem.reduceMotion ? nil : .easeOut(duration: DesignSystem.notchTransitionDuration)) {
                state = .expanded
            }
            panel?.updateFrame(for: .expanded, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.activeModule?.start()
        } else if !isHovered {
            withAnimation(DesignSystem.reduceMotion ? nil : .easeOut(duration: DesignSystem.notchTransitionDuration)) {
                state = .collapsed
            }
            panel?.updateFrame(for: .collapsed, animated: !DesignSystem.reduceMotion)
            ModuleRegistry.shared.stopAll()
        } else {
            panel?.updateFrame(for: .expanded, animated: false)
        }
    }
}
