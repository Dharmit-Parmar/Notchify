import Foundation
import SwiftUI
import Combine

// MARK: - Google Sync Data Models

public struct GoogleCalendarListResponse: Decodable, Sendable {
    public let items: [GoogleCalendarItem]?
}

public struct GoogleCalendarItem: Decodable, Sendable {
    public let id: String
    public let summary: String?
    public let description: String?
    public let location: String?
    public let colorId: String?
    public let start: GoogleDateOrDateTime?
    public let end: GoogleDateOrDateTime?
}

public struct GoogleDateOrDateTime: Decodable, Sendable {
    public let date: String?       // "YYYY-MM-DD" for all-day events
    public let dateTime: String?   // RFC3339 formatted ISO string
    public let timeZone: String?
}

public struct GoogleTasksListResponse: Decodable, Sendable {
    public let items: [GoogleTaskItem]?
}

public struct GoogleTaskItem: Decodable, Sendable {
    public let id: String
    public let title: String?
    public let notes: String?
    public let due: String?        // RFC3339 formatted ISO string
    public let status: String?     // "needsAction" or "completed"
}

// MARK: - Google Sync Service

@MainActor
public final class GoogleSyncService: ObservableObject {

    public static let shared = GoogleSyncService()

    public static let oauthTokenKey = "google_oauth_token"
    public static let accountEmailKey = "google_account_email"
    public static let calendarFeedUrlKey = "google_calendar_feed_url"

    // MARK: Published State

    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var syncErrorMessage: String?
    @Published public private(set) var cachedEvents: [CalendarEventItem] = []

    private let cacheStorageKey = "NotchApp_GoogleCalendarCachedEvents"

    public var isConnected: Bool {
        let email = SettingsStore.shared.connectedGoogleEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = KeychainHelper.shared.loadSecret(forKey: Self.oauthTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !email.isEmpty || !token.isEmpty
    }

    public var connectedEmail: String {
        SettingsStore.shared.connectedGoogleEmail
    }

    private init() {
        loadCachedEvents()
    }

    // MARK: - Account Connection Management (Single Google Login across Notch)

    public func connectAccount(email: String, token: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanEmail.isEmpty {
            SettingsStore.shared.connectedGoogleEmail = cleanEmail
            KeychainHelper.shared.saveSecret(cleanEmail, forKey: Self.accountEmailKey)
        }

        if !cleanToken.isEmpty {
            KeychainHelper.shared.saveSecret(cleanToken, forKey: Self.oauthTokenKey)
        }

        syncErrorMessage = nil
        FeedbackManager.playSuccess()

        // Notify entire app that Google Account connected (syncs AI & Calendar immediately)
        NotificationCenter.default.post(name: .googleAccountDidChange, object: nil)

        Task {
            await syncNow()
        }
    }

    public func disconnectAccount() {
        SettingsStore.shared.connectedGoogleEmail = ""
        KeychainHelper.shared.deleteSecret(forKey: Self.oauthTokenKey)
        KeychainHelper.shared.deleteSecret(forKey: Self.accountEmailKey)
        KeychainHelper.shared.deleteSecret(forKey: Self.calendarFeedUrlKey)
        KeychainHelper.shared.deleteSecret(forKey: GoogleOAuthManager.refreshTokenKey)

        cachedEvents = []
        lastSyncDate = nil
        syncErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: cacheStorageKey)

        FeedbackManager.playDelete()
        NotificationCenter.default.post(name: .googleAccountDidChange, object: nil)
    }

    // MARK: - Synchronize Calendar Events & Tasks

    public func syncNow() async {
        guard isConnected else { return }
        isSyncing = true
        syncErrorMessage = nil

        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let end = calendar.date(byAdding: .month, value: 2, to: now) ?? now

        let items = await fetchEventsAndTasks(start: start, end: end)

        if !items.isEmpty || syncErrorMessage == nil {
            self.cachedEvents = items
            self.lastSyncDate = Date()
            persistCachedEvents(items)
        }

        self.isSyncing = false
    }

    // MARK: - Fetch Google Calendar & Tasks Data

    public func fetchEventsAndTasks(start: Date, end: Date) async -> [CalendarEventItem] {
        guard let token = KeychainHelper.shared.loadSecret(forKey: Self.oauthTokenKey),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // If user only provided email or no token yet, return cached events if available
            return cachedEvents
        }

        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Concurrent execution via async let (Swift 6 structured concurrency)
            async let calendarEvents = fetchGoogleCalendarEvents(token: cleanToken, start: start, end: end)
            async let taskEvents = fetchGoogleTasks(token: cleanToken, start: start, end: end)

            let (calResults, taskResults) = try await (calendarEvents, taskEvents)
            let combined = (calResults + taskResults).sorted { $0.date < $1.date }

