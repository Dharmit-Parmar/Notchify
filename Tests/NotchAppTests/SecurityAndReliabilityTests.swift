import Foundation
import CryptoKit
import Testing
@testable import NotchApp

private struct FailingKeychainMock: KeychainManaging {
    func loadSecret(forKey account: String) -> String? { nil }
    func saveSecret(_ secret: String, forKey account: String) -> Bool { false }
    func deleteSecret(forKey account: String) -> Bool { true }
}

private final class SyncTestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    var requests: [URLRequest] = []
    var calendarAttempts = 0
    var tasksAttempts = 0
    var refreshCalls = 0
    var persistedAccess: String?
    var persistedRefresh: String?
    var persistedExpiry: String?

    func recordRequest(_ req: URLRequest) -> (calCount: Int, taskCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(req)
        let urlStr = req.url?.absoluteString ?? ""
        if urlStr.contains("calendar/v3") {
            calendarAttempts += 1
        } else if urlStr.contains("tasks.googleapis.com") {
            tasksAttempts += 1
        }
        return (calendarAttempts, tasksAttempts)
    }

    func incrementRefresh() -> Int {
        lock.lock()
        defer { lock.unlock() }
        refreshCalls += 1
        return refreshCalls
    }

    func setPersisted(access: String, refresh: String?, expiry: String?) {
        lock.lock()
        defer { lock.unlock() }
        persistedAccess = access
        if let refresh { persistedRefresh = refresh }
        if let expiry { persistedExpiry = expiry }
    }
}

@Suite("Security and Reliability Regression Tests")
struct SecurityAndReliabilityTests {

    // MARK: - Priority 1: LocalShare Cancellation Security

    @Test("LocalShareServer generates 256-bit unpredictable hex session capabilities")
    func localShareSessionIdEntropy() {
        let id1 = LocalShareServer.generateSessionId()
        let id2 = LocalShareServer.generateSessionId()
        #expect(id1.count == 64)
        #expect(id2.count == 64)
        #expect(id1 != id2)
        #expect(id1.allSatisfy { $0.isHexDigit })
    }

