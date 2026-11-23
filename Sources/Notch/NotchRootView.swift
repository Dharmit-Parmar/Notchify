import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct NotchRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var coordinator = NotchShellCoordinator.shared
    @ObservedObject var registry = ModuleRegistry.shared
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var themeEngine = DynamicThemeEngine.shared
    @ObservedObject private var airDropModule = AirDropModule.shared
    @ObservedObject private var quickControls = QuickControlsManager.shared
    
    public init() {}
    
    private var isExpanded: Bool {
        coordinator.state == .expanded
    }
    
    private var currentTopRadius: CGFloat {
        if isExpanded {
            return store.cornerStyle.topRadius
        } else {
            // Hardware notch top edge is flush with screen bezel (0 radius); non-notch display is a rounded pill (10 radius)
            return coordinator.geometry.hasPhysicalNotch ? 0 : 10
        }
    }
    
    private var currentBottomRadius: CGFloat {
        if isExpanded {
            return store.cornerStyle.bottomRadius
        } else {
            return 14
        }
    }
    
    private var currentAccentColor: Color {
        if store.usePerModuleAccent, let activeId = registry.activeModuleId {
            return DesignSystem.moduleAccentColor(for: activeId)
        }
        return DesignSystem.accentColor
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Clean Liquid Retina Glass: No drop shadow, deep continuous squircle radii
            NotchGlassBackground(
                topRadius: currentTopRadius,
                bottomRadius: currentBottomRadius,
                showsMaterial: isExpanded
            )
            
            VStack(spacing: 0) {
                if !isExpanded {
                    CompactNotchIndicator(height: store.hoverTriggerHeight)
                        .transition(.opacity)
                } else {
                    let expandedSize = coordinator.currentExpandedLayout.windowRect.size
                    VStack(spacing: 0) {
                        // Camera Clear Zone: Leaves notchInset clear on hardware notch; compact on non-notch or belowMenuBar
                        Spacer()
                            .frame(height: coordinator.currentExpandedLayout.contentTopPadding)
                        
                        // Persistent Navigation Dock (Reorderable Tabs, Edge Auto-Scroll, Close Button)
                        expandedHeaderTabs
                            .padding(.horizontal, store.contentHorizontalPadding)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                        
                        // Dynamic Specular Divider
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        currentAccentColor.opacity(0.35),
                                        currentAccentColor.opacity(0.10),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, store.contentHorizontalPadding)
                            .padding(.bottom, 10)
                        
                        // Body: Home Dashboard (by default) OR Selected Secondary Module
                        // The Home Dashboard must NEVER be wrapped in an outer vertical ScrollView so widgets remain stable and never scroll off-screen.
                        ResponsiveTabContent(enablesVerticalScrollFallback: registry.activeModuleId != nil && !moduleHasInternalVerticalScroll) { availableH in
                            contentArea(availableHeight: availableH)
                        }
                        .padding(.horizontal, store.contentHorizontalPadding)
                        .padding(.bottom, store.contentVerticalPadding)
                        .frame(maxHeight: .infinity, alignment: .top)
                            .overlay(
                                // Zero-allocation composited dimming overlay avoiding CoreAnimation offscreen group render pass
                                Color.black
                                    .opacity(coordinator.isIdleDimmed ? 0.12 : 0.0)
                                    .allowsHitTesting(false)
                                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coordinator.isIdleDimmed)
                            )
                        
                        // Shared Global Quick Controls Panel (Rendered beneath whichever module is active)
                        if store.showQuickControls && quickControls.state.isPanelVisible {
                            QuickControlsSectionView()
                                .padding(.horizontal, store.contentHorizontalPadding)
                                .padding(.bottom, 6)
                                .transition(
                                    reduceMotion
                                    ? .opacity
                                    : .asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity.combined(with: .move(edge: .top))
                                    )
                                )
                        }
                    }
                    .frame(width: expandedSize.width, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: currentTopRadius,
                    bottomLeading: currentBottomRadius,
                    bottomTrailing: currentBottomRadius,
                    topTrailing: currentTopRadius
                ),
                style: .continuous
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: store.currentTheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: themeEngine.canvasColor)
        .onContinuousHover { _ in
            if isExpanded {
                coordinator.resetIdleTimer()
            }
        }
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .image, .text, .plainText, .utf8PlainText, .item, .data, .content], isTargeted: $coordinator.isFileDragTargeted) { providers in
            coordinator.fileDropWasAccepted = true
            URLCollector.extractURLs(from: providers) { urls in
                guard !urls.isEmpty else { return }
                if registry.activeModuleId == "airdrop" {
                    AirDropModule.shared.shareFiles(urls)
                } else if registry.activeModuleId == "localshare" {
                    LocalShareModule.shared.startSending(files: urls)
                } else {
                    for u in urls {
                        ShelfModule.shared.addItem(u)
                    }
                }
                coordinator.onFileDropFinished()
            }
            return !providers.isEmpty
        }
        .onChange(of: coordinator.isFileDragTargeted) { _, targeted in
            if targeted {
                coordinator.fileDropWasAccepted = false
                coordinator.onFileDragEntered()
            } else if !coordinator.fileDropWasAccepted {
                // Debounce exit check to prevent flicker between child views
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if !coordinator.isFileDragTargeted && !coordinator.fileDropWasAccepted {
                        coordinator.onFileDragExited()
                        registry.cancelFileDropTarget()
                    }
                }
            }
        }
    }
    
    // Persistent Navigation Dock with Reorderable Tabs & Edge Auto-Scroll
    private var expandedHeaderTabs: some View {
        HStack(spacing: 8) {
            // Dashboard Home Tab Button (Locked at Far Left)
            let isDashboardActive = (registry.activeModuleId == nil)
            let isDashboardPinned = registry.isDashboardPinned
            Button(action: {
                registry.clearSuppression()
                registry.toggleDashboardPin()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isDashboardActive ? DesignSystem.accentColor : Color.white.opacity(0.8))
                    
                    Text("Dashboard")
                        .font(.system(size: 11, weight: isDashboardActive ? .bold : .medium, design: .rounded))
                        .foregroundColor(isDashboardActive ? .white : DesignSystem.secondaryText)
                    
                    if isDashboardPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isDashboardActive ? DesignSystem.structureColor : Color.white.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isDashboardActive ? DesignSystem.accentColor.opacity(0.7) : Color.white.opacity(0.08), lineWidth: isDashboardPinned ? 1.4 : (isDashboardActive ? 1.2 : 0.7))
                )
            }
            .buttonStyle(.spring)
            .help("Home Media & Calendar")
            .onHover { hovering in
                if hovering {
                    registry.onDashboardHover()
                } else {
                    registry.onDashboardHoverExit()
                }
            }
            .onDrop(of: [.fileURL, .item, .data, .content], isTargeted: nil) { providers in
                let valid = providers.filter { $0.canLoadObject(ofClass: URL.self) }
                guard !valid.isEmpty else { return false }
                for p in valid {
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async {
                            ShelfModule.shared.addItem(url)
                            registry.selectFileDropTarget(for: "shelf")
                        }
                    }
                }
                NotchShellCoordinator.shared.onFileDropFinished()
                return true
            }
            
            // Specular Vertical Separator
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 1)
            
            // Scrollable & Reorderable Module Dock with Edge Auto-Scroll
            ScrollViewReader { scrollProxy in
                HStack(spacing: 4) {
                    // Scroll Left Edge Arrow
                    Button {
                        if let first = registry.orderedModules.first?.id {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scrollProxy.scrollTo(first, anchor: .leading)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.4))
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scroll tabs left")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(registry.orderedModules.filter { $0.isEnabled }, id: \.id) { module in
                                DraggableTabChip(
                                    module: module,
                                    registry: registry,
                                    scrollProxy: scrollProxy
                                )
                                .id(module.id)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .overlay(
                        HStack(spacing: 0) {
                            LinearGradient(
                                colors: [DesignSystem.canvasColor.opacity(0.85), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 8)
                            
                            Spacer()
                            
                            LinearGradient(
                                colors: [Color.clear, DesignSystem.canvasColor.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 8)
                        }
                        .allowsHitTesting(false)
                    )
                    
                    // Scroll Right Edge Arrow
                    Button {
                        if let last = registry.orderedModules.last?.id {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scrollProxy.scrollTo(last, anchor: .trailing)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.4))
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scroll tabs right")
                }
                .onChange(of: registry.activeModuleId) { _, newId in
                    if let newId = newId {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            scrollProxy.scrollTo(newId, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    if let activeId = registry.activeModuleId {
                        scrollProxy.scrollTo(activeId, anchor: .center)
                    }
                }
            }
            
            Spacer()
            
            // Global Quick Controls Entry Point (Accessible across Dashboard, Thock, Shelf, AirDrop, LocalShare)
            if store.showQuickControls {
                Button(action: {
                    FeedbackManager.playClick()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        if quickControls.state.isPanelVisible {
                            quickControls.state = .closed
                            if store.quickControlsPinned {
                                store.quickControlsPinned = false
                            }
                        } else {
                            quickControls.state = store.quickControlsPinned ? .pinned : .hoverPreview
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(quickControls.state.isPanelVisible ? DesignSystem.accentColor.opacity(0.20) : DesignSystem.structureColor)
                            .frame(width: 24, height: 24)
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10, weight: quickControls.state.isPanelVisible ? .bold : .medium))
                            .foregroundColor(quickControls.state.isPanelVisible ? DesignSystem.accentColor : Color.white.opacity(0.75))
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(quickControls.state.isPanelVisible ? DesignSystem.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.spring)
                .help(quickControls.state.isPanelVisible ? "Close Quick Controls" : "Open Quick Controls (Volume, Brightness, Keyboard)")
                .accessibilityLabel("Quick Controls, currently \(quickControls.state.isPanelVisible ? "Open" : "Closed")")
            }
            
            // Pin / Lock Toggle with Spring Feedback
            Button(action: {
                FeedbackManager.playClick()
                coordinator.toggleLock()
            }) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.structureColor)
                        .frame(width: 24, height: 24)
                    Image(systemName: coordinator.isLockedOpen ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundColor(coordinator.isLockedOpen ? DesignSystem.accentColor : Color.white.opacity(0.4))
                }
            }
            .buttonStyle(.spring)
            .help(coordinator.isLockedOpen ? "Lock Open (Active)" : "Lock Notch Open")
            .accessibilityLabel(coordinator.isLockedOpen ? "Unlock Notch Island" : "Lock Notch Island Open")
            
            // Settings Cog
            Button(action: {
                FeedbackManager.playClick()
                AppDelegate.openSettingsWindow()
            }) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.structureColor)
                        .frame(width: 24, height: 24)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.75))
                }
            }
            .buttonStyle(.spring)
            .help("Open Preferences & Themes")
            .accessibilityLabel("Preferences and Themes")
            
            // Dedicated Close / Collapse Notch Button
            Button(action: {
                FeedbackManager.playClick()
                coordinator.collapseImmediately(force: true)
            }) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.structureColor)
                        .frame(width: 24, height: 24)
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.65))
                }
            }
            .buttonStyle(.spring)
            .help("Collapse Notch (Esc)")
            .accessibilityLabel("Collapse Notch Island")
        }
        .onHover { hovering in
            if !hovering {
                registry.onNavBarHoverExit()
            }
        }
    }
    
    private var moduleHasInternalVerticalScroll: Bool {
        guard let id = registry.activeModuleId else { return false }
        return id == "telegram" || id == "notifications" || id == "notes" || id == "askAI"
    }

    // Content Area: Default Home Landing OR Selected Secondary Module with Breadcrumb Ribbon
    @ViewBuilder
    private func contentArea(availableHeight: CGFloat) -> some View {
        Group {
            if let active = registry.activeModule {
                // Selected Secondary Module View
                VStack(alignment: .leading, spacing: 6) {
                    if store.showBreadcrumbs {
                        // Breadcrumb Ribbon (Situated inside the card, leaving top dock untouched)
                        HStack(spacing: 5) {
                            Button(action: {
                                registry.returnToHome()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "house.fill")
                                        .font(.system(size: 9))
                                    Text("Dashboard")
                                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(Color.white.opacity(0.7))
                            }
                            .buttonStyle(.spring)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.3))
                            
                            HStack(spacing: 4) {
                                Image(systemName: active.iconName)
                                    .font(.system(size: 9))
                                    .foregroundColor(active.themeColor)
                                Text(active.title)
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            if active.id == "shelf" {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.3))
                                
                                Text(ShelfModule.shared.selectedTool.title)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(DesignSystem.accentColor)
                            }
                            
                            Spacer()
                            
                            Text(moduleSubtitle(for: active))
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(DesignSystem.secondaryText)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    }
                    
                    if moduleHasInternalVerticalScroll {
                        active.makeExpandedView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        ViewThatFits(in: .vertical) {
                            active.makeExpandedView()
                            ScrollView(.vertical, showsIndicators: false) {
                                active.makeExpandedView()
                            }
                        }
                    }
                }
                .id(active.id)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .fill(active.id == "airdrop" && airDropModule.isDropTargeted ? currentAccentColor.opacity(0.12) : DesignSystem.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(active.id == "airdrop" && airDropModule.isDropTargeted ? currentAccentColor.opacity(0.8) : DesignSystem.cardBorder, lineWidth: active.id == "airdrop" && airDropModule.isDropTargeted ? 1.5 : 0.8)
                )
                .contentShape(Rectangle())
                .onDrop(of: [.fileURL, .url, .image, .text, .plainText, .utf8PlainText, .item, .data, .content], isTargeted: active.id == "airdrop" ? $airDropModule.isDropTargeted : .constant(false)) { providers in
                    coordinator.fileDropWasAccepted = true
                    URLCollector.extractURLs(from: providers) { urls in
                        guard !urls.isEmpty else { return }
                        if active.id == "airdrop" {
                            AirDropModule.shared.shareFiles(urls)
                        } else if active.id == "localshare" {
                            LocalShareModule.shared.startSending(files: urls)
                        } else {
                            for u in urls {
                                ShelfModule.shared.addItem(u)
                            }
                        }
                        coordinator.onFileDropFinished()
                    }
                    return !providers.isEmpty
                }
            } else {
                // Modular 4-Slot Customizable Home Dashboard
                ModularDashboardView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: registry.activeModuleId)
    }
    
    private func moduleSubtitle(for module: any NotchModule) -> String {
        switch module.id {
        case "airdrop":
            if let lazy = module as? LazyNotchModule, !lazy.isLoaded {
                return "1-Click Wireless Sharing"
            }
            return AirDropModule.shared.statusMessage
        case "localshare":
            if let lazy = module as? LazyNotchModule, !lazy.isLoaded {
                return "Local Network File Transfer"
            }
            return LocalShareModule.shared.statusMessage
        case "shelf":
            if let lazy = module as? LazyNotchModule, !lazy.isLoaded {
                return "File workspace & stash"
            }
            return ShelfModule.shared.selectedTool.subtitle
        case "thock":
            if let lazy = module as? LazyNotchModule, !lazy.isLoaded {
                return "Tactile mechanical keyboard audio"
            }
            return ThockModule.shared.statusSubtitle
        case "telegram":
            return "Direct chat via WhatsApp & Telegram"
        case "battery":
            return "Real-time battery & power health"
        case "notifications":
            return "Notification history glances"
        case "mirror":
            return "MacBook HD Camera preview"
        default:
            return ""
        }
    }
}

