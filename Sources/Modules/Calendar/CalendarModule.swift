import SwiftUI
import EventKit
import AppKit

public enum CalendarSubsection: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case schedule = "Schedule"
    
    public var id: String { rawValue }
}

public struct CalendarEventItem: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let timeString: String
    public let date: Date
    public let colorName: String
    
    public init(title: String, timeString: String, date: Date = Date(), colorName: String) {
        self.title = title
        self.timeString = timeString
        self.date = date
        self.colorName = colorName
    }
    
    public var color: Color {
        switch colorName {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        default: return .orange
        }
    }
}

public struct CalendarCellData: Identifiable, Sendable {
    public let id: Int
    public let date: Date
    public let dayNumber: Int
    public let isCurrentMonth: Bool
    public let isToday: Bool
    public let hasEvents: Bool
}

@MainActor
public final class CalendarModule: ObservableObject {
    public static let shared = CalendarModule()
    
    public let id = "calendar"
    public let title = "Calendar"
    public let iconName = "calendar"
    
    @Published public var activeSubsection: CalendarSubsection = .calendar
    @Published public var displayedMonthDate: Date = Date()
    @Published public var selectedDate: Date = Date()
    @Published public var upcomingEvents: [CalendarEventItem] = []
    @Published public var monthGridCells: [CalendarCellData] = []
    
    public init() {
        loadEvents()
        updateGridCells()
    }
    
    public func start() {
        loadEvents()
        updateGridCells()
    }
    
    public func stop() {}

    public func updateGridCells() {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonthDate) else {
            monthGridCells = []
            return
        }
        
        let startOfMonth = monthInterval.start
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        
        guard let gridStartDate = calendar.date(byAdding: .day, value: -leadingDays, to: startOfMonth) else {
            monthGridCells = []
            return
        }
        
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        let totalCellsNeeded = leadingDays + numberOfDaysInMonth
        let totalCells = totalCellsNeeded > 35 ? 42 : 35
        let currentMonth = calendar.component(.month, from: displayedMonthDate)
        
        var cells: [CalendarCellData] = []
        cells.reserveCapacity(totalCells)
        
        for i in 0..<totalCells {
            if let date = calendar.date(byAdding: .day, value: i, to: gridStartDate) {
                let dayNum = calendar.component(.day, from: date)
                let isCurr = calendar.component(.month, from: date) == currentMonth
                let isTod = calendar.isDateInToday(date)
                let hasEv = upcomingEvents.contains(where: { calendar.isDate($0.date, inSameDayAs: date) })
                cells.append(CalendarCellData(
                    id: i,
                    date: date,
                    dayNumber: dayNum,
                    isCurrentMonth: isCurr,
                    isToday: isTod,
                    hasEvents: hasEv
                ))
            }
        }
        monthGridCells = cells
    }
    
    private func loadEvents() {
        let calendar = Calendar.current
        let today = Date()
        
        let event1 = CalendarEventItem(
            title: "Team Standup",
            timeString: "11:00 AM",
            date: today,
            colorName: "blue"
        )
        let event2 = CalendarEventItem(
            title: "Design Review",
            timeString: "2:30 PM",
            date: today,
            colorName: "purple"
        )
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let event3 = CalendarEventItem(
            title: "Project Sync",
            timeString: "4:00 PM",
            date: tomorrow,
            colorName: "green"
        )
        upcomingEvents = [event1, event2, event3]
    }
    
    public func events(for date: Date) -> [CalendarEventItem] {
        let cal = Calendar.current
        return upcomingEvents.filter { cal.isDate($0.date, inSameDayAs: date) }
    }
    
    public func changeMonth(by amount: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: amount, to: displayedMonthDate) {
            withAnimation(DesignSystem.reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 1)) {
                displayedMonthDate = newDate
                updateGridCells()
            }
            FeedbackManager.playClick()
        }
    }
    
    public func snapToToday() {
        let today = Date()
        withAnimation(DesignSystem.reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 1)) {
            displayedMonthDate = today
            selectedDate = today
            updateGridCells()
        }
        FeedbackManager.playClick()
    }
    
    public func openCalendarApp(for date: Date) {
        let timestamp = date.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(timestamp)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// Right-side Calendar Card for Home Dashboard
public struct CalendarHomeCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var module: CalendarModule = CalendarModule.shared
    
    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    
    private var monthYearTitle: String {
        module.displayedMonthDate.formatted(.dateTime.month(.abbreviated).year())
    }
    
    private var weekDays: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let firstWeekday = Calendar.current.firstWeekday - 1
        return Array(symbols[firstWeekday...] + symbols[..<firstWeekday])
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Month Navigation Header
            HStack {
                Text(monthYearTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.opacity)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Button(action: { module.changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.spring)
                    
                    Button(action: { module.snapToToday() }) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(DesignSystem.accentColor)
                                .frame(width: 4, height: 4)
                            Text("Today")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 24)
                    }
                    .buttonStyle(.spring)
                    
                    Button(action: { module.changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.spring)
                    
                    Button(action: { module.openCalendarApp(for: module.selectedDate) }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.spring)
                }
                .padding(2)
                .background(Capsule().fill(Color.white.opacity(0.07)))
            }
            
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekDays.indices, id: \.self) { index in
                    Text(weekDays[index])
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days Grid
            let calendar = Calendar.current
            LazyVGrid(columns: Self.gridColumns, spacing: 2) {
                ForEach(module.monthGridCells) { cell in
                    let isSelected = calendar.isDate(cell.date, inSameDayAs: module.selectedDate)
                    let hasEvents = cell.hasEvents
                    
                    Button(action: {
                        FeedbackManager.playClick()
                        module.selectedDate = cell.date
                    }) {
                        ZStack {
                            if isSelected {
                                Circle().fill(DesignSystem.accentColor)
                            } else if cell.isToday {
                                Circle().strokeBorder(DesignSystem.accentColor, lineWidth: 1)
                            }

                            Text("\(cell.dayNumber)")
                                .font(.system(size: 10, weight: cell.isToday || isSelected ? .semibold : .regular, design: .rounded))
                                .foregroundColor(
                                    isSelected ? DesignSystem.canvasColor :
                                    (cell.isToday ? DesignSystem.accentColor :
                                    (cell.isCurrentMonth ? .white : Color.white.opacity(0.20)))
                                )

                            if hasEvents {
                                Circle()
                                    .fill(isSelected ? DesignSystem.canvasColor : DesignSystem.accentColor)
                                    .frame(width: 3, height: 3)
                                    .offset(y: 7)
                            }
                        }
                        .frame(width: 20, height: 20)
                        .frame(maxWidth: .infinity)
                        .contentShape(Circle())
                        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1), value: isSelected)
                    }
                    .buttonStyle(.spring(scale: 0.97))
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: module.displayedMonthDate)
            
            // Selected Day Event Glance
            let dayEvents = module.events(for: module.selectedDate)
            if !dayEvents.isEmpty {
                HStack(spacing: 5) {
                    Circle()
                        .fill(dayEvents.first?.color ?? DesignSystem.accentColor)
                        .frame(width: 5, height: 5)
                    Text(dayEvents.first?.title ?? "")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(dayEvents.first?.timeString ?? "")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.06)))
                .transition(.opacity)
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardGradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
        )
    }
}
