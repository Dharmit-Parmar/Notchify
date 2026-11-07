import SwiftUI
import AppKit

@MainActor
final class NotesUIState: ObservableObject {
    @Published var isCopied: Bool = false
    @Published var showUndoClear: Bool = false
    @Published var isThockRunning: Bool = ThockModule.shared.isRunning
    @Published var showAIPanel: Bool = false
    @Published var aiQuery: String = ""
    @Published var aiResponse: String = ""
    @Published var isAIGenerating: Bool = false
    public var selectedProvider: AIProvider {
        get { AskAIService.shared.activeProvider }
        set { AskAIService.shared.switchProvider(to: newValue) }
    }
    @Published var isAIInserted: Bool = false
    @Published var apiKeyInput: String = ""
    var previousTextBeforeClear: String = ""
    var undoTimer: Timer? = nil
}

public struct NotesWidgetView: View {
    @ObservedObject private var noteStorage = NoteStorageManager.shared
    @ObservedObject private var aiService = AskAIService.shared
    @ObservedObject private var store = SettingsStore.shared
    @StateObject private var uiState = NotesUIState()
    
    public var span: Int // 1, 2, or 4 spaces
    
    public init(span: Int = 1) {
        self.span = span
    }
    
    private var wordCount: Int {
        noteStorage.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
    private var charCount: Int {
        noteStorage.text.count
    }
    
    public var body: some View {
        Group {
            if span == 1 {
                oneSpaceView
            } else if span == 2 {
                twoSpaceView
            } else {
                fourSpaceView
            }
        }
        .onReceive(ThockModule.shared.$isRunning) { running in
            self.uiState.isThockRunning = running
        }
        .onDisappear {
            uiState.undoTimer?.invalidate()
            uiState.undoTimer = nil
            // Immediate save when collapsing or navigating away
            noteStorage.saveImmediately()
            // Note: Mechanical key sounds persist while Notch is running so users can type anywhere in macOS
        }
    }
    
    // MARK: - 1-Space Mode (Compact Tile)
    private var oneSpaceView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Note icon + Text("Notes") + Spacer() + Text("\(wordCount)w")
            HStack(spacing: 5) {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.98, green: 0.72, blue: 0.20))
                
                Text("Notes")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
                
