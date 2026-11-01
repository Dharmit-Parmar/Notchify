import SwiftUI
import UniformTypeIdentifiers

public struct DashboardSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @StateObject private var uiState = DashboardSettingsUIState()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Modular Dashboard Grid")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Customize the 4-slot Bento Grid for your Notch Home Dashboard. Drag widgets into slots, reorder, or choose an Apple-calibrated preset.")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            // Live Notch Layout Preview
            layoutMiniPreviewSection
            
            // 4-Slot Canvas & Palette Side-by-Side (or stacked on narrow)
            VStack(alignment: .leading, spacing: 14) {
                Text("DASHBOARD SLOTS CANVAS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DesignSystem.secondaryText)
                
                // 2x2 Interactive Slot Grid
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        SlotDropCard(
                            slotIndex: 0,
                            title: "Slot 1 (Top Left)",
                            widget: store.dashboardSlots[0],
                            onDrop: { widget in store.setDashboardSlot(at: 0, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 0, widget: nil) }
                        )
                        
                        SlotDropCard(
                            slotIndex: 1,
                            title: "Slot 2 (Top Right)",
                            widget: store.dashboardSlots[1],
                            onDrop: { widget in store.setDashboardSlot(at: 1, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 1, widget: nil) }
                        )
                    }
                    
                    HStack(spacing: 12) {
                        SlotDropCard(
                            slotIndex: 2,
                            title: "Slot 3 (Bottom Left)",
                            widget: store.dashboardSlots[2],
                            onDrop: { widget in store.setDashboardSlot(at: 2, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 2, widget: nil) }
                        )
                        
                        SlotDropCard(
                            slotIndex: 3,
                            title: "Slot 4 (Bottom Right)",
                            widget: store.dashboardSlots[3],
                            onDrop: { widget in store.setDashboardSlot(at: 3, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 3, widget: nil) }
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.9)
                    )
            )
            
            // Available Widgets Palette
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AVAILABLE WIDGETS PALETTE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DesignSystem.secondaryText)
                    Spacer()
                    Text("Drag card into any slot above")
                        .font(.system(size: 10.5))
                        .foregroundColor(DesignSystem.tertiaryText)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 10)], spacing: 10) {
                    ForEach(DashboardWidgetType.allCases) { widget in
                        let isPlaced = store.dashboardSlots.contains(widget)
                        let placedSlotIndex = store.dashboardSlots.firstIndex(of: widget)
                        
                        DraggableWidgetPaletteCard(
                            widget: widget,
                            isPlaced: isPlaced,
                            placedSlotIndex: placedSlotIndex,
                            onQuickAssign: {
                                // Find first empty slot
                                if let firstEmpty = store.dashboardSlots.firstIndex(where: { $0 == nil }) {
                                    store.setDashboardSlot(at: firstEmpty, widget: widget)
                                } else {
                                    store.setDashboardSlot(at: 0, widget: widget)
                                }
                            },
                            onEject: {
                                store.removeDashboardWidget(widget)
                            }
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.9)
                    )
            )
            
            // Quick Layout Presets
            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK LAYOUT PRESETS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DesignSystem.secondaryText)
                
                HStack(spacing: 8) {
                    PresetButton(title: "Classic Duo", subtitle: "Media + Calendar") {
                        store.applyPresetDashboard(slots: [.nowPlaying, .calendar, nil, nil])
                    }
                    
                    PresetButton(title: "Productivity 4-Grid", subtitle: "Notes + Clock + Cal + Media") {
                        store.applyPresetDashboard(slots: [.notes, .clock, .calendar, .nowPlaying])
                    }
                    
                    PresetButton(title: "Morning Hub", subtitle: "Clock + Calendar") {
                        store.applyPresetDashboard(slots: [.clock, .calendar, nil, nil])
                    }
                    
                    PresetButton(title: "Studio Focus", subtitle: "Media + Mirror") {
                        store.applyPresetDashboard(slots: [.nowPlaying, .mirror, nil, nil])
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            // Clock Customization Section
            VStack(alignment: .leading, spacing: 12) {
                Text("CLOCK WIDGET CUSTOMIZATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DesignSystem.secondaryText)
                
                HStack(spacing: 20) {
                    // Dial Style Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dial Aesthetics")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            ForEach(ClockDialStyle.allCases) { style in
                                Button {
                                    store.clockDialStyle = style
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: style == .analog ? "clock" : "numbers.rectangle")
                                            .font(.system(size: 11))
                                        Text(style.title)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(store.clockDialStyle == style ? DesignSystem.accentColor : Color.white.opacity(0.08))
                                    )
                                    .foregroundColor(store.clockDialStyle == style ? .white : DesignSystem.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 12h vs 24h toggle
                    Toggle("24-Hour Time", isOn: $store.clockIs24Hour)
                        .font(.system(size: 11, weight: .medium))
                        .toggleStyle(.switch)
                    
                    // Seconds toggle
                    Toggle("Smooth Seconds", isOn: $store.clockShowSeconds)
                        .font(.system(size: 11, weight: .medium))
                        .toggleStyle(.switch)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.9)
                    )
            )
        }
    }
    
    // MARK: - Mini Layout Preview
    private var layoutMiniPreviewSection: some View {
        let activeCount = store.activeDashboardWidgets.count
        
        return HStack(spacing: 16) {
            // Live Notch Silhouette Mini View
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.75))
                    .frame(width: 130, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                
                // Camera notch simulator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black)
                    .frame(width: 32, height: 7)
                
                // Mini widget slots inside preview
                HStack(spacing: 3) {
                    if activeCount == 1 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignSystem.accentColor.opacity(0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if activeCount == 2 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignSystem.accentColor.opacity(0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if activeCount == 3 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignSystem.accentColor.opacity(0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue.opacity(0.5))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange.opacity(0.5))
                        }
                    } else {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2).fill(Color.red.opacity(0.5))
                                RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.5))
                            }
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.5))
                                RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Auto-Stretch Dynamics:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(activeCount) of 4 Spaces Active")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(DesignSystem.accentColor.opacity(0.18)))
                }
                
                Text(stretchExplanationText(activeCount))
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    private func stretchExplanationText(_ count: Int) -> String {
        switch count {
        case 0: return "Dashboard is currently empty. Drag widgets into slots above."
        case 1: return "1 widget expands to occupy 100% of the Notch dashboard canvas."
        case 2: return "2 widgets split 50% / 50% side-by-side with fluid proportions."
        case 3: return "1 widget takes a dual-height column, and 2 widgets stack beside it."
        default: return "All 4 quadrants active in a balanced 2×2 Bento Grid."
        }
    }
}

