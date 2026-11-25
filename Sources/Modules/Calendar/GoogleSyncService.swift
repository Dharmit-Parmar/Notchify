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

// MARK: - Redirect-Blocking Delegate for Sync API Calls

private final class GoogleSyncNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

// MARK: - Google Sync Service

@MainActor
public final class GoogleSyncService: ObservableObject {

    public static let shared = GoogleSyncService()

    public static let oauthTokenKey = "google_oauth_token"
    public static let accountEmailKey = "google_account_email"
    public static let calendarFeedUrlKey = "google_calendar_feed_url"

    private nonisolated static let noRedirectDelegate = GoogleSyncNoRedirectDelegate()
    private nonisolated static let apiSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config, delegate: noRedirectDelegate, delegateQueue: nil)
    }()

    // MARK: Published State

    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var syncErrorMessage: String?
    @Published public private(set) var cachedEvents: [CalendarEventItem] = []

    private let cacheStorageKey = "NotchApp_GoogleCalendarCachedEvents"
    private let customCacheFileURL: URL?
    private let fileStore: EncryptedFileStore
    private let userDefaults: UserDefaults

    typealias HTTPExecutor = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    typealias TokenProvider = @MainActor () async -> String?
    typealias TokenRefresher = @MainActor (String?) async -> String?

    private let httpExecutor: HTTPExecutor
    private let tokenProvider: TokenProvider
    private let tokenRefresher: TokenRefresher
    private let connectionChecker: (@MainActor () -> Bool)?
    private var syncGeneration: UInt64 = 0

    public var isConnected: Bool {
        if let connectionChecker {
            return connectionChecker()
        }
        let email = SettingsStore.shared.connectedGoogleEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = KeychainHelper.shared.loadSecret(forKey: Self.oauthTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !email.isEmpty || !token.isEmpty
    }

    public var connectedEmail: String {
        SettingsStore.shared.connectedGoogleEmail
    }

    private init() {
        self.customCacheFileURL = nil
        self.fileStore = .shared
        self.userDefaults = .standard
        self.httpExecutor = { request in
            try await GoogleSyncService.apiSession.data(for: request)
        }
        self.tokenProvider = {
            await GoogleOAuthManager.shared.validAccessToken()
        }
        self.tokenRefresher = { failingToken in
            await GoogleOAuthManager.shared.refreshAccessTokenIfNeeded(failingToken: failingToken)
        }
        self.connectionChecker = nil
        loadCachedEvents()
    }

    /// Internal initializer for isolated cache/migration and sync/refresh unit tests.
    init(
        customCacheFileURL: URL,
        fileStore: EncryptedFileStore = .shared,
        userDefaults: UserDefaults = .standard,
        httpExecutor: HTTPExecutor? = nil,
        tokenProvider: TokenProvider? = nil,
        tokenRefresher: TokenRefresher? = nil,
        connectionChecker: (@MainActor () -> Bool)? = nil
    ) {
        self.customCacheFileURL = customCacheFileURL
        self.fileStore = fileStore
        self.userDefaults = userDefaults
        self.httpExecutor = httpExecutor ?? { request in
            try await GoogleSyncService.apiSession.data(for: request)
        }
        self.tokenProvider = tokenProvider ?? {
            await GoogleOAuthManager.shared.validAccessToken()
        }
        self.tokenRefresher = tokenRefresher ?? { failingToken in
            await GoogleOAuthManager.shared.refreshAccessTokenIfNeeded(failingToken: failingToken)
        }
        self.connectionChecker = connectionChecker
        loadCachedEvents()
    }

    // MARK: - Account Connection Management (Single Google Login across Notch)

    public func connectAccount(email: String, token: String) {
        syncGeneration &+= 1
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")

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
        syncGeneration &+= 1
        GoogleOAuthManager.shared.invalidateAuthSession()

        SettingsStore.shared.connectedGoogleEmail = ""
        KeychainHelper.shared.deleteSecret(forKey: Self.oauthTokenKey)
        KeychainHelper.shared.deleteSecret(forKey: Self.accountEmailKey)
        KeychainHelper.shared.deleteSecret(forKey: Self.calendarFeedUrlKey)
        KeychainHelper.shared.deleteSecret(forKey: GoogleOAuthManager.refreshTokenKey)
        KeychainHelper.shared.deleteSecret(forKey: GoogleOAuthManager.tokenExpiryKey)

        clearCachedEventsOnDisk()
        isSyncing = false

        FeedbackManager.playDelete()
        NotificationCenter.default.post(name: .googleAccountDidChange, object: nil)
    }

    func invalidateForDisconnectInTests() {
        syncGeneration &+= 1
        GoogleOAuthManager.shared.invalidateAuthSession()
        clearCachedEventsOnDisk()
        isSyncing = false
    }

    func clearCachedEventsOnDisk() {
        cachedEvents = []
        lastSyncDate = nil
        syncErrorMessage = nil
        userDefaults.removeObject(forKey: cacheStorageKey)
        try? FileManager.default.removeItem(at: cacheFileURL)
    }

    // MARK: - Synchronize Calendar Events & Tasks

    public func syncNow() async {
        guard isConnected else { return }
        let startGeneration = syncGeneration
        guard let token = await tokenProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return
        }
        guard startGeneration == syncGeneration, isConnected else {
            return
        }

        isSyncing = true
        syncErrorMessage = nil

        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let end = calendar.date(byAdding: .month, value: 2, to: now) ?? now

        let items = await fetchEventsAndTasks(start: start, end: end, preloadedToken: token)

        guard startGeneration == syncGeneration, isConnected else {
            isSyncing = false
            return
        }

        if syncErrorMessage == nil {
            self.cachedEvents = items
            self.lastSyncDate = Date()
            _ = persistCachedEvents(items)
        }

        self.isSyncing = false
    }

    // MARK: - Fetch Google Calendar & Tasks Data

    public func fetchEventsAndTasks(start: Date, end: Date) async -> [CalendarEventItem] {
        return await fetchEventsAndTasks(start: start, end: end, preloadedToken: nil)
    }

    private func fetchEventsAndTasks(start: Date, end: Date, preloadedToken: String?) async -> [CalendarEventItem] {
        let startGeneration = syncGeneration
        let resolvedToken: String?
        if let preloadedToken {
            resolvedToken = preloadedToken
        } else {
            resolvedToken = await tokenProvider()
        }
        guard startGeneration == syncGeneration,
              let token = resolvedToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              !token.contains("\r"),
              !token.contains("\n") else {
            // If user only provided email or no token yet, return cached events if available
            return cachedEvents
        }

        do {
            // Concurrent execution via async let (Swift 6 structured concurrency)
            async let calendarEvents = fetchGoogleCalendarEvents(token: token, start: start, end: end, startGeneration: startGeneration)
            async let taskEvents = fetchGoogleTasks(token: token, start: start, end: end, startGeneration: startGeneration)

            let (calResults, taskResults) = try await (calendarEvents, taskEvents)
            guard startGeneration == syncGeneration, isConnected else {
                return cachedEvents
            }
            let combined = (calResults + taskResults).sorted { $0.date < $1.date }

            self.syncErrorMessage = nil
            return combined
        } catch {
            guard startGeneration == syncGeneration, isConnected else {
                return cachedEvents
            }
            self.syncErrorMessage = error.localizedDescription
            return cachedEvents
        }
    }

    // MARK: - Unified Authorized GET with Single 401 Refresh & Retry

    private func performAuthorizedGET(
        url: URL,
        token: String,
        startGeneration: UInt64
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        let (data, response) = try await httpExecutor(request)
        guard startGeneration == syncGeneration else {
            throw NSError(domain: "GoogleSync", code: NSUserCancelledError, userInfo: [NSLocalizedDescriptionKey: "Google account disconnected during sync."])
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GoogleSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Google."])
        }

        if httpResponse.statusCode != 401 {
            return (data, httpResponse)
        }

        // Single coalesced refresh attempt + at most one retry
        guard let refreshedToken = await tokenRefresher(token)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !refreshedToken.isEmpty,
              !refreshedToken.contains("\r"),
              !refreshedToken.contains("\n"),
              startGeneration == syncGeneration else {
            throw NSError(domain: "GoogleSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Google session expired. Please sign in again in Settings."])
        }

        var retryRequest = request
        retryRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
        let (retryData, retryResponse) = try await httpExecutor(retryRequest)
        guard startGeneration == syncGeneration else {
            throw NSError(domain: "GoogleSync", code: NSUserCancelledError, userInfo: [NSLocalizedDescriptionKey: "Google account disconnected during sync."])
        }
        guard let retryHTTP = retryResponse as? HTTPURLResponse else {
            throw NSError(domain: "GoogleSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Google."])
        }
        if retryHTTP.statusCode == 401 {
            throw NSError(domain: "GoogleSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Google session expired. Please sign in again in Settings."])
        }
        return (retryData, retryHTTP)
    }

    // MARK: - Google Calendar API v3

    private func fetchGoogleCalendarEvents(token: String, start: Date, end: Date, startGeneration: UInt64) async throws -> [CalendarEventItem] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let startStr = isoFormatter.string(from: start)
        let endStr = isoFormatter.string(from: end)

        guard let encodedStart = startStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEnd = endStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(encodedStart)&timeMax=\(encodedEnd)&singleEvents=true&orderBy=startTime&maxResults=250") else {
            return []
        }

        let (data, httpResponse) = try await performAuthorizedGET(url: url, token: token, startGeneration: startGeneration)
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "GoogleSync", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Calendar sync failed (HTTP \(httpResponse.statusCode))."])
        }

        let list = try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data)
        guard let items = list.items else { return [] }

        return items.compactMap { item in
            self.convertGoogleEventToItem(item)
        }
    }

    // MARK: - Google Tasks API v1

    private func fetchGoogleTasks(token: String, start: Date, end: Date, startGeneration: UInt64) async throws -> [CalendarEventItem] {
        guard let url = URL(string: "https://tasks.googleapis.com/tasks/v1/users/@me/lists/@default/tasks?showCompleted=false&maxResults=100") else {
            return []
        }

        let (data, httpResponse) = try await performAuthorizedGET(url: url, token: token, startGeneration: startGeneration)
        guard httpResponse.statusCode == 200 else {
            // Tasks API might not be enabled (e.g. 403/404); gracefully return empty list without failing calendar, while 401 still fails consistently above
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
        if let customCacheFileURL {
            return customCacheFileURL
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotchApp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        return dir.appendingPathComponent("calendar_cache.enc")
    }

    @discardableResult
    func persistCachedEvents(_ items: [CalendarEventItem]) -> Bool {
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
        guard let data = try? JSONEncoder().encode(dtos) else {
            return false
        }
        let target = cacheFileURL
        let stagingURL = target.deletingLastPathComponent()
            .appendingPathComponent(".\(target.lastPathComponent).stage_\(UUID().uuidString).tmp")
        do {
            try fileStore.write(data: data, to: stagingURL)
            guard let verifyData = try fileStore.read(from: stagingURL),
                  let verified = try? JSONDecoder().decode([CachedEventDTO].self, from: verifyData),
                  verified.count == dtos.count else {
                try? FileManager.default.removeItem(at: stagingURL)
                return false
            }
            _ = try FileManager.default.replaceItemAt(target, withItemAt: stagingURL, backupItemName: nil, options: [])
            return true
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            return false
        }
    }

    private func loadCachedEvents() {
        // 1. Try AES-256-GCM encrypted cache first
        if FileManager.default.fileExists(atPath: cacheFileURL.path),
           let data = try? fileStore.read(from: cacheFileURL),
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
            userDefaults.removeObject(forKey: cacheStorageKey)
            return
        }

        // 2. Legacy unencrypted fallback: migrate to AES-256-GCM and purge plaintext only after read-back verification
        if let data = userDefaults.data(forKey: cacheStorageKey),
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
            if persistCachedEvents(self.cachedEvents) {
                userDefaults.removeObject(forKey: cacheStorageKey)
            }
        }
    }
}