// MARK: - Draggable & Drop-Targetable Tab Chip
public struct DraggableTabChip: View {
    let module: any NotchModule
    @ObservedObject var registry: ModuleRegistry
    let scrollProxy: ScrollViewProxy
    @StateObject private var uiState = LocalUIState()
    
    private var isSelected: Bool {
        registry.activeModuleId == module.id
    }
    
    private var isPinned: Bool {
        registry.pinnedModuleId == module.id
    }
    
    private var chipLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: module.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected || uiState.isTargeted ? module.themeColor : module.themeColor.opacity(0.85))
            
            Text(module.title)
                .font(.system(size: 11, weight: isSelected || uiState.isTargeted ? .bold : .medium, design: .rounded))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(isSelected || uiState.isTargeted ? .white : DesignSystem.secondaryText)
            
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7))
                    .foregroundColor(module.themeColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
    
    private var chipBackground: some View {
        Capsule()
            .fill(uiState.isTargeted ? module.themeColor.opacity(0.25) : (isSelected ? DesignSystem.structureColor : Color.white.opacity(0.05)))
    }
    
    private var chipBorder: some View {
        Capsule()
            .strokeBorder(
                uiState.isTargeted ? module.themeColor : (isSelected ? module.themeColor.opacity(0.8) : Color.white.opacity(0.08)),
                lineWidth: uiState.isTargeted ? 1.8 : (isPinned ? 1.4 : 0.8)
            )
    }

    private func handleTap() {
        registry.clearSuppression()
        if registry.activeModuleId == module.id {
            registry.togglePin(module.id)
        } else {
            registry.selectModule(module.id)
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollProxy.scrollTo(module.id, anchor: .center)
        }
    }

    private func createItemProvider() -> NSItemProvider {
        FeedbackManager.playHover()
        let identifier: NSString = "tab:\(module.id)" as NSString
        return NSItemProvider(object: identifier)
    }
    
    public var body: some View {
        chipLabel
            .background(chipBackground)
            .overlay(chipBorder)
            .scaleEffect(uiState.isTargeted ? 1.08 : (uiState.isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: uiState.isTargeted)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(module.title) Tab\(isPinned ? ", Pinned" : "")")
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            .contextMenu {
                Button {
                    registry.togglePin(module.id)
                } label: {
                    Label(isPinned ? "Unpin Tab" : "Pin Tab", systemImage: isPinned ? "pin.slash" : "pin")
                }
            }
            .onHover { hovering in
                uiState.isHovered = hovering
                if hovering {
                    registry.onTabHover(module.id)
                } else {
                    registry.onTabHoverExit(module.id)
                }
            }
            // Draggable tab source for manual reordering
            .onDrag {
                createItemProvider()
            }
            // Drop target supporting both Tab Reordering AND External File Drag-Hover!
            .onDrop(of: [.text, .fileURL, .item, .data, .content], delegate: UniversalTabDropDelegate(
                module: module,
                registry: registry,
                scrollProxy: scrollProxy,
                isTargeted: $uiState.isTargeted
            ))
    }
}

// MARK: - Spring-Loaded Interaction Manager for Tab Switching during File Drag
@MainActor
public final class SpringLoadManager {
    public static let shared = SpringLoadManager()
    private var workItem: DispatchWorkItem?
    private var currentTarget: String?
    
    public func schedule(for moduleId: String, execute: @escaping @MainActor () -> Void) {
        cancel()
        currentTarget = moduleId
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard self?.currentTarget == moduleId else { return }
                execute()
            }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40, execute: item)
    }
    
    public func cancel() {
        workItem?.cancel()
        workItem = nil
        currentTarget = nil
    }
}

