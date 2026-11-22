import SwiftUI
import UniformTypeIdentifiers

public struct DashboardSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    // FIX: track which key/model field has focus so we can render a visible
    // focus ring — `.textFieldStyle(.plain)` removes the native one.
    private enum KeyField: Hashable { case geminiKey, geminiModel, openAIKey, openAIModel }
    @FocusState private var focusedField: KeyField?

    public init() {}

    // FIX: `Divider().background(...)` doesn't recolour the divider line.
    // A plain Rectangle does.
    private var themedDivider: some View {
        Rectangle()
            .fill(SettingsInk.tint(0.12))
            .frame(height: 1)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Header Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Modular Dashboard Grid")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(SettingsInk.primary)
                    .lineLimit(1)
                Text("Customize layout slots with Notes, Calendar, Media, Mirror, and Clock. Choose side-by-side strip, 2×2 bento, or smart adaptive auto-stretch.")
                    .font(.system(size: 12))
                    .foregroundColor(SettingsInk.secondary)
            }

            layoutMiniPreviewSection
            layoutModeSelectionSection
            layoutSlotsSection
            availableWidgetsPaletteSection
            quickLayoutPresetsSection

            themedDivider
            notesCustomizationSection

            themedDivider
            clockCustomizationSection

            themedDivider
            aiAssistantCustomizationSection

            themedDivider
            quickControlsCustomizationSection
        }
    }

    // MARK: - Slots Canvas

    private var layoutSlotsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DASHBOARD SLOTS CANVAS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(SettingsInk.secondary)
                    .lineLimit(1)

                Spacer()

                Text("Reorder, assign, or set 1-space / 2-space size")
                    .font(.system(size: 10.5))
                    .foregroundColor(SettingsInk.tertiary)
                    .lineLimit(1)
            }

            if store.dashboardLayoutFlow == .horizontalStrip {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        if index > 0 && store.dashboardSlots[index - 1] != nil && store.dashboardSlots[index] != nil {
                            Rectangle()
                                .stroke(SettingsInk.tint(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .frame(width: 1)
                                .padding(.vertical, 8)
                        }

                        SlotDropCard(
                            slotIndex: index,
                            title: "Slot \(index + 1)",
                            widget: store.dashboardSlots[index],
                            onDrop: { widget in store.setDashboardSlot(at: index, widget: widget) },
                            onClear: { store.setDashboardSlot(at: index, widget: nil) }
                        )
                    }
                }
            } else if store.dashboardLayoutFlow == .focusDominant {
                let hasBoth = store.dashboardSlots[0] != nil && store.dashboardSlots[1] != nil

                HStack(spacing: 0) {
                    SlotDropCard(
                        slotIndex: 0,
                        title: "Slot 1 (Dominant)",
                        widget: store.dashboardSlots[0],
                        onDrop: { widget in store.setDashboardSlot(at: 0, widget: widget) },
                        onClear: { store.setDashboardSlot(at: 0, widget: nil) }
                    )
                    .frame(maxWidth: .infinity)

                    if hasBoth {
                        DottedDividerView(totalWidth: 500)
                            .frame(height: 52)
                    } else {
                        Spacer().frame(width: 8)
                    }

                    SlotDropCard(
                        slotIndex: 1,
                        title: "Slot 2 (Companion)",
                        widget: store.dashboardSlots[1],
                        onDrop: { widget in store.setDashboardSlot(at: 1, widget: widget) },
                        onClear: { store.setDashboardSlot(at: 1, widget: nil) }
                    )
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "DashboardContainer")
            } else {
                let leftHasFilled = (store.dashboardSlots[0] != nil || store.dashboardSlots[2] != nil)
                let rightHasFilled = (store.dashboardSlots[1] != nil || store.dashboardSlots[3] != nil)

                HStack(spacing: 0) {
                    VStack(spacing: 10) {
                        SlotDropCard(
                            slotIndex: 0,
                            title: "Slot 1 (Top Left)",
                            widget: store.dashboardSlots[0],
                            onDrop: { widget in store.setDashboardSlot(at: 0, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 0, widget: nil) }
                        )

                        SlotDropCard(
                            slotIndex: 2,
                            title: "Slot 3 (Bottom Left)",
                            widget: store.dashboardSlots[2],
                            onDrop: { widget in store.setDashboardSlot(at: 2, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 2, widget: nil) }
                        )
                    }
                    .frame(maxWidth: .infinity)

                    if leftHasFilled && rightHasFilled {
                        DottedDividerView(totalWidth: 500)
                            .frame(height: 120)
                    } else {
                        Spacer().frame(width: 10)
                    }

                    VStack(spacing: 10) {
                        SlotDropCard(
                            slotIndex: 1,
                            title: "Slot 2 (Top Right)",
                            widget: store.dashboardSlots[1],
                            onDrop: { widget in store.setDashboardSlot(at: 1, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 1, widget: nil) }
                        )

                        SlotDropCard(
                            slotIndex: 3,
                            title: "Slot 4 (Bottom Right)",
                            widget: store.dashboardSlots[3],
                            onDrop: { widget in store.setDashboardSlot(at: 3, widget: widget) },
                            onClear: { store.setDashboardSlot(at: 3, widget: nil) }
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "DashboardContainer")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SettingsInk.tint(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.9)
                )
        )
    }

    // MARK: - Available Widgets Palette

    private var availableWidgetsPaletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AVAILABLE WIDGETS PALETTE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(SettingsInk.secondary)
                    .lineLimit(1)
                Spacer()
                Text("Drag card into slot or tap + to assign")
                    .font(.system(size: 10.5))
                    .foregroundColor(SettingsInk.tertiary)
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
                .fill(SettingsInk.tint(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.9)
                )
        )
    }

    // MARK: - Quick Layout Presets

    private var quickLayoutPresetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK LAYOUT PRESETS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(SettingsInk.secondary)
                .lineLimit(1)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                // FIX: spans → slots → flow. Applying flow first could let a
                // store that re-lays-out on flow change overwrite the spans.
                PresetButton(title: "Classic Duo", subtitle: "Media + Calendar") {
                    store.setSpan(2, for: .nowPlaying)
                    store.setSpan(2, for: .calendar)
                    store.applyPresetDashboard(slots: [.nowPlaying, .calendar, nil, nil])
                    store.dashboardLayoutFlow = .adaptiveAuto
                }

                PresetButton(title: "4 Side-by-Side Strip", subtitle: "Clock + Cal + Notes + Media") {
                    store.setSpan(1, for: .clock)
                    store.setSpan(1, for: .calendar)
                    store.setSpan(1, for: .notes)
                    store.setSpan(1, for: .nowPlaying)
                    store.applyPresetDashboard(slots: [.clock, .calendar, .notes, .nowPlaying])
                    store.dashboardLayoutFlow = .horizontalStrip
                }

                PresetButton(title: "3-Widget Studio", subtitle: "Notes (2-Space) + Clock + Cal") {
                    store.setSpan(2, for: .notes)
                    store.setSpan(1, for: .clock)
                    store.setSpan(1, for: .calendar)
                    store.applyPresetDashboard(slots: [.notes, .clock, .calendar, nil])
                    store.dashboardLayoutFlow = .horizontalStrip
                }

                PresetButton(title: "Productivity 4-Grid", subtitle: "Notes + Clock + Cal + Media") {
                    store.setSpan(1, for: .notes)
                    store.setSpan(1, for: .clock)
                    store.setSpan(1, for: .calendar)
                    store.setSpan(1, for: .nowPlaying)
                    store.applyPresetDashboard(slots: [.notes, .clock, .calendar, .nowPlaying])
                    store.dashboardLayoutFlow = .bentoQuad
                }

                PresetButton(title: "AI & Notes Studio", subtitle: "Ask AI (2-Sp) + Notes (2-Sp)") {
                    store.setSpan(2, for: .askAI)
                    store.setSpan(2, for: .notes)
                    store.applyPresetDashboard(slots: [.askAI, .notes, nil, nil])
                    store.dashboardLayoutFlow = .adaptiveAuto
                }

                PresetButton(title: "Power Dashboard", subtitle: "Battery + Clock + Cal + Notes") {
                    store.setSpan(1, for: .battery)
                    store.setSpan(1, for: .clock)
                    store.setSpan(1, for: .calendar)
                    store.setSpan(1, for: .notes)
                    store.applyPresetDashboard(slots: [.battery, .clock, .calendar, .notes])
                    store.dashboardLayoutFlow = .horizontalStrip
                }
            }
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
                        .foregroundColor(SettingsInk.primary)
                    Text("Manage scratchpad options and unified AI copilot integration")
                        .font(.system(size: 10))
                        .foregroundColor(SettingsInk.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable AI Assistant in Notes")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(SettingsInk.primary)
                    Text("Summarize notes, extract action items, and polish text directly within the note editor.")
                        .font(.system(size: 10))
                        .foregroundColor(SettingsInk.secondary)
                }

                Spacer()

                Toggle("", isOn: $store.isNotesAIEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(SettingsInk.tint(0.04)))

            if store.isNotesAIEnabled {
                if AskAIService.shared.hasAnyCloudLogin {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Unified AI Login Active")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(SettingsInk.primary)
                            Text("Logged in via \(AskAIService.shared.currentLoginBadgeText). Active across both Notes and Ask AI.")
                                .font(.system(size: 9.5))
                                .foregroundColor(SettingsInk.secondary)
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
                            Text("AI API Key Required for Notes & Ask AI")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(SettingsInk.primary)
                        }
                        Text("To use AI in Notes and Ask AI, configure a Google Gemini or OpenAI API key. You can get a free Gemini key from Google AI Studio.")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.secondary)

                        HStack(spacing: 8) {
                            Button {
                                AskAIService.shared.connectGoogleAccount()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Get Free Gemini Key")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(SettingsInk.primary)
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
                                .foregroundColor(SettingsInk.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(SettingsInk.tint(0.12)))
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
                .fill(SettingsInk.tint(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.9)
                )
        )
    }

    // MARK: - Layout Mode Selection Section

    private var layoutModeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAYOUT ORIENTATION MODE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(SettingsInk.secondary)
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
                                .fill(store.dashboardLayoutFlow == flow ? DesignSystem.accentColor : SettingsInk.tint(0.05))
                        )
                        .foregroundColor(store.dashboardLayoutFlow == flow ? SettingsInk.primary : SettingsInk.secondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(store.dashboardLayoutFlow == flow ? SettingsInk.tint(0.25) : SettingsInk.tint(0.08), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerHoverCursor()
                    .focusable()
                    .accessibilityLabel(flow.title)
                    .accessibilityAddTraits(store.dashboardLayoutFlow == flow ? [.isButton, .isSelected] : .isButton)
                }
            }

            if store.dashboardLayoutFlow == .focusDominant {
                // FIX: previously this row was a Button whose label contained
                // a Toggle bound to the same state. Clicking the toggle fired
                // BOTH the outer button action and the toggle binding —
                // double-toggle, ends up where it started. Only the toggle is
                // interactive now.
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Auto-Rotate Companion Widget")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(SettingsInk.primary)
                            Text("Default: OFF")
                                .font(.system(size: 8.5))
                                .foregroundColor(Color.orange)
                        }
                        Text("Cycles through secondary tools every 30s only while the notch is collapsed.")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $store.autoRotateCompanion)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SettingsInk.tint(0.03)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Auto-Rotate Companion Widget")
                .accessibilityHint("When enabled, periodically cycles the companion widget every 30 seconds only while the notch is hidden.")
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
                            .strokeBorder(SettingsInk.tint(0.18), lineWidth: 0.8)
                    )

                // Camera notch simulator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black)
                    .frame(width: 32, height: 7)

                // FIX: the mini preview was fabricating bars when the
                // dashboard was empty:
                //   • horizontalStrip used `max(1, activeCount)` → 1 bar at 0
                //   • focusDominant unconditionally drew 2 bars
                //   • bentoQuad / adaptiveAuto fell into the 4-bar `else`
                //     branch when `activeCount == 0`
                // Each branch now explicitly handles `activeCount == 0`.
                Group {
                    if store.dashboardLayoutFlow == .horizontalStrip {
                        if activeCount == 0 {
                            emptyPreviewPlaceholder
                        } else {
                            HStack(spacing: 3) {
                                ForEach(0..<activeCount, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(colorForSlot(i).opacity(0.75))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                    } else if store.dashboardLayoutFlow == .focusDominant {
                        if activeCount == 0 {
                            emptyPreviewPlaceholder
                        } else if activeCount == 1 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DesignSystem.accentColor.opacity(0.85))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DesignSystem.accentColor.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                Rectangle()
                                    .stroke(SettingsInk.tint(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                    .frame(width: 1)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange.opacity(0.75))
                                    .frame(width: 32)
                            }
                        }
                    } else if store.dashboardLayoutFlow == .bentoQuad || store.dashboardLayoutFlow == .adaptiveAuto {
                        if activeCount == 0 {
                            emptyPreviewPlaceholder
                        } else if activeCount == 1 {
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
                        .foregroundColor(SettingsInk.primary)
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
                    .foregroundColor(SettingsInk.secondary)
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
        .background(RoundedRectangle(cornerRadius: 10).fill(SettingsInk.tint(0.03)))
    }

    // FIX: shared empty state for every branch of the mini preview.
    private var emptyPreviewPlaceholder: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 10))
            Text("Empty")
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundColor(Color.white.opacity(0.3))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func colorForSlot(_ index: Int) -> Color {
        switch index % 4 {
        case 0: return DesignSystem.accentColor
        case 1: return Color(red: 0.20, green: 0.50, blue: 0.98)
        case 2: return Color(red: 0.90, green: 0.62, blue: 0.30)
        default: return Color(red: 0.30, green: 0.72, blue: 0.55)
        }
    }

    private func stretchExplanationText(_ count: Int) -> String {
        if store.dashboardLayoutFlow == .focusDominant {
            return "70% primary dominant widget + 30% companion glance widget. Live draggable divider."
        }
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
                .foregroundColor(SettingsInk.secondary)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Dial Aesthetics:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(SettingsInk.primary)
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
                                    .fill(store.clockDialStyle == style ? DesignSystem.accentColor : SettingsInk.tint(0.08))
                            )
                            .foregroundColor(store.clockDialStyle == style ? SettingsInk.primary : SettingsInk.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

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
                .fill(SettingsInk.tint(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.9)
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
                        .foregroundColor(SettingsInk.primary)
                    Text("Configure intelligence engine, native Siri bridge, and cloud API keys")
                        .font(.system(size: 10))
                        .foregroundColor(SettingsInk.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("DEFAULT PROVIDER")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(SettingsInk.secondary)

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
                                    .foregroundColor(isSelected ? SettingsInk.primary : provider.tintColor)
                                Text(provider.displayName)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? SettingsInk.primary : SettingsInk.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? provider.tintColor.opacity(0.85) : SettingsInk.tint(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? SettingsInk.tint(0.25) : SettingsInk.tint(0.08), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if store.aiDefaultProvider == .siri {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AIProvider.siri.tintColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Native macOS Siri Integration")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(SettingsInk.primary)
                        Text("Zero configuration required. Interacts directly with macOS built-in Siri assistant with 0 MB background RAM overhead.")
                            .font(.system(size: 10))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                    Button("Test Siri") {
                        AskAIService.shared.triggerSiri()
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(SettingsInk.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AIProvider.siri.tintColor))
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(SettingsInk.tint(0.04)))
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
                                    .foregroundColor(SettingsInk.primary)
                                Text(store.connectedGoogleEmail)
                                    .font(.system(size: 10))
                                    .foregroundColor(SettingsInk.secondary)
                            }
                            Spacer()
                            Button("Disconnect") {
                                AskAIService.shared.disconnectGoogleAccount()
                            }
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(SettingsInk.tint(0.08)))
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
                                Image(systemName: "arrow.up.right.square")
                                Text("Get Gemini API Key (Google AI Studio)")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SettingsInk.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AIProvider.gemini.tintColor))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("aistudio.google.com")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("GOOGLE GEMINI API KEY")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(SettingsInk.secondary)
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
                        Text("Enter your Google AI Studio API key to enable Gemini features across Notes and Ask AI.")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.secondary)
                        SecureField("AIzaSy...", text: $store.geminiApiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(SettingsInk.primary)
                            .focused($focusedField, equals: .geminiKey)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(SettingsInk.tint(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(
                                                focusedField == .geminiKey ? DesignSystem.accentColor : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MODEL")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(SettingsInk.secondary)
                            TextField("gemini-1.5-flash", text: $store.geminiModel)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(SettingsInk.primary)
                                .focused($focusedField, equals: .geminiModel)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(SettingsInk.tint(0.07))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(
                                                    focusedField == .geminiModel ? DesignSystem.accentColor : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("RAM FOOTPRINT")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(SettingsInk.secondary)
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
                            .foregroundColor(SettingsInk.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AIProvider.gpt.tintColor))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("Opens platform.openai.com/api-keys")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("OPENAI API KEY")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(SettingsInk.secondary)
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
                            .foregroundColor(SettingsInk.primary)
                            .focused($focusedField, equals: .openAIKey)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(SettingsInk.tint(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(
                                                focusedField == .openAIKey ? DesignSystem.accentColor : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MODEL")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(SettingsInk.secondary)
                            TextField("gpt-4o-mini", text: $store.gptModel)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(SettingsInk.primary)
                                .focused($focusedField, equals: .openAIModel)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(SettingsInk.tint(0.07))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(
                                                    focusedField == .openAIModel ? DesignSystem.accentColor : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("RAM FOOTPRINT")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(SettingsInk.secondary)
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
                .fill(SettingsInk.tint(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.9)
                )
        )
    }

    // MARK: - Quick Controls Customization Section
    private var quickControlsCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(DesignSystem.accentColor.opacity(0.2))
                        .frame(width: 26, height: 26)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("SYSTEM QUICK CONTROLS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                    Text("Dedicated hardware controls situated beneath the dashboard grid")
                        .font(.system(size: 10))
                        .foregroundColor(SettingsInk.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Quick Controls in Dashboard")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(SettingsInk.primary)
                    Text("Reveals a dedicated system control bar beneath the widgets on hover.")
                        .font(.system(size: 10))
                        .foregroundColor(SettingsInk.secondary)
                }

                Spacer()

                Toggle("", isOn: $store.showQuickControls)
                    .toggleStyle(.switch)
                    .tint(DesignSystem.accentColor)
                    .accessibilityLabel("Show Quick Controls in Dashboard")
            }
            .padding(10)
            .background(SettingsInk.tint(0.04))
            .cornerRadius(8)

            if store.showQuickControls {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep Quick Controls Pinned Open")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(SettingsInk.primary)
                        Text("Always display the expanded control sliders when the dashboard is visible.")
                            .font(.system(size: 10))
                            .foregroundColor(SettingsInk.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $store.quickControlsPinned)
                        .toggleStyle(.switch)
                        .tint(DesignSystem.accentColor)
                        .accessibilityLabel("Keep Quick Controls Pinned Open")
                }
                .padding(10)
                .background(SettingsInk.tint(0.04))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ENABLED CONTROLS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(SettingsInk.secondary)

                    ForEach(QuickControlKind.allCases) { kind in
                        let isEnabled = store.enabledQuickControls.contains(kind)
                        HStack(spacing: 10) {
                            Image(systemName: kind.iconName)
                                .font(.system(size: 11))
                                .foregroundColor(isEnabled ? DesignSystem.accentColor : SettingsInk.secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(SettingsInk.primary)

                                Text(kind == .volume ? "Hardware synchronized via Core Audio HAL" : (kind == .brightness ? "System Managed (Quick Displays Settings Route)" : "Hardware Managed (Keyboard F5/F6 & Keyboard Settings)"))
                                    .font(.system(size: 9))
                                    .foregroundColor(SettingsInk.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding<Bool>(
                                get: { store.enabledQuickControls.contains(kind) },
                                set: { newValue in
                                    if newValue {
                                        if !store.enabledQuickControls.contains(kind) {
                                            store.enabledQuickControls.append(kind)
                                        }
                                    } else {
                                        store.enabledQuickControls.removeAll(where: { $0 == kind })
                                    }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .accessibilityLabel("Enable \(kind.title)")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(SettingsInk.tint(0.02))
                        .cornerRadius(6)
                    }
                }

                Button(action: {
                    store.resetQuickControlsSettings()
                    FeedbackManager.playClick()
                }) {
                    Text("Reset Quick Controls to Default")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(SettingsInk.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(SettingsInk.tint(0.15), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SettingsInk.tint(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.9)
                )
        )
    }
}

// MARK: - Drop Target State
// NOTE / COMPATIBILITY FIX:
// When compiling via Swift CLI with Apple Command Line Tools (without full Xcode.app installed),
// `@State` invokes the external macro `SwiftUIMacros.StateMacro` which is not present in CLT:
//   "error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found"
// We use `@StateObject private var targetState = DropTargetState()` to bypass the macro requirement
// and ensure compilation succeeds under CLI/release builds.
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

    // NOTE: Using @StateObject instead of @State to avoid SwiftUIMacros.StateMacro CLT error.
    @StateObject private var targetState = DropTargetState()

    var body: some View {
        ZStack {
            if let widget = widget {
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
                            .foregroundColor(SettingsInk.primary)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(title)
                            .font(.system(size: 9))
                            .foregroundColor(SettingsInk.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        FeedbackManager.playClick()
                        let nextSpan = currentSpan == 1 ? 2 : 1
                        store.setSpan(nextSpan, for: widget)
                    } label: {
                        Text(currentSpan == 2 ? "2 Spaces" : "1 Space")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(currentSpan == 2 ? Color.orange : SettingsInk.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(SettingsInk.tint(currentSpan == 2 ? 0.15 : 0.07)))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle slot span: 1 space or 2 spaces")

                    Button {
                        FeedbackManager.playClick()
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(SettingsInk.tint(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("Remove widget from slot")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SettingsInk.tint(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(targetState.isTargeted ? DesignSystem.accentColor : SettingsInk.tint(0.12), lineWidth: targetState.isTargeted ? 1.5 : 0.8)
                        )
                )
                .onDrag {
                    NSItemProvider(object: widget.rawValue as NSString)
                }
            } else {
                Button {
                    if let firstUnplaced = DashboardWidgetType.allCases.first(where: { !store.dashboardSlots.contains($0) }) {
                        FeedbackManager.playPin()
                        store.setDashboardSlot(at: slotIndex, widget: firstUnplaced)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(targetState.isTargeted ? DesignSystem.accentColor : SettingsInk.tint(0.25))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(targetState.isTargeted ? SettingsInk.primary : SettingsInk.secondary)
                                .lineLimit(1)
                            Text("Click or drop to assign")
                                .font(.system(size: 8.5))
                                .foregroundColor(SettingsInk.tint(0.3))
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                targetState.isTargeted ? DesignSystem.accentColor : SettingsInk.tint(0.15),
                                style: StrokeStyle(lineWidth: targetState.isTargeted ? 1.5 : 1.0, dash: [4, 4])
                            )
                            .background(targetState.isTargeted ? DesignSystem.accentColor.opacity(0.08) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                .accessibilityLabel("\(title) Empty Slot")
                .accessibilityHint("Click to assign the first available widget, or drag and drop a widget here.")
            }
        }
        .frame(height: 50)
        .onDrop(of: [.text, .plainText], isTargeted: $targetState.isTargeted) { providers in
            guard let provider = providers.first,
                  provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                    || provider.hasItemConformingToTypeIdentifier(UTType.text.identifier)
            else {
                return false
            }
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                guard let raw = string as? String,
                      let droppedType = DashboardWidgetType(rawValue: raw) else { return }
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
            Button {
                if isPlaced {
                    FeedbackManager.playClick()
                    let nextSpan = currentSpan == 1 ? 2 : 1
                    store.setSpan(nextSpan, for: widget)
                } else {
                    FeedbackManager.playPin()
                    onQuickAssign()
                }
            } label: {
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
                            .foregroundColor(isPlaced ? SettingsInk.secondary : DesignSystem.primaryText)
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
                                .foregroundColor(SettingsInk.tertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerHoverCursor()
            .accessibilityLabel("\(widget.title) Widget")
            .accessibilityHint(isPlaced ? "Placed in slot. Click to toggle width." : "Click to assign to first available slot.")

            Button {
                FeedbackManager.playClick()
                let nextSpan = currentSpan == 1 ? 2 : 1
                store.setSpan(nextSpan, for: widget)
            } label: {
                Text(currentSpan == 2 ? "2 Sp" : "1 Sp")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(currentSpan == 2 ? Color.orange : SettingsInk.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(SettingsInk.tint(currentSpan == 2 ? 0.15 : 0.08)))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .pointerHoverCursor()
            .help("Set widget space: 1 space or 2 spaces")

            if isPlaced {
                Button {
                    FeedbackManager.playClick()
                    onEject()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(SettingsInk.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                .help("Remove from slot")
            } else {
                Button {
                    FeedbackManager.playPin()
                    onQuickAssign()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(SettingsInk.primary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(SettingsInk.tint(0.12)))
                }
                .buttonStyle(.plain)
                .pointerHoverCursor()
                .help("Assign to first open slot")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isPlaced ? SettingsInk.tint(0.02) : SettingsInk.tint(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isPlaced ? SettingsInk.tint(0.06) : SettingsInk.tint(0.12), lineWidth: 0.8)
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
                    .foregroundColor(SettingsInk.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(SettingsInk.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SettingsInk.tint(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(SettingsInk.tint(0.1), lineWidth: 0.8)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerHoverCursor()
        .focusable()
        .accessibilityLabel(title)
        .accessibilityHint("Applies preset layout: \(subtitle)")
    }
}