                Text("\(wordCount)w")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.secondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            
            // Body: CustomTextEditor filling available height or AI panel
            ZStack(alignment: .topLeading) {
                if uiState.showAIPanel && store.isNotesAIEnabled {
                    notesAIPanelView(compact: true)
                } else if uiState.showUndoClear {
                    HStack(spacing: 6) {
                        Text("Note cleared")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        Spacer()
                        
                        Button("Undo") {
                            undoClear()
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DesignSystem.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DesignSystem.accentColor.opacity(0.2)))
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    editorWithPlaceholder(placeholder: "Type note...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Bottom Action Bar: Sound button on left, Spacer(), AI button, Copy button and Clear button on right
            HStack(spacing: 8) {
                Button {
                    FeedbackManager.playClick()
                    if uiState.isThockRunning {
                        ThockModule.shared.stopEngine()
                    } else {
                        ThockModule.shared.startEngine()
                    }
                } label: {
                    Image(systemName: uiState.isThockRunning ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(uiState.isThockRunning ? Color(red: 0.98, green: 0.72, blue: 0.20) : DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .help(uiState.isThockRunning ? "Mechanical key sound active (persists while Notch is running)" : "Turn on typing sound")
                
                Spacer()
                
                // Ask AI Button & Provider Switcher (Gated by Notes AI Settings Toggle)
                if store.isNotesAIEnabled {
                    Menu {
                        ForEach(AIProvider.allCases) { provider in
                            Button {
                                AskAIService.shared.switchProvider(to: provider)
                                uiState.selectedProvider = provider
                            } label: {
                                if uiState.selectedProvider == provider {
                                    Label(provider.displayName, systemImage: "checkmark")
                                } else {
                                    Text(provider.displayName)
                                }
                            }
                        }
                        Divider()
                        Button(uiState.showAIPanel ? "Close AI Copilot" : "Open AI Copilot") {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                uiState.showAIPanel.toggle()
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9.5, weight: .semibold))
                            Text(uiState.selectedProvider.shortName)
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(uiState.showAIPanel ? uiState.selectedProvider.tintColor : DesignSystem.secondaryText)
                    } primaryAction: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            uiState.showAIPanel.toggle()
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .help("AI Copilot: \(uiState.selectedProvider.displayName). Tap to toggle panel, hold/click arrow to switch provider.")
                }
                
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: uiState.isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(uiState.isCopied ? .green : DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Copy notes")
                
                Button {
                    clearNotes()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Clear notes")
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
    }
    
    // MARK: - 2-Space Mode (Tall Column)
    private var twoSpaceView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.98, green: 0.72, blue: 0.20).opacity(0.22))
                        .frame(width: 24, height: 24)
                    Image(systemName: "note.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.98, green: 0.72, blue: 0.20))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quick Memo")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(wordCount) words · \(charCount) characters")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
                
                // Key Sound button
                Button {
                    FeedbackManager.playClick()
                    if uiState.isThockRunning {
                        ThockModule.shared.stopEngine()
                    } else {
                        ThockModule.shared.startEngine()
                    }
                } label: {
                    Image(systemName: uiState.isThockRunning ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(uiState.isThockRunning ? Color(red: 0.98, green: 0.72, blue: 0.20) : DesignSystem.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(uiState.isThockRunning ? "Mechanical key sound active (persists while Notch is running)" : "Turn on typing sound")
                
                // Ask AI Button
                Button {
                    FeedbackManager.playClick()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        uiState.showAIPanel.toggle()
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(uiState.showAIPanel ? Color(red: 0.76, green: 0.44, blue: 0.98) : DesignSystem.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(uiState.showAIPanel ? 0.2 : 0.08)))
                }
                .buttonStyle(.plain)
                .help("Chat with AI (Siri, Gemini, GPT) using note")
                
                // Bullet point button
                Button {
                    insertBullet()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Add bullet point")
                
                // Copy button
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: uiState.isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(uiState.isCopied ? .green : DesignSystem.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Copy all text")
                
                // Clear button
                Button {
                    clearNotes()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Clear notepad")
            }
            
            // Undo bar if active
            if uiState.showUndoClear {
                HStack {
                    Text("Notepad cleared.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                    Spacer()
                    Button("Undo") {
                        undoClear()
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DesignSystem.accentColor)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
            }
            
            // Richer Editor or AI Panel
            ZStack(alignment: .topLeading) {
                if uiState.showAIPanel {
                    notesAIPanelView(compact: false)
                } else {
                    editorWithPlaceholder(placeholder: "Capture quick tasks, links, snippets, or meeting notes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
    }
    
    // MARK: - 4-Space Mode (Full Stage)
    private var fourSpaceView: some View {
        HStack(spacing: 12) {
            // Left summary column
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.98, green: 0.72, blue: 0.20))
                    Text("Workspace Notes")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("Persistent scratchpad anchored directly to your MacBook hardware notch.")
                    .font(.system(size: 10.5))
                    .foregroundColor(DesignSystem.secondaryText)
                    .lineLimit(3)
                
                Divider().background(Color.white.opacity(0.12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TELEMETRY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.secondaryText)
                    Text("\(wordCount) Words · \(charCount) Characters")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        FeedbackManager.playClick()
                        if uiState.isThockRunning {
                            ThockModule.shared.stopEngine()
                        } else {
                            ThockModule.shared.startEngine()
                        }
                    } label: {
                        Label(uiState.isThockRunning ? "Sound ON" : "Sound OFF", systemImage: uiState.isThockRunning ? "speaker.wave.2.fill" : "speaker.slash")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(uiState.isThockRunning ? Color(red: 0.98, green: 0.72, blue: 0.20) : .white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    
                    if store.isNotesAIEnabled {
                        HStack(spacing: 4) {
                            Button {
                                FeedbackManager.playClick()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    uiState.showAIPanel.toggle()
                                }
                            } label: {
                                Label(uiState.showAIPanel ? "Notes" : "Ask AI", systemImage: "sparkles")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(uiState.showAIPanel ? uiState.selectedProvider.tintColor : .white)
                            }
                            .buttonStyle(.plain)
                            
                            Menu {
                                ForEach(AIProvider.allCases) { provider in
                                    Button {
                                        AskAIService.shared.switchProvider(to: provider)
                                        uiState.selectedProvider = provider
                                    } label: {
                                        if uiState.selectedProvider == provider {
                                            Label(provider.displayName, systemImage: "checkmark")
                                        } else {
                                            Text(provider.displayName)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Text(uiState.selectedProvider.shortName)
                                        .font(.system(size: 9, weight: .bold))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 7))
                                }
                                .foregroundColor(uiState.selectedProvider.tintColor)
                            }
                            .menuStyle(.borderlessButton)
                            .help("Current AI: \(uiState.selectedProvider.displayName). Tap to switch to Siri, Gemini, or ChatGPT.")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(uiState.showAIPanel ? uiState.selectedProvider.tintColor.opacity(0.2) : Color.white.opacity(0.08)))
                    }
                    
                    Button {
                        insertBullet()
                    } label: {
                        Label("Bullet", systemImage: "list.bullet")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    
                    Button {
                        copyToClipboard()
                    } label: {
                        Label(uiState.isCopied ? "Copied" : "Copy", systemImage: uiState.isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(uiState.isCopied ? .green : .white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .frame(width: 170)
            .padding(.trailing, 4)
            
            Divider().background(Color.white.opacity(0.12))
            
            // Right wide editor or AI Panel
            ZStack {
                if uiState.showAIPanel && store.isNotesAIEnabled {
                    notesAIPanelView(compact: false)
                } else {
                    editorWithPlaceholder(placeholder: "Write anything... thoughts, code snippets, quick reminders, or to-dos.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
    }
    
    // MARK: - Editor with Placeholder Helper
    @ViewBuilder
    private func editorWithPlaceholder(placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if noteStorage.text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                    .padding(.top, 2)
                    .padding(.leading, 1)
                    .allowsHitTesting(false)
            }
            CustomTextEditor(text: $noteStorage.text, placeholder: placeholder)
        }
    }
    
    // MARK: - Actions
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(noteStorage.text, forType: .string)
        FeedbackManager.playClick()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            uiState.isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                self.uiState.isCopied = false
            }
        }
    }
    
    private func clearNotes() {
        guard !noteStorage.text.isEmpty else { return }
        uiState.previousTextBeforeClear = noteStorage.text
        noteStorage.clear()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            uiState.showUndoClear = true
        }
        uiState.undoTimer?.invalidate()
        uiState.undoTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    self.uiState.showUndoClear = false
                }
            }
        }
    }
    
    private func undoClear() {
        uiState.undoTimer?.invalidate()
        noteStorage.text = uiState.previousTextBeforeClear
        uiState.previousTextBeforeClear = ""
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            uiState.showUndoClear = false
        }
        noteStorage.saveImmediately()
    }
    
    private func insertBullet() {
        if noteStorage.text.isEmpty || noteStorage.text.hasSuffix("\n") {
            noteStorage.text += "• "
        } else {
            noteStorage.text += "\n• "
        }
    }
    
    // MARK: - Notes AI Assistant Panel
    @ViewBuilder
    private func notesAIPanelView(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            // Header: Sparkles + Title + Provider Pills + Close button
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(uiState.selectedProvider.tintColor)
                
                Text("Ask AI with Note")
                    .font(.system(size: compact ? 10.5 : 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Provider pills
                HStack(spacing: 3) {
                    ForEach(AIProvider.allCases) { provider in
                        let isSelected = uiState.selectedProvider == provider
                        Button {
                            FeedbackManager.playClick()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                uiState.selectedProvider = provider
                            }
                        } label: {
                            Text(provider.shortName)
                                .font(.system(size: 8.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(isSelected ? provider.tintColor : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        uiState.showAIPanel = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Close AI panel")
            }
            
            // Quick Note Action Chips (Summarize, Action Items, Polish)
            HStack(spacing: 4) {
                Button("Summarize") {
                    runAIAction {
                        await AskAIService.shared.summarizeNotes(noteText: noteStorage.text, provider: uiState.selectedProvider)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                
                Button("To-Dos") {
                    runAIAction {
                        await AskAIService.shared.extractActionItems(noteText: noteStorage.text, provider: uiState.selectedProvider)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                
                Button("Polish") {
                    runAIAction {
                        await AskAIService.shared.polishNotes(noteText: noteStorage.text, provider: uiState.selectedProvider)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            
            // Result Display or Empty Prompt State
            ZStack(alignment: .topLeading) {
                if uiState.isAIGenerating {
                    VStack(spacing: 6) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.75)
                            .progressViewStyle(CircularProgressViewStyle(tint: uiState.selectedProvider.tintColor))
                        Text("Thinking via \(uiState.selectedProvider.displayName)...")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !uiState.aiResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(uiState.aiResponse)
                                .font(.system(size: compact ? 10 : 10.5))
                                .foregroundColor(.white.opacity(0.92))
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        
                        // Action buttons
                        HStack(spacing: 6) {
                            Button {
                                appendAIResponse()
                            } label: {
                                Label(uiState.isAIInserted ? "Appended!" : "Append", systemImage: uiState.isAIInserted ? "checkmark" : "plus.bubble")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(uiState.isAIInserted ? .green : DesignSystem.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                replaceWithAIResponse()
                            } label: {
                                Text("Replace")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(DesignSystem.secondaryText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                copyAIText()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 9))
                                    .foregroundColor(DesignSystem.secondaryText)
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                            .help("Copy AI response")
                        }
                    }
                } else if uiState.selectedProvider == .gemini && store.geminiApiKey.isEmpty && store.connectedGoogleEmail.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(AIProvider.gemini.tintColor)
                            Text("Google Gemini")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                            if !store.connectedGoogleEmail.isEmpty {
                                Text("• \(store.connectedGoogleEmail)")
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundColor(.green)
                                    .lineLimit(1)
                            }
                        }
                        Text(!store.connectedGoogleEmail.isEmpty ? "Connected via Google Antigravity. Enter Gemini key to enable cloud queries:" : "Sign in with Google to connect your Gemini account:")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        HStack(spacing: 5) {
                            Button {
                                AskAIService.shared.connectGoogleAccount()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                    Text(!store.connectedGoogleEmail.isEmpty ? "Google Connected" : "Sign in with Google")
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(!store.connectedGoogleEmail.isEmpty ? Color.green.opacity(0.8) : AIProvider.gemini.tintColor))
                            }
                            .buttonStyle(.plain)
                            
                            SecureField("Paste AIzaSy... key", text: $uiState.apiKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2.5)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.12)))
                            
                            Button("Save") {
                                AskAIService.shared.saveGeminiKey(uiState.apiKeyInput)
                                uiState.apiKeyInput = ""
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(Color.white.opacity(0.20)))
                            .buttonStyle(.plain)
                            .disabled(uiState.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if uiState.selectedProvider == .gpt && store.openAIApiKey.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AIProvider.gpt.tintColor)
                            Text("OpenAI ChatGPT Setup")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Get an API key from OpenAI platform:")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        HStack(spacing: 5) {
                            Button {
                                AskAIService.shared.openOpenAIKeyPage()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "key.fill")
                                    Text("Get OpenAI Key")
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AIProvider.gpt.tintColor))
                            }
                            .buttonStyle(.plain)
                            
                            SecureField("Paste sk-... key", text: $uiState.apiKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2.5)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.12)))
                            
                            Button("Save") {
                                AskAIService.shared.saveOpenAIKey(uiState.apiKeyInput)
                                uiState.apiKeyInput = ""
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(Color.white.opacity(0.20)))
                            .buttonStyle(.plain)
                            .disabled(uiState.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text(uiState.selectedProvider == .siri ? "Tap 'Siri' below to activate native macOS Siri with this note, or type below." : "Ask questions or rewrite this note using \(uiState.selectedProvider.displayName).")
                        .font(.system(size: compact ? 9.5 : 10.5))
                        .foregroundColor(DesignSystem.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Query Input
            HStack(spacing: 6) {
                if uiState.selectedProvider == .siri {
                    Button {
                        AskAIService.shared.triggerSiri(query: uiState.aiQuery, context: noteStorage.text)
                        uiState.aiQuery = ""
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("Siri")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(AIProvider.siri.tintColor))
                    }
                    .buttonStyle(.plain)
                }
                
                TextField("Ask about note...", text: $uiState.aiQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .onSubmit {
                        submitNotesAIQuery()
                    }
                
                Button {
                    submitNotesAIQuery()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 10))
                        .foregroundColor(uiState.aiQuery.isEmpty ? DesignSystem.secondaryText : .white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(uiState.aiQuery.isEmpty ? Color.white.opacity(0.08) : uiState.selectedProvider.tintColor))
                }
                .buttonStyle(.plain)
                .disabled(uiState.aiQuery.isEmpty || uiState.isAIGenerating)
            }
        }
        .padding(compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(uiState.selectedProvider.tintColor.opacity(0.35), lineWidth: 0.9)
                )
        )
    }
    
    // MARK: - AI Action Helpers
    private func submitNotesAIQuery() {
        guard !uiState.aiQuery.isEmpty && !uiState.isAIGenerating else { return }
        let q = uiState.aiQuery
        uiState.aiQuery = ""
        runAIAction {
            await AskAIService.shared.ask(prompt: q, context: noteStorage.text, provider: uiState.selectedProvider)
        }
    }
    
    private func runAIAction(_ action: @escaping () async -> String) {
        FeedbackManager.playClick()
        uiState.isAIGenerating = true
        Task {
            let res = await action()
            Task { @MainActor in
                self.uiState.aiResponse = res
                self.uiState.isAIGenerating = false
            }
        }
    }
    
    private func appendAIResponse() {
        guard !uiState.aiResponse.isEmpty else { return }
        FeedbackManager.playClick()
        if noteStorage.text.isEmpty {
            noteStorage.text = uiState.aiResponse
        } else {
            noteStorage.text += "\n\n--- AI (\(uiState.selectedProvider.shortName)) ---\n" + uiState.aiResponse
        }
        noteStorage.saveImmediately()
        uiState.isAIInserted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.uiState.isAIInserted = false
        }
    }
    
    private func replaceWithAIResponse() {
        guard !uiState.aiResponse.isEmpty else { return }
        FeedbackManager.playClick()
        uiState.previousTextBeforeClear = noteStorage.text
        noteStorage.text = uiState.aiResponse
        noteStorage.saveImmediately()
        withAnimation {
            uiState.showAIPanel = false
        }
    }
    
    private func copyAIText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(uiState.aiResponse, forType: .string)
        FeedbackManager.playClick()
    }
}

// MARK: - AppKit Native CustomTextEditor for Flawless, Thermal-Safe macOS Typing
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        textView.textColor = NSColor.white
        textView.insertionPointColor = NSColor.white
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticTextCompletionEnabled = false
        if #available(macOS 14.0, *) {
            textView.contentType = nil
        }
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.string = text
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }
    }
}
