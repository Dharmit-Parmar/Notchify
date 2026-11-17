import Foundation

// MARK: - Telegram Redirect Protection Delegate
private final class TelegramRedirectTaskDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let newURL = request.url,
              newURL.scheme == "https",
              newURL.host?.lowercased() == "api.telegram.org" else {
            // Drop redirect to prevent bot token forwarding to third-party hosts
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

/// Dedicated ephemeral HTTP client for Telegram Bot API operations (SEC-B-1).
/// Enforces ephemeral URLSession with zero disk caching, zero cookies, zero credential storage, and strict redirect isolation.
/// Strictly scrubs authentication tokens and sensitive endpoints from all error descriptions.
public final class TelegramClient: @unchecked Sendable {
    public static let shared = TelegramClient()
    
    private let session: URLSession
    
    public init(session: URLSession? = nil) {
        if let customSession = session {
            self.session = customSession
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.httpCookieStorage = nil
            config.urlCredentialStorage = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.timeoutIntervalForRequest = 8.0
            config.timeoutIntervalForResource = 15.0
            let delegate = TelegramRedirectTaskDelegate()
            self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        }
    }
    
    /// Redacts raw bot tokens, API URLs, and endpoint paths from error descriptions.
    public static func scrubErrorDescription(_ rawError: String, token: String) -> String {
        var scrubbed = rawError
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanToken.isEmpty {
            scrubbed = scrubbed.replacingOccurrences(of: cleanToken, with: "[REDACTED_TOKEN]")
        }
        
        // Scrub Telegram URL path patterns containing bot tokens
        let urlPattern = "https?://api\\.telegram\\.org/bot[^/\\s]+"
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) {
            let range = NSRange(scrubbed.startIndex..<scrubbed.endIndex, in: scrubbed)
            scrubbed = regex.stringByReplacingMatches(in: scrubbed, options: [], range: range, withTemplate: "https://api.telegram.org/bot[REDACTED_TOKEN]")
        }
        
        // Scrub standalone bot token patterns (e.g. 123456789:ABC-DEF...)
        let tokenPattern = "\\b[0-9]{8,11}:[A-Za-z0-9_-]{25,}\\b"
        if let regex = try? NSRegularExpression(pattern: tokenPattern, options: []) {
            let range = NSRange(scrubbed.startIndex..<scrubbed.endIndex, in: scrubbed)
            scrubbed = regex.stringByReplacingMatches(in: scrubbed, options: [], range: range, withTemplate: "[REDACTED_TOKEN]")
        }
        
        return scrubbed
    }
    
    /// Sends a text message to a chat/channel using Telegram Bot API.
    public func sendMessage(
        token: String,
        chatId: String,
        text: String
    ) async throws -> (ok: Bool, description: String?) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            throw NSError(
                domain: "TelegramClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Telegram bot token is missing"]
            )
        }
        
        guard let url = URL(string: "https://api.telegram.org/bot\(cleanToken)/sendMessage") else {
            throw NSError(
                domain: "TelegramClient",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Telegram API endpoint"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        
        let payload: [String: Any] = [
            "chat_id": chatId,
            "text": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let desc = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["description"] as? String
                let scrubbed = desc.map { Self.scrubErrorDescription($0, token: cleanToken) }
                return (false, scrubbed ?? "HTTP error \(http.statusCode)")
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool, ok {
                return (true, "Delivered via Telegram Bot ✓✓")
            } else {
                let desc = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["description"] as? String
                let scrubbed = desc.map { Self.scrubErrorDescription($0, token: cleanToken) }
                return (false, scrubbed ?? "Telegram API Error")
            }
        } catch {
            let scrubbedMsg = Self.scrubErrorDescription(error.localizedDescription, token: cleanToken)
            throw NSError(
                domain: "TelegramClient",
                code: (error as NSError).code,
                userInfo: [NSLocalizedDescriptionKey: scrubbedMsg]
            )
        }
    }
    
    /// Verifies Telegram bot token with getMe endpoint.
    public func getMe(token: String) async throws -> String {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            throw NSError(
                domain: "TelegramClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Telegram bot token is missing"]
            )
        }
        
        guard let url = URL(string: "https://api.telegram.org/bot\(cleanToken)/getMe") else {
            throw NSError(
                domain: "TelegramClient",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Telegram API endpoint"]
            )
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let desc = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["description"] as? String
                let scrubbed = desc.map { Self.scrubErrorDescription($0, token: cleanToken) }
                throw NSError(
                    domain: "TelegramClient",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: scrubbed ?? "HTTP \(http.statusCode)"]
                )
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool, ok,
               let result = json["result"] as? [String: Any],
               let username = result["username"] as? String {
                return username
            }
            throw NSError(
                domain: "TelegramClient",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Token"]
            )
        } catch {
            let scrubbedMsg = Self.scrubErrorDescription(error.localizedDescription, token: cleanToken)
            throw NSError(
                domain: "TelegramClient",
                code: (error as NSError).code,
                userInfo: [NSLocalizedDescriptionKey: scrubbedMsg]
            )
        }
    }
}
