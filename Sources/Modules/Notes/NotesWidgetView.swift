import SwiftUI
import AppKit

@MainActor
final class NotesUIState: ObservableObject {
    @Published var isCopied: Bool = false
    @Published var showUndoClear: Bool = false
    @Published var isThockRunning: Bool = ThockModule.shared.isRunning
    var previousTextBeforeClear: String = ""
    var undoTimer: Timer? = nil
}

public struct NotesWidgetView: View {
    @ObservedObject private var noteStorage = NoteStorageManager.shared
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
            // Immediate save when collapsing or navigating away
            noteStorage.saveImmediately()
            // Stop typing sounds when Notes widget is hidden or collapsed
            if ThockModule.shared.isRunning {
                ThockModule.shared.stopEngine()
            }
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
            
            // Body: CustomTextEditor filling available height
            ZStack(alignment: .topLeading) {
                if uiState.showUndoClear {
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
            
            // Bottom Action Bar: Sound button on left, Spacer(), Copy button and Clear button on right
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
                .help(uiState.isThockRunning ? "Mechanical key sound active (auto-stops on close)" : "Turn on typing sound")
                
                Spacer()
                
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
                .help(uiState.isThockRunning ? "Mechanical key sound active (auto-stops on close)" : "Turn on typing sound")
                
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
            
            // Richer Editor
            editorWithPlaceholder(placeholder: "Capture quick tasks, links, snippets, or meeting notes...")
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
            
            // Right wide editor
            editorWithPlaceholder(placeholder: "Write anything... thoughts, code snippets, temporary credentials, or to-dos.")
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
