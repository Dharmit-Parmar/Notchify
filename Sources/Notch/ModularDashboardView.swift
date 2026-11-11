import SwiftUI

// MARK: - Dotted Vertical Divider for Live Drag-Resizing
@MainActor
public final class DividerUIState: ObservableObject {
    @Published public var isHovered: Bool = false
    @Published public var isDragging: Bool = false
    @Published public var previewRatio: CGFloat? = nil
    @Published public var lastHapticSnap: CGFloat? = nil
}

public struct DottedDividerView: View {
    @ObservedObject private var store = SettingsStore.shared
    @StateObject private var uiState = DividerUIState()
    let totalWidth: CGFloat
    
    public init(totalWidth: CGFloat) {
        self.totalWidth = totalWidth
    }
    
    public var body: some View {
        ZStack {
            // Invisible wider hit-target area (16pt wide) for easy grabbing
            Rectangle()
                .fill(Color.clear)
                .frame(width: 16)
                .contentShape(Rectangle())
            
            // Dotted vertical line
            LineShape()
                .stroke(
                    uiState.isDragging ? DesignSystem.accentColor : (uiState.isHovered ? Color.white.opacity(0.65) : Color.white.opacity(0.25)),
                    style: StrokeStyle(lineWidth: uiState.isDragging ? 1.5 : 1.0, lineCap: .round, dash: [3, 4])
                )
                .frame(width: 2)
            
            // Small grab handle pill on hover/drag
            if uiState.isHovered || uiState.isDragging {
                Capsule()
                    .fill(uiState.isDragging ? DesignSystem.accentColor : Color.white.opacity(0.85))
                    .frame(width: 4, height: 26)
                    .shadow(color: Color.black.opacity(0.4), radius: 2)
                    .transition(.opacity)
            }
        }
        .frame(width: 16)
        .frame(maxHeight: .infinity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                uiState.isHovered = hovering
            }
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(coordinateSpace: .named("DashboardContainer"))
                .onChanged { value in
                    uiState.isDragging = true
                    let x = value.location.x
                    guard totalWidth > 0 else { return }
                    var rawRatio = x / totalWidth
                    
                    // Clamp to min/max ratio ensuring minimum widget usable width of 140 pt
                    let minAllowedRatio = max(0.20, 140.0 / totalWidth)
                    let maxAllowedRatio = min(0.80, 1.0 - (140.0 / totalWidth))
                    rawRatio = min(maxAllowedRatio, max(minAllowedRatio, rawRatio))
                    
                    // Snap to 1/3 (~0.333), 1/2 (0.500), 2/3 (~0.667) within 12pt threshold
                    let snapTargets: [CGFloat] = [1.0 / 3.0, 0.50, 2.0 / 3.0]
                    var snappedRatio = rawRatio
                    let thresholdRatio = 12.0 / totalWidth
                    
                    for target in snapTargets {
                        if abs(rawRatio - target) <= thresholdRatio {
                            snappedRatio = target
                            if uiState.lastHapticSnap != target {
                                FeedbackManager.playPin()
                                uiState.lastHapticSnap = target
                            }
                            break
                        }
                    }
                    if snapTargets.allSatisfy({ abs(rawRatio - $0) > thresholdRatio }) {
                        uiState.lastHapticSnap = nil
                    }
                    
                    // Track ratio in local state during drag; only persist when drag ends
                    uiState.previewRatio = snappedRatio
                }
                .onEnded { _ in
                    if let finalRatio = uiState.previewRatio {
                        store.dashboardSplitRatio = finalRatio
                    }
                    uiState.isDragging = false
                    uiState.previewRatio = nil
                    uiState.lastHapticSnap = nil
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                FeedbackManager.playClick()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    store.dashboardSplitRatio = 0.50
                }
            }
        )
        .focusable()
        .onKeyPress(.leftArrow) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                let newRatio = max(0.20, store.dashboardSplitRatio - 0.05)
                store.dashboardSplitRatio = newRatio
            }
            FeedbackManager.playClick()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                let newRatio = min(0.80, store.dashboardSplitRatio + 0.05)
                store.dashboardSplitRatio = newRatio
            }
            FeedbackManager.playClick()
            return .handled
        }
        .accessibilityLabel("Dashboard Slot Resize Divider")
        .accessibilityValue("\(Int(store.dashboardSplitRatio * 100)) percent left, \(Int((1.0 - store.dashboardSplitRatio) * 100)) percent right")
        .accessibilityHint("Drag or use left and right arrow keys to resize columns. Double-click to reset to 50/50.")
    }
}

// Vertical line shape for dotted divider
struct LineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 6))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 6))
        return path
    }
}

