import SwiftUI
import UniformTypeIdentifiers

public struct DashboardSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @StateObject private var uiState = DashboardSettingsUIState()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Header Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Modular Dashboard Grid")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Customize layout slots with Notes, Calendar, Media, Mirror, and Clock. Choose side-by-side strip, 2×2 bento, or smart adaptive auto-stretch.")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            // Live Notch Layout Preview & Trigger
            layoutMiniPreviewSection
            
            // Layout Mode Selector (Side-by-Side Strip vs 2x2 Bento vs Smart Adaptive)
            layoutModeSelectionSection
            
            // 4-Slot Canvas
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("DASHBOARD SLOTS CANVAS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("Reorder, assign, or set 1-space / 2-space size")
                        .font(.system(size: 10.5))
                        .foregroundColor(DesignSystem.tertiaryText)
                        .lineLimit(1)
                }
                
                if store.dashboardLayoutFlow == .horizontalStrip {
                    // Single row horizontal strip representation
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            SlotDropCard(
                                slotIndex: index,
                                title: "Slot \(index + 1)",
                                widget: store.dashboardSlots[index],
                                onDrop: { widget in store.setDashboardSlot(at: index, widget: widget) },
                                onClear: { store.setDashboardSlot(at: index, widget: nil) }
                            )
                        }
                    }
                } else {
                    // 2x2 Quad Grid representation
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
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
                        
                        HStack(spacing: 10) {
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
                        .lineLimit(1)
                    Spacer()
                    Text("Drag card into slot or tap + to assign")
                        .font(.system(size: 10.5))
                        .foregroundColor(DesignSystem.tertiaryText)
                        .lineLimit(1)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 10)], spacing: 10) {
                    ForEach(DashboardWidgetType.allCases) { widget in
                        let isPlaced = store.dashboardSlots.contains(widget)
                        let placedSlotIndex = store.dashboardSlots.firstIndex(of: widget)
                        
                        DraggableWidgetPaletteCard(
                            widget: widget,
                            isPlaced: isPlaced,
                            placedSlotIndex: placedSlotIndex,
                            onQuickAssign: {
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
                    .lineLimit(1)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    PresetButton(title: "Classic Duo", subtitle: "Media + Calendar") {
                        store.dashboardLayoutFlow = .adaptiveAuto
                        store.setSpan(2, for: .nowPlaying)
                        store.setSpan(2, for: .calendar)
                        store.applyPresetDashboard(slots: [.nowPlaying, .calendar, nil, nil])
                    }
                    
                    PresetButton(title: "4 Side-by-Side Strip", subtitle: "Clock + Cal + Notes + Media") {
                        store.dashboardLayoutFlow = .horizontalStrip
                        store.setSpan(1, for: .clock)
                        store.setSpan(1, for: .calendar)
                        store.setSpan(1, for: .notes)
                        store.setSpan(1, for: .nowPlaying)
                        store.applyPresetDashboard(slots: [.clock, .calendar, .notes, .nowPlaying])
                    }
                    
                    PresetButton(title: "3-Widget Studio", subtitle: "Notes (2-Space) + Clock + Cal") {
                        store.dashboardLayoutFlow = .horizontalStrip
                        store.setSpan(2, for: .notes)
                        store.setSpan(1, for: .clock)
                        store.setSpan(1, for: .calendar)
                        store.applyPresetDashboard(slots: [.notes, .clock, .calendar, nil])
                    }
                    
                    PresetButton(title: "Productivity 4-Grid", subtitle: "Notes + Clock + Cal + Media") {
                        store.dashboardLayoutFlow = .bentoQuad
                        store.setSpan(1, for: .notes)
                        store.setSpan(1, for: .clock)
                        store.setSpan(1, for: .calendar)
                        store.setSpan(1, for: .nowPlaying)
                        store.applyPresetDashboard(slots: [.notes, .clock, .calendar, .nowPlaying])
                    }
                    
                    PresetButton(title: "AI & Notes Studio", subtitle: "Ask AI (2-Sp) + Notes (2-Sp)") {
                        store.dashboardLayoutFlow = .adaptiveAuto
                        store.setSpan(2, for: .askAI)
                        store.setSpan(2, for: .notes)
                        store.applyPresetDashboard(slots: [.askAI, .notes, nil, nil])
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            // Notes Widget Customization Section
            notesCustomizationSection
            
            Divider().background(Color.white.opacity(0.12))
            
            // Clock Customization Section
            clockCustomizationSection
            
            Divider().background(Color.white.opacity(0.12))
            
            // AI Assistant Customization Section
            aiAssistantCustomizationSection
        }
    }
    
    // MARK: - Notes Widget Customization Section
    private var notesCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.98, green: 0.72, blue: 0.20).opacity(0.2))
                        .frame(width: 26, height: 26)
                    Image(systemName: "note.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.98, green: 0.72, blue: 0.20))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("QUICK NOTES WIDGET CUSTOMIZATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("Manage scratchpad options and unified AI copilot integration")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
            }
            
            // Toggle for Notes AI
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable AI Assistant in Notes")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Summarize notes, extract action items, and polish text directly within the note editor.")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
                
                Toggle("", isOn: $store.isNotesAIEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            
            // If Notes AI is enabled: Show Unified Login Status or Prompt to Login
            if store.isNotesAIEnabled {
                if AskAIService.shared.hasAnyCloudLogin {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Unified AI Login Active")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                            Text("Logged in via \(AskAIService.shared.currentLoginBadgeText). Active across both Notes and Ask AI.")
                                .font(.system(size: 9.5))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                        Spacer()
                        Text("Ready ✓")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.06)))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.orange)
                            Text("AI Login Required for Notes & Ask AI")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("To use AI in Notes and Ask AI, sign in with your Google account or configure an API key. Once logged in, your session is automatically shared between Notes and Ask AI.")
                            .font(.system(size: 9.5))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        HStack(spacing: 8) {
                            Button {
                                AskAIService.shared.connectGoogleAccount()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                    Text("Sign in with Google")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AIProvider.gemini.tintColor))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                withAnimation {
                                    AskAIService.shared.switchProvider(to: .gpt)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "key.fill")
                                    Text("Configure API Key Below")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.8)
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
    }
    
    // MARK: - Layout Mode Selection Section
    private var layoutModeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAYOUT ORIENTATION MODE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.secondaryText)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                ForEach(DashboardLayoutFlow.allCases) { flow in
                    Button {
                        FeedbackManager.playPin()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            store.dashboardLayoutFlow = flow
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: flow.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(flow.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(store.dashboardLayoutFlow == flow ? DesignSystem.accentColor : Color.white.opacity(0.05))
                        )
                        .foregroundColor(store.dashboardLayoutFlow == flow ? .white : DesignSystem.secondaryText)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(store.dashboardLayoutFlow == flow ? Color.white.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Mini Layout Preview
    private var layoutMiniPreviewSection: some View {
        let activeCount = store.activeDashboardWidgets.count
        
        return HStack(spacing: 16) {
            // Live Notch Silhouette Mini View
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.85))
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
                Group {
                    if store.dashboardLayoutFlow == .horizontalStrip {
                        // 4 side-by-side columns
                        HStack(spacing: 3) {
                            let count = max(1, activeCount)
                            ForEach(0..<count, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForSlot(i).opacity(0.75))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    } else if store.dashboardLayoutFlow == .bentoQuad || store.dashboardLayoutFlow == .adaptiveAuto {
                        if activeCount == 1 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignSystem.accentColor.opacity(0.6))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if activeCount == 2 {
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 2).fill(DesignSystem.accentColor.opacity(0.6))
                                RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.6))
                            }
                        } else if activeCount == 3 {
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 2).fill(DesignSystem.accentColor.opacity(0.6))
                                VStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.6))
                                    RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.6))
                                }
                            }
                        } else {
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2).fill(DesignSystem.accentColor.opacity(0.7))
                                    RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.6))
                                }
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.6))
                                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.6))
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(4)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    FeedbackManager.playHover()
                    NotchShellCoordinator.shared.previewDashboard(duration: 4.5)
                }
            }
            .onTapGesture {
                FeedbackManager.playHover()
                NotchShellCoordinator.shared.previewDashboard(duration: 5.0)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Mode: \(store.dashboardLayoutFlow.title)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(activeCount) of 4 Active")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(DesignSystem.accentColor.opacity(0.18)))
                        .lineLimit(1)
                }
                
                Text(stretchExplanationText(activeCount))
                    .font(.system(size: 10.5))
                    .foregroundColor(DesignSystem.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Live Preview on Notch Button
            Button {
                FeedbackManager.playHover()
                NotchShellCoordinator.shared.previewDashboard(duration: 4.0)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("Preview on Notch")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Capsule().fill(DesignSystem.accentColor.opacity(0.2)))
                .foregroundColor(DesignSystem.accentColor)
                .overlay(Capsule().strokeBorder(DesignSystem.accentColor.opacity(0.4), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .help("Expand the physical notch dashboard to preview live changes")
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    private func colorForSlot(_ index: Int) -> Color {
        switch index % 4 {
        case 0: return DesignSystem.accentColor
        case 1: return Color(red: 0.20, green: 0.50, blue: 0.98) // macOS System Blue
        case 2: return Color(red: 0.90, green: 0.62, blue: 0.30) // Warm Amber
        default: return Color(red: 0.30, green: 0.72, blue: 0.55) // Refined Sage
        }
    }
    
    private func stretchExplanationText(_ count: Int) -> String {
        if store.dashboardLayoutFlow == .horizontalStrip {
            return "Active widgets display side-by-side in a horizontal strip, auto-weighted by span."
        }
        switch count {
        case 0: return "Dashboard is empty. Drag widgets into slots above."
        case 1: return "1 widget expands to occupy 100% of the Notch dashboard canvas."
        case 2: return "2 widgets split 50% / 50% side-by-side."
        case 3: return "1 widget takes a 2-space tall column; 2 widgets stack beside it."
        default: return "All 4 quadrants active in a balanced 2×2 Bento Grid."
        }
    }
    
    // MARK: - Clock Customization Section
    private var clockCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLOCK WIDGET CUSTOMIZATION")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.secondaryText)
                .lineLimit(1)
            
            VStack(alignment: .leading, spacing: 12) {
                // Dial Style Picker Row
                HStack(spacing: 8) {
                    Text("Dial Aesthetics:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    ForEach(ClockDialStyle.allCases) { style in
                        Button {
                            store.clockDialStyle = style
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: style == .analog ? "clock" : "numbers.rectangle")
                                    .font(.system(size: 11))
                                Text(style.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
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
                
                // Toggles Row
                HStack(spacing: 24) {
                    Toggle("24-Hour Time", isOn: $store.clockIs24Hour)
                        .font(.system(size: 11, weight: .medium))
                        .toggleStyle(.switch)
                        .lineLimit(1)
                    
                    Toggle("Smooth Seconds", isOn: $store.clockShowSeconds)
                        .font(.system(size: 11, weight: .medium))
                        .toggleStyle(.switch)
                        .lineLimit(1)
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
    }
    
    // MARK: - AI Assistant Customization Section
    private var aiAssistantCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.68, green: 0.42, blue: 0.98).opacity(0.2))
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.68, green: 0.42, blue: 0.98))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI ASSISTANT (SIRI, GEMINI, CHATGPT)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("Configure intelligence engine, native Siri bridge, and cloud API keys")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
            }
            
            // Engine Selector Pills
            VStack(alignment: .leading, spacing: 6) {
                Text("DEFAULT PROVIDER")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(DesignSystem.secondaryText)
                
                HStack(spacing: 8) {
                    ForEach(AIProvider.allCases) { provider in
                        let isSelected = store.aiDefaultProvider == provider
                        Button {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                AskAIService.shared.switchProvider(to: provider)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: provider.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : provider.tintColor)
                                Text(provider.displayName)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? provider.tintColor.opacity(0.85) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Provider Specific Configuration
            if store.aiDefaultProvider == .siri {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AIProvider.siri.tintColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Native macOS Siri Integration")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                        Text("Zero configuration required. Interacts directly with macOS built-in Siri assistant with 0 MB background RAM overhead.")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    Spacer()
                    Button("Test Siri") {
                        AskAIService.shared.triggerSiri()
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AIProvider.siri.tintColor))
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            } else if store.aiDefaultProvider == .gemini {
                VStack(alignment: .leading, spacing: 10) {
                    if !store.connectedGoogleEmail.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Google Account Connected")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Text(store.connectedGoogleEmail)
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            Spacer()
                            Button("Disconnect") {
                                AskAIService.shared.disconnectGoogleAccount()
                            }
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.08)))
                    }
                    
                    HStack {
                        Button {
                            AskAIService.shared.connectGoogleAccount()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text(store.connectedGoogleEmail.isEmpty ? "Sign in with Google (Instant Zero-Key Login)" : "Open Gemini Web Workspace")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AIProvider.gemini.tintColor))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text(store.connectedGoogleEmail.isEmpty ? "Uses Google session without requiring API key" : "gemini.google.com")
                            .font(.system(size: 9.5))
                            .foregroundColor(DesignSystem.tertiaryText)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(store.connectedGoogleEmail.isEmpty ? "GOOGLE GEMINI API KEY" : "CUSTOM GEMINI API KEY OVERRIDE (OPTIONAL)")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(DesignSystem.secondaryText)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                                Text("Hardware AES-256 Vault")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        if !store.connectedGoogleEmail.isEmpty {
                            Text("Google Account (\(store.connectedGoogleEmail)) is active. A manual API key is completely optional.")
                                .font(.system(size: 9.5))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                        SecureField("AIzaSy... (optional override)", text: $store.geminiApiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
                    }
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MODEL")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(DesignSystem.secondaryText)
                            TextField("gemini-1.5-flash", text: $store.geminiModel)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RAM FOOTPRINT")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(DesignSystem.secondaryText)
                            Text("< 50 KB (Pure URLSession REST)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.vertical, 5)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button {
                            AskAIService.shared.openOpenAIKeyPage()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "key.fill")
                                Text("Get OpenAI API Key")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AIProvider.gpt.tintColor))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text("Opens platform.openai.com/api-keys")
                            .font(.system(size: 9.5))
                            .foregroundColor(DesignSystem.tertiaryText)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("OPENAI API KEY")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(DesignSystem.secondaryText)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                                Text("macOS Keychain AES-256")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        SecureField("sk-...", text: $store.openAIApiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
                    }
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MODEL")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(DesignSystem.secondaryText)
                            TextField("gpt-4o-mini", text: $store.gptModel)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RAM FOOTPRINT")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(DesignSystem.secondaryText)
                            Text("< 50 KB (Pure URLSession REST)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.vertical, 5)
                        }
                    }
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
    @ObservedObject private var store = SettingsStore.shared
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
                let currentSpan = store.span(for: widget)
                
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(widget.tintColor.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Image(systemName: widget.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(widget.tintColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(widget.title)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(title)
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Span Selector Button: 1 Space vs 2 Spaces
                    Button {
                        FeedbackManager.playClick()
                        let nextSpan = currentSpan == 1 ? 2 : 1
                        store.setSpan(nextSpan, for: widget)
                    } label: {
                        Text(currentSpan == 2 ? "2 Spaces" : "1 Space")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(currentSpan == 2 ? Color.orange : DesignSystem.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(Color.white.opacity(currentSpan == 2 ? 0.15 : 0.07)))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle slot span: 1 space or 2 spaces")
                    
                    // Eject / Remove Button
                    Button {
                        FeedbackManager.playClick()
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("Remove widget from slot")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(targetState.isTargeted ? DesignSystem.accentColor : Color.white.opacity(0.12), lineWidth: targetState.isTargeted ? 1.5 : 0.8)
                        )
                )
                .onDrag {
                    NSItemProvider(object: widget.rawValue as NSString)
                }
            } else {
                // Empty Slot Drop Placeholder
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .foregroundColor(targetState.isTargeted ? DesignSystem.accentColor : Color.white.opacity(0.25))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(targetState.isTargeted ? .white : DesignSystem.secondaryText)
                            .lineLimit(1)
                        Text("Drop widget here")
                            .font(.system(size: 8.5))
                            .foregroundColor(Color.white.opacity(0.3))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
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
        .frame(height: 50)
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
    @ObservedObject private var store = SettingsStore.shared
    let widget: DashboardWidgetType
    let isPlaced: Bool
    let placedSlotIndex: Int?
    let onQuickAssign: () -> Void
    let onEject: () -> Void
    
    var body: some View {
        let currentSpan = store.span(for: widget)
        
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(widget.tintColor.opacity(isPlaced ? 0.15 : 0.25))
                    .frame(width: 26, height: 26)
                Image(systemName: widget.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isPlaced ? widget.tintColor.opacity(0.6) : widget.tintColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(widget.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isPlaced ? DesignSystem.secondaryText : .white)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                
                if isPlaced, let idx = placedSlotIndex {
                    Text("In Slot \(idx + 1)")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(DesignSystem.accentColor)
                        .lineLimit(1)
                } else {
                    Text(widget.subtitle)
                        .font(.system(size: 8.5))
                        .foregroundColor(DesignSystem.tertiaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Span selector pill
            Button {
                FeedbackManager.playClick()
                let nextSpan = currentSpan == 1 ? 2 : 1
                store.setSpan(nextSpan, for: widget)
            } label: {
                Text(currentSpan == 2 ? "2 Sp" : "1 Sp")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(currentSpan == 2 ? Color.orange : DesignSystem.secondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(currentSpan == 2 ? 0.15 : 0.08)))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Set widget space: 1 space or 2 spaces")
            
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
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Assign to first open slot")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isPlaced ? Color.white.opacity(0.02) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isPlaced ? Color.white.opacity(0.06) : Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
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
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