// Universal Drop Delegate: Handles Tab Reordering & Spring-Loaded File Drag Switching
public struct UniversalTabDropDelegate: DropDelegate {
    let moduleId: String
    let registry: ModuleRegistry
    let scrollProxy: ScrollViewProxy
    @Binding var isTargeted: Bool
    
    public init(module: any NotchModule, registry: ModuleRegistry, scrollProxy: ScrollViewProxy, isTargeted: Binding<Bool>) {
        self.moduleId = module.id
        self.registry = registry
        self.scrollProxy = scrollProxy
        self._isTargeted = isTargeted
    }
    
    public func validateDrop(info: DropInfo) -> Bool {
        return true
    }
    
    public func dropUpdated(info: DropInfo) -> NSDragOperation? {
        if info.hasItemsConforming(to: [.text]) && !info.hasItemsConforming(to: [.fileURL, .image, .pdf]) {
            return .move
        }
        return .copy
    }
    
    public func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        SpringLoadManager.shared.cancel()
        let targetId = moduleId
        
        // 1. Tab Reordering drop completion
        if info.hasItemsConforming(to: [.text]) && !info.hasItemsConforming(to: [.fileURL, .item, .data, .content]) {
            if let provider = info.itemProviders(for: [.text]).first {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (item, _) in
                    var foundStr: String? = nil
                    if let data = item as? Data {
                        foundStr = String(data: data, encoding: .utf8)
                    } else if let str = item as? String {
                        foundStr = str
                    }
                    if let text = foundStr, text.hasPrefix("tab:") {
                        let sourceId = String(text.dropFirst(4))
                        if sourceId != targetId {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    self.registry.moveModule(from: sourceId, to: targetId)
                                }
                                FeedbackManager.playDrop()
                            }
                        }
                    }
                }
            }
            return true
        }
        
        let providers = info.itemProviders(for: [.fileURL, .url, .image, .text, .plainText, .utf8PlainText, .item, .data, .content])
        guard !providers.isEmpty else { return false }
        
        URLCollector.extractURLs(from: providers) { urls in
            guard !urls.isEmpty else { return }
            FeedbackManager.playDrop()
            if targetId == "airdrop" {
                AirDropModule.shared.shareFiles(urls)
                self.registry.selectFileDropTarget(for: "airdrop")
            } else if targetId == "localshare" {
                LocalShareModule.shared.startSending(files: urls)
                self.registry.selectFileDropTarget(for: "localshare")
            } else {
                for u in urls {
                    ShelfModule.shared.addItem(u)
                }
                self.registry.selectFileDropTarget(for: "shelf")
            }
            NotchShellCoordinator.shared.onFileDropFinished()
        }
        return true
    }
    
    public func dropEntered(info: DropInfo) {
        isTargeted = true
        let targetId = moduleId
        
        // 1. Check if this is an internal tab reordering drag (only plain text with "tab:" prefix)
        if info.hasItemsConforming(to: [.text]) && !info.hasItemsConforming(to: [.fileURL, .item, .data, .content]) {
            if let provider = info.itemProviders(for: [.text]).first {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (item, error) in
                    var foundStr: String? = nil
                    if let data = item as? Data {
                        foundStr = String(data: data, encoding: .utf8)
                    } else if let str = item as? String {
                        foundStr = str
                    }
                    if let text = foundStr, text.hasPrefix("tab:") {
                        let sourceId = String(text.dropFirst(4))
                        if sourceId != targetId {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    self.registry.moveModule(from: sourceId, to: targetId)
                                }
                                FeedbackManager.playHover()
                            }
                        }
                    }
                }
            }
            return
        }
        
        // 2. EXTERNAL FILE DRAG HOVER: Spring-loaded dwell timer (0.4s hover triggers switch)
        FeedbackManager.playHover()
        SpringLoadManager.shared.schedule(for: targetId) {
            self.registry.selectFileDropTarget(for: targetId)
            FeedbackManager.playPin()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.scrollProxy.scrollTo(targetId, anchor: .center)
            }
        }
    }
    
    public func dropExited(info: DropInfo) {
        isTargeted = false
        SpringLoadManager.shared.cancel()
    }
}