// MARK: - Auto-Rotate Companion Manager for Focus Mode
@MainActor
public final class FocusCompanionRotationManager: ObservableObject {
    public static let shared = FocusCompanionRotationManager()
    private var lastRotationDate: Date = .distantPast
    private var timer: Timer?
    
    private init() {
        startTimer()
    }
    
    public func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateRotation()
            }
        }
        t.tolerance = 5.0
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    public func evaluateRotation() {
        let store = SettingsStore.shared
        guard store.dashboardLayoutFlow == .focusDominant, store.autoRotateCompanion else { return }
        
        // Strict guard: NEVER change while expanded! Only while HIDDEN (collapsed)
        guard !NotchShellCoordinator.shared.isExpanded else { return }
        
        // Strict guard: at most once every 30 seconds
        let now = Date()
        guard now.timeIntervalSince(lastRotationDate) >= 30.0 else { return }
        
        let allWidgets = DashboardWidgetType.allCases
        let dominantSlot = store.focusDominantSlotIndex
        let dominantWidget = store.dashboardSlots.indices.contains(dominantSlot) ? store.dashboardSlots[dominantSlot] : store.dashboardSlots.compactMap({ $0 }).first
        
        let candidates = allWidgets.filter { $0 != dominantWidget }
        guard !candidates.isEmpty else { return }
        
        let companionSlotIndex = (dominantSlot == 0) ? 1 : 0
        let currentCompanion = store.dashboardSlots.indices.contains(companionSlotIndex) ? store.dashboardSlots[companionSlotIndex] : nil
        
        let nextIndex: Int
        if let current = currentCompanion, let idx = candidates.firstIndex(of: current) {
            nextIndex = (idx + 1) % candidates.count
        } else {
            nextIndex = 0
        }
        
        store.setDashboardSlot(at: companionSlotIndex, widget: candidates[nextIndex])
        lastRotationDate = now
    }
}

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
                case .focusDominant:
                    focusDominantView(activeWidgets)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(.opacity.combined(with: .scale(scale: 0.99)))
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: store.dashboardSlots)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: store.dashboardLayoutFlow)
        .onAppear {
            FocusCompanionRotationManager.shared.startTimer()
        }
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
        case .battery:
            BatteryWidgetView(span: span)
        }
    }
    
    // MARK: - Layout Flow 1: 4 Side-by-Side Horizontal Strip
    private func horizontalStripView(_ widgets: [DashboardWidgetType]) -> some View {
        GeometryReader { geo in
            let targetExpanded = NotchShellCoordinator.shared.currentExpandedLayout
            let totalWidth = max(geo.size.width, targetExpanded.targetWidth - (store.contentHorizontalPadding * 2.0))
            let totalHeight = geo.size.height > 0 ? geo.size.height : max(100.0, targetExpanded.contentRect.height - 96.0)
            let count = widgets.count
            let spacing: CGFloat = 8.0
            let totalSpacing = CGFloat(max(0, count - 1)) * spacing
            let availableWidth = max(0, totalWidth - totalSpacing)
            
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
                                let w = availableWidth * 0.50
                                return (w >= 220 ? 2 : 1, w)
                            } else {
                                return (1, availableWidth * 0.25)
                            }
                        } else {
                            let totalSpan = widgets.reduce(0) { $0 + store.span(for: $1) }
                            let safeTotalSpan = max(1, totalSpan)
                            let span = store.span(for: widget)
                            let width = (CGFloat(span) / CGFloat(safeTotalSpan)) * availableWidth
                            let actualSpan = (width >= 220 && span >= 2) ? span : 1
                            return (actualSpan, width)
                        }
                    }()
                    
                    Self.renderWidget(type: widget, span: widgetSpan)
                        .frame(width: max(0, widgetWidth), height: totalHeight)
                        .clipped()
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
            .clipped()
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
            GeometryReader { geo in
                let targetExpanded = NotchShellCoordinator.shared.currentExpandedLayout
                let totalWidth = max(geo.size.width, targetExpanded.targetWidth - (store.contentHorizontalPadding * 2.0))
                let totalHeight = max(geo.size.height, targetExpanded.contentRect.height - 96.0)
                let dividerSpacing: CGFloat = 12.0
                let availableWidth = max(0, totalWidth - dividerSpacing)
                let split = max(0.20, min(0.80, store.dashboardSplitRatio))
                let minColWidth: CGFloat = min(120, availableWidth * 0.30)
                let leftWidth = max(minColWidth, min(availableWidth - minColWidth, availableWidth * split))
                let rightWidth = max(0, availableWidth - leftWidth)
                
                HStack(alignment: .top, spacing: 0) {
                    // Left Column (Slot 0 top, Slot 2 bottom)
                    renderColumnView(widgets: leftCol, columnWidth: leftWidth, oppositeCount: rightCol.count, totalHeight: totalHeight)
                        .frame(width: leftWidth, height: totalHeight)
                        .clipped()
                    
                    // Clean static separator between adjacent filled slots (draggable divider moved to Settings canvas)
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.horizontal, (dividerSpacing - 1) / 2)
                        .padding(.vertical, 8)
                    
                    // Right Column (Slot 1 top, Slot 3 bottom)
                    renderColumnView(widgets: rightCol, columnWidth: rightWidth, oppositeCount: leftCol.count, totalHeight: totalHeight)
                        .frame(width: rightWidth, height: totalHeight)
                        .clipped()
                }
                .coordinateSpace(name: "DashboardContainer")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
    
    // MARK: - Layout Flow 4: Focus (Dominant 70% + Companion 30%)
    private func focusDominantView(_ widgets: [DashboardWidgetType]) -> some View {
        GeometryReader { geo in
            let targetExpanded = NotchShellCoordinator.shared.currentExpandedLayout
            let totalWidth = max(geo.size.width, targetExpanded.targetWidth - (store.contentHorizontalPadding * 2.0))
            let totalHeight = max(geo.size.height, targetExpanded.contentRect.height - 96.0)
            let dividerSpacing: CGFloat = 12.0
            let availableWidth = max(0, totalWidth - dividerSpacing)
            
            let ratio = max(0.20, min(0.80, store.dashboardSplitRatio))
            let minColWidth: CGFloat = min(120, availableWidth * 0.25)
            let dominantWidth = max(minColWidth, min(availableWidth - minColWidth, availableWidth * ratio))
            let companionWidth = max(0, availableWidth - dominantWidth)
            
            let dominantWidget: DashboardWidgetType = {
                if let slotDom = store.dashboardSlots.first(where: { $0 != nil }) as? DashboardWidgetType {
                    return slotDom
                }
                return widgets.first ?? .nowPlaying
            }()
            
            let companionWidget: DashboardWidgetType? = {
                widgets.first(where: { $0 != dominantWidget })
            }()
            
            HStack(spacing: 0) {
                // Dominant Primary Widget
                Self.renderWidget(type: dominantWidget, span: companionWidget == nil ? 4 : (dominantWidth >= 220 ? 2 : 1))
                    .frame(width: companionWidget == nil ? totalWidth : dominantWidth, height: totalHeight)
                    .clipped()
                
                if let companion = companionWidget {
                    // Clean static separator between dominant and companion slot
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.horizontal, (dividerSpacing - 1) / 2)
                        .padding(.vertical, 8)
                    
                    // Companion Widget (span: 1)
                    Self.renderWidget(type: companion, span: 1)
                        .frame(width: companionWidth, height: totalHeight)
                        .clipped()
                }
            }
            .coordinateSpace(name: "DashboardContainer")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func renderColumnView(widgets: [DashboardWidgetType], columnWidth: CGFloat, oppositeCount: Int, totalHeight: CGFloat) -> some View {
        if widgets.count == 1 {
            // Span 2 only if column width >= 220pt AND totalHeight >= 160pt
            let span = (columnWidth >= 220 && totalHeight >= 160) ? (oppositeCount > 1 ? 2 : max(1, store.span(for: widgets[0]))) : 1
            Self.renderWidget(type: widgets[0], span: span)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            // Stacked widgets in this column (e.g. Clock on top, Ask AI directly below it!)
            let spacing: CGFloat = 8.0
            let widgetHeight = max(50, (totalHeight - spacing) / 2.0)
            VStack(spacing: spacing) {
                Self.renderWidget(type: widgets[0], span: 1)
                    .frame(maxWidth: .infinity)
                    .frame(height: widgetHeight)
                    .clipped()
                Self.renderWidget(type: widgets[1], span: 1)
                    .frame(maxWidth: .infinity)
                    .frame(height: widgetHeight)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }
    
    @ViewBuilder
    private func renderSingleColumn(widgets: [DashboardWidgetType]) -> some View {
        if widgets.count == 1 {
            oneWidgetView(widgets[0])
        } else {
            GeometryReader { geo in
                let spacing: CGFloat = 10.0
                let totalWidth = geo.size.width
                let itemWidth = max(0, (totalWidth - spacing) / 2.0)
                HStack(spacing: spacing) {
                    Self.renderWidget(type: widgets[0], span: itemWidth >= 220 ? 2 : 1)
                        .frame(width: itemWidth, height: geo.size.height)
                        .clipped()
                    Self.renderWidget(type: widgets[1], span: itemWidth >= 220 ? 2 : 1)
                        .frame(width: itemWidth, height: geo.size.height)
                        .clipped()
                }
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
