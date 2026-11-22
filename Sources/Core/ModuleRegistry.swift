import SwiftUI
import Combine

@MainActor
public final class ModuleRegistry: ObservableObject {
    public static let shared = ModuleRegistry()
    
    @Published public private(set) var modules: [any NotchModule] = []
    @Published public var moduleOrder: [String] = []
    
    // Hoverful & Pinning State Machine (nil = Home Dashboard)
    @Published public var hoveredModuleId: String? = nil {
        didSet {
            guard hoveredModuleId != oldValue else { return }
            NotchShellCoordinator.shared.onActiveModuleChanged()
        }
    }
    @Published public var pinnedModuleId: String? = nil {
        didSet {
            guard pinnedModuleId != oldValue else { return }
            NotchShellCoordinator.shared.onActiveModuleChanged()
        }
    }
    
    // Intelligent Hover Intent & Accidental Activation Suppression
    private var suppressedHoverId: String? = nil
    private var isExpansionInProgress: Bool = false
    private var tabHoverWorkItem: DispatchWorkItem?
    private var pendingHoverTarget: String? = nil
    private var expansionCooldownWorkItem: DispatchWorkItem?
    private let tabHoverDwellDelay: TimeInterval = 0.28 // 280ms dwell delay
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
                    let wasEnabled = m.isEnabled
                    let isNowEnabled = enabledDict[m.id] ?? true
                    m.isEnabled = isNowEnabled
                    if wasEnabled && !isNowEnabled {
                        m.stop()
                    }
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
    
    public func registerLazy(
        id: String,
        title: String,
        iconName: String,
        themeColor: Color,
        factory: @escaping @MainActor () -> any NotchModule
    ) {
        let lazyModule = LazyNotchModule(
            id: id,
            title: title,
            iconName: iconName,
            themeColor: themeColor,
            factory: factory
        )
        register(lazyModule)
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
    
    public var allOrderedModules: [any NotchModule] {
        var result: [any NotchModule] = []
        for id in moduleOrder {
            if let m = modules.first(where: { $0.id == id }) {
                result.append(m)
            }
        }
        for m in modules {
            if !result.contains(where: { $0.id == m.id }) {
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
    
    // Notch Expansion Lifecycle: Ensures Dashboard is active and suppresses accidental hover on the tab under the cursor
    public func onNotchExpanding() {
        cancelPendingTabHover()
        expansionCooldownWorkItem?.cancel()
        
        // Preserve Dashboard as default on expansion unless explicitly pinned to a module
        if pinnedModuleId == nil {
            if hoveredModuleId != nil {
                modules.first(where: { $0.id == hoveredModuleId })?.stop()
                hoveredModuleId = nil
            }
        }
        
        isExpansionInProgress = true
        
        // Expansion cooldown window matching notch spring animation (~0.35s - 0.40s)
        let cooldownItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isExpansionInProgress = false
            self.expansionCooldownWorkItem = nil
        }
        expansionCooldownWorkItem = cooldownItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: cooldownItem)
    }

    // Hover action: When mouse enters a tab, preview it after an intentional dwell delay
    public func onTabHover(_ id: String?) {
        guard let id = id else {
            // Hovering over Dashboard home tab (id == nil)
            onDashboardHover()
            return
        }
        
        // If a module or Dashboard is pinned, hovering over other tabs must NOT switch the view
        guard pinnedModuleId == nil else { return }
        
        // If the notch is currently expanding, record the tab underneath the pointer and suppress auto-activation
        if isExpansionInProgress {
            suppressedHoverId = id
            cancelPendingTabHover()
            return
        }
        
        // If this tab was already underneath the pointer on expansion and hasn't been exited yet, keep it suppressed
        if id == suppressedHoverId {
            return
        }
        
        // Cancel any pending activation from a previously hovered tab
        cancelPendingTabHover()
        guard hoveredModuleId != id else { return }
        
        pendingHoverTarget = id
        // 250-300ms continuous hover dwell delay before activating module
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.suppressedHoverId != id, !self.isExpansionInProgress else { return }
            self.activateHoveredModule(id)
        }
        tabHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + tabHoverDwellDelay, execute: workItem)
    }
    
    // Hover exit: Cancel pending activation only if the exiting tab is the pending target
    public func onTabHoverExit(_ id: String) {
        if pendingHoverTarget == id {
            cancelPendingTabHover()
        }
        
        // Once pointer exits the tab hit area, clear suppression so intentional re-entry activates normally
        if suppressedHoverId == id {
            suppressedHoverId = nil
        }
    }
    
