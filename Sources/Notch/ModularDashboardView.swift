import SwiftUI

public struct ModularDashboardView: View {
    @ObservedObject private var store = SettingsStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        let activeWidgets = store.activeDashboardWidgets
        
        Group {
            if activeWidgets.isEmpty {
                emptyDashboardView
            } else {
                switch store.dashboardLayoutFlow {
                case .horizontalStrip:
                    horizontalStripView(activeWidgets)
                case .bentoQuad:
                    bentoQuadView(activeWidgets)
                case .adaptiveAuto:
                    adaptiveAutoView(activeWidgets)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(.opacity.combined(with: .scale(scale: 0.99)))
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: store.dashboardSlots)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: store.dashboardLayoutFlow)
    }
    
    // MARK: - Render Widget by Type and Span
    @ViewBuilder
    public static func renderWidget(type: DashboardWidgetType, span: Int) -> some View {
        switch type {
        case .nowPlaying:
            NowPlayingAdaptiveWidgetView(span: span)
        case .calendar:
            CalendarAdaptiveWidgetView(span: span)
        case .notes:
            NotesWidgetView(span: span)
        case .clock:
            ClockWidgetView(span: span)
        case .mirror:
            MirrorAdaptiveWidgetView(span: span)
        case .askAI:
            AskAIWidgetView(span: span)
        }
    }
    
    // MARK: - Layout Flow 1: 4 Side-by-Side Horizontal Strip
    private func horizontalStripView(_ widgets: [DashboardWidgetType]) -> some View {
        GeometryReader { geo in
            let count = widgets.count
            let spacing: CGFloat = 8.0
            let totalSpacing = CGFloat(max(0, count - 1)) * spacing
            let availableWidth = max(0, geo.size.width - totalSpacing)
            
            HStack(spacing: spacing) {
                ForEach(widgets) { widget in
                    let (widgetSpan, widgetWidth): (Int, CGFloat) = {
                        if count == 4 {
                            // Enforce equal 25% share for each widget (widgetSpan = 1) in compact glance
                            return (1, availableWidth * 0.25)
                        } else if count == 3 {
                            // Allocate 50% width to the widget with span 2 and 25% each to the other two widgets
                            let span2Index = widgets.firstIndex(where: { store.span(for: $0) == 2 }) ?? 0
                            if widget == widgets[span2Index] {
                                return (2, availableWidth * 0.50)
                            } else {
                                return (1, availableWidth * 0.25)
                            }
                        } else {
                            let totalSpan = widgets.reduce(0) { $0 + store.span(for: $1) }
                            let safeTotalSpan = max(1, totalSpan)
                            let span = store.span(for: widget)
                            let width = (CGFloat(span) / CGFloat(safeTotalSpan)) * availableWidth
                            return (span, width)
                        }
                    }()
                    
                    Self.renderWidget(type: widget, span: widgetSpan)
                        .frame(width: max(130, widgetWidth), height: geo.size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Layout Flow 2: 2×2 Bento Quad
    private func bentoQuadView(_ widgets: [DashboardWidgetType]) -> some View {
        slotBasedBentoView()
    }
    
    // MARK: - Layout Flow 3: Smart Adaptive
    private func adaptiveAutoView(_ widgets: [DashboardWidgetType]) -> some View {
        slotBasedBentoView()
    }
    
    // MARK: - 1 Widget (Full Stage)
    private func oneWidgetView(_ widget: DashboardWidgetType) -> some View {
        Self.renderWidget(type: widget, span: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - True Slot-Based Column Layout (Respects exact Top-Left, Top-Right, Bottom-Left, Bottom-Right placement)
    private func slotBasedBentoView() -> some View {
        // Slot 0 (Top-Left) & Slot 2 (Bottom-Left) form Column 0 (Left)
        // Slot 1 (Top-Right) & Slot 3 (Bottom-Right) form Column 1 (Right)
        let s0 = store.dashboardSlots.indices.contains(0) ? store.dashboardSlots[0] : nil
        let s1 = store.dashboardSlots.indices.contains(1) ? store.dashboardSlots[1] : nil
        let s2 = store.dashboardSlots.indices.contains(2) ? store.dashboardSlots[2] : nil
        let s3 = store.dashboardSlots.indices.contains(3) ? store.dashboardSlots[3] : nil
        
        let leftCol = [s0, s2].compactMap { $0 }
        let rightCol = [s1, s3].compactMap { $0 }
        
        if leftCol.isEmpty && rightCol.isEmpty {
            return AnyView(emptyDashboardView)
        }
        
        if leftCol.count + rightCol.count == 1 {
            let single = leftCol.first ?? rightCol.first!
            return AnyView(oneWidgetView(single))
        }
        
        if leftCol.isEmpty {
            return AnyView(renderSingleColumn(widgets: rightCol))
        }
        if rightCol.isEmpty {
            return AnyView(renderSingleColumn(widgets: leftCol))
        }
        
        return AnyView(
            HStack(alignment: .top, spacing: 10) {
                // Left Column (Slot 0 top, Slot 2 bottom)
                renderColumnView(widgets: leftCol, oppositeCount: rightCol.count)
                
                // Right Column (Slot 1 top, Slot 3 bottom)
                renderColumnView(widgets: rightCol, oppositeCount: leftCol.count)
            }
        )
    }
    
    @ViewBuilder
    private func renderColumnView(widgets: [DashboardWidgetType], oppositeCount: Int) -> some View {
        if widgets.count == 1 {
            // If the opposite column has 2 stacked widgets, this widget spans full vertical height (span: 2)
            let span = oppositeCount > 1 ? 2 : max(1, store.span(for: widgets[0]))
            Self.renderWidget(type: widgets[0], span: span)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Stacked widgets in this column (e.g. Clock on top, Ask AI directly below it!)
            VStack(spacing: 8) {
                Self.renderWidget(type: widgets[0], span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Self.renderWidget(type: widgets[1], span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private func renderSingleColumn(widgets: [DashboardWidgetType]) -> some View {
        if widgets.count == 1 {
            oneWidgetView(widgets[0])
        } else {
            HStack(spacing: 10) {
                Self.renderWidget(type: widgets[0], span: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Self.renderWidget(type: widgets[1], span: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Empty Dashboard
    private var emptyDashboardView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 48)
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 22))
                    .foregroundColor(DesignSystem.accentColor)
            }
            
            VStack(spacing: 4) {
                Text("Empty Dashboard")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Customize your layout with Notes, Calendar, Media, Mirror, and Clock.")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                AppDelegate.openSettingsWindow()
            } label: {
                Text("Open Dashboard Settings")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(DesignSystem.accentColor))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
                )
        )
    }
}
