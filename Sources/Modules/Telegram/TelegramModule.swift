import SwiftUI
import AppKit
import ApplicationServices

public struct ChatContact: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var platform: String  // "Telegram" or "WhatsApp"
    public var handle: String    // @username or phone number
    public var messages: [ChatMessage]
    
    public init(id: UUID = UUID(), name: String, platform: String, handle: String, messages: [ChatMessage] = []) {
        self.id = id
        self.name = name
        self.platform = platform
        self.handle = handle
        self.messages = messages
    }
}

public struct ChatMessage: Identifiable, Codable, Hashable {
    public let id: UUID
    public let sender: String
    public let text: String
    public let isMe: Bool
    public let time: String
    
    public init(id: UUID = UUID(), sender: String, text: String, isMe: Bool, time: String) {
        self.id = id
        self.sender = sender
        self.text = text
        self.isMe = isMe
        self.time = time
    }
}

public struct DirectMessenger {
    public static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }
    
    public static func requestAccessibilityPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true as CFBoolean] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @MainActor
    public static func dispatch(
        platform: String,
        handle: String,
        text: String,
        botToken: String? = nil,
        completion: @escaping @MainActor @Sendable (Bool, String?) -> Void = { _, _ in }
    ) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { completion(false, "Empty message"); return }
        
        // 1. Direct Telegram Bot API Dispatch (100% Background, Silent, Zero Windows)
        if platform == "Telegram", let token = botToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            dispatchViaTelegramBot(token: token, handle: handle, text: cleanText, completion: completion)
            return
        }
        
        FeedbackManager.playSend()
        
        // Open without activating or bringing window forward
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        
        if platform == "WhatsApp" {
            let digits = handle.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let encoded = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = digits.isEmpty ? "whatsapp://send?text=\(encoded)" : "whatsapp://send?phone=\(digits)&text=\(encoded)"
            
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url, configuration: config) { _, error in
                    if let error = error {
                        DispatchQueue.main.async { completion(false, error.localizedDescription) }
                        return
                    }
                    if AXIsProcessTrusted() {
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.45) {
                            let script = """
                            tell application "System Events"
                                if exists (process "WhatsApp") then
                                    tell process "WhatsApp"
                                        key code 36
                                    end tell
                                end if
                            end tell
                            """
                            var scError: NSDictionary?
                            if let appleScript = NSAppleScript(source: script) {
                                appleScript.executeAndReturnError(&scError)
                            }
                            DispatchQueue.main.async {
                                completion(true, "Sent via WhatsApp")
                            }
                        }
                    } else {
                        DispatchQueue.main.async { completion(true, "Opened in WhatsApp") }
                    }
                }
            } else {
                completion(false, "Invalid WhatsApp URL")
            }
        } else {
            // Telegram URL Dispatch (When Bot API token is not yet configured)
            var rawHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            if rawHandle.hasPrefix("https://t.me/") {
                rawHandle = String(rawHandle.dropFirst(13))
            } else if rawHandle.hasPrefix("t.me/") {
                rawHandle = String(rawHandle.dropFirst(5))
            }
            
            let digits = rawHandle.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let cleanUser = rawHandle.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
            let encoded = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            let isPhone = rawHandle.hasPrefix("+") || (digits.count >= 7 && !rawHandle.contains("@") && cleanUser.allSatisfy { $0.isNumber || $0 == "+" || $0 == " " || $0 == "-" || $0 == "(" || $0 == ")" })
            
            let urlString: String
            if cleanUser.isEmpty && digits.isEmpty {
                urlString = "tg://msg?text=\(encoded)"
            } else if isPhone && !digits.isEmpty {
                urlString = "tg://resolve?phone=\(digits)&text=\(encoded)"
            } else {
                urlString = "tg://resolve?domain=\(cleanUser)&text=\(encoded)"
            }
            
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url, configuration: config) { _, error in
                    if let error = error {
                        DispatchQueue.main.async { completion(false, error.localizedDescription) }
                        return
                    }
                    // Do NOT forcibly close/hide Telegram with "set visible of process to false"
                    if AXIsProcessTrusted() {
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.45) {
                            let script = """
                            tell application "System Events"
                                if exists (process "Telegram") then
                                    tell process "Telegram"
                                        key code 36
                                    end tell
                                end if
                            end tell
                            """
                            var scError: NSDictionary?
                            if let appleScript = NSAppleScript(source: script) {
                                appleScript.executeAndReturnError(&scError)
                            }
                            DispatchQueue.main.async {
                                completion(true, "Sent to Telegram")
                            }
                        }
                    } else {
                        DispatchQueue.main.async { completion(true, "Opened in Telegram") }
                    }
                }
            } else {
                completion(false, "Invalid Telegram URL")
            }
        }
    }
    
    // Asynchronous Telegram Bot API HTTP POST Dispatch (100% Background, Silent, Zero Windows)
    @MainActor
    private static func dispatchViaTelegramBot(
        token: String,
        handle: String,
        text: String,
        completion: @escaping @MainActor @Sendable (Bool, String?) -> Void
    ) {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else {
            completion(false, "Invalid Telegram Bot API endpoint URL")
            return
        }
        
        var targetChatId = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if targetChatId.hasPrefix("https://t.me/") {
            targetChatId = String(targetChatId.dropFirst(13))
        } else if targetChatId.hasPrefix("t.me/") {
            targetChatId = String(targetChatId.dropFirst(5))
        }
        if !targetChatId.hasPrefix("@") && !targetChatId.allSatisfy({ $0.isNumber || $0 == "-" }) {
            targetChatId = "@" + targetChatId
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        
        let payload: [String: Any] = [
            "chat_id": targetChatId,
            "text": text
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(false, "Failed to serialize message payload")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            if let err = err {
                Task { @MainActor in
                    completion(false, err.localizedDescription)
                }
                return
            }
            
            guard let data = data else {
                Task { @MainActor in
                    completion(false, "Empty response from Telegram server")
                }
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool, ok {
                Task { @MainActor in
                    FeedbackManager.playSend()
                    completion(true, "Delivered via Telegram Bot ✓✓")
                }
            } else {
                let desc = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["description"] as? String ?? "Telegram API Error"
                Task { @MainActor in
                    completion(false, desc)
                }
            }
        }.resume()
    }
}

@MainActor
public final class TelegramModule: NotchModule {
    public let id = "telegram"
    public let title = "Messages"
    public let iconName = "message.fill"
    @Published public var isEnabled: Bool = true
    
    @Published public var contacts: [ChatContact] = []
    @Published public var selectedContactId: UUID?
    @Published public var draftText: String = ""
    
    @Published public var isAddingContact: Bool = false
    @Published public var newPersonName: String = ""
    @Published public var newPersonPlatform: String = "Telegram"
    @Published public var newPersonHandle: String = ""
    @Published public var newPersonHandleType: String = "Number"
    
    @Published public var isDispatching: Bool = false
    @Published public var isAccessibilityGranted: Bool = DirectMessenger.isAccessibilityGranted
    @Published public var lastDispatchStatus: String? = nil
    @Published public var isConfiguringBot: Bool = false
    @Published public var testBotStatus: String? = nil
    @Published public var isTestingBot: Bool = false
    
    @Published public var botToken: String = UserDefaults.standard.string(forKey: "NotchApp_TelegramBotToken") ?? "" {
        didSet {
            UserDefaults.standard.set(botToken.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "NotchApp_TelegramBotToken")
        }
    }
    
    private let contactsStorageKey = "NotchApp_SavedContacts"
    
    public init() {
        loadSavedContacts()
        self.isAccessibilityGranted = DirectMessenger.isAccessibilityGranted
    }
    
    public func start() {
        refreshAccessibility()
    }
    public func stop() {}
    
    public func refreshAccessibility() {
        self.isAccessibilityGranted = DirectMessenger.isAccessibilityGranted
    }
    
    public func testBotConnection() {
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            testBotStatus = "Enter token first"
            return
        }
        isTestingBot = true
        testBotStatus = "Verifying..."
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/getMe") else {
            isTestingBot = false
            testBotStatus = "Invalid URL"
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isTestingBot = false
                if let err = err {
                    self.testBotStatus = "Error: \(err.localizedDescription)"
                    return
                }
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ok = json["ok"] as? Bool, ok,
                   let result = json["result"] as? [String: Any],
                   let username = result["username"] as? String {
                    self.testBotStatus = "Connected to @\(username) ✓"
                    FeedbackManager.playSuccess()
                } else {
                    self.testBotStatus = "Invalid Token"
                }
            }
        }.resume()
    }
    
    private func loadSavedContacts() {
        if let data = UserDefaults.standard.data(forKey: contactsStorageKey),
           let saved = try? JSONDecoder().decode([ChatContact].self, from: data),
           !saved.isEmpty {
            self.contacts = saved
            self.selectedContactId = saved.first?.id
        } else {
            let welcome = ChatContact(
                name: "Add Contact (+)",
                platform: "Telegram",
                handle: "@username",
                messages: [
                    ChatMessage(
                        sender: "Notch",
                        text: "Tap the (+) button above to pin any Telegram or WhatsApp person to your Notch.",
                        isMe: false,
                        time: "Now"
                    )
                ]
            )
            self.contacts = [welcome]
            self.selectedContactId = welcome.id
        }
    }
    
    private func persistContacts() {
        if let encoded = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(encoded, forKey: contactsStorageKey)
        }
    }
    
    public var selectedContact: ChatContact? {
        if let id = selectedContactId {
            return contacts.first(where: { $0.id == id })
        }
        return contacts.first
    }
    
    public func selectContact(_ contact: ChatContact) {
        selectedContactId = contact.id
        isAddingContact = false
        isConfiguringBot = false
        FeedbackManager.playClick()
    }
    
    public func addContact(name: String, platform: String, handle: String) {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }
        
        if contacts.count == 1 && contacts[0].name.contains("Add Contact") {
            contacts.removeAll()
        }
        
        let newContact = ChatContact(
            name: cleanName,
            platform: platform,
            handle: handle.trimmingCharacters(in: .whitespaces),
            messages: [
                ChatMessage(
                    sender: cleanName,
                    text: "Connected via Notch. Enter below to message \(cleanName) directly.",
                    isMe: false,
                    time: "Now"
                )
            ]
        )
        contacts.append(newContact)
        selectedContactId = newContact.id
        newPersonName = ""
        newPersonHandle = ""
        isAddingContact = false
        persistContacts()
        FeedbackManager.playClick()
    }
    
    public func removeContact(id: UUID) {
        contacts.removeAll(where: { $0.id == id })
        if selectedContactId == id {
            selectedContactId = contacts.first?.id
        }
        persistContacts()
        FeedbackManager.playDelete()
    }
    
    private static let chatDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    public func sendMessage(overrideText: String? = nil) {
        let raw = overrideText ?? draftText
        let textToSend = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty,
              let contact = selectedContact,
              let idx = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        
        let timeString = Self.chatDateFormatter.string(from: Date())
        
        let msg = ChatMessage(
            sender: "Me",
            text: textToSend,
            isMe: true,
            time: timeString
        )
        
        contacts[idx].messages.append(msg)
        if contacts[idx].messages.count > 50 {
            contacts[idx].messages.removeFirst(contacts[idx].messages.count - 50)
        }
        draftText = ""
        persistContacts()
        isDispatching = true
        lastDispatchStatus = nil
        
        DirectMessenger.dispatch(
            platform: contact.platform,
            handle: contact.handle,
            text: textToSend,
            botToken: botToken.isEmpty ? nil : botToken
        ) { [weak self] success, statusDesc in
            guard let self = self else { return }
            self.isDispatching = false
            self.lastDispatchStatus = statusDesc
            if success {
                FeedbackManager.playSend()
            }
        }
    }
    
    public func makeCompactView() -> AnyView {
        let contact = selectedContact
        return AnyView(
            HStack(spacing: 5) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.accentColor)
                if let contact = contact {
                    Text(contact.name)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
        )
    }
    
    public func makeExpandedView() -> AnyView {
        AnyView(
            TelegramModuleExpandedView(module: self)
        )
    }
}