// MARK: - Helper UI State
@MainActor
final class DashboardSettingsUIState: ObservableObject {
    @Published var draggedWidget: DashboardWidgetType? = nil
}

@MainActor
final class DropTargetState: ObservableObject {
    @Published var isTargeted: Bool = false
}

// MARK: - Interactive Slot Drop Target Card
struct SlotDropCard: View {
    let slotIndex: Int
    let title: String
    let widget: DashboardWidgetType?
    let onDrop: (DashboardWidgetType) -> Void
    let onClear: () -> Void
    
    @StateObject private var targetState = DropTargetState()
    
    var body: some View {
        ZStack {
            if let widget = widget {
                // Occupied Slot View
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(widget.tintColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: widget.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(widget.tintColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(widget.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(title)
                            .font(.system(size: 9.5))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Eject / Remove Button
                    Button {
                        FeedbackManager.playClick()
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("Remove widget from slot")
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(targetState.isTargeted ? DesignSystem.accentColor : Color.white.opacity(0.12), lineWidth: targetState.isTargeted ? 1.5 : 0.8)
                        )
                )
                // Allow dragging out or dropping onto
                .onDrag {
                    NSItemProvider(object: widget.rawValue as NSString)
                }
            } else {
                // Empty Slot Drop Placeholder
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(targetState.isTargeted ? DesignSystem.accentColor : Color.white.opacity(0.25))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(targetState.isTargeted ? .white : DesignSystem.secondaryText)
                        Text("Drop widget here")
                            .font(.system(size: 9.5))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                    
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            targetState.isTargeted ? DesignSystem.accentColor : Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: targetState.isTargeted ? 1.5 : 1.0, dash: [4, 4])
                        )
                        .background(targetState.isTargeted ? DesignSystem.accentColor.opacity(0.08) : Color.clear)
                )
            }
        }
        .frame(height: 52)
        .onDrop(of: [.text, .plainText], isTargeted: $targetState.isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                guard let raw = string as? String, let droppedType = DashboardWidgetType(rawValue: raw) else { return }
                DispatchQueue.main.async {
                    FeedbackManager.playPin()
                    onDrop(droppedType)
                }
            }
            return true
        }
    }
}

// MARK: - Draggable Widget Palette Card
struct DraggableWidgetPaletteCard: View {
    let widget: DashboardWidgetType
    let isPlaced: Bool
    let placedSlotIndex: Int?
    let onQuickAssign: () -> Void
    let onEject: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(widget.tintColor.opacity(isPlaced ? 0.15 : 0.25))
                    .frame(width: 28, height: 28)
                Image(systemName: widget.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isPlaced ? widget.tintColor.opacity(0.6) : widget.tintColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(widget.title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(isPlaced ? DesignSystem.secondaryText : .white)
                
                if isPlaced, let idx = placedSlotIndex {
                    Text("In Slot \(idx + 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.accentColor)
                } else {
                    Text(widget.subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.tertiaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if isPlaced {
                Button {
                    FeedbackManager.playClick()
                    onEject()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.secondaryText)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Remove from slot")
            } else {
                Button {
                    FeedbackManager.playPin()
                    onQuickAssign()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Assign to first open slot")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPlaced ? Color.white.opacity(0.02) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isPlaced ? Color.white.opacity(0.06) : Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
        // Enable Native macOS Drag
        .onDrag {
            NSItemProvider(object: widget.rawValue as NSString)
        }
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button {
            FeedbackManager.playPin()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
