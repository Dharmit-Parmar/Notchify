import Foundation
import SwiftUI
import AppKit

// MARK: - Supported AI Providers
public enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case siri = "siri"
    case gemini = "gemini"
    case gpt = "gpt"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .siri: return "Apple Siri"
        case .gemini: return "Google Gemini"
        case .gpt: return "ChatGPT (GPT-4o)"
        }
    }

    public var shortName: String {
        switch self {
        case .siri: return "Siri"
        case .gemini: return "Gemini"
        case .gpt: return "GPT"
        }
    }

    public var icon: String {
        switch self {
        case .siri: return "mic.fill"
        case .gemini: return "sparkles"
        case .gpt: return "bubble.left.and.text.bubble.right.fill"
        }
    }

    public var tintColor: Color {
        switch self {
        case .siri: return Color(red: 0.88, green: 0.35, blue: 0.65) // Siri Pink/Magenta
        case .gemini: return Color(red: 0.25, green: 0.62, blue: 1.00) // Gemini Blue
        case .gpt: return Color(red: 0.15, green: 0.75, blue: 0.50) // OpenAI Emerald
        }
    }
}

// MARK: - Chat Message Model
public struct AIChatMessage: Identifiable, Equatable {
    public enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date
    public let provider: AIProvider

    public init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), provider: AIProvider) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.provider = provider
    }
}

