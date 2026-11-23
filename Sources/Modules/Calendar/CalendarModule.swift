import SwiftUI
import EventKit
import AppKit

// MARK: - Calendar Event Model

public struct CalendarEventItem: Identifiable, Sendable {

    public let id: UUID
    public let title: String
    public let timeString: String
    public let date: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let colorName: String

    public init(
        title: String,
        timeString: String,
        date: Date = Date(),
        endDate: Date? = nil,
        isAllDay: Bool = false,
        colorName: String = "blue",
        id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        self.timeString = timeString
        self.date = date
        self.endDate = endDate ?? date
        self.isAllDay = isAllDay
        self.colorName = colorName
    }

    public var color: Color {
        switch colorName.lowercased() {
        case "blue":
            return Color(red: 0.0, green: 0.48, blue: 1.0)
        case "green":
            return .green
        case "red":
            return .red
        case "purple":
            return .purple
        default:
            return .orange
        }
    }
}

// MARK: - Calendar Cell Model

public struct CalendarCellData: Identifiable, Sendable {

    public let id: Int
    public let date: Date
    public let dayNumber: Int
    public let isCurrentMonth: Bool
    public let isToday: Bool
    public let hasEvents: Bool
}

// MARK: - Calendar Module

@MainActor
public final class CalendarModule: ObservableObject {

    public static let shared = CalendarModule()

    public let id = "calendar"
    public let title = "Calendar"
    public let iconName = "calendar"

    // MARK: Published State

    /// The month currently shown by the month-grid interface.
    @Published public var displayedMonthDate: Date = Date() {
        didSet {
            let calendar = Calendar.current
            let monthChanged = !calendar.isDate(
                oldValue,
                equalTo: displayedMonthDate,
                toGranularity: .month
            )

            if monthChanged {
                // Update the grid immediately, then fetch events for its new range.
                updateGridCells()
                loadEvents()
            }
        }
    }

    /// The day selected in either the month grid or the agenda screen.
    @Published public var selectedDate: Date = Date()

    /// Controls the month-grid / selected-day agenda transition. Keeping this
    /// in the shared observable model avoids requiring SwiftUI local @State.
    @Published public var isShowingDayAgenda = false

    @Published public private(set) var upcomingEvents: [CalendarEventItem] = []
    @Published public private(set) var monthGridCells: [CalendarCellData] = []
    @Published public private(set) var isCalendarAccessGranted = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var authorizationMessage: String?

    // MARK: Private State

    private let eventStore = EKEventStore()
    private let eventLookAheadDays = 30

    private var activeObserver: NSObjectProtocol?
    private var storeChangedObserver: NSObjectProtocol?
    private var sourceObserver: NSObjectProtocol?
    private var googleObserver: NSObjectProtocol?
    private var observersInstalled = false
    private var isRequestingAccess = false

    // A generation prevents an older month query from overwriting newer results.
    private var eventLoadGeneration = 0
    private var eventQueryTask: Task<[CalendarEventItem], Never>?

    // MARK: Initialization

    public init() {
        updateGridCells()
        refreshAuthorizationStatus()
        installObservers()
        loadEvents()
    }

    // MARK: Lifecycle

    public func start() {
        installObservers()
        refreshAuthorizationStatus()
        loadEvents()
        updateGridCells()
    }

    public func stop() {
        eventLoadGeneration += 1
        eventQueryTask?.cancel()
        eventQueryTask = nil
        isLoading = false

        guard observersInstalled else { return }

        if let observer = activeObserver {
            NotificationCenter.default.removeObserver(observer)
            activeObserver = nil
        }

        if let observer = storeChangedObserver {
            NotificationCenter.default.removeObserver(observer)
            storeChangedObserver = nil
        }

        if let observer = sourceObserver {
            NotificationCenter.default.removeObserver(observer)
            sourceObserver = nil
        }

        if let observer = googleObserver {
            NotificationCenter.default.removeObserver(observer)
            googleObserver = nil
        }

        observersInstalled = false
    }