private struct CompactNotchIndicator: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var themeEngine = DynamicThemeEngine.shared
    @ObservedObject private var coordinator = NotchShellCoordinator.shared
    let height: CGFloat

    var body: some View {
        let layout = coordinator.currentCollapsedLayout
        if coordinator.geometry.hasPhysicalNotch {
            if !layout.isWingsVisible {
                // In "Hide behind notch" or inactive "Wings on events":
                // Zero pixels drawn outside the hardware cutout. Completely disappears into bezel!
                EmptyView()
            } else {
                switch store.compactIndicatorStyle {
                case .minimal:
                    compactWingMinimalView(layout: layout)
                case .threeZoneStatusBar:
                    CompactThreeZoneStatusBarIndicator(layout: layout)
                case .media:
                    CompactWingMediaIndicator(layout: layout)
                case .battery:
                    CompactWingBatteryIndicator(layout: layout)
                case .dateTime:
                    CompactWingDateTimeIndicator(layout: layout)
                case .circadian:
                    CompactWingCircadianIndicator(layout: layout)
                }
            }
        } else {
            HStack(spacing: 8) {
                switch store.compactIndicatorStyle {
                case .media:
                    CompactMediaIndicator()
                case .minimal:
                    minimalIndicator
                case .battery:
                    CompactBatteryIndicator()
                case .dateTime:
                    dateTimeIndicator
                case .circadian:
                    circadianIndicator
                case .threeZoneStatusBar:
                    CompactThreeZoneStatusBarIndicator()
                }
            }
            .padding(.horizontal, 10)
            .frame(height: height)
        }
    }
    
    private func compactWingMinimalView(layout: CollapsedLayout) -> some View {
        HStack(spacing: 0) {
            Circle()
                .fill(CompactIndicatorStyle.minimal.tintColor)
                .frame(width: 5, height: 5)
                .frame(width: layout.effectiveWingWidth, alignment: .center)
            
            Spacer()
                .frame(width: layout.centerCutoutRect.width)
                .allowsHitTesting(false)
            
            Capsule()
                .fill(CompactIndicatorStyle.minimal.tintColor.opacity(0.70))
                .frame(width: 12, height: 3)
                .frame(width: layout.effectiveWingWidth, alignment: .center)
        }
    }
    
    private var minimalIndicator: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(CompactIndicatorStyle.minimal.tintColor)
                .frame(width: 16, height: 4)
            Spacer()
        }
    }
    
    private var dateTimeIndicator: some View {
        TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 9))
                    .foregroundColor(CompactIndicatorStyle.dateTime.tintColor)
                Text(timeline.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                Text(timeline.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
            }
        }
    }
    
    private var circadianIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 9))
                .foregroundColor(CompactIndicatorStyle.circadian.tintColor)
            Text(themeEngine.paletteSource)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
                Text(timeline.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(DesignSystem.secondaryText)
            }
        }
    }
}

