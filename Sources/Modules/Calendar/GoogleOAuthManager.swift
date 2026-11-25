import Foundation
import AuthenticationServices
import CryptoKit
import AppKit

// MARK: - Google OAuth Error

public enum GoogleOAuthError: LocalizedError, Sendable {
    case missingClientID
    case codeGenerationFailed
    case invalidAuthURL
    case userCancelled
    case missingAuthorizationCode
    case tokenExchangeFailed(String)
    case userInfoFailed(String)
    case loopbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Please provide a Google Cloud Desktop Client ID in Settings."
        case .codeGenerationFailed:
            return "Failed to generate secure cryptographic PKCE challenge."
        case .invalidAuthURL:
            return "Invalid Google Authorization URL."
        case .userCancelled:
            return "Google sign-in was cancelled or timed out."
        case .missingAuthorizationCode:
            return "No authorization code returned from Google."
        case .tokenExchangeFailed(let msg):
            return "Token exchange failed: \(msg)"
        case .userInfoFailed(let msg):
            return "Failed to fetch user profile: \(msg)"
        case .loopbackFailed(let msg):
            return "Loopback server error: \(msg)"
        }
    }
}

// MARK: - Google Token Response (RFC 6749)

public struct GoogleTokenResponse: Decodable, Sendable {
    public let accessToken: String
    public let expiresIn: Int?
    public let refreshToken: String?
    public let tokenType: String?
    public let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case idToken = "id_token"
    }
}

// MARK: - Google User Info

public struct GoogleUserInfo: Decodable, Sendable {
    public let sub: String?
    public let name: String?
    public let email: String?
    public let picture: String?
}

// MARK: - Redirect-Blocking Delegate (RFC 8252 / Security Hardening)

private final class GoogleOAuthNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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

// MARK: - Google OAuth Manager (RFC 8252 Public Native Client PKCE)

@MainActor
public final class GoogleOAuthManager: ObservableObject {

    public static let shared = GoogleOAuthManager()

    public static let refreshTokenKey = "google_oauth_refresh_token"
    public static let tokenExpiryKey = "google_oauth_token_expires_at"

    @Published public private(set) var isAuthenticating: Bool = false
    @Published public private(set) var authErrorMessage: String?

    private var refreshTask: Task<String?, Never>?
    public private(set) var authGeneration: UInt64 = 0