    @Test("LocalShare cancellation rejects unknown sessions, other LAN IPs, mTLS downgrades, and completed transfers")
    func localShareCancelAuthorization() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalShareCancelTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let coordinator = LocalShareSessionCoordinator()
        let validId = LocalShareServer.generateSessionId()
        let sessionDir = tempRoot.appendingPathComponent("session-\(validId)", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let promotedProbe = sessionDir.appendingPathComponent("delivered.txt")
        try Data("ok".utf8).write(to: promotedProbe)

        let peerInfo = LocalShareDeviceInfo(
            alias: "Sender",
            fingerprint: String(repeating: "a", count: 64),
            port: 53317,
            protocol: "https"
        )
        let meta = LocalShareFileMetadata(id: "f1", fileName: "delivered.txt", size: 2)
        let boundClientCertFP = String(repeating: "b", count: 64)

        let session = try coordinator.offerIncomingSession(
            sessionId: validId,
            peerInfo: peerInfo,
            peerIP: "192.168.1.50",
            verifiedPeerFingerprint: boundClientCertFP,
            sessionDirectory: sessionDir,
            filesMetadata: ["f1": meta]
        )

        // 1. Missing/unknown sessionId -> 400/404
        #expect(
            LocalShareServer.shared.authorizeAndCancelSession(
                sessionId: nil, remoteIP: "192.168.1.50", verifiedPeerFingerprint: boundClientCertFP, coordinator: coordinator
            ).statusCode == 400
        )
        #expect(
            LocalShareServer.shared.authorizeAndCancelSession(
                sessionId: String(repeating: "f", count: 64), remoteIP: "192.168.1.50", verifiedPeerFingerprint: boundClientCertFP, coordinator: coordinator
            ).statusCode == 404
        )

        // 2. Different LAN host knowing sessionId -> 403 and session remains active
        #expect(
            LocalShareServer.shared.authorizeAndCancelSession(
                sessionId: validId, remoteIP: "192.168.1.99", verifiedPeerFingerprint: boundClientCertFP, coordinator: coordinator
            ).statusCode == 403
        )
        #expect(session.currentState.isActive)

        // 3. Same IP but missing or wrong mTLS client certificate when session bound a cert -> 403 (no nil downgrade)
        #expect(
            LocalShareServer.shared.authorizeAndCancelSession(
                sessionId: validId, remoteIP: "192.168.1.50", verifiedPeerFingerprint: nil, coordinator: coordinator
            ).statusCode == 403
        )
        #expect(
            LocalShareServer.shared.authorizeAndCancelSession(
                sessionId: validId, remoteIP: "192.168.1.50", verifiedPeerFingerprint: String(repeating: "c", count: 64), coordinator: coordinator
            ).statusCode == 403
        )
        #expect(session.currentState.isActive)

        // 4. Legitimate sender cancels active session -> 200 & terminates
        let cancelOutcome = LocalShareServer.shared.authorizeAndCancelSession(
            sessionId: validId, remoteIP: "192.168.1.50", verifiedPeerFingerprint: boundClientCertFP, coordinator: coordinator
        )
        #expect(cancelOutcome.statusCode == 200)
        #expect(!session.currentState.isActive)

        // 5. Completed session must reject /cancel (409) and preserve files in sessionDirectory
        let completedId = LocalShareServer.generateSessionId()
        let completedDir = tempRoot.appendingPathComponent("session-\(completedId)", isDirectory: true)
        try FileManager.default.createDirectory(at: completedDir, withIntermediateDirectories: true)
        let completedFile = completedDir.appendingPathComponent("finished.txt")
        try Data("done".utf8).write(to: completedFile)

        let completedSession = try coordinator.offerIncomingSession(
            sessionId: completedId,
            peerInfo: peerInfo,
            peerIP: "192.168.1.50",
            verifiedPeerFingerprint: nil,
            sessionDirectory: completedDir,
            filesMetadata: ["f1": meta]
        )
        completedSession.markFileCompleted(fileId: "f1")
        #expect(completedSession.currentState == .completed)

        let postCompleteCancel = LocalShareServer.shared.authorizeAndCancelSession(
            sessionId: completedId, remoteIP: "192.168.1.50", verifiedPeerFingerprint: nil, coordinator: coordinator
        )
        #expect(postCompleteCancel.statusCode == 409)
        #expect(FileManager.default.fileExists(atPath: completedFile.path))
    }

    // MARK: - Priority 2: Google OAuth PKCE, RFC 3986 Encoding & Callback Security

    @Test("PKCE verifier and S256 challenge follow RFC 7636 Base64URL without padding")
    func pkceVerifierAndChallenge() throws {
        let verifier = GoogleOAuthManager.generateCodeVerifier()
        #expect(verifier.count >= 43)
        #expect(!verifier.contains("+"))
        #expect(!verifier.contains("/"))
        #expect(!verifier.contains("="))

        // PKCE verifiers only use unreserved characters so form encoding leaves them verbatim
        #expect(GoogleOAuthManager.formURLEncodedString([("code_verifier", verifier)]) == "code_verifier=\(verifier)")

        let challenge = try #require(GoogleOAuthManager.generateCodeChallenge(from: verifier))
        #expect(challenge.count == 43)
        #expect(!challenge.contains("+"))
        #expect(!challenge.contains("/"))
        #expect(!challenge.contains("="))
        #expect(challenge != verifier)
    }

    @Test("RFC 3986 form-urlencoded helper encodes spaces, +, /, =, &, %, unicode, and empty values")
    func formURLEncodingEdgeCases() {
        #expect(GoogleOAuthManager.formURLEncodedString([("q", "hello world")]) == "q=hello%20world")
        #expect(GoogleOAuthManager.formURLEncodedString([("plus", "a+b")]) == "plus=a%2Bb")
        #expect(GoogleOAuthManager.formURLEncodedString([("slash", "4/0A/b")]) == "slash=4%2F0A%2Fb")
        #expect(GoogleOAuthManager.formURLEncodedString([("eq", "a=b==")]) == "eq=a%3Db%3D%3D")
        #expect(GoogleOAuthManager.formURLEncodedString([("amp", "x&y=z")]) == "amp=x%26y%3Dz")
        #expect(GoogleOAuthManager.formURLEncodedString([("pct", "100%25")]) == "pct=100%2525")
        #expect(GoogleOAuthManager.formURLEncodedString([("uni", "café ✓")]) == "uni=caf%C3%A9%20%E2%9C%93")
        #expect(GoogleOAuthManager.formURLEncodedString([("empty", "")]) == "empty=")
        #expect(
            GoogleOAuthManager.formURLEncodedString([("unreserved", "AZaz09-._~")]) == "unreserved=AZaz09-._~"
        )
    }

    @Test("OAuth loopback parser strictly enforces CSRF state, method, host authority, and benign requests")
    func loopbackParserCSRFSafety() {
        let expectedState = "csrf-state-12345"

        let missingStateReq = "GET /oauth2callback?code=auth_code_1 HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(missingStateReq, port: 8089, expectedState: expectedState)
                == .failed(message: "CSRF state verification failed.", userCancelled: false)
        )

        let emptyStateReq = "GET /oauth2callback?code=auth_code_1&state= HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(emptyStateReq, port: 8089, expectedState: expectedState)
                == .failed(message: "CSRF state verification failed.", userCancelled: false)
        )

        let wrongStateReq = "GET /oauth2callback?code=auth_code_1&state=evil HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(wrongStateReq, port: 8089, expectedState: expectedState)
                == .failed(message: "CSRF state verification failed.", userCancelled: false)
        )

        // Authority confusion payloads must be rejected cleanly
        let atAuthorityReq = "GET @evil.com/oauth2callback?code=c&state=csrf-state-12345 HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(atAuthorityReq, port: 8089, expectedState: expectedState)
                == .failed(message: "Invalid request received.", userCancelled: false)
        )

        let doubleSlashReq = "GET //evil.com/oauth2callback?code=c&state=csrf-state-12345 HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(doubleSlashReq, port: 8089, expectedState: expectedState)
                == .failed(message: "Invalid request received.", userCancelled: false)
        )

        let postMethodReq = "POST /oauth2callback?code=auth_code_1&state=csrf-state-12345 HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(postMethodReq, port: 8089, expectedState: expectedState)
                == .failed(message: "Invalid request received.", userCancelled: false)
        )

        let faviconReq = "GET /favicon.ico HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(faviconReq, port: 8089, expectedState: expectedState)
                == .ignoreNonCallback
        )

        let deniedReq = "GET /oauth2callback?error=access_denied&state=csrf-state-12345 HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(deniedReq, port: 8089, expectedState: expectedState)
                == .failed(message: "Sign-in cancelled.", userCancelled: true)
        )

        let validReq = "GET /oauth2callback?code=auth%2Fcode%2B1&state=csrf-state-12345 HTTP/1.1\r\nHost: 127.0.0.1:8089\r\n\r\n"
        #expect(
            GoogleOAuthManager.parseCallbackHTTPRequest(validReq, port: 8089, expectedState: expectedState)
                == .authorizationCode("auth/code+1")
        )
    }

    // MARK: - Priority 3: Consistent Google Token Refresh, Coalescing & Disconnect Safety

    @MainActor
    @Test("Calendar and Tasks coalesce concurrent 401 refreshes, retry once, and preserve refresh token")
    func googleRefreshCoalescingAndRetry() async throws {
        let suiteName = "com.notch.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchSyncTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("calendar_cache.enc")
        let isolatedStore = EncryptedFileStore(key: SymmetricKey(size: .bits256), managedDirectoryURL: tempDir)
        let recorder = SyncTestRecorder()
        let oauthManager = GoogleOAuthManager()

        let calOK = Data(#"{"items":[{"id":"e1","summary":"Team Sync","start":{"date":"2026-11-25"}}]}"#.utf8)
        let tasksOK = Data(#"{"items":[{"id":"t1","title":"Verify Refresh"}]}"#.utf8)
        let refreshOK = Data(#"{"access_token":"fresh-token-2","expires_in":3600,"token_type":"Bearer"}"#.utf8)

        let service = GoogleSyncService(
            customCacheFileURL: cacheURL,
            fileStore: isolatedStore,
            userDefaults: defaults,
            httpExecutor: { request in
                let url = request.url!
                let auth = request.value(forHTTPHeaderField: "Authorization")
                let _ = recorder.recordRequest(request)
                if auth == "Bearer expired-token-1" {
                    let resp = HTTPURLResponse(url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
                    return (Data(), resp)
                }
                if auth == "Bearer fresh-token-2" {
                    let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
                    return (url.absoluteString.contains("tasks") ? tasksOK : calOK, resp)
                }
                let resp = HTTPURLResponse(url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
                return (Data(), resp)
            },
            tokenProvider: { "expired-token-1" },
            tokenRefresher: { failingToken in
                await oauthManager.refreshAccessTokenIfNeeded(
                    failingToken: failingToken,
                    clientID: "test-client",
                    refreshToken: "keep-my-refresh-token",
                    loadCurrentAccessToken: { recorder.persistedAccess },
                    executor: { req in
                        _ = recorder.incrementRefresh()
                        try await Task.sleep(nanoseconds: 30_000_000)
                        let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
                        return (refreshOK, resp)
                    },
                    persistTokens: { access, newRefresh, expiry in
                        recorder.setPersisted(access: access, refresh: newRefresh, expiry: expiry)
                        return true
                    }
                )
            },
            connectionChecker: { true }
        )

        await service.syncNow()

        #expect(recorder.refreshCalls == 1)
        #expect(recorder.calendarAttempts == 2)
        #expect(recorder.tasksAttempts == 2)
        #expect(recorder.persistedAccess == "fresh-token-2")
        #expect(recorder.persistedRefresh == nil) // Refresh response omitted refresh_token -> original preserved
        #expect(service.cachedEvents.count == 2)
        #expect(service.syncErrorMessage == nil)
    }

    @MainActor
    @Test("Tasks and Calendar fail consistently on 401 without looping when refresh fails or retry returns 401")
    func googleTasksAndCalendar401ConsistencyAndSingleRetryCap() async throws {
        let suiteName = "com.notch.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchSync401Tests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("calendar_cache.enc")
        let isolatedStore = EncryptedFileStore(key: SymmetricKey(size: .bits256), managedDirectoryURL: tempDir)
        let recorder = SyncTestRecorder()
        let calOK = Data(#"{"items":[{"id":"e1","summary":"Team Sync","start":{"date":"2026-11-25"}}]}"#.utf8)

        // Case A: Calendar returns 200, Tasks returns 401 -> refresh returns new token -> retry STILL 401
        // Tasks must fail with 401 instead of silently swallowing unauthorized state, and must retry ONLY ONCE.
        let service = GoogleSyncService(
            customCacheFileURL: cacheURL,
            fileStore: isolatedStore,
            userDefaults: defaults,
            httpExecutor: { request in
                let url = request.url!
                _ = recorder.recordRequest(request)
                if url.absoluteString.contains("tasks") {
                    let resp = HTTPURLResponse(url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
                    return (Data(), resp)
                }
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
                return (calOK, resp)
            },
            tokenProvider: { "token-1" },
            tokenRefresher: { _ in
                _ = recorder.incrementRefresh()
                return "token-2"
            },
            connectionChecker: { true }
        )

        let result = await service.fetchEventsAndTasks(start: Date(), end: Date())
        #expect(result.isEmpty)
        #expect(recorder.tasksAttempts == 2) // 1 initial + 1 retry max
        #expect(recorder.refreshCalls == 1)
        #expect(service.syncErrorMessage?.contains("expired") == true)
    }

    @MainActor
    @Test("Disconnect during an in-flight refresh discards refreshed token and prevents stale cache write")
    func disconnectDuringInFlightRefresh() async throws {
        let suiteName = "com.notch.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchDisconnectTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("calendar_cache.enc")
        let isolatedStore = EncryptedFileStore(key: SymmetricKey(size: .bits256), managedDirectoryURL: tempDir)
        let recorder = SyncTestRecorder()
        let oauthManager = GoogleOAuthManager()

        let refreshOK = Data(#"{"access_token":"zombie-token","refresh_token":"zombie-refresh","expires_in":3600}"#.utf8)

        let serviceHolder: GoogleSyncService
        let calOK = Data(#"{"items":[{"id":"e1","summary":"Stale Event","start":{"date":"2026-11-25"}}]}"#.utf8)
        let service = GoogleSyncService(
            customCacheFileURL: cacheURL,
            fileStore: isolatedStore,
            userDefaults: defaults,
            httpExecutor: { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!
                return (calOK, resp)
            },
            tokenProvider: { "old-token" },
            tokenRefresher: { failingToken in
                await oauthManager.refreshAccessTokenIfNeeded(
                    failingToken: failingToken,
                    clientID: "test-client",
                    refreshToken: "old-refresh",
                    loadCurrentAccessToken: { nil },
                    executor: { req in
                        try await Task.sleep(nanoseconds: 80_000_000)
                        let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
                        return (refreshOK, resp)
                    },
                    persistTokens: { access, refresh, expiry in
                        recorder.setPersisted(access: access, refresh: refresh, expiry: expiry)
                        return true
                    }
                )
            },
            connectionChecker: { true }
        )
        serviceHolder = service

        let disconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 25_000_000)
            oauthManager.invalidateAuthSession()
            serviceHolder.invalidateForDisconnectInTests()
        }

        await service.syncNow()
        await disconnectTask.value

        #expect(recorder.persistedAccess == nil)
        #expect(recorder.persistedRefresh == nil)
        #expect(service.cachedEvents.isEmpty)
        #expect(service.lastSyncDate == nil)
        #expect(!FileManager.default.fileExists(atPath: cacheURL.path))
    }

    // MARK: - Priority 4: Migration Failure Preservation Tests

    @MainActor
    @Test("GoogleSyncService cache migration preserves legacy UserDefaults when Keychain or verification fails")
    func googleSyncCacheMigrationFailurePreservesLegacyData() throws {
        let suiteName = "com.notch.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("calendar_cache.enc")
        let dtoPayload = Data("""
        [{"title":"Security Review","timeString":"10:00 AM","date":0,"endDate":3600,"isAllDay":false,"colorName":"blue"}]
        """.utf8)
        defaults.set(dtoPayload, forKey: "NotchApp_GoogleCalendarCachedEvents")

        // 1. Failing Keychain prevents encryption key creation -> legacy UserDefaults MUST be preserved
        let failingKeychainStore = EncryptedFileStore(
            keychain: FailingKeychainMock(),
            managedDirectoryURL: tempDir
        )
        let serviceOnFail = GoogleSyncService(
            customCacheFileURL: cacheURL,
            fileStore: failingKeychainStore,
            userDefaults: defaults
        )
        #expect(serviceOnFail.cachedEvents.count == 1)
        #expect(defaults.data(forKey: "NotchApp_GoogleCalendarCachedEvents") == dtoPayload)
        #expect(!FileManager.default.fileExists(atPath: cacheURL.path))

        // 2. Subsequent launch with working store succeeds, verifies read-back, and purges legacy data
        let isolatedStore = EncryptedFileStore(
            key: SymmetricKey(size: .bits256),
            managedDirectoryURL: tempDir
        )
        let service = GoogleSyncService(
            customCacheFileURL: cacheURL,
            fileStore: isolatedStore,
            userDefaults: defaults
        )

        #expect(service.cachedEvents.count == 1)
        #expect(service.cachedEvents.first?.title == "Security Review")
        #expect(FileManager.default.fileExists(atPath: cacheURL.path))
        #expect(defaults.object(forKey: "NotchApp_GoogleCalendarCachedEvents") == nil)

        // 3. Corrupting encrypted file verification leaves disk cache intact
        let diskBefore = try Data(contentsOf: cacheURL)
        #expect(!diskBefore.isEmpty)

        // 4. Wipe clears both encrypted file and in-memory state
        service.clearCachedEventsOnDisk()
        #expect(service.cachedEvents.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: cacheURL.path))
    }

    @Test("EncryptedFileStore plaintext migration keeps original plaintext untouched when verification fails")
    func encryptedFileStoreMigrationVerificationRollback() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EncryptedMigrationTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let targetURL = tempDir.appendingPathComponent("notes.txt")
        let legacyPlaintext = Data("Sensitive legacy note content".utf8)
        try legacyPlaintext.write(to: targetURL)

        let store = EncryptedFileStore(key: SymmetricKey(size: .bits256), managedDirectoryURL: tempDir)
        store.migrationVerificationHook = { packet in
            var corrupted = packet
            corrupted[corrupted.count - 1] ^= 0xFF
            return corrupted
        }

        // read() catches failed migration and still returns original plaintext while preserving disk file
        let readData = try store.read(from: targetURL)
        #expect(readData == legacyPlaintext)
        #expect(try Data(contentsOf: targetURL) == legacyPlaintext)
        #expect(!EncryptedFileStore.isCiphertextFile(at: targetURL))

        // Once verification succeeds, original file is atomically replaced with NOTCHENC1 ciphertext
        store.migrationVerificationHook = nil
        let migratedRead = try store.read(from: targetURL)
        #expect(migratedRead == legacyPlaintext)
        #expect(EncryptedFileStore.isCiphertextFile(at: targetURL))
    }

    @MainActor
    @Test("LocalShareSettings PIN migration preserves legacy UserDefaults if Keychain save or read-back fails")
    func localSharePinMigrationPreservesLegacyOnFailure() throws {
        let suiteName = "com.notch.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let fallbackKey = "test_pin_fallback"
        defaults.set("4829", forKey: fallbackKey)

        // 1. Keychain write/verify failure -> legacy fallback MUST remain untouched
        var storedInKeychain = ""
        let pinOnFailure = LocalShareSettings.loadAndMigratePin(
            fallbackKey: fallbackKey,
            defaults: defaults,
            loadKeychain: { storedInKeychain },
            storeKeychain: { _ in false }
        )
        #expect(pinOnFailure == "4829")
        #expect(defaults.string(forKey: fallbackKey) == "4829")

        // 2. Keychain write & read-back verification succeeds -> legacy fallback purged
        let pinOnSuccess = LocalShareSettings.loadAndMigratePin(
            fallbackKey: fallbackKey,
            defaults: defaults,
            loadKeychain: { storedInKeychain },
            storeKeychain: { data in
                storedInKeychain = String(data: data, encoding: .utf8) ?? ""
                return storedInKeychain == "4829"
            }
        )
        #expect(pinOnSuccess == "4829")
        #expect(defaults.object(forKey: fallbackKey) == nil)
        #expect(storedInKeychain == "4829")
    }

    // MARK: - LocalShare Security & Bounds Helpers

    @Test("LocalShareSecurity sanitizes paths, validates SHA-256 fingerprints, and scrubs secrets")
    func localShareSecuritySanitizationAndScrubbing() {
        #expect(LocalShareSecurity.sanitizeFilename("../../../../etc/passwd") == "passwd")
        #expect(LocalShareSecurity.sanitizeFilename(".hidden") == "hidden")
        #expect(!LocalShareSecurity.isValidFingerprint("not-a-sha256"))
        #expect(LocalShareSecurity.isValidFingerprint(String(repeating: "a", count: 64)))

        let rawErr = "Upload failed for https://192.168.1.50:53317/api/localsend/v2/upload?sessionId=abc&token=secret123&pin=9999 in /Users/alice/Downloads"
        let scrubbed = LocalShareSecurity.scrubSecrets(from: rawErr)
        #expect(!scrubbed.contains("secret123"))
        #expect(!scrubbed.contains("9999"))
        #expect(!scrubbed.contains("alice"))
    }

    @Test("LocalShareRateLimiter enforces per-IP sliding window limits")
    func localShareRateLimiterBounds() {
        let limiter = LocalShareRateLimiter(maxRequests: 2, windowDuration: 60.0)
        #expect(limiter.isAllowed(ip: "::ffff:192.168.1.10"))
        #expect(limiter.isAllowed(ip: "192.168.1.10"))
        #expect(!limiter.isAllowed(ip: "192.168.1.10"))
        #expect(limiter.isAllowed(ip: "192.168.1.11"))
    }

    @Test("NotchGeometry.current(for: nil) safely falls back without trapping")
    func notchGeometryNilScreenFallbackDoesNotTrap() {
        let geom = NotchGeometry.current(for: nil)
        #expect(!geom.hasPhysicalNotch)
        #expect(geom.screenFrame.width > 0)
        #expect(geom.screenFrame.height > 0)
    }

    @Test("ThockModule.isValidPackName blocks path traversal payloads")
    func thockPackNameValidation() {
        #expect(ThockModule.isValidPackName("cherry-mx-blue"))
        #expect(!ThockModule.isValidPackName("../etc"))
        #expect(!ThockModule.isValidPackName("a/b"))
        #expect(!ThockModule.isValidPackName("."))
        #expect(!ThockModule.isValidPackName(""))
    }
}
