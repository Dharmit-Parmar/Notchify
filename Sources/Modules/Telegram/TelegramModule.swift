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
    public static func dispatch(platform: String, handle: String, text: String, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { completion(false); return }
        
        FeedbackManager.playSend()
        
        // Open without activating or bringing window forward
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.hides = true
        
        if platform == "WhatsApp" {
            let digits = handle.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let encoded = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = digits.isEmpty ? "whatsapp://send?text=\(encoded)" : "whatsapp://send?phone=\(digits)&text=\(encoded)"
            
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url, configuration: config) { _, _ in
                    // Silent background dispatch: send Return key and keep WhatsApp hidden
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.4) {
                        let script = """
                        tell application "System Events"
                            if exists (process "WhatsApp") then
                                tell process "WhatsApp"
                                    key code 36
                                end tell
                                set visible of process "WhatsApp" to false
                            end if
                        end tell
                        """
                        var error: NSDictionary?
                        if let appleScript = NSAppleScript(source: script) {
                            appleScript.executeAndReturnError(&error)
                        }
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                }
            } else {
                completion(false)
            }
        } else {
            // Telegram (Supports both Phone Numbers and @Usernames)
            let rawHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
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
                NSWorkspace.shared.open(url, configuration: config) { _, _ in
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.4) {
                        let script = """
                        tell application "System Events"
                            if exists (process "Telegram") then
                                tell process "Telegram"
                                    key code 36
                                end tell
                                set visible of process "Telegram" to false
                            end if
                        end tell
                        """
                        var error: NSDictionary?
                        if let appleScript = NSAppleScript(source: script) {
                            appleScript.executeAndReturnError(&error)
                        }
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                }
            } else {
                completion(false)
            }
        }
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
    
    public func sendMessage() {
        let textToSend = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        DirectMessenger.dispatch(platform: contact.platform, handle: contact.handle, text: textToSend) { [weak self] _ in
            self?.isDispatching = false
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
            
            // Accessibility Guidance Banner (if not yet granted)
            if !module.isAccessibilityGranted {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text("1-Click Send needs Accessibility permission")
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
                        TextField("Name", text: $module.newPersonName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(5)
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
                        
                        TextField(placeholderText, text: $module.newPersonHandle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(5)
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
                                                    Text("✓")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(DesignSystem.accentColor)
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
                        .frame(height: 80)
                        .onChange(of: contact.messages.count) { _, _ in
                            if let lastId = contact.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
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
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(.spring)
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
    
    public func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .white
        field.font = .systemFont(ofSize: 11, weight: .regular)
        field.delegate = context.coordinator
        return field
    }
    
    public func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
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
                parent.onCommit()
                return true
            }
            return false
        }
    }
}
