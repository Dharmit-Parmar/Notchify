import SwiftUI

public struct ModularDashboardView: View {
    @ObservedObject private var store = SettingsStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        let activeWidgets = store.activeDashboardWidgets
        
        Group {
            switch activeWidgets.count {
            case 0:
                emptyDashboardView
            case 1:
                oneWidgetView(activeWidgets[0])
            case 2:
                twoWidgetsView(activeWidgets[0], activeWidgets[1])
            case 3:
                threeWidgetsView(activeWidgets[0], activeWidgets[1], activeWidgets[2])
            default:
                fourWidgetsView
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(.opacity.combined(with: .scale(scale: 0.99)))
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: store.dashboardSlots)
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
    
    // MARK: - 1 Widget (Full Stage)
    private func oneWidgetView(_ widget: DashboardWidgetType) -> some View {
        Self.renderWidget(type: widget, span: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 2 Widgets (Side-by-Side 50/50 Split)
    private func twoWidgetsView(_ w1: DashboardWidgetType, _ w2: DashboardWidgetType) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Self.renderWidget(type: w1, span: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Self.renderWidget(type: w2, span: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 3 Widgets (1 Major Column + 2 Stacked Tiles)
    private func threeWidgetsView(_ w1: DashboardWidgetType, _ w2: DashboardWidgetType, _ w3: DashboardWidgetType) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Major left widget (tall)
            Self.renderWidget(type: w1, span: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Stacked right widgets (2 compact tiles)
            VStack(spacing: 10) {
                Self.renderWidget(type: w2, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Self.renderWidget(type: w3, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 4 Widgets (2x2 Bento Grid)
    private var fourWidgetsView: some View {
        let slots = store.dashboardSlots
        let w0 = slots[0] ?? .nowPlaying
        let w1 = slots[1] ?? .calendar
        let w2 = slots[2] ?? .notes
        let w3 = slots[3] ?? .clock
        
        return VStack(spacing: 10) {
            // Top Row
            HStack(spacing: 12) {
                Self.renderWidget(type: w0, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Self.renderWidget(type: w1, span: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Row
            HStack(spacing: 12) {
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
                Text("Customize your 4-slot layout with Notes, Calendar, Media, Mirror, and Clock.")
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
