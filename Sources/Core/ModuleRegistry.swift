import SwiftUI
import Combine

@MainActor
public final class ModuleRegistry: ObservableObject {
    public static let shared = ModuleRegistry()
    
    @Published public private(set) var modules: [any NotchModule] = []
    @Published public var moduleOrder: [String] = []
    
    // Hoverful & Pinning State Machine (nil = Home Dashboard)
    @Published public var hoveredModuleId: String? = nil
    @Published public var pinnedModuleId: String? = nil
    private var suppressedHoverId: String? = nil
    private var tabHoverWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    
    private let orderStorageKey = "NotchApp_ModuleOrder"
    
    private init() {
        if let savedOrder = UserDefaults.standard.stringArray(forKey: orderStorageKey) {
            // Filter out 'nowPlaying' or 'calendar' from header tabs if previously saved
            self.moduleOrder = savedOrder.filter { $0 != "nowPlaying" && $0 != "home" }
        }
        
        SettingsStore.shared.$enabledModules
            .receive(on: RunLoop.main)
            .sink { [weak self] enabledDict in
                guard let self = self else { return }
                for m in self.modules {
                    m.isEnabled = enabledDict[m.id] ?? true
                }
                if let pinned = self.pinnedModuleId, pinned != "dashboard" && !(enabledDict[pinned] ?? true) {
                    self.pinnedModuleId = nil
                }
                if let hovered = self.hoveredModuleId, !(enabledDict[hovered] ?? true) {
                    self.hoveredModuleId = nil
                }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    public func register(_ module: any NotchModule) {
        // Exclude nowPlaying from header tabs (nowPlaying lives permanently in Home Dashboard)
        guard module.id != "nowPlaying" else { return }

        module.isEnabled = SettingsStore.shared.isModuleEnabled(module.id)
        
        if !modules.contains(where: { $0.id == module.id }) {
            modules.append(module)
            if !moduleOrder.contains(module.id) {
                moduleOrder.append(module.id)
                persistOrder()
            }
        }
    }
    
    public var orderedModules: [any NotchModule] {
        var result: [any NotchModule] = []
        for id in moduleOrder {
            if let m = modules.first(where: { $0.id == id && $0.isEnabled }) {
                result.append(m)
            }
        }
        for m in modules {
            if m.isEnabled && !result.contains(where: { $0.id == m.id }) {
                result.append(m)
            }
        }
        return result
    }
    
    // Active Module ID: nil means HOME DASHBOARD!
    public var activeModuleId: String? {
        if pinnedModuleId == "dashboard" {
            return nil
        }
        if let pinned = pinnedModuleId, isModuleValidAndEnabled(pinned) {
            return pinned
        }
        if let hovered = hoveredModuleId, isModuleValidAndEnabled(hovered) {
            return hovered
        }
        // Default is nil -> HOME DASHBOARD!
        return nil
    }
    
    public var isDashboardPinned: Bool {
        return pinnedModuleId == "dashboard"
    }
    
    public var activeModule: (any NotchModule)? {
        guard let currentId = activeModuleId else { return nil }
        return modules.first(where: { $0.id == currentId && $0.isEnabled })
    }
    
    public func module(for id: String) -> (any NotchModule)? {
        return modules.first(where: { $0.id == id })
    }
    
    private func isModuleValidAndEnabled(_ id: String) -> Bool {
        guard let mod = modules.first(where: { $0.id == id }) else { return false }
        return mod.isEnabled
    }
    
    // Hover action: When mouse enters a tab, preview it after a smooth dwell
    public func onTabHover(_ id: String?) {
        guard let id = id else {
            // Hovering over Dashboard home tab (id == nil)
            onDashboardHover()
            return
        }
        
        // If a module or Dashboard is pinned, hovering over other tabs must NOT switch the view
        guard pinnedModuleId == nil else { return }
        
        if id == suppressedHoverId {
            return
        }
        suppressedHoverId = nil
        
        cancelPendingTabHover()
        guard hoveredModuleId != id else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.activateHoveredModule(id)
        }
        tabHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
    
    // Hover over Dashboard home tab: smoothly previews the Home Dashboard
    public func onDashboardHover() {
        cancelPendingTabHover()
        guard hoveredModuleId != nil || activeModuleId != nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.pinnedModuleId == nil {
                self.hoverToHome()
            }
        }
        tabHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }
    
    public func hoverToHome() {
        if let currentId = activeModuleId {
            modules.first(where: { $0.id == currentId })?.stop()
        }
        hoveredModuleId = nil
        suppressedHoverId = nil
        FeedbackManager.playHover()
    }

    private func activateHoveredModule(_ id: String) {
        tabHoverWorkItem = nil
        guard hoveredModuleId != id else { return }
        let previousActive = activeModuleId
        hoveredModuleId = id
        
        if pinnedModuleId == nil && previousActive != id {
            FeedbackManager.playHover()
            if let prev = previousActive {
                modules.first(where: { $0.id == prev })?.stop()
            }
            modules.first(where: { $0.id == id })?.start()
        }
    }
    
    // Explicit Select / Pin Module
    public func selectModule(_ id: String) {
        cancelPendingTabHover()
        let prevId = activeModuleId
        pinnedModuleId = id
        hoveredModuleId = id
        suppressedHoverId = nil
        FeedbackManager.playPin()
        
        if prevId != id {
            if let prev = prevId {
                modules.first(where: { $0.id == prev })?.stop()
            }
            activeModule?.start()
        }
    }
    
    // Click action: Toggle Pin / Return to Home
    public func toggleDashboardPin() {
        cancelPendingTabHover()
        let prevId = activeModuleId
        
        if isDashboardPinned {
            // Already pinned: unpin dashboard!
            pinnedModuleId = nil
            hoveredModuleId = nil
            suppressedHoverId = "dashboard"
            FeedbackManager.playPin()
        } else {
            // Pin the Home Dashboard!
            pinnedModuleId = "dashboard"
            hoveredModuleId = nil
            suppressedHoverId = nil
            FeedbackManager.playPin()
        }
        
        if let prev = prevId {
            modules.first(where: { $0.id == prev })?.stop()
        }
    }
    
    public func togglePin(_ id: String) {
        cancelPendingTabHover()
        let prevId = activeModuleId
        
        if pinnedModuleId == id {
            // Already pinned: unpin and return directly to Home Dashboard!
            pinnedModuleId = nil
            hoveredModuleId = nil
            suppressedHoverId = id
            FeedbackManager.playPin()
        } else {
            // Pin this secondary module
            pinnedModuleId = id
            hoveredModuleId = id
            suppressedHoverId = nil
            FeedbackManager.playPin()
        }
        
        if prevId != activeModuleId {
            if let prev = prevId {
                modules.first(where: { $0.id == prev })?.stop()
            }
            activeModule?.start()
        }
    }
    
    public func returnToHome() {
        cancelPendingTabHover()
        activeModule?.stop()
        pinnedModuleId = nil
        hoveredModuleId = nil
        suppressedHoverId = nil
        FeedbackManager.playClick()
    }

    public func selectFileDropTarget(for id: String = "shelf") {
        guard isModuleValidAndEnabled(id) else { return }
        cancelPendingTabHover()
        let previous = activeModuleId
        pinnedModuleId = id
        hoveredModuleId = id
        if previous != id {
            if let previous { modules.first(where: { $0.id == previous })?.stop() }
            activeModule?.start()
            FeedbackManager.playHover()
        }
    }

    public func cancelFileDropTarget() {
        guard !NotchShellCoordinator.shared.isFileDraggingActive else { return }
        guard NotchShellCoordinator.shared.state == .collapsed else { return }
        guard pinnedModuleId == "shelf" else { return }
        modules.first(where: { $0.id == "shelf" })?.stop()
        pinnedModuleId = nil
        hoveredModuleId = nil
    }
    
    // Drag & Drop Reordering
    public func moveModule(from sourceId: String, to targetId: String) {
        guard sourceId != targetId,
              let sourceIdx = moduleOrder.firstIndex(of: sourceId),
              let targetIdx = moduleOrder.firstIndex(of: targetId) else { return }
        
        withAnimation(DesignSystem.reduceMotion ? nil : .spring(response: DesignSystem.springResponse, dampingFraction: DesignSystem.springDamping)) {
            moduleOrder.remove(at: sourceIdx)
            moduleOrder.insert(sourceId, at: targetIdx)
            persistOrder()
            FeedbackManager.playHover()
        }
    }
    
    public func moveModuleToFirst(_ id: String) {
        guard let idx = moduleOrder.firstIndex(of: id), idx > 0 else { return }
        withAnimation(DesignSystem.reduceMotion ? nil : .spring(response: DesignSystem.springResponse, dampingFraction: DesignSystem.springDamping)) {
            let item = moduleOrder.remove(at: idx)
            moduleOrder.insert(item, at: 0)
            persistOrder()
            FeedbackManager.playClick()
        }
    }
    
    public func moveModuleToLast(_ id: String) {
        guard let idx = moduleOrder.firstIndex(of: id), idx < moduleOrder.count - 1 else { return }
        withAnimation(DesignSystem.reduceMotion ? nil : .spring(response: DesignSystem.springResponse, dampingFraction: DesignSystem.springDamping)) {
            let item = moduleOrder.remove(at: idx)
            moduleOrder.append(item)
            persistOrder()
            FeedbackManager.playClick()
        }
    }
    
    private func persistOrder() {
        UserDefaults.standard.set(moduleOrder, forKey: orderStorageKey)
    }

    private func cancelPendingTabHover() {
        tabHoverWorkItem?.cancel()
        tabHoverWorkItem = nil
    }
    
    public func stopAll() {
        cancelPendingTabHover()
        for m in modules {
            m.stop()
        }
        hoveredModuleId = nil
        pinnedModuleId = nil
        suppressedHoverId = nil
    }
}