public struct TelegramModuleExpandedView: View {
    @ObservedObject var module: TelegramModule
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top Bar: Pinned Contacts List + Add (+) Button
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(module.contacts) { contact in
                            let isSelected = module.selectedContactId == contact.id
                            HStack(spacing: 5) {
                                Button(action: {
                                    module.selectContact(contact)
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: contact.platform == "WhatsApp" ? "phone.bubble.fill" : "paperplane.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(contact.platform == "WhatsApp" ? Color.green : Color.cyan)
                                        
                                        Text(contact.name)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(.spring)
                                
                                // Delete contact button
                                if module.contacts.count > 1 {
                                    Button(action: {
                                        module.removeContact(id: contact.id)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.35))
                                    }
                                    .buttonStyle(.spring)
                                    .help("Remove contact")
                                }
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? DesignSystem.structureColor : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? DesignSystem.accentColor : Color.clear, lineWidth: 1)
                            )
                            .contextMenu {
                                Button("Delete \(contact.name)") {
                                    module.removeContact(id: contact.id)
                                }
                            }
                        }
                    }
                }
                
                Button(action: {
                    FeedbackManager.playClick()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        module.isConfiguringBot.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundColor(module.botToken.isEmpty ? Color.white.opacity(0.4) : Color.cyan)
                        Text(module.botToken.isEmpty ? "Direct Bot" : "Bot Active")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(module.botToken.isEmpty ? DesignSystem.secondaryText : Color.cyan)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(module.botToken.isEmpty ? Color.white.opacity(0.06) : Color.cyan.opacity(0.16)))
                    .overlay(Capsule().strokeBorder(module.botToken.isEmpty ? Color.white.opacity(0.1) : Color.cyan.opacity(0.4), lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .help("Configure Telegram Bot for 100% silent background sending (zero windows)")
                
                Button(action: {
                    FeedbackManager.playClick()
                    module.isAddingContact.toggle()
                }) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.structureColor)
                            .frame(width: 22, height: 22)
                        Image(systemName: module.isAddingContact ? "xmark" : "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                }
                .buttonStyle(.spring)
                .help("Add Contact")
            }
            
            // Bot Configuration Card (Zero-Window Direct Mode)
            if module.isConfiguringBot {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "bolt.shield.fill")
                            .foregroundColor(.cyan)
                            .font(.system(size: 11))
                        Text("Telegram Direct Bot Setup (Zero-Window Silent Send)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button("Close") {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                module.isConfiguringBot = false
                            }
                        }
                        .buttonStyle(.spring)
                        .controlSize(.mini)
                    }
                    
                    Text("Enter your Telegram Bot Token from @BotFather. Messages beam silently in the background with zero app popups.")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.secondaryText)
                    
                    HStack(spacing: 6) {
                        PasteableTextField(text: $module.botToken, placeholder: "Bot Token (e.g. 123456789:AAFx...)")
                            .frame(height: 20)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(DesignSystem.structureColor))
                        
                        Button(action: {
                            module.testBotConnection()
                        }) {
                            HStack(spacing: 3) {
                                if module.isTestingBot {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text("Test")
                            }
                            .font(.system(size: 9.5, weight: .bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    if let status = module.testBotStatus {
                        Text(status)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(status.contains("✓") ? .green : .orange)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.structureColor.opacity(0.75)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.8))
            }
            
            // Accessibility Guidance Banner (if not yet granted and not using bot)
            if !module.isAccessibilityGranted && module.botToken.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text("App auto-send requires Accessibility, or use Direct Bot mode above")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Grant") {
                        DirectMessenger.requestAccessibilityPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            module.refreshAccessibility()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.20)))
            }
            
            if module.isAddingContact {
                // Add Contact Form Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Pin Person to Notch")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DesignSystem.accentColor)
                        Spacer()
                        if module.newPersonPlatform == "Telegram" {
                            Picker("", selection: $module.newPersonHandleType) {
                                Text("Phone #").tag("Number")
                                Text("@Username").tag("Username")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        PasteableTextField(text: $module.newPersonName, placeholder: "Name")
                            .frame(height: 20)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DesignSystem.structureColor))
                        
                        Picker("", selection: $module.newPersonPlatform) {
                            Text("Telegram").tag("Telegram")
                            Text("WhatsApp").tag("WhatsApp")
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        
                        let placeholderText: String = {
                            if module.newPersonPlatform == "WhatsApp" {
                                return "Phone (+1...)"
                            } else if module.newPersonHandleType == "Number" {
                                return "Phone (+1... or digits)"
                            } else {
                                return "@username"
                            }
                        }()
                        
                        HStack(spacing: 4) {
                            PasteableTextField(text: $module.newPersonHandle, placeholder: placeholderText)
                                .frame(height: 20)
                            
                            // 1-Click Clipboard Paste Shortcut
                            Button(action: {
                                if let clipboard = NSPasteboard.general.string(forType: .string) {
                                    let cleaned = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !cleaned.isEmpty {
                                        module.newPersonHandle = cleaned
                                        FeedbackManager.playClick()
                                    }
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.accentColor)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                            .help("Paste phone number or username from clipboard")
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DesignSystem.structureColor))
                        
                        Button("Pin") {
                            module.addContact(
                                name: module.newPersonName,
                                platform: module.newPersonPlatform,
                                handle: module.newPersonHandle
                            )
                        }
                        .buttonStyle(.spring)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(DesignSystem.accentColor))
                        .foregroundColor(.black)
                        .font(.system(size: 10, weight: .bold))
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignSystem.structureColor.opacity(0.7)))
            } else if let contact = module.selectedContact {
                // Active Chat Conversation View
                VStack(alignment: .leading, spacing: 4) {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 4) {
                                ForEach(contact.messages) { msg in
                                    HStack {
                                        if msg.isMe { Spacer() }
                                        
                                        VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 1) {
                                            Text(msg.text)
                                                .font(.system(size: 11))
                                                .foregroundColor(.white)
                                            
                                             HStack(spacing: 4) {
                                                Text(msg.time)
                                                    .font(.system(size: 8))
                                                    .foregroundColor(Color.white.opacity(0.45))
                                                if msg.isMe {
                                                    Text(module.botToken.isEmpty ? "✓" : "✓✓")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(Color.cyan)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(msg.isMe ? DesignSystem.accentColor.opacity(0.85) : DesignSystem.structureColor)
                                        )
                                        .foregroundColor(msg.isMe ? .black : .white)
                                        .id(msg.id)
                                        
                                        if !msg.isMe { Spacer() }
                                    }
                                }
                            }
                        }
                        .frame(height: 72)
                        .onChange(of: contact.messages.count) { _, _ in
                            if let lastId = contact.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    
                    // Dispatch Status / Feedback Pill
                    if let status = module.lastDispatchStatus {
                        HStack(spacing: 4) {
                            Image(systemName: status.contains("✓") ? "checkmark.circle.fill" : "info.circle.fill")
                                .font(.system(size: 8))
                            Text(status)
                                .font(.system(size: 9, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(status.contains("✓") ? Color.cyan : (status.contains("Failed") || status.contains("Error") ? Color.orange : Color.white.opacity(0.7)))
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                    }
                    
                    // Input Bar with DirectTextField (guarantees Enter key always sends)
                    HStack(spacing: 6) {
                        DirectTextField(
                            text: $module.draftText,
                            placeholder: "Message \(contact.name) (Press Enter to send)...",
                            onCommit: {
                                module.sendMessage()
                            }
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DesignSystem.structureColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DesignSystem.accentColor.opacity(0.3), lineWidth: 0.5)
                        )
                        
                        Button(action: {
                            module.sendMessage()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.accentColor)
                                    .frame(width: 26, height: 26)
                                if module.isDispatching {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .buttonStyle(.spring)
                        .disabled(module.isDispatching)
                        .help("Send Message (Enter)")
                    }
                }
            }
        }
        .onAppear {
            module.refreshAccessibility()
        }
    }
}

// Robust AppKit TextField with native Cmd+V (Paste), Cmd+C (Copy), Cmd+A (Select All), Cmd+X (Cut) and immediate Return/Enter handling
public final class CustomPasteableNSTextField: NSTextField {
    public var onCommit: (() -> Void)?
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle Return (36) and Keypad Enter (76) without modifiers
        if (event.keyCode == 36 || event.keyCode == 76) && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            if let editor = currentEditor() as? NSTextView {
                self.stringValue = editor.string
            }
            NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: self)
            self.onCommit?()
            return true
        }
        
        if event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "v" {
                if let string = NSPasteboard.general.string(forType: .string) {
                    if let editor = currentEditor() as? NSTextView {
                        editor.insertText(string, replacementRange: editor.selectedRange())
                    } else {
                        self.stringValue = string
                        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: self)
                    }
                    return true
                }
            } else if key == "c" {
                if let editor = currentEditor() as? NSTextView, editor.selectedRange().length > 0 {
                    editor.copy(nil)
                    return true
                }
            } else if key == "x" {
                if let editor = currentEditor() as? NSTextView, editor.selectedRange().length > 0 {
                    editor.cut(nil)
                    return true
                }
            } else if key == "a" {
                self.selectText(nil)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        let pasteItem = menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        pasteItem.isEnabled = NSPasteboard.general.string(forType: .string) != nil
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }
}