    private final class LoopbackCancelBox: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }
    }

    private nonisolated static let noRedirectDelegate = GoogleOAuthNoRedirectDelegate()
    private nonisolated static let oauthSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config, delegate: noRedirectDelegate, delegateQueue: nil)
    }()

    init() {}

    // MARK: - Form URL Encoding (RFC 3986 Unreserved Set)

    public nonisolated static func formURLEncodedString(_ params: [(String, String)]) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }

    // MARK: - PKCE Helpers (RFC 7636)

    public nonisolated static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    public nonisolated static func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Interactive Google Sign-In (RFC 8252 Native App Flow)

    public func signIn(clientID customClientID: String? = nil) async throws -> GoogleUserInfo {
        guard !isAuthenticating else {
            throw GoogleOAuthError.loopbackFailed("A Google sign-in is already in progress.")
        }

        let rawID = (customClientID ?? SettingsStore.shared.googleOAuthClientId)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawID.isEmpty else {
            let err = GoogleOAuthError.missingClientID
            authErrorMessage = err.localizedDescription
            throw err
        }

        let clientID = rawID

        isAuthenticating = true
        authErrorMessage = nil
        defer { isAuthenticating = false }
        let startGeneration = authGeneration

        // 1. Generate PKCE verifier and S256 challenge (RFC 7636)
        let verifier = Self.generateCodeVerifier()
        guard let challenge = Self.generateCodeChallenge(from: verifier) else {
            throw GoogleOAuthError.codeGenerationFailed
        }

        // 2. Generate cryptographically strong random State for CSRF defense
        let state = UUID().uuidString

        // 3. Bind local loopback socket BEFORE opening browser (eliminates race condition)
        let (serverSocket, boundPort) = try Self.createListeningSocket()
        let redirectURI = "http://127.0.0.1:\(boundPort)/oauth2callback"

        // 4. Construct Authorization URL with required scopes
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        let scopes = [
            "openid",
            "email",
            "profile",
            "https://www.googleapis.com/auth/calendar.events.readonly",
            "https://www.googleapis.com/auth/tasks.readonly"
        ].joined(separator: " ")

        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components?.url else {
            close(serverSocket)
            throw GoogleOAuthError.invalidAuthURL
        }

        // 5. Open user's default browser and await loopback callback
        let cancelBox = LoopbackCancelBox()
        let authCode: String
        do {
            authCode = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    Task.detached {
                        do {
                            let code = try Self.runLoopbackListener(
                                serverSocket: serverSocket,
                                port: boundPort,
                                expectedState: state,
                                timeoutSeconds: 120,
                                cancelBox: cancelBox
                            )
                            continuation.resume(returning: code)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }

                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(authURL)
                    }
                }
            } onCancel: {
                cancelBox.cancel()
            }
        } catch {
            authErrorMessage = error.localizedDescription
            throw error
        }

        // 6. Exchange Authorization Code for Tokens (RFC 8252 Public Client: NO client_secret)
        let tokens = try await exchangeCodeForTokens(
            code: authCode,
            verifier: verifier,
            clientID: clientID,
            redirectURI: redirectURI
        )

        let cleanAccessToken = tokens.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAccessToken.isEmpty,
              !cleanAccessToken.contains("\r"),
              !cleanAccessToken.contains("\n") else {
            let err = GoogleOAuthError.tokenExchangeFailed("Google returned an invalid access token.")
            authErrorMessage = err.localizedDescription
            throw err
        }

        // 7. Retrieve User Profile BEFORE persisting credentials so failed fetches never leave partial state
        let userInfo = try await fetchUserInfo(accessToken: cleanAccessToken)

        guard !Task.isCancelled, startGeneration == authGeneration else {
            throw GoogleOAuthError.userCancelled
        }

        // 8. Store Access, Refresh Tokens, and Expiry in Keychain
        guard KeychainHelper.shared.saveSecret(cleanAccessToken, forKey: GoogleSyncService.oauthTokenKey) else {
            let err = GoogleOAuthError.tokenExchangeFailed("Unable to store Google access token in Keychain.")
            authErrorMessage = err.localizedDescription
            throw err
        }
        if let refreshToken = tokens.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !refreshToken.isEmpty {
            _ = KeychainHelper.shared.saveSecret(refreshToken, forKey: Self.refreshTokenKey)
        }
        if let expiresIn = tokens.expiresIn, expiresIn > 0 {
            let expiryEpoch = String(Date().addingTimeInterval(TimeInterval(expiresIn)).timeIntervalSince1970)
            _ = KeychainHelper.shared.saveSecret(expiryEpoch, forKey: Self.tokenExpiryKey)
        }
        if let email = userInfo.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            SettingsStore.shared.connectedGoogleEmail = email
            _ = KeychainHelper.shared.saveSecret(email, forKey: GoogleSyncService.accountEmailKey)
        }

        // 9. Play Success Feedback & Broadcast Account Change
        FeedbackManager.playSuccess()
        NotificationCenter.default.post(name: .googleAccountDidChange, object: nil)
        await GoogleSyncService.shared.syncNow()

        return userInfo
    }

    // MARK: - Native Loopback HTTP Server (RFC 8252 Section 7.3)

    private nonisolated static func createListeningSocket(preferredPorts: [UInt16] = [8089, 8090, 8091, 0]) throws -> (Int32, UInt16) {
        for port in preferredPorts {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            if fd < 0 { continue }

            var opt: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")

            let bindRes = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            if bindRes == 0 && listen(fd, 1) == 0 {
                var boundAddr = sockaddr_in()
                var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let nameRes = withUnsafeMutablePointer(to: &boundAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        getsockname(fd, $0, &addrLen)
                    }
                }
                let actualPort = nameRes == 0 ? UInt16(bigEndian: boundAddr.sin_port) : port
                return (fd, actualPort)
            }
            close(fd)
        }
        throw GoogleOAuthError.loopbackFailed("Unable to bind local loopback listener.")
    }

    public enum LoopbackParseOutcome: Equatable, Sendable {
        case authorizationCode(String)
        case ignoreNonCallback
        case failed(message: String, userCancelled: Bool)
    }

    public nonisolated static func parseCallbackHTTPRequest(
        _ reqString: String,
        port: UInt16,
        expectedState: String
    ) -> LoopbackParseOutcome {
        guard let firstLine = reqString.components(separatedBy: "\r\n").first else {
            return .failed(message: "Invalid request received.", userCancelled: false)
        }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count == 3,
              parts[0] == "GET",
              parts[1].hasPrefix("/"),
              !parts[1].hasPrefix("//"),
              parts[2].hasPrefix("HTTP/1."),
              let url = URL(string: "http://127.0.0.1:\(port)" + parts[1]),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "127.0.0.1",
              components.port == Int(port) else {
            return .failed(message: "Invalid request received.", userCancelled: false)
        }

        if components.path != "/oauth2callback" {
            return .ignoreNonCallback
        }

        let queryItems = components.queryItems ?? []

        // Strict CSRF verification: state parameter MUST be present AND match expectedState
        guard let state = queryItems.first(where: { $0.name == "state" })?.value,
              !state.isEmpty,
              state == expectedState else {
            return .failed(message: "CSRF state verification failed.", userCancelled: false)
        }

        if let errorParam = queryItems.first(where: { $0.name == "error" })?.value {
            if errorParam == "access_denied" {
                return .failed(message: "Sign-in cancelled.", userCancelled: true)
            }
            return .failed(message: errorParam, userCancelled: false)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            return .failed(message: "No authorization code returned.", userCancelled: false)
        }

        return .authorizationCode(code)
    }

    private nonisolated static func runLoopbackListener(
        serverSocket: Int32,
        port: UInt16,
        expectedState: String,
        timeoutSeconds: Int = 120,
        cancelBox: LoopbackCancelBox
    ) throws -> String {
        defer { close(serverSocket) }

        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        while true {
            if cancelBox.isCancelled {
                throw GoogleOAuthError.userCancelled
            }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                throw GoogleOAuthError.userCancelled
            }

            var pfd = pollfd(fd: serverSocket, events: Int16(POLLIN), revents: 0)
            let sliceSeconds = min(remaining, 0.25)
            let timeoutMs = Int32(min(Int.max, max(1, Int(ceil(sliceSeconds * 1000.0)))))
            let ready = poll(&pfd, 1, timeoutMs)
            if ready == 0 {
                continue
            }
            if ready < 0 {
                if errno == EINTR { continue }
                throw GoogleOAuthError.loopbackFailed("Loopback poll failed (errno \(errno))")
            }

            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientLen)
                }
            }

            guard clientSocket >= 0 else {
                if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
                throw GoogleOAuthError.loopbackFailed("Connection accept failed (errno \(errno))")
            }

            defer { close(clientSocket) }

            var buffer = [UInt8](repeating: 0, count: 8192)
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            guard bytesRead > 0 else {
                continue
            }
            let reqString = String(decoding: buffer[..<bytesRead], as: UTF8.self)

            switch parseCallbackHTTPRequest(reqString, port: port, expectedState: expectedState) {
            case .ignoreNonCallback:
                let noContent = "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n"
                _ = noContent.withCString { send(clientSocket, $0, strlen($0), 0) }
                continue
            case .failed(let message, let userCancelled):
                sendResponse(to: clientSocket, isSuccess: false, message: userCancelled ? "Sign-in cancelled." : message)
                if userCancelled {
                    throw GoogleOAuthError.userCancelled
                }
                if message == "No authorization code returned." || message == "Invalid request received." {
                    throw GoogleOAuthError.missingAuthorizationCode
                }
                throw GoogleOAuthError.tokenExchangeFailed(message)
            case .authorizationCode(let code):
                sendResponse(to: clientSocket, isSuccess: true, message: "Your Google Account is connected. Return to Notch.")
                return code
            }
        }
    }

    private nonisolated static func sendResponse(to socket: Int32, isSuccess: Bool, message: String) {
        let badge = isSuccess ? "✓" : "✕"
        let badgeColor = isSuccess ? "#34c759" : "#ff3b30"
        let title = isSuccess ? "Signed in to Notch" : "Authentication Incomplete"

        let html = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Connection: close\r
        \r
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Notch - Google Authentication</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #121214; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .card { background: #1c1c1e; border: 1px solid rgba(255,255,255,0.12); border-radius: 16px; padding: 32px 40px; text-align: center; box-shadow: 0 16px 40px rgba(0,0,0,0.5); max-width: 360px; }
            .badge { width: 44px; height: 44px; border-radius: 50%; background: \(badgeColor); color: #fff; display: inline-flex; align-items: center; justify-content: center; font-size: 20px; font-weight: bold; margin-bottom: 12px; }
            h1 { font-size: 19px; font-weight: 700; margin: 0 0 8px; }
            p { color: rgba(255,255,255,0.7); font-size: 13px; line-height: 1.5; margin: 0; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="badge">\(badge)</div>
            <h1>\(title)</h1>
            <p>\(message)</p>
          </div>
        </body>
        </html>
        """
        _ = html.withCString { send(socket, $0, strlen($0), 0) }
    }

    // MARK: - Exchange Code for Tokens (RFC 8252 Public Desktop Client)

    private func exchangeCodeForTokens(
        code: String,
        verifier: String,
        clientID: String,
        redirectURI: String
    ) async throws -> GoogleTokenResponse {
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            throw GoogleOAuthError.tokenExchangeFailed("Invalid token endpoint")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        let bodyParams: [(String, String)] = [
            ("client_id", clientID),
            ("code", code),
            ("code_verifier", verifier),
            ("redirect_uri", redirectURI),
            ("grant_type", "authorization_code")
        ]

        request.httpBody = Self.formURLEncodedString(bodyParams).data(using: .utf8)

        let (data, response) = try await Self.oauthSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.tokenExchangeFailed("No HTTP response received")
        }

        guard httpResponse.statusCode == 200 else {
            var reason = "HTTP \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let desc = json["error_description"] as? String, !desc.isEmpty {
                    reason = desc
                } else if let errCode = json["error"] as? String, !errCode.isEmpty {
                    reason = errCode
                }
            }
            throw GoogleOAuthError.tokenExchangeFailed(reason)
        }

        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    // MARK: - Fetch User Profile Information

    public func fetchUserInfo(accessToken: String) async throws -> GoogleUserInfo {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo") else {
            throw GoogleOAuthError.userInfoFailed("Invalid user info endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0

        let (data, response) = try await Self.oauthSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleOAuthError.userInfoFailed("Failed to fetch Google profile info")
        }

        return try JSONDecoder().decode(GoogleUserInfo.self, from: data)
    }

    // MARK: - Automatic Access Token Refresh (Coalesced, Disconnect-Safe, Preserves Refresh Token)

    public func invalidateAuthSession() {
        authGeneration &+= 1
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func validAccessToken(minimumLifetimeSeconds: TimeInterval = 60) async -> String? {
        guard let storedToken = KeychainHelper.shared.loadSecret(forKey: GoogleSyncService.oauthTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !storedToken.isEmpty else {
            return await refreshAccessTokenIfNeeded()
        }

        if let expiryStr = KeychainHelper.shared.loadSecret(forKey: Self.tokenExpiryKey),
           let expiryEpoch = Double(expiryStr),
           Date(timeIntervalSince1970: expiryEpoch) <= Date().addingTimeInterval(minimumLifetimeSeconds) {
            if let refreshed = await refreshAccessTokenIfNeeded(failingToken: storedToken) {
                return refreshed
            }
        }
        return storedToken
    }

    public func refreshAccessTokenIfNeeded(failingToken: String? = nil) async -> String? {
        guard let refreshToken = KeychainHelper.shared.loadSecret(forKey: Self.refreshTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !refreshToken.isEmpty else {
            return nil
        }
        let rawID = SettingsStore.shared.googleOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawID.isEmpty else { return nil }

        return await refreshAccessTokenIfNeeded(
            failingToken: failingToken,
            clientID: rawID,
            refreshToken: refreshToken,
            loadCurrentAccessToken: {
                KeychainHelper.shared.loadSecret(forKey: GoogleSyncService.oauthTokenKey)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            },
            executor: { request in
                try await Self.oauthSession.data(for: request)
            },
            persistTokens: { access, newRefresh, expiryEpoch in
                guard KeychainHelper.shared.saveSecret(access, forKey: GoogleSyncService.oauthTokenKey) else {
                    return false
                }
                if let newRefresh, !newRefresh.isEmpty {
                    _ = KeychainHelper.shared.saveSecret(newRefresh, forKey: Self.refreshTokenKey)
                }
                if let expiryEpoch {
                    _ = KeychainHelper.shared.saveSecret(expiryEpoch, forKey: Self.tokenExpiryKey)
                }
                return true
            }
        )
    }

    func refreshAccessTokenIfNeeded(
        failingToken: String? = nil,
        clientID: String,
        refreshToken: String,
        loadCurrentAccessToken: () -> String?,
        executor: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
        persistTokens: @escaping @MainActor (String, String?, String?) -> Bool
    ) async -> String? {
        if let failingToken,
           let currentToken = loadCurrentAccessToken(),
           !currentToken.isEmpty,
           currentToken != failingToken {
            return currentToken
        }

        if let inFlight = refreshTask {
            return await inFlight.value
        }

        let startGeneration = authGeneration
        let task = Task<String?, Never> { @MainActor [weak self] in
            guard let self = self else { return nil }
            defer { self.refreshTask = nil }
            return await self.performTokenRefresh(
                expectedGeneration: startGeneration,
                clientID: clientID,
                refreshToken: refreshToken,
                executor: executor,
                persistTokens: persistTokens
            )
        }
        self.refreshTask = task
        return await task.value
    }

    private func performTokenRefresh(
        expectedGeneration: UInt64,
        clientID: String,
        refreshToken: String,
        executor: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
        persistTokens: @escaping @MainActor (String, String?, String?) -> Bool
    ) async -> String? {
        guard !Task.isCancelled, expectedGeneration == authGeneration else {
            return nil
        }
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            return nil
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        let params: [(String, String)] = [
            ("client_id", clientID),
            ("refresh_token", refreshToken),
            ("grant_type", "refresh_token")
        ]

        request.httpBody = Self.formURLEncodedString(params).data(using: .utf8)

        do {
            let (data, response) = try await executor(request)
            guard !Task.isCancelled, expectedGeneration == authGeneration else {
                return nil
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
            let cleanAccess = tokenResponse.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanAccess.isEmpty,
                  !cleanAccess.contains("\r"),
                  !cleanAccess.contains("\n") else { return nil }

            let cleanRefresh = tokenResponse.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            let expiryEpoch: String? = {
                guard let expiresIn = tokenResponse.expiresIn, expiresIn > 0 else { return nil }
                return String(Date().addingTimeInterval(TimeInterval(expiresIn)).timeIntervalSince1970)
            }()

            guard !Task.isCancelled, expectedGeneration == authGeneration,
                  persistTokens(cleanAccess, (cleanRefresh?.isEmpty == false) ? cleanRefresh : nil, expiryEpoch) else {
                return nil
            }
            return cleanAccess
        } catch {
            return nil
        }
    }
}