// MARK: - Dedicated Lazy Compact Indicator Subviews
private struct CompactMediaIndicator: View {
    @ObservedObject private var nowPlaying = NowPlayingModule.shared
    
    var body: some View {
        if nowPlaying.hasActiveMedia {
            if let art = nowPlaying.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            } else {
                Circle()
                    .fill(CompactIndicatorStyle.media.tintColor)
                    .frame(width: 5, height: 5)
            }

            Text(nowPlaying.trackTitle)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if nowPlaying.isPlaying {
                HStack(spacing: 1.5) {
                    RoundedRectangle(cornerRadius: 1).fill(CompactIndicatorStyle.media.tintColor).frame(width: 2, height: 6)
                    RoundedRectangle(cornerRadius: 1).fill(CompactIndicatorStyle.media.tintColor).frame(width: 2, height: 11)
                    RoundedRectangle(cornerRadius: 1).fill(CompactIndicatorStyle.media.tintColor).frame(width: 2, height: 7)
                }
            } else {
                Image(systemName: "pause.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.45))
            }
        } else {
            Spacer()
            Circle().fill(CompactIndicatorStyle.media.tintColor).frame(width: 5, height: 5)
            Spacer()
        }
    }
}

private struct CompactBatteryIndicator: View {
    @ObservedObject private var battery = BatteryModule.shared
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                .font(.system(size: 10))
                .foregroundColor(battery.percentage < 20 ? .red : CompactIndicatorStyle.battery.tintColor)
            Text("\(battery.percentage)%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Text(battery.isCharging ? "Charging" : "Battery")
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.secondaryText)
        }
    }
}

