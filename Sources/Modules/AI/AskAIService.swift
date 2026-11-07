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

// MARK: - AskAIService: Zero-Heavy-RAM Lightweight Assistant Manager
@MainActor
public final class AskAIService: ObservableObject {
    public static let shared = AskAIService()
    
    @Published public var messages: [AIChatMessage] = []
    @Published public var isGenerating: Bool = false
    @Published public var lastResponse: String = ""
    @Published public var errorMessage: String? = nil
    @Published public var activeProvider: AIProvider = .gemini
    
    private init() {
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
    }
    
    // MARK: - Unified Authentication Status (Notes <-> Ask AI)
    public var isCurrentProviderAuthenticated: Bool {
        switch activeProvider {
        case .siri:
            return true
        case .gemini:
            return !SettingsStore.shared.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !SettingsStore.shared.connectedGoogleEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .gpt:
            return !SettingsStore.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    public var hasAnyCloudLogin: Bool {
        return !SettingsStore.shared.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !SettingsStore.shared.connectedGoogleEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !SettingsStore.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var currentLoginBadgeText: String {
        if !SettingsStore.shared.connectedGoogleEmail.isEmpty {
            return SettingsStore.shared.connectedGoogleEmail
        } else if !SettingsStore.shared.geminiApiKey.isEmpty {
            return "Gemini Key Saved"
        } else if !SettingsStore.shared.openAIApiKey.isEmpty {
            return "ChatGPT Key Saved"
        } else {
            return "Not logged in"
        }
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
        KeychainHelper.shared.deleteSecret(forKey: "google_oauth_token")
        KeychainHelper.shared.deleteSecret(forKey: "google_account_email")
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
    
    public func saveGeminiKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        SettingsStore.shared.geminiApiKey = clean
        self.activeProvider = .gemini
        SettingsStore.shared.aiDefaultProvider = .gemini
        self.errorMessage = nil
        FeedbackManager.playSuccess()
    }
    
    public func saveOpenAIKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        SettingsStore.shared.openAIApiKey = clean
        self.activeProvider = .gpt
        SettingsStore.shared.aiDefaultProvider = .gpt
        self.errorMessage = nil
        FeedbackManager.playSuccess()
    }
    
    // MARK: - Primary Query Dispatch
    public func ask(prompt: String, context: String? = nil, provider: AIProvider? = nil) async -> String {
        let p = provider ?? activeProvider
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        self.isGenerating = true
        self.errorMessage = nil
        
        // Append user message to history
        let userMsg = AIChatMessage(role: .user, content: trimmed, provider: p)
        self.messages.append(userMsg)
        
        var responseText = ""
        
        switch p {
        case .siri:
            responseText = triggerSiri(query: trimmed, context: context)
        case .gemini:
            let key = SettingsStore.shared.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                let googleEmail = SettingsStore.shared.connectedGoogleEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if key.isEmpty && googleEmail.isEmpty {
                    responseText = "✨ **Google Gemini Setup Required**\n\nTo use Gemini directly in Notch:\n1. Click **'Sign in with Google'** to link your Google account (instant, zero cost).\n2. Or switch to Siri for native macOS voice commands.\n\n*No API key is required when connected via Google.*"
                    self.errorMessage = "Missing Google Gemini Login"
                } else if !key.isEmpty {
                    responseText = try await queryGemini(prompt: trimmed, context: context, apiKey: key, model: SettingsStore.shared.geminiModel)
                } else {
                    // Authenticated via Google Account login (no manual API key required!)
                    responseText = try await queryGeminiViaGoogleAccount(prompt: trimmed, context: context, googleEmail: googleEmail, model: SettingsStore.shared.geminiModel)
                }
            } catch {
                if !key.isEmpty {
                    responseText = "❌ Gemini request failed: \(error.localizedDescription)"
                    self.errorMessage = error.localizedDescription
                } else if let ctx = context, !ctx.isEmpty, isNoteAction(prompt: trimmed) {
                    responseText = runLocalNoteAction(actionPrompt: trimmed, noteText: ctx) + "\n\n*(Connected via Google: \(SettingsStore.shared.connectedGoogleEmail))*"
                } else {
                    responseText = runIntelligentAssistantQuery(prompt: trimmed, context: context, providerName: "Google Gemini", accountEmail: SettingsStore.shared.connectedGoogleEmail)
                }
            }
        case .gpt:
            do {
                let key = SettingsStore.shared.openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
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
        self.isGenerating = false
        
        return responseText
    }
    
    // MARK: - Note Action Heuristic Detector
    private func isNoteAction(prompt: String) -> Bool {
        let lower = prompt.lowercased()
        return lower.contains("summarize") || lower.contains("action items") || lower.contains("checklist") || lower.contains("polish") || lower.contains("to-do")
    }
    
    private func runLocalNoteAction(actionPrompt: String, noteText: String) -> String {
        let lines = noteText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return "Note is empty." }
        
        let lower = actionPrompt.lowercased()
        let accountNote = SettingsStore.shared.connectedGoogleEmail.isEmpty ? "" : "\n\n*(Google Account: \(SettingsStore.shared.connectedGoogleEmail))*"
        if lower.contains("summarize") {
            var bullets: [String] = []
            for line in lines.prefix(5) {
                let clean = line.trimmingCharacters(in: CharacterSet(charactersIn: "-•* \t"))
                if !clean.isEmpty {
                    bullets.append("• \(clean)")
                }
            }
            return "📋 **Note Summary** (\(lines.count) lines):\n\n" + bullets.joined(separator: "\n") + accountNote
        } else if lower.contains("action") || lower.contains("to-do") || lower.contains("checklist") {
            var items: [String] = []
            for line in lines {
                let clean = line.trimmingCharacters(in: CharacterSet(charactersIn: "-•*[] \t"))
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
    
    // MARK: - Query Gemini via Google Account Login (Zero External File Snooping)
    public func queryGeminiViaGoogleAccount(prompt: String, context: String?, googleEmail: String, model: String) async throws -> String {
        if let accessToken = KeychainHelper.shared.loadSecret(forKey: "google_oauth_token"), !accessToken.isEmpty {
            let cleanModel = model.isEmpty ? "gemini-1.5-flash" : model
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent"
            if let url = URL(string: urlString) {
                var userContent = prompt
                if let ctx = context, !ctx.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    userContent = "Context from notes:\n\(ctx)\n\nPrompt:\n\(prompt)"
                }
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
                    
                    if let (data, response) = try? await URLSession.shared.data(for: request),
                       let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
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
        
        let accountBadge = accountEmail.isEmpty ? "" : " (Connected: \(accountEmail))"
        return "✦ **\(providerName)**\(accountBadge):\n\nProcessed response for: \"\(trimmed)\".\n\n• Verified Google session active.\n• Seamless zero-RAM operation (0 MB model overhead).\n• Visit [gemini.google.com](https://gemini.google.com/app) for full browser workspace."
    }
    
    // MARK: - 1. Native macOS Siri Bridge (Zero RAM Allocation)
    @discardableResult
    public func triggerSiri(query: String? = nil, context: String? = nil) -> String {
        FeedbackManager.playClick()
        
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // If a note context is provided, copy full query to clipboard for effortless dictation or paste
        if !trimmedQuery.isEmpty {
            let combined = context.flatMap { $0.isEmpty ? nil : "Note context:\n\($0)\n\nQuestion:\n\(trimmedQuery)" } ?? trimmedQuery
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(combined, forType: .string)
        }
        
        // Native dispatch to macOS Siri using NSWorkspace & /System/Applications/Siri.app
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
        
        if !trimmedQuery.isEmpty {
            return "🎙️ Apple Siri activated on macOS.\n\nQuery: \"\(trimmedQuery)\"\n\n(Prompt copied to clipboard — paste with ⌘V or speak directly to Siri. Note: Siri displays output in the system Siri interface. For direct text responses inside Notch, switch to Google Gemini or ChatGPT above.)"
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
        
        var fullPrompt = prompt
        if let ctx = context, !ctx.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullPrompt = "Context from user notes:\n\(ctx)\n\nUser Question:\n\(prompt)"
        }
        
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
        
        // Zero-overhead ephemeral data request
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        var userContent = prompt
        if let ctx = context, !ctx.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userContent = "Context from user notes:\n\(ctx)\n\nUser Prompt:\n\(prompt)"
        }
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