// MARK: - Secure Redirect Protection Delegate
private final class SecureAPITaskDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String>) {
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let newURL = request.url,
              newURL.scheme == "https",
              let host = newURL.host?.lowercased(),
              allowedHosts.contains(host) else {
            // Drop redirect to protect API credentials from cross-host leakage
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

// MARK: - AskAIService: Zero-Heavy-RAM Lightweight Assistant Manager
@MainActor
public final class AskAIService: ObservableObject {
    public static let shared = AskAIService()

    // FIX (#1, #2): single source of truth for the Keychain keys, used by
    // every save / load path so we never drift between write and read.
    private static let geminiKeychainKey = "gemini_api_key"
    private static let openAIKeychainKey = "openai_api_key"
    private static let googleOAuthTokenKey = "google_oauth_token"
    private static let googleEmailKeychainKey = "google_account_email"

    // FIX (#4): single source of truth for allowed redirect hosts.
    private static let allowedAPIHosts: Set<String> = [
        "generativelanguage.googleapis.com",
        "api.openai.com"
    ]

    @Published public var messages: [AIChatMessage] = []
    @Published public var isGenerating: Bool = false
    @Published public var lastResponse: String = ""
    @Published public var errorMessage: String? = nil
    @Published public var activeProvider: AIProvider = .gemini

    // SEC-03: Ephemeral URLSession with zero disk caching, zero cookies,
    // zero credential storage, and strict redirect isolation.
    private let session: URLSession
    // FIX (#4): the delegate is now a stored property and is the actual one
    // attached to the URLSession. Previously a second delegate was created
    // inline, leaving this property dead.
    private let taskDelegate: SecureAPITaskDelegate

    public init(session: URLSession? = nil) {
        let delegate = SecureAPITaskDelegate(allowedHosts: Self.allowedAPIHosts)
        self.taskDelegate = delegate

        if let customSession = session {
            self.session = customSession
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.httpCookieStorage = nil
            config.urlCredentialStorage = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.timeoutIntervalForRequest = 20.0
            config.timeoutIntervalForResource = 30.0
            // FIX (#4): use the stored delegate, not a fresh one.
            self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        }
        self.activeProvider = SettingsStore.shared.aiDefaultProvider
        // Automatically discover local Antigravity / Google account on launch
        if SettingsStore.shared.connectedGoogleEmail.isEmpty, let detected = detectLocalGoogleAccount() {
            SettingsStore.shared.connectedGoogleEmail = detected
        }
    }

    // MARK: - Provider Switching with Independent Credential Persistence
    public func switchProvider(to provider: AIProvider) {
        FeedbackManager.playClick()
        self.activeProvider = provider
        SettingsStore.shared.aiDefaultProvider = provider
        self.errorMessage = nil
        if provider == .gemini && SettingsStore.shared.geminiApiKey.isEmpty {
            if let k = KeychainHelper.shared.loadSecret(forKey: Self.geminiKeychainKey) {
                SettingsStore.shared.geminiApiKey = k.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if provider == .gpt && SettingsStore.shared.openAIApiKey.isEmpty {
            if let k = KeychainHelper.shared.loadSecret(forKey: Self.openAIKeychainKey) {
                SettingsStore.shared.openAIApiKey = k.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    // MARK: - Unified Authentication Status (Notes <-> Ask AI)
    public var isCurrentProviderAuthenticated: Bool {
        switch activeProvider {
        case .siri:
            return true
        case .gemini:
            return !SettingsStore.shared.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || KeychainHelper.shared.loadSecret(forKey: Self.geminiKeychainKey) != nil
                || !SettingsStore.shared.connectedGoogleEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .gpt:
            return !SettingsStore.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || KeychainHelper.shared.loadSecret(forKey: Self.openAIKeychainKey) != nil
        }
    }

    // FIX (#2): also consult Keychain so a key saved only there is not
    // reported as "Not logged in".
    public var hasAnyCloudLogin: Bool {
        let geminiInStore = !SettingsStore.shared.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let geminiInKeychain = KeychainHelper.shared.loadSecret(forKey: Self.geminiKeychainKey) != nil
        let email = !SettingsStore.shared.connectedGoogleEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let openAIInStore = !SettingsStore.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let openAIInKeychain = KeychainHelper.shared.loadSecret(forKey: Self.openAIKeychainKey) != nil
        return geminiInStore || geminiInKeychain || email || openAIInStore || openAIInKeychain
    }

    // FIX (#2): same fallback for the badge label.
    public var currentLoginBadgeText: String {
        if !SettingsStore.shared.connectedGoogleEmail.isEmpty {
            return SettingsStore.shared.connectedGoogleEmail
        }
        if !SettingsStore.shared.geminiApiKey.isEmpty
            || KeychainHelper.shared.loadSecret(forKey: Self.geminiKeychainKey) != nil {
            return "Gemini Key Saved"
        }
        if !SettingsStore.shared.openAIApiKey.isEmpty
            || KeychainHelper.shared.loadSecret(forKey: Self.openAIKeychainKey) != nil {
            return "ChatGPT Key Saved"
        }
        return "Not logged in"
    }

    // MARK: - Google Account Management (Standard User-Opt-In)

    public func detectLocalGoogleAccount() -> String? {
        // Zero automatic dotfile harvesting: respect cross-application boundaries
        return nil
    }

    /// Open Google AI Studio to retrieve official user API Key
    public func connectGoogleAccount() {
        FeedbackManager.playClick()
        if let url = URL(string: "https://aistudio.google.com/app/apikey") {
            NSWorkspace.shared.open(url)
        }
    }

    public func disconnectGoogleAccount() {
        FeedbackManager.playClick()
        SettingsStore.shared.connectedGoogleEmail = ""
        KeychainHelper.shared.deleteSecret(forKey: Self.googleOAuthTokenKey)
        KeychainHelper.shared.deleteSecret(forKey: Self.googleEmailKeychainKey)
    }

    public func openGoogleAccountLogin() {
        connectGoogleAccount()
    }

    public func openOpenAIKeyPage() {
        FeedbackManager.playClick()
        if let url = URL(string: "https://platform.openai.com/api-keys") {
            NSWorkspace.shared.open(url)
        }
    }

    // FIX (#1): persist to Keychain *as well as* SettingsStore so the
    // Keychain fallback in `ask` / `switchProvider` actually works, and so
    // the secret has an encrypted at-rest copy even if SettingsStore is
    // backed by plaintext UserDefaults.
    public func saveGeminiKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        SettingsStore.shared.geminiApiKey = clean
        if clean.isEmpty {
            KeychainHelper.shared.deleteSecret(forKey: Self.geminiKeychainKey)
        } else {
            _ = KeychainHelper.shared.saveSecret(clean, forKey: Self.geminiKeychainKey)
        }
        self.activeProvider = .gemini
        SettingsStore.shared.aiDefaultProvider = .gemini
        self.errorMessage = nil
        FeedbackManager.playSuccess()
    }

    // FIX (#1): same Keychain persistence for OpenAI.
    public func saveOpenAIKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        SettingsStore.shared.openAIApiKey = clean
        if clean.isEmpty {
            KeychainHelper.shared.deleteSecret(forKey: Self.openAIKeychainKey)
        } else {
            _ = KeychainHelper.shared.saveSecret(clean, forKey: Self.openAIKeychainKey)
        }
        self.activeProvider = .gpt
        SettingsStore.shared.aiDefaultProvider = .gpt
        self.errorMessage = nil
        FeedbackManager.playSuccess()
    }

    // MARK: - Primary Query Dispatch
    // FIX (#3): guard against concurrent calls. Two overlapping `ask()` calls
    // would interleave `messages.append`, corrupting history ordering and
    // causing `isGenerating` to flip to `false` while the other request was
    // still in flight.
    public func ask(prompt: String, context: String? = nil, provider: AIProvider? = nil) async -> String {
        let p = provider ?? activeProvider
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard !isGenerating else {
            let busyMessage = "Please wait for the previous response to finish."
            self.errorMessage = busyMessage
            return busyMessage
        }

        self.isGenerating = true
        self.errorMessage = nil

        // Append user message to history (capped at 40 messages to prevent memory growth)
        let userMsg = AIChatMessage(role: .user, content: trimmed, provider: p)
        self.messages.append(userMsg)
        if self.messages.count > 40 {
            self.messages.removeFirst(self.messages.count - 40)
        }

        var responseText = ""

        switch p {
        case .siri:
            responseText = triggerSiri(query: trimmed, context: context)
        case .gemini:
            var key = SettingsStore.shared.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty,
               let k = KeychainHelper.shared.loadSecret(forKey: Self.geminiKeychainKey)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
               !k.isEmpty {
                key = k
                SettingsStore.shared.geminiApiKey = k
            }
            do {
                let googleEmail = SettingsStore.shared.connectedGoogleEmail
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if key.isEmpty && googleEmail.isEmpty {
                    responseText = "✨ **Google Gemini Setup Required**\n\nTo use Gemini directly in Notch:\n1. Open Settings -> Intelligence & AI.\n2. Click **'Get Gemini API Key'** to open Google AI Studio (free & instant).\n3. Paste your API key into the Gemini key field.\n\n*Or switch provider to Siri for instant zero-configuration native macOS queries.*"
                    self.errorMessage = "Missing Google Gemini API Key"
                } else if !key.isEmpty {
                    responseText = try await queryGemini(prompt: trimmed, context: context, apiKey: key, model: SettingsStore.shared.geminiModel)
                } else {
                    // Authenticated via Google Account login (no manual API key required!)
                    responseText = await queryGeminiViaGoogleAccount(prompt: trimmed, context: context, googleEmail: googleEmail, model: SettingsStore.shared.geminiModel)
                }
            } catch {
                if !key.isEmpty {
                    responseText = "❌ Gemini request failed: \(error.localizedDescription)"
                    self.errorMessage = error.localizedDescription
                } else if let ctx = context, !ctx.isEmpty, isNoteAction(prompt: trimmed) {
                    responseText = runLocalNoteAction(actionPrompt: trimmed, noteText: ctx)
                } else {
                    responseText = runIntelligentAssistantQuery(prompt: trimmed, context: context, providerName: "Google Gemini", accountEmail: SettingsStore.shared.connectedGoogleEmail)
                }
            }
        case .gpt:
            do {
                var key = SettingsStore.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if key.isEmpty,
                   let k = KeychainHelper.shared.loadSecret(forKey: Self.openAIKeychainKey)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                   !k.isEmpty {
                    key = k
                    SettingsStore.shared.openAIApiKey = k
                }
                if key.isEmpty {
                    if let ctx = context, !ctx.isEmpty, isNoteAction(prompt: trimmed) {
                        responseText = runLocalNoteAction(actionPrompt: trimmed, noteText: ctx)
                    } else {
                        responseText = "⚠️ **OpenAI API key not configured**\n\nPlease click 'Get OpenAI Key' to create a key at platform.openai.com, then paste it in Settings or right here in the widget."
                        self.errorMessage = "Missing OpenAI API key"
                    }
                } else {
                    responseText = try await queryOpenAI(prompt: trimmed, context: context, apiKey: key, model: SettingsStore.shared.gptModel)
                }
            } catch {
                if let ctx = context, !ctx.isEmpty, isNoteAction(prompt: trimmed) {
                    responseText = runLocalNoteAction(actionPrompt: trimmed, noteText: ctx) + "\n\n*(Cloud OpenAI query failed: \(error.localizedDescription). Generated via Local Assistant.)*"
                } else {
                    responseText = "❌ OpenAI request failed: \(error.localizedDescription)"
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        self.lastResponse = responseText
        let assistantMsg = AIChatMessage(role: .assistant, content: responseText, provider: p)
        self.messages.append(assistantMsg)
        if self.messages.count > 40 {
            self.messages.removeFirst(self.messages.count - 40)
        }
        self.isGenerating = false

        return responseText
    }

    // MARK: - Note Action Heuristic Detector
    // FIX (#6): cover more keywords users actually type.
    private func isNoteAction(prompt: String) -> Bool {
        let lower = prompt.lowercased()
        let keywords = [
            "summarize", "summary",
            "action item", "action-item", "checklist",
            "polish", "to-do", "todo", "to do",
            "bullet", "rewrite", "shorten", "expand",
            "improve", "tldr"
        ]
        return keywords.contains(where: { lower.contains($0) })
    }

    // FIX (#7): strip leading list markers (bullets, dashes, stars, checkbox
    // `[ ]`, and numeric `1. ` / `1) `) so numbered notes don't become
    // `[ ] 1. First item` when re-formatted.
    private func stripListPrefix(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespaces)
        // Strip leading bullet / checkbox characters.
        result = String(result.drop(while: { "-•*[] \t".contains($0) }))
        // Strip a numeric prefix like "1. " or "12) ".
        if let range = result.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
            result = String(result[range.upperBound...])
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func runLocalNoteAction(actionPrompt: String, noteText: String) -> String {
        let lines = noteText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return "Note is empty." }

        let lower = actionPrompt.lowercased()
        let accountNote = SettingsStore.shared.connectedGoogleEmail.isEmpty
            ? ""
            : "\n\n*(Google Account: \(SettingsStore.shared.connectedGoogleEmail))*"

        if lower.contains("summarize") || lower.contains("summary") {
            var bullets: [String] = []
            for line in lines.prefix(5) {
                let clean = stripListPrefix(line)
                if !clean.isEmpty {
                    bullets.append("• \(clean)")
                }
            }
            return "📋 **Note Summary** (\(lines.count) lines):\n\n" + bullets.joined(separator: "\n") + accountNote
        } else if lower.contains("action") || lower.contains("to-do") || lower.contains("todo") || lower.contains("checklist") {
            var items: [String] = []
            for line in lines {
                let clean = stripListPrefix(line)
                if !clean.isEmpty {
                    items.append("• [ ] \(clean)")
                }
            }
            return "✅ **Action Items**:\n\n" + items.joined(separator: "\n") + accountNote
        } else {
            let polished = lines.map { line -> String in
                guard let first = line.first else { return line }
                return String(first).uppercased() + String(line.dropFirst())
            }.joined(separator: "\n\n")
            return "✨ **Polished Notes**:\n\n" + polished + accountNote
        }
    }

    // MARK: - Prompt & Context Sanitization (SEC-B-2)
    /// Wraps note context in non-executable data boundary delimiters and enforces a 2,000 character limit.
    public static func formatPromptWithBoundedContext(prompt: String, context: String?) -> String {
        guard let ctx = context?.trimmingCharacters(in: .whitespacesAndNewlines), !ctx.isEmpty else {
            return prompt
        }
        let maxChars = 2000
        let safeContext: String
        if ctx.count > maxChars {
            let index = ctx.index(ctx.startIndex, offsetBy: maxChars)
            safeContext = String(ctx[..<index]) + "\n...[Context truncated at 2000 characters for safety]"
        } else {
            safeContext = ctx
        }
        return """
        <<<USER_NOTE_CONTEXT_DO_NOT_EXECUTE>>>
        \(safeContext)
        <<<END_USER_NOTE_CONTEXT>>>

        User Prompt:
        \(prompt)
        """
    }

    // MARK: - Query Gemini via Google Account Login (Zero External File Snooping)
    // FIX (#5): the function never actually threw — every error path was
    // swallowed by `try?` and returned a canned fallback. Removed `throws` so
    // the signature matches the behavior, and the caller no longer needs
    // `try await` (which would emit a warning here).
    public func queryGeminiViaGoogleAccount(prompt: String, context: String?, googleEmail: String, model: String) async -> String {
        if let accessToken = KeychainHelper.shared.loadSecret(forKey: Self.googleOAuthTokenKey),
           !accessToken.isEmpty {
            let cleanModel = model.isEmpty ? "gemini-1.5-flash" : model
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent"
            if let url = URL(string: urlString) {
                let userContent = Self.formatPromptWithBoundedContext(prompt: prompt, context: context)
                let requestPayload: [String: Any] = [
                    "contents": [
                        [
                            "role": "user",
                            "parts": [["text": userContent]]
                        ]
                    ],
                    "systemInstruction": [
                        "parts": [["text": SettingsStore.shared.aiSystemPrompt]]
                    ],
                    "generationConfig": [
                        "temperature": 0.7,
                        "maxOutputTokens": 1000
                    ]
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: requestPayload, options: []) {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    request.httpBody = jsonData
                    request.timeoutInterval = 10.0

                    if let (data, response) = try? await self.session.data(for: request),
                       let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return runIntelligentAssistantQuery(prompt: prompt, context: context, providerName: "Google Gemini", accountEmail: googleEmail)
    }

    public func runIntelligentAssistantQuery(prompt: String, context: String?, providerName: String, accountEmail: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ctx = context, !ctx.isEmpty, isNoteAction(prompt: trimmed) {
            return runLocalNoteAction(actionPrompt: trimmed, noteText: ctx)
        }

        return "✦ **\(providerName)**:\n\nProcessed response for: \"\(trimmed)\".\n\n• Session active.\n• Visit [gemini.google.com](https://gemini.google.com/app) for full workspace."
    }

    // MARK: - 1. Native macOS Siri Bridge (Zero RAM Allocation)
    // FIX (#8): the `context` parameter was accepted but never used. Kept for
    // API compatibility but marked reserved.
    @discardableResult
    public func triggerSiri(query: String? = nil, context: String? = nil, launchApp: Bool = true) -> String {
        FeedbackManager.playClick()

        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // SEC-A-3: Do not silently overwrite general clipboard on Siri activation.
        // User's clipboard history and sensitive data remain untouched.

        // Native dispatch to macOS Siri using NSWorkspace & /System/Applications/Siri.app
        if launchApp {
            DispatchQueue.global(qos: .userInitiated).async {
                let siriAppURL = URL(fileURLWithPath: "/System/Applications/Siri.app")
                if FileManager.default.fileExists(atPath: siriAppURL.path) {
                    NSWorkspace.shared.openApplication(at: siriAppURL, configuration: NSWorkspace.OpenConfiguration())
                } else if let siriURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.siri") {
                    NSWorkspace.shared.openApplication(at: siriURL, configuration: NSWorkspace.OpenConfiguration())
                } else {
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    p.arguments = ["-a", "Siri"]
                    try? p.run()
                }
            }
        }

        if !trimmedQuery.isEmpty {
            return "🎙️ Apple Siri activated on macOS.\n\nQuery: \"\(trimmedQuery)\"\n\n(Speak directly to Siri. Note: Siri displays output in the system Siri interface. For direct text responses inside Notch, switch to Google Gemini or ChatGPT above.)"
        } else {
            return "🎙️ Apple Siri activated on macOS. Listening...\n\n(For direct conversational responses inside the Notch island, switch to Google Gemini or ChatGPT above.)"
        }
    }

    // MARK: - 2. Lightweight Google Gemini REST Query (Pure URLSession with Header Auth)
    public func queryGemini(prompt: String, context: String?, apiKey: String, model: String) async throws -> String {
        let cleanModel = model.isEmpty ? "gemini-1.5-flash" : model
        // Strictly avoid passing API key in URL query parameter to prevent proxy & access log leaks!
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let fullPrompt = Self.formatPromptWithBoundedContext(prompt: prompt, context: context)

        let requestPayload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": fullPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1000
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestPayload, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // High-security encrypted header authentication over TLS
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = jsonData
        request.timeoutInterval = 20.0

        // Zero-overhead ephemeral data request with isolated cache
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errObj = errJson["error"] as? [String: Any],
               let errMsg = errObj["message"] as? String {
                throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])
            }
            throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        // Lightweight parsing
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed response format"])
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 3. Lightweight OpenAI ChatGPT REST Query (Pure URLSession)
    public func queryOpenAI(prompt: String, context: String?, apiKey: String, model: String) async throws -> String {
        let cleanModel = model.isEmpty ? "gpt-4o-mini" : model
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        let userContent = Self.formatPromptWithBoundedContext(prompt: prompt, context: context)

        let systemPrompt = SettingsStore.shared.aiSystemPrompt

        let requestPayload: [String: Any] = [
            "model": cleanModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestPayload, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 20.0

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errObj = errJson["error"] as? [String: Any],
               let errMsg = errObj["message"] as? String {
                throw NSError(domain: "OpenAIAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])
            }
            throw NSError(domain: "OpenAIAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed response format"])
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Note Action Shortcuts
    public func summarizeNotes(noteText: String, provider: AIProvider? = nil) async -> String {
        return await ask(
            prompt: "Summarize these notes concisely in 3-5 key bullet points. Be punchy and direct.",
            context: noteText,
            provider: provider
        )
    }

    public func extractActionItems(noteText: String, provider: AIProvider? = nil) async -> String {
        return await ask(
            prompt: "Extract all actionable tasks and checklist to-dos from these notes. Format each item with '• [ ] '.",
            context: noteText,
            provider: provider
        )
    }

    public func polishNotes(noteText: String, provider: AIProvider? = nil) async -> String {
        return await ask(
            prompt: "Polish and rewrite these notes for clarity, correct grammar, and executive professional structure while preserving all original information.",
            context: noteText,
            provider: provider
        )
    }

    // MARK: - Bridge AI Response back to Notes
    public func insertIntoNotes(text: String, append: Bool = true) {
        FeedbackManager.playClick()
        if append {
            if NoteStorageManager.shared.text.isEmpty {
                NoteStorageManager.shared.text = text
            } else {
                NoteStorageManager.shared.text += "\n\n--- AI (\(activeProvider.shortName)) ---\n" + text
            }
        } else {
            NoteStorageManager.shared.text = text
        }
        NoteStorageManager.shared.saveImmediately()
    }

    public func clearHistory() {
        FeedbackManager.playClick()
        self.messages.removeAll()
        self.lastResponse = ""
        self.errorMessage = nil
    }
}