private struct CompactWingMediaIndicator: View {
    @ObservedObject private var nowPlaying = NowPlayingModule.shared
    let layout: CollapsedLayout
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Wing
            HStack(spacing: 4) {
                if nowPlaying.hasActiveMedia {
                    if let art = nowPlaying.artwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 13, height: 13)
                            .clipShape(RoundedRectangle(cornerRadius: 3.0, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 8.5))
                            .foregroundColor(CompactIndicatorStyle.media.tintColor)
                    }
                    Text(nowPlaying.trackTitle)
                        .font(.system(size: 9.0, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 8.5))
                        .foregroundColor(CompactIndicatorStyle.media.tintColor)
                }
            }
            .frame(width: layout.effectiveWingWidth, alignment: .center)
            .padding(.horizontal, 4)
            
            // Physical Cutout Clear Zone: 0 pixels inside physical notch cutout
            Spacer()
                .frame(width: layout.centerCutoutRect.width)
                .allowsHitTesting(false)
            
            // Right Wing
            HStack(spacing: 2) {
                if nowPlaying.hasActiveMedia && nowPlaying.isPlaying {
                    HStack(spacing: 1.5) {
                        RoundedRectangle(cornerRadius: 1).fill(CompactIndicatorStyle.media.tintColor).frame(width: 2, height: 5)
                        RoundedRectangle(cornerRadius: 1).fill(CompactIndicatorStyle.media.tintColor).frame(width: 2, height: 10)
                        RoundedRectangle(cornerRadius: 1).fill(CompactIndicatorStyle.media.tintColor).frame(width: 2, height: 6)
                    }
                } else if nowPlaying.hasActiveMedia {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 7.5))
                        .foregroundColor(Color.white.opacity(0.45))
                } else {
                    Circle()
                        .fill(CompactIndicatorStyle.media.tintColor.opacity(0.40))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: layout.effectiveWingWidth, alignment: .center)
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
    }
}