public struct PasteableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: (() -> Void)?
    
    public init(text: Binding<String>, placeholder: String, onCommit: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> CustomPasteableNSTextField {
        let field = CustomPasteableNSTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .white
        field.font = .systemFont(ofSize: 11, weight: .regular)
        field.delegate = context.coordinator
        field.onCommit = onCommit
        return field
    }
    
    public func updateNSView(_ nsView: CustomPasteableNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        nsView.onCommit = onCommit
    }
    
    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PasteableTextField
        
        init(_ parent: PasteableTextField) {
            self.parent = parent
        }
        
        public func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.text = textView.string
                parent.onCommit?()
                return true
            }
            return false
        }
    }
}

// Custom AppKit TextField ensuring Enter/Return key always commits
public struct DirectTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    
    public init(text: Binding<String>, placeholder: String, onCommit: @escaping () -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> CustomPasteableNSTextField {
        let field = CustomPasteableNSTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .white
        field.font = .systemFont(ofSize: 11, weight: .regular)
        field.delegate = context.coordinator
        field.onCommit = {
            if let editor = field.currentEditor() as? NSTextView {
                context.coordinator.parent.text = editor.string
            } else {
                context.coordinator.parent.text = field.stringValue
            }
            onCommit()
        }
        return field
    }
    
    public func updateNSView(_ nsView: CustomPasteableNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        nsView.onCommit = {
            if let editor = nsView.currentEditor() as? NSTextView {
                context.coordinator.parent.text = editor.string
            } else {
                context.coordinator.parent.text = nsView.stringValue
            }
            onCommit()
        }
    }
    
    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DirectTextField
        
        init(_ parent: DirectTextField) {
            self.parent = parent
        }
        
        public func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.text = textView.string
                parent.onCommit()
                return true
            }
            return false
        }
    }
}
