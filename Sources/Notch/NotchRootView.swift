import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct NotchRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var coordinator = NotchShellCoordinator.shared
    @ObservedObject var registry = ModuleRegistry.shared
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var themeEngine = DynamicThemeEngine.shared
    
    public init() {}
    
    private var isExpanded: Bool {
        coordinator.state == .expanded
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Clean Liquid Retina Glass: No drop shadow, deep continuous squircle radii
            NotchGlassBackground(
                topRadius: isExpanded ? store.cornerStyle.topRadius : 4,
                bottomRadius: isExpanded ? store.cornerStyle.bottomRadius : 14,
                showsMaterial: isExpanded
            )
            
            VStack(spacing: 0) {
                if !isExpanded {
                    CompactNotchIndicator(height: store.hoverTriggerHeight)
                        .transition(.opacity)
                } else {
                    // Camera Clear Zone: Leaves 38pt+ clear at the top so nothing renders behind physical MacBook notch
                    Spacer()
                        .frame(height: max(38.0, coordinator.geometry.physicalNotchHeight + 6))
                    
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
                                    DesignSystem.accentColor.opacity(0.35),
                                    DesignSystem.accentColor.opacity(0.10),
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
                    contentArea
                        .padding(.horizontal, store.contentHorizontalPadding)
                        .padding(.bottom, store.contentVerticalPadding)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: store.currentTheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: themeEngine.canvasColor)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .item, .data, .content], isTargeted: $coordinator.isFileDragTargeted) { providers in
            coordinator.fileDropWasAccepted = true
            coordinator.onFileDropFinished()
            
            for provider in providers {
                if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async {
                            if registry.activeModuleId == "airdrop" {
                                AirDropModule.shared.shareFiles([url])
                            } else {
                                ShelfModule.shared.addItem(url)
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                        guard let url else { return }
                        DispatchQueue.main.async {
                            if registry.activeModuleId == "airdrop" {
                                AirDropModule.shared.shareFiles([url])
                            } else {
                                ShelfModule.shared.addItem(url)
                            }
                        }
                    }
                }
            }
            return true
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
            Button(action: {
                registry.returnToHome()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isDashboardActive ? DesignSystem.accentColor : Color.white.opacity(0.8))
                    
                    Text("Dashboard")
                        .font(.system(size: 11, weight: isDashboardActive ? .bold : .medium, design: .rounded))
                        .foregroundColor(isDashboardActive ? .white : DesignSystem.secondaryText)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isDashboardActive ? DesignSystem.structureColor : Color.white.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isDashboardActive ? DesignSystem.accentColor.opacity(0.7) : Color.white.opacity(0.08), lineWidth: isDashboardActive ? 1.2 : 0.7)
                )
            }
            .buttonStyle(.spring)
            .help("Home Media & Calendar")
            .onHover { hovering in
                if hovering {
                    registry.onDashboardHover()
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
                        .padding(.horizontal, 2)
                    }
                    
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
                }
            }
            
            Spacer()
            
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
        }
    }
    
    // Content Area: Default Home Landing OR Selected Secondary Module with Breadcrumb Ribbon
    @ViewBuilder
    private var contentArea: some View {
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
                    
                    active.makeExpandedView()
                        .id(active.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .fill(DesignSystem.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
                )
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
            return AirDropModule.shared.statusMessage
        case "shelf":
            return ShelfModule.shared.selectedTool.subtitle
        case "thock":
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
    
    public var body: some View {
        let isSelected = (registry.activeModuleId == module.id)
        let isPinned = (registry.pinnedModuleId == module.id)
        
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
        .background(
            Capsule()
                .fill(uiState.isTargeted ? module.themeColor.opacity(0.25) : (isSelected ? DesignSystem.structureColor : Color.white.opacity(0.05)))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    uiState.isTargeted ? module.themeColor : (isSelected ? module.themeColor.opacity(0.8) : Color.white.opacity(0.08)),
                    lineWidth: uiState.isTargeted ? 1.8 : (isPinned ? 1.4 : 0.8)
                )
        )
        .scaleEffect(uiState.isTargeted ? 1.08 : (uiState.isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: uiState.isTargeted)
        .contentShape(Rectangle())
        .onTapGesture {
            registry.togglePin(module.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scrollProxy.scrollTo(module.id, anchor: .center)
            }
        }
        .onHover { hovering in
            uiState.isHovered = hovering
            if hovering {
                registry.onTabHover(module.id)
            }
        }
        // Draggable tab source for manual reordering
        .onDrag {
            FeedbackManager.playHover()
            return NSItemProvider(object: "tab:\(module.id)" as NSString)
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

// Universal Drop Delegate: Handles Tab Reordering & File Drag-Hover Switching
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
        return .copy
    }
    
    public func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let targetId = moduleId
        
        let providers = info.itemProviders(for: [.fileURL, .item, .data, .content])
        var handled = false
        
        for p in providers {
            if p.canLoadObject(ofClass: URL.self) {
                handled = true
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        FeedbackManager.playDrop()
                        if targetId == "airdrop" {
                            AirDropModule.shared.shareFiles([url])
                            self.registry.selectFileDropTarget(for: "airdrop")
                        } else {
                            ShelfModule.shared.addItem(url)
                            self.registry.selectFileDropTarget(for: "shelf")
                        }
                    }
                }
            } else if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    guard let url else { return }
                    DispatchQueue.main.async {
                        FeedbackManager.playDrop()
                        if targetId == "airdrop" {
                            AirDropModule.shared.shareFiles([url])
                            self.registry.selectFileDropTarget(for: "airdrop")
                        } else {
                            ShelfModule.shared.addItem(url)
                            self.registry.selectFileDropTarget(for: "shelf")
                        }
                    }
                }
            }
        }
        
        if handled {
            NotchShellCoordinator.shared.onFileDropFinished()
            return true
        }
        return true
    }
    
    public func dropEntered(info: DropInfo) {
        isTargeted = true
        let targetId = moduleId
        
        // 1. Check if this is an internal tab reordering drag (only plain text with "tab:" prefix)
        if let provider = info.itemProviders(for: [.text]).first,
           !info.hasItemsConforming(to: [.fileURL, .pdf, .image, .movie, .audio, .archive]) {
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
                            self.registry.moveModule(from: sourceId, to: targetId)
                        }
                    }
                }
            }
            return
        }
        
        // 2. EXTERNAL FILE DRAG HOVER: Immediate tab activation and tactile haptic response!
        FeedbackManager.playHover()
        DispatchQueue.main.async {
            self.registry.selectFileDropTarget(for: targetId)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.scrollProxy.scrollTo(targetId, anchor: .center)
            }
        }
    }
    
    public func dropExited(info: DropInfo) {
        isTargeted = false
    }
}

private struct CompactNotchIndicator: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var nowPlaying = NowPlayingModule.shared
    @ObservedObject private var battery = BatteryModule.shared
    @ObservedObject private var themeEngine = DynamicThemeEngine.shared
    let height: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            switch store.compactIndicatorStyle {
            case .media:
                mediaIndicator
            case .minimal:
                minimalIndicator
            case .battery:
                batteryIndicator
            case .dateTime:
                dateTimeIndicator
            case .circadian:
                circadianIndicator
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
    }
    
    @ViewBuilder
    private var mediaIndicator: some View {
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
    
    private var minimalIndicator: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(CompactIndicatorStyle.minimal.tintColor)
                .frame(width: 16, height: 4)
            Spacer()
        }
    }
    
    private var batteryIndicator: some View {
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
    
    private var dateTimeIndicator: some View {
        TimelineView(.periodic(from: .now, by: 60.0)) { timeline in
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 9))
                    .foregroundColor(CompactIndicatorStyle.dateTime.tintColor)
                Text(timeline.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
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