private struct CompactWingBatteryIndicator: View {
    @ObservedObject private var battery = BatteryModule.shared
    let layout: CollapsedLayout
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Wing
            HStack(spacing: 3) {
                Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 8.5))
                    .foregroundColor(battery.percentage < 20 ? .red : CompactIndicatorStyle.battery.tintColor)
                Text("\(battery.percentage)%")
                    .font(.system(size: 9.0, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: layout.effectiveWingWidth, alignment: .center)
            .padding(.horizontal, 4)
            
            // Physical Cutout Clear Zone
            Spacer()
                .frame(width: layout.centerCutoutRect.width)
                .allowsHitTesting(false)
            
            // Right Wing
            TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8.0))
                        .foregroundColor(CompactIndicatorStyle.battery.tintColor)
                    Text(timeline.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .frame(width: layout.effectiveWingWidth, alignment: .center)
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
    }
}

private struct CompactWingDateTimeIndicator: View {
    let layout: CollapsedLayout
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
            HStack(spacing: 0) {
                // Left Wing
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 8.5))
                        .foregroundColor(CompactIndicatorStyle.dateTime.tintColor)
                    Text(timeline.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9.0, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(width: layout.effectiveWingWidth, alignment: .center)
                .padding(.horizontal, 4)
                
                // Physical Cutout Clear Zone
                Spacer()
                    .frame(width: layout.centerCutoutRect.width)
                    .allowsHitTesting(false)
                
                // Right Wing
                HStack(spacing: 3) {
                    Text(timeline.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 9.0, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .frame(width: layout.effectiveWingWidth, alignment: .center)
                .padding(.horizontal, 4)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct CompactWingCircadianIndicator: View {
    @ObservedObject private var themeEngine = DynamicThemeEngine.shared
    let layout: CollapsedLayout
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Wing
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 8.5))
                    .foregroundColor(CompactIndicatorStyle.circadian.tintColor)
                Text(themeEngine.paletteSource)
                    .font(.system(size: 9.0, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: layout.effectiveWingWidth, alignment: .center)
            .padding(.horizontal, 4)
            
            // Physical Cutout Clear Zone
            Spacer()
                .frame(width: layout.centerCutoutRect.width)
                .allowsHitTesting(false)
            
            // Right Wing
            TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
                HStack(spacing: 3) {
                    Text(timeline.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            .frame(width: layout.effectiveWingWidth, alignment: .center)
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
    }
}

private struct CompactThreeZoneStatusBarIndicator: View {
    @ObservedObject private var nowPlaying = NowPlayingModule.shared
    @ObservedObject private var battery = BatteryModule.shared
    let layout: CollapsedLayout?
    
    init(layout: CollapsedLayout? = nil) {
        self.layout = layout
    }
    
    var body: some View {
        let geometry = NotchGeometry.current()
        if geometry.hasPhysicalNotch, let layout = layout {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    if nowPlaying.hasActiveMedia {
                        Image(systemName: "music.note")
                            .font(.system(size: 8.5))
                            .foregroundColor(CompactIndicatorStyle.threeZoneStatusBar.tintColor)
                        Text(nowPlaying.trackTitle)
                            .font(.system(size: 9.0, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 8.0))
                            .foregroundColor(CompactIndicatorStyle.threeZoneStatusBar.tintColor)
                        TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
                            Text(timeline.date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 9.0, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: layout.effectiveWingWidth, alignment: .center)
                .padding(.horizontal, 4)
                
                Spacer()
                    .frame(width: layout.centerCutoutRect.width)
                    .allowsHitTesting(false)
                
                HStack(spacing: 3) {
                    Text("\(battery.percentage)%")
                        .font(.system(size: 9.0, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: 8.5))
                        .foregroundColor(battery.percentage < 20 ? .red : CompactIndicatorStyle.threeZoneStatusBar.tintColor)
                }
                .frame(width: layout.effectiveWingWidth, alignment: .center)
                .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        } else {
            HStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 8.5))
                            .foregroundColor(CompactIndicatorStyle.threeZoneStatusBar.tintColor)
                        Text(timeline.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 9.0, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 3, height: 3)
                
                if nowPlaying.hasActiveMedia {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 8.5))
                            .foregroundColor(CompactIndicatorStyle.threeZoneStatusBar.tintColor)
                        Text(nowPlaying.trackTitle)
                            .font(.system(size: 9.0, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                } else {
                    Text("Notch Island")
                        .font(.system(size: 9.0, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 3, height: 3)
                
                HStack(spacing: 3) {
                    Text("\(battery.percentage)%")
                        .font(.system(size: 9.0, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: 8.5))
                        .foregroundColor(battery.percentage < 20 ? .red : CompactIndicatorStyle.threeZoneStatusBar.tintColor)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}