    private func installObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshAuthorizationStatus()
                self.loadEvents()
                self.updateGridCells()
            }
        }

        storeChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if SettingsStore.shared.calendarSource == .apple {
                    self.loadEvents()
                }
            }
        }

        sourceObserver = NotificationCenter.default.addObserver(
            forName: .calendarSourceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshAuthorizationStatus()
                self.loadEvents()
                self.updateGridCells()
            }
        }

        googleObserver = NotificationCenter.default.addObserver(
            forName: .googleAccountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if SettingsStore.shared.calendarSource == .google {
                    self.refreshAuthorizationStatus()
                    self.loadEvents()
                    self.updateGridCells()
                }
            }
        }
    }

    // MARK: Authorization

    private func refreshAuthorizationStatus() {
        if SettingsStore.shared.calendarSource == .google {
            isCalendarAccessGranted = GoogleSyncService.shared.isConnected
            if isCalendarAccessGranted {
                authorizationMessage = nil
            } else {
                authorizationMessage = "Connect Google Account in Settings to sync Calendar & Tasks."
            }
            return
        }

        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            isCalendarAccessGranted = status == .fullAccess
        } else {
            isCalendarAccessGranted = status == .authorized
        }

        if isCalendarAccessGranted {
            authorizationMessage = nil
        }
    }

    private func openCalendarPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    public func requestCalendarAccess() {
        if SettingsStore.shared.calendarSource == .google {
            AppDelegate.openSettingsWindow()
            return
        }

        guard !isRequestingAccess else { return }

        let status = EKEventStore.authorizationStatus(for: .event)
        refreshAuthorizationStatus()

        if isCalendarAccessGranted {
            loadEvents()
            return
        }

        if status == .denied || status == .restricted {
            authorizationMessage = "Enable Calendar access in System Settings."
            openCalendarPrivacySettings()
            return
        }

        if #available(macOS 14.0, *) {
            // Write-only access cannot read the user's calendar events.
            if status == .writeOnly {
                authorizationMessage = "Full Calendar access is required to read events."
                openCalendarPrivacySettings()
                return
            }
        }

        guard status == .notDetermined else {
            authorizationMessage = "Calendar access is unavailable. Check System Settings."
            return
        }

        isRequestingAccess = true

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    self.isRequestingAccess = false
                    self.refreshAuthorizationStatus()

                    if let error {
                        self.authorizationMessage = error.localizedDescription
                    } else if !granted {
                        self.authorizationMessage = "Calendar access was not granted."
                    } else {
                        self.authorizationMessage = nil
                        self.loadEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    self.isRequestingAccess = false
                    self.refreshAuthorizationStatus()

                    if let error {
                        self.authorizationMessage = error.localizedDescription
                    } else if !granted {
                        self.authorizationMessage = "Calendar access was not granted."
                    } else {
                        self.authorizationMessage = nil
                        self.loadEvents()
                    }
                }
            }
        }
    }

    // MARK: Event Loading

    /// Loads two bounded ranges:
    /// 1. The visible month grid (including its leading/trailing days).
    /// 2. The next 30 days, used by the compact glance widget.
    ///
    /// EventKit's matching API is synchronous, so the actual store reads run
    /// in a detached task. Only Sendable CalendarEventItem values return to the
    /// main actor. A generation token prevents stale results from being applied.
    private func loadEvents() {
        refreshAuthorizationStatus()

        eventLoadGeneration += 1
        let generation = eventLoadGeneration

        eventQueryTask?.cancel()
        eventQueryTask = nil

        guard isCalendarAccessGranted else {
            upcomingEvents = []
            isLoading = false
            updateGridCells()
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let upcomingEnd = calendar.date(
            byAdding: .day,
            value: eventLookAheadDays,
            to: now
        ) else {
            upcomingEvents = []
            isLoading = false
            updateGridCells()
            return
        }

        let visibleStart = monthGridCells.first?.date
            ?? calendar.dateInterval(of: .month, for: displayedMonthDate)?.start
            ?? todayStart

        let visibleEndBase = monthGridCells.last?.date ?? upcomingEnd
        let visibleEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: visibleEndBase
        ) ?? upcomingEnd

        if SettingsStore.shared.calendarSource == .google {
            guard GoogleSyncService.shared.isConnected else {
                upcomingEvents = []
                isLoading = false
                isCalendarAccessGranted = false
                authorizationMessage = "Connect Google Account in Settings to sync Calendar & Tasks."
                updateGridCells()
                return
            }

            isCalendarAccessGranted = true
            authorizationMessage = nil
            isLoading = true

            let queryTask = Task.detached(priority: .userInitiated) {
                await GoogleSyncService.shared.fetchEventsAndTasks(start: visibleStart, end: visibleEnd)
            }
            eventQueryTask = queryTask

            Task { @MainActor [weak self] in
                let fetchedEvents = await queryTask.value

                guard let self,
                      !queryTask.isCancelled,
                      self.eventLoadGeneration == generation else {
                    return
                }

                self.upcomingEvents = fetchedEvents.sorted { lhs, rhs in
                    if lhs.date == rhs.date {
                        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                    }
                    return lhs.date < rhs.date
                }

                self.isLoading = false
                self.eventQueryTask = nil
                self.updateGridCells()
            }
            return
        }

        let queryRanges: [(start: Date, end: Date)] = [
            (start: visibleStart, end: visibleEnd),
            (start: todayStart, end: upcomingEnd)
        ]

        isLoading = true

        let queryTask = Task.detached(priority: .userInitiated) {
            Self.fetchEvents(in: queryRanges)
        }
        eventQueryTask = queryTask

        Task { @MainActor [weak self] in
            let fetchedEvents = await queryTask.value

            guard let self,
                  !queryTask.isCancelled,
                  self.eventLoadGeneration == generation else {
                return
            }

            self.upcomingEvents = fetchedEvents.sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.date < rhs.date
            }

            self.isLoading = false
            self.eventQueryTask = nil
            self.updateGridCells()
        }
    }

    /// Creates and uses its EventKit store entirely on the query task. EventKit
    /// objects never cross back to the main actor; only value-model data does.
    private nonisolated static func fetchEvents(
        in ranges: [(start: Date, end: Date)]
    ) -> [CalendarEventItem] {
        let store = EKEventStore()

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        var eventsByIdentifier: [String: CalendarEventItem] = [:]

        for range in ranges {
            if Task.isCancelled { break }
            guard range.end > range.start else { continue }

            let predicate = store.predicateForEvents(
                withStart: range.start,
                end: range.end,
                calendars: nil
            )

            for event in store.events(matching: predicate) {
                if Task.isCancelled { break }

                guard let start = event.startDate,
                      let end = event.endDate else {
                    continue
                }

                let trimmedTitle = event.title?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let safeTitle = (trimmedTitle?.isEmpty == false)
                    ? (trimmedTitle ?? "Event")
                    : "Event"

                let timeString = event.isAllDay
                    ? "All Day"
                    : formatter.string(from: start)

                let item = CalendarEventItem(
                    title: safeTitle,
                    timeString: timeString,
                    date: start,
                    endDate: end,
                    isAllDay: event.isAllDay,
                    colorName: "blue"
                )

                // eventIdentifier normally remains stable across EventKit refreshes.
                // The fallback handles unusual events without an identifier.
                let identifier = event.eventIdentifier
                    ?? "\(start.timeIntervalSince1970)|\(safeTitle)|\(end.timeIntervalSince1970)"

                eventsByIdentifier[identifier] = item
            }
        }

        return Array(eventsByIdentifier.values)
    }

    // MARK: Event Queries

    /// Returns events that overlap the selected calendar day.
    public func events(for date: Date) -> [CalendarEventItem] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        guard let dayEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: dayStart
        ) else {
            return []
        }

        return upcomingEvents.filter { event in
            // Treat zero-duration events as occurring at their start time.
            if event.endDate <= event.date {
                return event.date >= dayStart && event.date < dayEnd
            }

            return event.date < dayEnd && event.endDate > dayStart
        }
    }

    public var nextEvent: CalendarEventItem? {
        nextEvent(after: Date())
    }

    public func nextEvent(after now: Date) -> CalendarEventItem? {
        let calendar = Calendar.current
        let horizon = calendar.date(
            byAdding: .day,
            value: eventLookAheadDays,
            to: now
        ) ?? now.addingTimeInterval(TimeInterval(eventLookAheadDays * 24 * 60 * 60))

        // upcomingEvents also contains events from a separately loaded visible
        // month, which may be years away. Keep the compact glance limited to
        // the actual upcoming window rather than choosing one of those events.
        return upcomingEvents.first { event in
            guard event.date < horizon else { return false }

            if event.endDate > event.date {
                return event.endDate > now
            }

            return event.date >= now
                || calendar.isDate(event.date, inSameDayAs: now)
        }
    }

    // MARK: Calendar Grid

    public func updateGridCells() {
        let calendar = Calendar.current

        guard let monthInterval = calendar.dateInterval(
            of: .month,
            for: displayedMonthDate
        ) else {
            monthGridCells = []
            return
        }

        let startOfMonth = monthInterval.start
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7

        guard let gridStartDate = calendar.date(
            byAdding: .day,
            value: -leadingDays,
            to: startOfMonth
        ) else {
            monthGridCells = []
            return
        }

        let numberOfDays = calendar.range(
            of: .day,
            in: .month,
            for: startOfMonth
        )?.count ?? 30

        let requiredCells = leadingDays + numberOfDays
        let totalCells = requiredCells > 35 ? 42 : 35

        let eventDays = makeEventDaySet(
            calendar: calendar,
            gridStartDate: gridStartDate,
            totalCells: totalCells
        )

        var cells: [CalendarCellData] = []
        cells.reserveCapacity(totalCells)

        for index in 0..<totalCells {
            guard let date = calendar.date(
                byAdding: .day,
                value: index,
                to: gridStartDate
            ) else {
                continue
            }

            cells.append(
                CalendarCellData(
                    id: index,
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isCurrentMonth: calendar.isDate(
                        date,
                        equalTo: displayedMonthDate,
                        toGranularity: .month
                    ),
                    isToday: calendar.isDateInToday(date),
                    hasEvents: eventDays.contains(calendar.startOfDay(for: date))
                )
            )
        }

        monthGridCells = cells
    }

    private func makeEventDaySet(
        calendar: Calendar,
        gridStartDate: Date,
        totalCells: Int
    ) -> Set<Date> {
        guard let gridEndDate = calendar.date(
            byAdding: .day,
            value: totalCells,
            to: gridStartDate
        ) else {
            return []
        }

        var result = Set<Date>()

        for event in upcomingEvents {
            // A zero-duration event still occupies its start day for the dot.
            let effectiveEnd: Date
            if event.endDate > event.date {
                effectiveEnd = event.endDate
            } else {
                effectiveEnd = calendar.date(
                    byAdding: .second,
                    value: 1,
                    to: event.date
                ) ?? event.date
            }

            guard event.date < gridEndDate,
                  effectiveEnd > gridStartDate else {
                continue
            }

            let firstVisibleDay = max(
                calendar.startOfDay(for: event.date),
                gridStartDate
            )

            var current = firstVisibleDay

            while current < effectiveEnd && current < gridEndDate {
                result.insert(calendar.startOfDay(for: current))

                guard let next = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: current
                ) else {
                    break
                }

                current = next
            }
        }

        return result
    }

    // MARK: Date Selection

    public func selectDate(_ date: Date) {
        selectedDate = date

        let calendar = Calendar.current
        if !calendar.isDate(
            date,
            equalTo: displayedMonthDate,
            toGranularity: .month
        ) {
            displayedMonthDate = date
        }

        FeedbackManager.playClick()
    }

    // MARK: Month Navigation

    /// Changes the displayed month and keeps the selected day number where possible.
    /// Example: January 31 -> February 28/29, rather than an unrelated date.
    public func changeMonth(by amount: Int) {
        guard amount != 0 else { return }

        let calendar = Calendar.current
        let currentMonthStart = calendar.dateInterval(
            of: .month,
            for: displayedMonthDate
        )?.start ?? calendar.startOfDay(for: displayedMonthDate)

        guard let newMonthDate = calendar.date(
            byAdding: .month,
            value: amount,
            to: currentMonthStart
        ),
        let newMonthInterval = calendar.dateInterval(
            of: .month,
            for: newMonthDate
        ) else {
            return
        }

        let selectedDay = calendar.component(.day, from: selectedDate)
        let daysInTargetMonth = calendar.range(
            of: .day,
            in: .month,
            for: newMonthDate
        )?.count ?? 28
        let targetDay = min(selectedDay, daysInTargetMonth)

        let newSelectedDate = calendar.date(
            byAdding: .day,
            value: targetDay - 1,
            to: newMonthInterval.start
        ) ?? newMonthInterval.start

        withAnimation(
            DesignSystem.reduceMotion
                ? nil
                : .spring(response: 0.32, dampingFraction: 1)
        ) {
            selectedDate = newSelectedDate
            displayedMonthDate = newMonthDate
        }

        FeedbackManager.playClick()
    }

    // MARK: Day Navigation

    public func changeSelectedDay(by amount: Int) {
        guard let newDate = Calendar.current.date(
            byAdding: .day,
            value: amount,
            to: selectedDate
        ) else {
            return
        }

        selectDate(newDate)
    }

    // MARK: Today Navigation

    public func snapToToday() {
        let today = Date()

        withAnimation(
            DesignSystem.reduceMotion
                ? nil
                : .spring(response: 0.32, dampingFraction: 1)
        ) {
            selectedDate = today
            displayedMonthDate = today
        }

        FeedbackManager.playClick()
    }

    // MARK: Open Calendar Application

    public func openCalendarApp(for date: Date) {
        if SettingsStore.shared.calendarSource == .google {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            let dateStr = formatter.string(from: date)
            if let url = URL(string: "https://calendar.google.com/calendar/u/0/r/day/\(dateStr)") {
                NSWorkspace.shared.open(url)
                return
            }
        }

        let timestamp = date.timeIntervalSinceReferenceDate

        guard let url = URL(string: "calshow:\(timestamp)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    // MARK: Manual Refresh

    public func refreshEvents() {
        refreshAuthorizationStatus()
        loadEvents()
        updateGridCells()
    }
}

// MARK: - Calendar Home Card

public struct CalendarHomeCardView: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @ObservedObject private var module: CalendarModule

    private let gridSpacing: CGFloat = 2

    public init(module: CalendarModule = .shared) {
        self.module = module
    }

    private var monthYearTitle: String {
        module.displayedMonthDate.formatted(
            .dateTime.month(.wide).year()
        )
    }

    private var weekDays: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }

        let offset = max(
            0,
            min(symbols.count - 1, calendar.firstWeekday - 1)
        )

        return Array(symbols.dropFirst(offset) + symbols.prefix(offset))
    }

    public var body: some View {
        Group {
            if module.isShowingDayAgenda {
                CalendarDayAgendaView(module: module) {
                    withAnimation(
                        reduceMotion ? nil : .easeInOut(duration: 0.18)
                    ) {
                        module.isShowingDayAgenda = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                monthCalendarView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: DesignSystem.defaultCornerRadius,
                style: .continuous
            )
            .fill(DesignSystem.cardGradient)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignSystem.defaultCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: DesignSystem.defaultCornerRadius,
                style: .continuous
            )
            .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: module.isShowingDayAgenda
        )
    }

    // MARK: Responsive Month View

    private var monthCalendarView: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width)
            let height = max(0, geometry.size.height)
            let horizontalInset: CGFloat = width < 270 ? 8 : 10
            let verticalInset: CGFloat = height < 210 ? 5 : 7
            let availableGridWidth = max(
                0,
                width - (horizontalInset * 2) - (gridSpacing * 6)
            )
            let columnWidth = availableGridWidth / 7
            let rows = max(1, module.monthGridCells.count / 7)

            let headerEstimatedHeight: CGFloat = 22
            let weekdayEstimatedHeight: CGFloat = 12
            let showEventSection = height >= 180
            let eventEstimatedHeight: CGFloat = showEventSection ? (height < 210 ? 20 : 25) : 0
            let spacingTotal: CGFloat = (verticalInset * 2) + headerEstimatedHeight + 4 + weekdayEstimatedHeight + 3 + eventEstimatedHeight + (showEventSection ? 3 : 0)
            let availableGridHeight = max(50, height - spacingTotal)
            let rowHeight = max(13, min(26, (availableGridHeight - (gridSpacing * CGFloat(rows - 1))) / CGFloat(rows)))
            let dayDiameter = max(13, min(rowHeight - 1, columnWidth - 2, 24))
            let dayFontSize = min(11, max(8.5, dayDiameter * 0.46))

            VStack(alignment: .leading, spacing: 0) {
                // PINNED: Month & Year header is permanently visible and never scrolled off
                header
                    .padding(.bottom, height < 210 ? 2 : 4)

                // PINNED: Weekday abbreviations (S M T W T F S)
                weekdayHeader
                    .padding(.bottom, height < 210 ? 2 : 3)

                // Month Grid (all weeks fit concurrently on-screen)
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 12), spacing: gridSpacing),
                        count: 7
                    ),
                    spacing: gridSpacing
                ) {
                    ForEach(module.monthGridCells) { cell in
                        calendarDayButton(
                            cell,
                            diameter: dayDiameter,
                            fontSize: dayFontSize,
                            cellHeight: rowHeight
                        )
                    }
                }
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.16),
                    value: module.displayedMonthDate
                )

                if showEventSection {
                    Spacer(minLength: 2)

                    // Event Preview or Empty State
                    selectedEventSection
                }
            }
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 5) {
            Text(monthYearTitle)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .contentTransition(.opacity)

            Spacer(minLength: 2)

            todayButton

            HStack(spacing: 0) {
                monthNavigationButton(
                    symbol: "chevron.left",
                    accessibility: "Previous Month",
                    amount: -1
                )

                Rectangle()
                    .fill(DesignSystem.cardBorder)
                    .frame(width: 1, height: 11)

                monthNavigationButton(
                    symbol: "chevron.right",
                    accessibility: "Next Month",
                    amount: 1
                )
            }
            .background(Capsule().fill(Color.primary.opacity(0.07)))
            .overlay(
                Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
            )

            Button {
                module.openCalendarApp(for: module.selectedDate)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(SettingsStore.shared.calendarSource == .google ? "Open Google Calendar" : "Open Apple Calendar")
            .accessibilityLabel(SettingsStore.shared.calendarSource == .google ? "Open Google Calendar" : "Open Apple Calendar")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekDays.indices, id: \.self) { index in
                Text(weekDays[index])
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Today Button

    private var todayButton: some View {
        Button {
            module.snapToToday()
        } label: {
            HStack(spacing: 3) {
                Circle()
                    .fill(DesignSystem.accentColor)
                    .frame(width: 3.5, height: 3.5)

                Text("Today")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
            .overlay(
                Capsule().strokeBorder(DesignSystem.cardBorder, lineWidth: 0.8)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Jump to Today")
        .accessibilityLabel("Jump to Today")
    }

    // MARK: Month Navigation

    private func monthNavigationButton(
        symbol: String,
        accessibility: String,
        amount: Int
    ) -> some View {
        Button {
            module.changeMonth(by: amount)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.88))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(accessibility)
        .accessibilityLabel(accessibility)
    }

    // MARK: Calendar Day Button

    private func calendarDayButton(
        _ cell: CalendarCellData,
        diameter: CGFloat,
        fontSize: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(
            cell.date,
            inSameDayAs: module.selectedDate
        )

        return Button {
            module.selectDate(cell.date)
            withAnimation(
                reduceMotion ? nil : .easeInOut(duration: 0.18)
            ) {
                module.isShowingDayAgenda = true
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(DesignSystem.accentColor)
                        .frame(width: diameter, height: diameter)
                } else if cell.isToday {
                    Circle()
                        .strokeBorder(
                            DesignSystem.accentColor,
                            lineWidth: 1.3
                        )
                        .frame(width: diameter, height: diameter)
                }

                Text("\(cell.dayNumber)")
                    .font(.system(
                        size: fontSize,
                        weight: cell.isToday || isSelected ? .semibold : .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(
                        isSelected
                            ? DesignSystem.canvasColor
                            : (
                                cell.isToday
                                    ? DesignSystem.accentColor
                                    : (
                                        cell.isCurrentMonth
                                            ? Color.primary
                                            : Color.primary.opacity(0.32)
                                    )
                            )
                    )

                if cell.hasEvents {
                    Circle()
                        .fill(
                            isSelected
                                ? DesignSystem.canvasColor
                                : DesignSystem.accentColor
                        )
                        .frame(width: 4, height: 4)
                        .offset(y: diameter * 0.37)
                }
            }
            // The button occupies the entire grid column, not just the small
            // visual circle. This improves hit testing and uses the card width.
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .contentShape(Rectangle())
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9),
                value: isSelected
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(
            cell.date.formatted(date: .complete, time: .omitted)
        )
        .accessibilityValue(
            isSelected
                ? "Selected"
                : (cell.hasEvents ? "Has events. Opens schedule." : "Opens schedule.")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Selected Event Preview

    @ViewBuilder
    private var selectedEventSection: some View {
        let dayEvents = module.events(for: module.selectedDate)

        if let firstEvent = dayEvents.first {
            HStack(spacing: 6) {
                Circle()
                    .fill(firstEvent.color)
                    .frame(width: 5, height: 5)

                Text(firstEvent.title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(firstEvent.isAllDay ? "All day" : firstEvent.timeString)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if dayEvents.count > 1 {
                    Text("+\(dayEvents.count - 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignSystem.secondaryText)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .accessibilityElement(children: .combine)
        } else if !module.isCalendarAccessGranted {
            Button {
                module.requestCalendarAccess()
            } label: {
                Label(
                    module.authorizationMessage ?? (SettingsStore.shared.calendarSource == .google ? "Connect Google in Settings" : "Grant Calendar Access"),
                    systemImage: SettingsStore.shared.calendarSource == .google ? "g.circle.fill" : "lock.shield"
                )
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(SettingsStore.shared.calendarSource == .google ? DesignSystem.accentColor : .orange)
                .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help(SettingsStore.shared.calendarSource == .google ? "Open Settings to connect Google Account" : "Grant Calendar Access")
        } else if module.isLoading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading events…")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DesignSystem.secondaryText)
            }
            .padding(.vertical, 2)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DesignSystem.secondaryText)

                Text("No events scheduled")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DesignSystem.secondaryText)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Selected Day Agenda

public struct CalendarDayAgendaView: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.notchCompact)
    private var notchCompact
    @Environment(\.notchTight)
    private var notchTight

    @ObservedObject private var module: CalendarModule
    private let onBack: () -> Void

    public init(
        module: CalendarModule = .shared,
        onBack: @escaping () -> Void
    ) {
        self.module = module
        self.onBack = onBack
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            topBar
            dateHeading
            Divider().opacity(0.3)
            agendaBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    // MARK: Top Bar with Back Button and Quick Navigation

    private var topBar: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 9.5, weight: .bold))
                    Text("Month")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to Month Calendar")
            .accessibilityLabel("Back to Month Calendar")

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                dayNavigationButton(symbol: "chevron.left", label: "Previous Day", amount: -1)
                dayNavigationButton(symbol: "chevron.right", label: "Next Day", amount: 1)
            }

            Button {
                module.openCalendarApp(for: module.selectedDate)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(SettingsStore.shared.calendarSource == .google ? "Open Google Calendar" : "Open Apple Calendar")
            .accessibilityLabel(SettingsStore.shared.calendarSource == .google ? "Open Google Calendar" : "Open Apple Calendar")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Date Heading (Prominent Day, Month, Date, and Year)

    private var dateHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(module.selectedDate.formatted(
                .dateTime.weekday(.wide).month(.abbreviated).day().year()
            ))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer()

            if Calendar.current.isDateInToday(module.selectedDate) {
                Text("Today")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(DesignSystem.accentColor.opacity(0.14)))
            } else {
                Text("Daily schedule")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(DesignSystem.secondaryText)
            }
        }
    }

    private func dayNavigationButton(
        symbol: String,
        label: String,
        amount: Int
    ) -> some View {
        Button {
            module.changeSelectedDay(by: amount)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.primary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.primary.opacity(0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: Agenda Body

    @ViewBuilder
    private var agendaBody: some View {
        if !module.isCalendarAccessGranted {
            permissionState
        } else if module.isLoading {
            loadingState
        } else {
            agendaContent
        }
    }

    private var agendaContent: some View {
        let dayEvents = module.events(for: module.selectedDate)

        return Group {
            if dayEvents.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: notchTight ? 4 : 6) {
                        ForEach(dayEvents) { event in
                            agendaEventCard(event, for: module.selectedDate)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func agendaEventCard(
        _ event: CalendarEventItem,
        for selectedDay: Date
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Capsule()
                .fill(event.color)
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(event.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(eventTimeRange(event, on: selectedDay))
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignSystem.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.6)
        )
        .accessibilityElement(children: .combine)
    }

    private func eventTimeRange(
        _ event: CalendarEventItem,
        on selectedDay: Date
    ) -> String {
        if event.isAllDay { return "All day" }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDay)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return event.timeString
        }

        let startLabel = event.date < dayStart
            ? "Earlier"
            : event.date.formatted(date: .omitted, time: .shortened)

        guard event.endDate > event.date else { return startLabel }

        let endLabel = event.endDate >= dayEnd
            ? "End of day"
            : event.endDate.formatted(date: .omitted, time: .shortened)

        return "\(startLabel) – \(endLabel)"
    }

    // MARK: Agenda States

    private var emptyState: some View {
        VStack(spacing: 3) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(DesignSystem.secondaryText)

            Text("Nothing scheduled")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)

            Text("There are no events for this day.")
                .font(.system(size: 8.5))
                .foregroundStyle(DesignSystem.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionState: some View {
        let isGoogle = SettingsStore.shared.calendarSource == .google
        return VStack(alignment: .leading, spacing: 6) {
            Label(
                isGoogle ? "Google Account Required" : "Calendar access required",
                systemImage: isGoogle ? "g.circle.fill" : "lock.shield"
            )
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isGoogle ? DesignSystem.accentColor : .orange)
            .lineLimit(1)

            if !notchTight {
                Text(module.authorizationMessage
                     ?? (isGoogle
                         ? "Connect your Google account in Settings to sync calendar & tasks."
                         : "Allow Notchify to access Calendar."))
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .lineLimit(2)
            }

            Button(isGoogle ? "Open Settings" : "Grant Access") {
                module.requestCalendarAccess()
            }
            .font(.system(size: 9, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundStyle(DesignSystem.accentColor)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill((isGoogle ? DesignSystem.accentColor : Color.orange).opacity(0.08))
        )
    }

    private var loadingState: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text("Loading…")
                .font(.system(size: 10))
                .foregroundStyle(DesignSystem.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mini Calendar Glance View

public struct CalendarMiniGlanceView: View {

    @ObservedObject private var module: CalendarModule

    public init(module: CalendarModule = .shared) {
        self.module = module
    }

    public var body: some View {
        // A periodic timeline refreshes the displayed date at least once a
        // minute, so the glance card does not remain on yesterday after midnight.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            glanceContent(for: context.date)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: DesignSystem.defaultCornerRadius,
                style: .continuous
            )
            .fill(DesignSystem.cardFill)
            .overlay(
                RoundedRectangle(
                    cornerRadius: DesignSystem.defaultCornerRadius,
                    style: .continuous
                )
                .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
            )
        )
    }

    private func glanceContent(for todayDate: Date) -> some View {
        let monthAbbrev = todayDate.formatted(.dateTime.month(.abbreviated)).uppercased()
        let dayNumber = todayDate.formatted(.dateTime.day())
        let weekdayAbbrev = todayDate.formatted(.dateTime.weekday(.wide))
        let nextEvent = module.nextEvent(after: todayDate)

        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.accentColor)

                Text(monthAbbrev)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.accentColor)
                    .lineLimit(1)

                Spacer()

                Button {
                    module.openCalendarApp(for: todayDate)
                } label: {
                    Image(systemName: "arrow.up.right.app")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Open Calendar.app")
                .accessibilityLabel("Open Calendar.app")
            }

            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(weekdayAbbrev)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 5) {
                if let event = nextEvent {
                    Circle()
                        .fill(event.color)
                        .frame(width: 5, height: 5)

                    Text(event.title)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(event.isAllDay ? "All day" : event.timeString)
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else if !module.isCalendarAccessGranted {
                    Button {
                        module.requestCalendarAccess()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 8.5))
                            Text("Grant Access")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Grant Calendar Access")

                    Spacer(minLength: 0)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)

                    Text("No upcoming events")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DesignSystem.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
    }
}

// MARK: - Adaptive Calendar Widget Container

public struct CalendarAdaptiveWidgetView: View {

    public var span: Int

    public init(span: Int = 2) {
        self.span = span
    }

    public var body: some View {
        Group {
            if span <= 1 {
                CalendarMiniGlanceView()
            } else if span == 2 {
                CalendarHomeCardView()
            } else {
                // Prefer the two-panel layout only when both panels fit.
                // The month calendar becomes the fallback instead of forcing
                // a 270-point width that can escape narrow widget bounds.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        CalendarHomeCardView()
                            .frame(minWidth: 250, maxWidth: .infinity)

                        Rectangle()
                            .fill(DesignSystem.cardBorder)
                            .frame(width: 1)

                        CalendarMiniGlanceView()
                            .frame(minWidth: 145, maxWidth: 220)
                    }

                    CalendarHomeCardView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
