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

// MARK: - Google OAuth Manager (RFC 8252 Public Native Client PKCE)

@MainActor
public final class GoogleOAuthManager: ObservableObject {

    public static let shared = GoogleOAuthManager()

    public static let refreshTokenKey = "google_oauth_refresh_token"

    @Published public private(set) var isAuthenticating: Bool = false
    @Published public private(set) var authErrorMessage: String?

    private init() {}

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
        let authCode: String
        do {
            authCode = try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    do {
                        let code = try Self.runLoopbackListener(
                            serverSocket: serverSocket,
                            port: boundPort,
                            expectedState: state,
                            timeoutSeconds: 120
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

        // 7. Store Access & Refresh Tokens securely in Keychain (Axiom Security)
        KeychainHelper.shared.saveSecret(tokens.accessToken, forKey: GoogleSyncService.oauthTokenKey)
        if let refreshToken = tokens.refreshToken, !refreshToken.isEmpty {
            KeychainHelper.shared.saveSecret(refreshToken, forKey: Self.refreshTokenKey)
        }

        // 8. Retrieve User Profile from Google UserInfo endpoint
        let userInfo = try await fetchUserInfo(accessToken: tokens.accessToken)
        if let email = userInfo.email {
            SettingsStore.shared.connectedGoogleEmail = email
            KeychainHelper.shared.saveSecret(email, forKey: GoogleSyncService.accountEmailKey)
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

    private nonisolated static func runLoopbackListener(
        serverSocket: Int32,
        port: UInt16,
        expectedState: String,
        timeoutSeconds: Int = 120
    ) throws -> String {
        defer { close(serverSocket) }

        // Socket timeout for accept to avoid hanging indefinitely if browser closed
        var tv = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        setsockopt(serverSocket, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var clientAddr = sockaddr_in()
        var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(serverSocket, $0, &clientLen)
            }
        }

        guard clientSocket >= 0 else {
            if errno == EAGAIN || errno == EWOULDBLOCK {
                throw GoogleOAuthError.userCancelled
            }
            throw GoogleOAuthError.loopbackFailed("Connection accept failed (errno \(errno))")
        }

        defer { close(clientSocket) }

        // Read HTTP request from browser redirect
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        let reqString = String(decoding: buffer[..<max(0, bytesRead)], as: UTF8.self)

        guard let firstLine = reqString.components(separatedBy: "\r\n").first,
              let path = firstLine.components(separatedBy: " ").dropFirst().first,
              let url = URL(string: "http://127.0.0.1:\(port)" + path),
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems else {
            sendResponse(to: clientSocket, isSuccess: false, message: "Invalid request received.")
            throw GoogleOAuthError.missingAuthorizationCode
        }

        // Verify state parameter against CSRF attacks
        if let state = queryItems.first(where: { $0.name == "state" })?.value,
           state != expectedState {
            sendResponse(to: clientSocket, isSuccess: false, message: "CSRF state verification failed.")
            throw GoogleOAuthError.tokenExchangeFailed("State parameter mismatch")
        }

        if let errorParam = queryItems.first(where: { $0.name == "error" })?.value {
            sendResponse(to: clientSocket, isSuccess: false, message: "Sign-in cancelled.")
            if errorParam == "access_denied" {
                throw GoogleOAuthError.userCancelled
            }
            throw GoogleOAuthError.tokenExchangeFailed(errorParam)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            sendResponse(to: clientSocket, isSuccess: false, message: "No authorization code returned.")
            throw GoogleOAuthError.missingAuthorizationCode
        }

        // Send successful response page
        sendResponse(to: clientSocket, isSuccess: true, message: "Your Google Account is connected. Return to Notch.")
        return code
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

        let bodyParams = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        let bodyString = bodyParams.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.tokenExchangeFailed("No HTTP response received")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw GoogleOAuthError.tokenExchangeFailed(errorBody)
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleOAuthError.userInfoFailed("Failed to fetch Google profile info")
        }

        return try JSONDecoder().decode(GoogleUserInfo.self, from: data)
    }

    // MARK: - Automatic Access Token Refresh (Preserves Refresh Token)

    public func refreshAccessTokenIfNeeded() async -> String? {
        guard let refreshToken = KeychainHelper.shared.loadSecret(forKey: Self.refreshTokenKey),
              !refreshToken.isEmpty else {
            return nil
        }

        let rawID = SettingsStore.shared.googleOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawID.isEmpty else { return nil }

        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            return nil
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0

        let params = [
            "client_id": rawID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        let bodyString = params.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
            KeychainHelper.shared.saveSecret(tokenResponse.accessToken, forKey: GoogleSyncService.oauthTokenKey)
            if let newRefresh = tokenResponse.refreshToken, !newRefresh.isEmpty {
                KeychainHelper.shared.saveSecret(newRefresh, forKey: Self.refreshTokenKey)
            }
            return tokenResponse.accessToken
        } catch {
            return nil
        }
    }
}