    // Hover over Dashboard home tab: smoothly previews the Home Dashboard after dwell delay
    public func onDashboardHover() {
        cancelPendingTabHover()
        guard pinnedModuleId == nil else { return }
        guard hoveredModuleId != nil || activeModuleId != nil else { return }
        
        pendingHoverTarget = "dashboard"
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.pinnedModuleId == nil {
                self.hoverToHome()
            }
        }
        tabHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + tabHoverDwellDelay, execute: workItem)
    }
    
    public func onDashboardHoverExit() {
        if pendingHoverTarget == "dashboard" {
            cancelPendingTabHover()
        }
    }
    
    public func onNavBarHoverExit() {
        cancelPendingTabHover()
    }
    
    public func clearSuppression() {
        suppressedHoverId = nil
        isExpansionInProgress = false
        expansionCooldownWorkItem?.cancel()
        expansionCooldownWorkItem = nil
        cancelPendingTabHover()
    }
    
    public func hoverToHome() {
        tabHoverWorkItem = nil
        pendingHoverTarget = nil
        if let currentId = activeModuleId {
            modules.first(where: { $0.id == currentId })?.stop()
        }
        hoveredModuleId = nil
        suppressedHoverId = nil
        FeedbackManager.playHover()
    }

    private func activateHoveredModule(_ id: String) {
        tabHoverWorkItem = nil
        pendingHoverTarget = nil
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
        clearSuppression()
        let prevId = activeModuleId
        pinnedModuleId = id
        hoveredModuleId = id
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
        clearSuppression()
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
            FeedbackManager.playPin()
        }
        
        if let prev = prevId {
            modules.first(where: { $0.id == prev })?.stop()
        }
    }
    
    public func togglePin(_ id: String) {
        clearSuppression()
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
        clearSuppression()
        activeModule?.stop()
        pinnedModuleId = nil
        hoveredModuleId = nil
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

    public func cancelPendingTabHover() {
        tabHoverWorkItem?.cancel()
        tabHoverWorkItem = nil
        pendingHoverTarget = nil
    }
    
    /// Returns the loaded module instance ONLY if it has already been instantiated.
    /// Does NOT trigger the factory for uninstantiated lazy modules.
    public func loadedModule<T>(for id: String, as type: T.Type = T.self) -> T? {
        guard let m = modules.first(where: { $0.id == id }) else { return nil }
        if let lazy = m as? LazyNotchModule {
            return lazy.loadedInstance as? T
        }
        return m as? T
    }
    
    public func stopAll() {
        clearSuppression()
        for m in modules {
            m.stop()
        }
        hoveredModuleId = nil
        pinnedModuleId = nil
    }
    
    public func unloadInactiveModules() {
        let isCollapsed = NotchShellCoordinator.shared.state == .collapsed
        let activeId = activeModuleId
        for m in modules {
            if let lazy = m as? LazyNotchModule {
                if isCollapsed || lazy.id != activeId {
                    lazy.unload()
                }
            }
        }
    }
}

// MARK: - Lazy Module Wrapper for Zero-Startup Overhead
@MainActor
public final class LazyNotchModule: NotchModule, ObservableObject {
    public let id: String
    public let title: String
    public let iconName: String
    public let themeColor: Color
    public var isEnabled: Bool {
        get { _instance?.isEnabled ?? _isEnabled }
        set {
            _isEnabled = newValue
            _instance?.isEnabled = newValue
        }
    }
    private var _isEnabled: Bool = true
    private let factory: @MainActor () -> any NotchModule
    private var _instance: (any NotchModule)? = nil
    
    public init(
        id: String,
        title: String,
        iconName: String,
        themeColor: Color,
        factory: @escaping @MainActor () -> any NotchModule
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.themeColor = themeColor
        self.factory = factory
    }
    
    public var isLoaded: Bool {
        return _instance != nil
    }
    
    public var loadedInstance: (any NotchModule)? {
        return _instance
    }
    
    public func resolve() -> any NotchModule {
        if let inst = _instance { return inst }
        let inst = factory()
        inst.isEnabled = self._isEnabled
        _instance = inst
        return inst
    }
    
    public func unload() {
        // Suspend module hardware/timers on collapse without discarding instance state (P1-APP-1)
        _instance?.stop()
    }
    
    public func start() {
        resolve().start()
    }
    
    public func stop() {
        _instance?.stop()
    }
    
    public func makeCompactView() -> AnyView {
        resolve().makeCompactView()
    }
    
    public func makeExpandedView() -> AnyView {
        resolve().makeExpandedView()
    }
}
