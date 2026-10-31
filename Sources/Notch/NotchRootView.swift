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
                topRadius: isExpanded ? 14 : 4,
                bottomRadius: isExpanded ? 34 : 14,
                showsMaterial: isExpanded
            )
            
            VStack(spacing: 0) {
                if !isExpanded {
                    CompactNowPlayingIndicator(height: store.hoverTriggerHeight)
                        .transition(.opacity)
                } else {
                    // Camera Clear Zone: Leaves 38pt+ clear at the top so nothing renders behind the physical MacBook notch
                    Spacer()
                        .frame(height: max(38.0, coordinator.geometry.physicalNotchHeight + 6))
                    
                    // Persistent Navigation Dock (Stable layout, never mutates under cursor)
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
        .onDrop(of: [.fileURL], isTargeted: $coordinator.isFileDragTargeted) { providers in
            let fileProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
            guard !fileProviders.isEmpty else { return false }
            coordinator.fileDropWasAccepted = true
            registry.selectFileDropTarget()
            for provider in fileProviders {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { ShelfModule.shared.addItem(url) }
                }
            }
            return true
        }
        .onChange(of: coordinator.isFileDragTargeted) { _, targeted in
            if targeted {
                coordinator.fileDropWasAccepted = false
                coordinator.onFileDragEntered()
            } else if !coordinator.fileDropWasAccepted {
                coordinator.onFileDragExited()
                registry.cancelFileDropTarget()
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if !coordinator.isHovered { themeEngine.refreshColors() }
                coordinator.onMouseEnter()
            case .ended:
                coordinator.onMouseExit()
            }
        }
    }
    
    // Persistent Navigation Dock (Stable geometry: NEVER swaps view hierarchy under mouse)
    private var expandedHeaderTabs: some View {
        HStack(spacing: 8) {
            // Dashboard Home Tab Button
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
            
            // Specular Vertical Separator
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 1)
            
            // Scrollable Module Dock (AirDrop, File Studio, Messages, Battery, Alerts, Mirror)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(registry.orderedModules.filter { $0.isEnabled }, id: \.id) { module in
                        let isSelected = (registry.activeModuleId == module.id)
                        let isPinned = (registry.pinnedModuleId == module.id)
                        
                        Button(action: {
                            registry.togglePin(module.id)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: module.iconName)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.75))
                                
                                Text(module.title)
                                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                                
                                if isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 7))
                                        .foregroundColor(DesignSystem.accentColor)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? DesignSystem.structureColor : Color.white.opacity(0.05))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isSelected ? DesignSystem.accentColor : Color.white.opacity(0.08),
                                        lineWidth: isPinned ? 1.4 : 0.8
                                    )
                            )
                        }
                        .buttonStyle(.spring)
                        .onHover { isHovering in
                            if isHovering {
                                registry.onTabHover(module.id)
                            }
                        }
                        .onDrag {
                            FeedbackManager.playHover()
                            return NSItemProvider(object: module.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(item: module.id, registry: registry))
                    }
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
        }
    }
    
    // Content Area: Default Home Landing OR Selected Secondary Module with Breadcrumb Ribbon
    @ViewBuilder
    private var contentArea: some View {
        Group {
            if let active = registry.activeModule {
                // Selected Secondary Module View
                VStack(alignment: .leading, spacing: 6) {
                    // Breadcrumb Ribbon (Situated inside the card, leaving the top dock untouched)
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
                                .foregroundColor(DesignSystem.accentColor)
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
                    
                    active.makeExpandedView()
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
                // Home Landing Dashboard: Left: Currently Playing, Right: Calendar
                HStack(alignment: .top, spacing: 12) {
                    // Left Side: Live Currently Playing Media Card
                    NowPlayingHomeCardView()
                        .frame(maxWidth: .infinity)
                    
                    // Right Side: Interactive Calendar Card
                    CalendarHomeCardView()
                        .frame(width: 250)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
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

private struct CompactNowPlayingIndicator: View {
    @ObservedObject private var nowPlaying = NowPlayingModule.shared
    let height: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            if nowPlaying.hasActiveMedia {
                if let art = nowPlaying.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 13, height: 13)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                } else {
                    Circle()
                        .fill(DesignSystem.accentColor)
                        .frame(width: 5, height: 5)
                }

                Text(nowPlaying.trackTitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                if nowPlaying.isPlaying {
                    HStack(spacing: 1.5) {
                        RoundedRectangle(cornerRadius: 1).fill(DesignSystem.accentColor).frame(width: 2, height: 6)
                        RoundedRectangle(cornerRadius: 1).fill(DesignSystem.accentColor).frame(width: 2, height: 11)
                        RoundedRectangle(cornerRadius: 1).fill(DesignSystem.accentColor).frame(width: 2, height: 7)
                    }
                } else {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            } else {
                Spacer()
                Circle().fill(DesignSystem.accentColor).frame(width: 5, height: 5)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
    }
}

// Drag & Drop Delegate for Tab Reordering
public struct TabDropDelegate: DropDelegate {
    let item: String
    let registry: ModuleRegistry
    
    public init(item: String, registry: ModuleRegistry) {
        self.item = item
        self.registry = registry
    }
    
    public func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    public func dropEntered(info: DropInfo) {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return }
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (item, error) in
            var foundId: String? = nil
            if let data = item as? Data {
                foundId = String(data: data, encoding: .utf8)
            } else if let str = item as? String {
                foundId = str
            }
            if let sourceId = foundId, sourceId != self.item {
                DispatchQueue.main.async {
                    self.registry.moveModule(from: sourceId, to: self.item)
                }
            }
        }
    }
}
