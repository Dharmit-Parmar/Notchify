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
        Group {
            switch widgets.count {
            case 1:
                oneWidgetView(widgets[0])
            case 2:
                twoWidgetsView(widgets[0], widgets[1])
            case 3:
                threeWidgetsBentoView(widgets)
            default:
                fourWidgetsBentoView(widgets)
            }
        }
    }
    
    // MARK: - Layout Flow 3: Smart Adaptive
    private func adaptiveAutoView(_ widgets: [DashboardWidgetType]) -> some View {
        Group {
            switch widgets.count {
            case 1:
                oneWidgetView(widgets[0])
            case 2:
                twoWidgetsView(widgets[0], widgets[1])
            case 3:
                threeWidgetsBentoView(widgets)
            default:
                fourWidgetsBentoView(widgets)
            }
        }
    }
    
    // MARK: - 1 Widget (Full Stage)
    private func oneWidgetView(_ widget: DashboardWidgetType) -> some View {
        Self.renderWidget(type: widget, span: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 2 Widgets (Side-by-Side 50/50 Split)
    private func twoWidgetsView(_ w1: DashboardWidgetType, _ w2: DashboardWidgetType) -> some View {
        let span1 = store.span(for: w1)
        let span2 = store.span(for: w2)
        
        return HStack(alignment: .top, spacing: 10) {
            Self.renderWidget(type: w1, span: max(2, span1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Self.renderWidget(type: w2, span: max(2, span2))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 3 Widgets (Primary Major Column + 2 Stacked Tiles)
    private func threeWidgetsBentoView(_ widgets: [DashboardWidgetType]) -> some View {
        // Find which widget requested span 2, default to the first
        let primaryIndex = widgets.firstIndex(where: { store.span(for: $0) == 2 }) ?? 0
        let primaryWidget = widgets[primaryIndex]
        var secondaryWidgets = widgets
        secondaryWidgets.remove(at: primaryIndex)
        let sec1 = secondaryWidgets[0]
        let sec2 = secondaryWidgets[1]
        
        return HStack(alignment: .top, spacing: 10) {
            if primaryIndex == 0 {
                // Major left widget (tall)
                Self.renderWidget(type: primaryWidget, span: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Stacked right widgets (2 compact tiles)
                VStack(spacing: 8) {
                    Self.renderWidget(type: sec1, span: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Self.renderWidget(type: sec2, span: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Stacked left widgets (2 compact tiles)
                VStack(spacing: 8) {
                    Self.renderWidget(type: sec1, span: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Self.renderWidget(type: sec2, span: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Major right widget (tall)
                Self.renderWidget(type: primaryWidget, span: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - 4 Widgets (2×2 Bento Grid)
    private func fourWidgetsBentoView(_ widgets: [DashboardWidgetType]) -> some View {
        let w0 = widgets[0]
        let w1 = widgets[1]
        let w2 = widgets.count > 2 ? widgets[2] : widgets[0]
        let w3 = widgets.count > 3 ? widgets[3] : widgets[1]
        
        return VStack(spacing: 8) {
            // Top Row
            HStack(spacing: 10) {
                Self.renderWidget(type: w0, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Self.renderWidget(type: w1, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Row
            HStack(spacing: 10) {
                Self.renderWidget(type: w2, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Self.renderWidget(type: w3, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