            self.syncErrorMessage = nil
            return combined
        } catch {
            self.syncErrorMessage = error.localizedDescription
            return cachedEvents
        }
    }

    // MARK: - Google Calendar API v3

    private func fetchGoogleCalendarEvents(token: String, start: Date, end: Date) async throws -> [CalendarEventItem] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let startStr = isoFormatter.string(from: start)
        let endStr = isoFormatter.string(from: end)

        guard let encodedStart = startStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEnd = endStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(encodedStart)&timeMax=\(encodedEnd)&singleEvents=true&orderBy=startTime&maxResults=250") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return []
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                // Attempt automatic background refresh using secure refresh_token
                if let refreshedToken = await GoogleOAuthManager.shared.refreshAccessTokenIfNeeded() {
                    var retryRequest = request
                    retryRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
                    if let (retryData, retryResponse) = try? await URLSession.shared.data(for: retryRequest),
                       (retryResponse as? HTTPURLResponse)?.statusCode == 200,
                       let list = try? JSONDecoder().decode(GoogleCalendarListResponse.self, from: retryData),
                       let items = list.items {
                        return items.compactMap { self.convertGoogleEventToItem($0) }
                    }
                }
                throw NSError(domain: "GoogleSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Google session expired. Please sign in again in Settings."])
            }
            return []
        }

        let list = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
        guard let items = list.items else { return [] }

        return items.compactMap { item in
            self.convertGoogleEventToItem(item)
        }
    }

    // MARK: - Google Tasks API v1

    private func fetchGoogleTasks(token: String, start: Date, end: Date) async throws -> [CalendarEventItem] {
        guard let url = URL(string: "https://tasks.googleapis.com/tasks/v1/users/@me/lists/@default/tasks?showCompleted=false&maxResults=100") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // Tasks API might not be enabled or return empty; gracefully return empty list without failing calendar
            return []
        }

        let list = try? JSONDecoder().decode(GoogleTasksListResponse.self, from: data)
        guard let items = list?.items else { return [] }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]

        return items.compactMap { task in
            guard let title = task.title, !title.isEmpty else { return nil }

            let taskDate: Date
            if let dueStr = task.due,
               let parsed = isoFractional.date(from: dueStr) ?? isoStandard.date(from: dueStr) {
                taskDate = parsed
            } else {
                taskDate = Date()
            }

            let timeStr = task.due != nil
                ? taskDate.formatted(date: .omitted, time: .shortened)
                : "Google Task"

            return CalendarEventItem(
                title: "✓ \(title)",
                timeString: timeStr,
                date: taskDate,
                endDate: taskDate.addingTimeInterval(1800),
                isAllDay: task.due == nil,
                colorName: "purple",
                id: UUID()
            )
        }
    }

    // MARK: - Model Converters

    private func convertGoogleEventToItem(_ item: GoogleCalendarItem) -> CalendarEventItem? {
        guard let summary = item.summary, !summary.isEmpty else { return nil }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.timeZone = TimeZone.current

        var startDate: Date = Date()
        var endDate: Date = Date()
        var isAllDay = false

        if let dt = item.start?.dateTime,
           let parsed = isoFractional.date(from: dt) ?? isoStandard.date(from: dt) {
            startDate = parsed
        } else if let d = item.start?.date,
                  let parsed = dayFormatter.date(from: d) {
            startDate = parsed
            isAllDay = true
        }

        if let dt = item.end?.dateTime,
           let parsed = isoFractional.date(from: dt) ?? isoStandard.date(from: dt) {
            endDate = parsed
        } else if let d = item.end?.date,
                  let parsed = dayFormatter.date(from: d) {
            endDate = parsed
        } else {
            endDate = startDate.addingTimeInterval(3600)
        }

        let timeStr = isAllDay ? "All day" : startDate.formatted(date: .omitted, time: .shortened)

        let color: String
        switch item.colorId {
        case "1", "9": color = "blue"
        case "2", "10": color = "green"
        case "4", "11": color = "red"
        case "3": color = "purple"
        default: color = "orange"
        }

        return CalendarEventItem(
            title: summary,
            timeString: timeStr,
            date: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            colorName: color,
            id: UUID()
        )
    }

    // MARK: - Offline Cache Persistence

    private struct CachedEventDTO: Codable {
        let title: String
        let timeString: String
        let date: Date
        let endDate: Date
        let isAllDay: Bool
        let colorName: String
    }

    private var cacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotchApp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        return dir.appendingPathComponent("calendar_cache.enc")
    }

    private func persistCachedEvents(_ items: [CalendarEventItem]) {
        let dtos = items.map {
            CachedEventDTO(
                title: $0.title,
                timeString: $0.timeString,
                date: $0.date,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay,
                colorName: $0.colorName
            )
        }
        if let data = try? JSONEncoder().encode(dtos) {
            try? EncryptedFileStore.shared.write(data: data, to: cacheFileURL)
        }
    }

    private func loadCachedEvents() {
        // 1. Try hardware-backed encrypted cache first
        if FileManager.default.fileExists(atPath: cacheFileURL.path),
           let data = try? EncryptedFileStore.shared.read(from: cacheFileURL),
           let dtos = try? JSONDecoder().decode([CachedEventDTO].self, from: data) {
            self.cachedEvents = dtos.map {
                CalendarEventItem(
                    title: $0.title,
                    timeString: $0.timeString,
                    date: $0.date,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    colorName: $0.colorName,
                    id: UUID()
                )
            }
            UserDefaults.standard.removeObject(forKey: cacheStorageKey)
            return
        }

        // 2. Legacy unencrypted fallback: migrate to AES-256-GCM and purge plaintext
        if let data = UserDefaults.standard.data(forKey: cacheStorageKey),
           let dtos = try? JSONDecoder().decode([CachedEventDTO].self, from: data) {
            self.cachedEvents = dtos.map {
                CalendarEventItem(
                    title: $0.title,
                    timeString: $0.timeString,
                    date: $0.date,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    colorName: $0.colorName,
                    id: UUID()
                )
            }
            persistCachedEvents(self.cachedEvents)
            UserDefaults.standard.removeObject(forKey: cacheStorageKey)
        }
    }
}
