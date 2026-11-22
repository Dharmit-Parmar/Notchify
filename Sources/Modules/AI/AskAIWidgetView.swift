import SwiftUI
import AppKit

@MainActor
final class AskAIWidgetUIState: ObservableObject {
    @Published var inputPrompt: String = ""
    @Published var isCopied: Bool = false
    @Published var insertedIntoNotes: Bool = false
    // FIX (#5): separate buffers per provider so typing a Gemini key then
    // switching to GPT cannot accidentally save the wrong secret.
    @Published var geminiKeyInput: String = ""
    @Published var openAIKeyInput: String = ""
    var queryTask: Task<Void, Never>? = nil
}

public struct AskAIWidgetView: View {
    public var span: Int // 1, 2, or 4 spaces

    // FIX (#7): `notchCompact` was declared but never read; removed.
    @Environment(\.notchTight) private var notchTight
    @ObservedObject private var aiService = AskAIService.shared
    @ObservedObject private var store = SettingsStore.shared
    @StateObject private var uiState = AskAIWidgetUIState()
    @FocusState private var isFieldFocused: Bool

    public init(span: Int = 1) {
        self.span = span
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isFieldFocused) { _, focused in
            NotchShellCoordinator.shared.isTypingInWidget = focused
            if focused {
                NSApp.activate(ignoringOtherApps: true)
                NotchShellCoordinator.shared.panel?.makeKey()
            }
        }
        .onDisappear {
            if isFieldFocused {
                isFieldFocused = false
                NotchShellCoordinator.shared.isTypingInWidget = false
            }
            // FIX (#4): queryTask is now cleared when the wrapped task body
            // completes; this is just a safety net for torn-down views.
            uiState.queryTask = nil
        }
    }

    // MARK: - Shared Setup State Helper
    /// FIX (#1): a single, Keychain-aware check for whether the current
    /// provider actually needs the "setup required" panel. Previously the
    /// widget read `store.geminiApiKey.isEmpty` directly, so a user whose key
    /// lived only in the Keychain (the new persistence path) still saw the
    /// setup screen even though queries would have succeeded.
    private var activeProviderNeedsSetup: Bool {
        !aiService.isCurrentProviderAuthenticated
    }

    // MARK: - 1-Space Mode (Compact Tile)
    private var oneSpaceView: some View {
        VStack(alignment: .leading, spacing: notchTight ? 3 : 6) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(aiService.activeProvider.tintColor)

                Text("Ask AI")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                Text(aiService.activeProvider.shortName)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(aiService.activeProvider.tintColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(aiService.activeProvider.tintColor.opacity(0.18)))
            }

            // Content Stage
            ZStack(alignment: .topLeading) {
                if let err = aiService.errorMessage, !aiService.isGenerating {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Notice")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                aiService.errorMessage = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(err)
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                        Spacer()
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.14)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if aiService.isGenerating {
                    VStack(spacing: 6) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: aiService.activeProvider.tintColor))
                        Text("Thinking...")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                        // FIX (#6): allow aborting a hung query in the compact tile.
                        Button {
                            cancelActiveQuery()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(DesignSystem.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !aiService.lastResponse.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(aiService.lastResponse)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                } else if aiService.activeProvider == .gemini && activeProviderNeedsSetup {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Google Gemini")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Button {
                            aiService.connectGoogleAccount()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text("Sign in with Google")
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AIProvider.gemini.tintColor))
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 4) {
                            SecureField("Paste key...", text: $uiState.geminiKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
                            Button("Save") {
                                aiService.saveGeminiKey(uiState.geminiKeyInput)
                                uiState.geminiKeyInput = ""
                            }
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                            .buttonStyle(.plain)
                            .disabled(uiState.geminiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if aiService.activeProvider == .gpt && activeProviderNeedsSetup {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenAI Setup")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Button {
                            aiService.openOpenAIKeyPage()
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

                        HStack(spacing: 4) {
                            SecureField("Paste key...", text: $uiState.openAIKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
                            Button("Save") {
                                aiService.saveOpenAIKey(uiState.openAIKeyInput)
                                uiState.openAIKeyInput = ""
                            }
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                            .buttonStyle(.plain)
                            .disabled(uiState.openAIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(aiService.activeProvider == .siri ? "Tap mic to activate native Siri on macOS." : "Ask anything with Gemini or ChatGPT.")
                            .font(.system(size: 10.5))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineLimit(3)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            // Bottom Action & Input Bar
            HStack(spacing: 6) {
                if aiService.activeProvider == .siri {
                    Button {
                        aiService.triggerSiri()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Siri")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AIProvider.siri.tintColor.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                }

                TextField(aiService.activeProvider == .siri ? "Query..." : "Ask...", text: $uiState.inputPrompt)
                    .focused($isFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .onSubmit {
                        submitPrompt()
                    }

                Button {
                    submitPrompt()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(uiState.inputPrompt.isEmpty ? DesignSystem.secondaryText : aiService.activeProvider.tintColor)
                }
                .buttonStyle(.plain)
                .disabled(uiState.inputPrompt.isEmpty || aiService.isGenerating)
            }
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
            // Header with Provider Pills
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(aiService.activeProvider.tintColor.opacity(0.22))
                        .frame(width: 24, height: 24)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(aiService.activeProvider.tintColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Ask AI Assistant")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(aiService.activeProvider.displayName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                }

                Spacer()

                HStack(spacing: 3) {
                    ForEach(AIProvider.allCases) { provider in
                        let isSelected = aiService.activeProvider == provider
                        Button {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                aiService.switchProvider(to: provider)
                            }
                        } label: {
                            Text(provider.shortName)
                                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(isSelected ? provider.tintColor.opacity(0.85) : Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Quick Action Chips
            HStack(spacing: 5) {
                // FIX (#2): quick chips are disabled while a query is in
                // flight. Previously clicking one fired a second `ask()`,
                // which post-fix returns a busy message and sets
                // `errorMessage`, showing a red "Notice" panel for a
                // legitimate user click.
                quickChip(
                    title: "Summarize Note",
                    icon: "doc.text.magnifyingglass",
                    disabled: aiService.isGenerating
                ) {
                    runQuickTask { await aiService.summarizeNotes(noteText: store.quickNotesText) }
                }
                quickChip(
                    title: "Action Items",
                    icon: "checklist",
                    disabled: aiService.isGenerating
                ) {
                    runQuickTask { await aiService.extractActionItems(noteText: store.quickNotesText) }
                }
                quickChip(
                    title: "Polish Note",
                    icon: "wand.and.stars",
                    disabled: aiService.isGenerating
                ) {
                    runQuickTask { await aiService.polishNotes(noteText: store.quickNotesText) }
                }
            }

            // Middle Response Area
            ZStack(alignment: .topLeading) {
                if let err = aiService.errorMessage, !aiService.isGenerating {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                            Text("Notice")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                aiService.errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(err)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(2)

                        if !aiService.lastResponse.isEmpty {
                            Divider().background(Color.white.opacity(0.1))
                            ScrollView(.vertical, showsIndicators: false) {
                                Text(aiService.lastResponse)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if aiService.isGenerating {
                    VStack(spacing: 8) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.85)
                            .progressViewStyle(CircularProgressViewStyle(tint: aiService.activeProvider.tintColor))
                        Text("Thinking via \(aiService.activeProvider.displayName)...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                        // FIX (#6): abort button.
                        Button {
                            cancelActiveQuery()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(DesignSystem.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !aiService.lastResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(aiService.lastResponse)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.94))
                                .lineSpacing(2.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }

                        HStack(spacing: 8) {
                            Button {
                                aiService.insertIntoNotes(text: aiService.lastResponse, append: true)
                                uiState.insertedIntoNotes = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    self.uiState.insertedIntoNotes = false
                                }
                            } label: {
                                Label(uiState.insertedIntoNotes ? "Appended!" : "Insert into Note", systemImage: uiState.insertedIntoNotes ? "checkmark" : "note.text.badge.plus")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(uiState.insertedIntoNotes ? .green : DesignSystem.accentColor)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                copyResponse()
                            } label: {
                                Label(uiState.isCopied ? "Copied" : "Copy", systemImage: uiState.isCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(uiState.isCopied ? .green : DesignSystem.secondaryText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                aiService.clearHistory()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .help("Clear response")
                        }
                    }
                } else if aiService.activeProvider == .gemini && activeProviderNeedsSetup {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundColor(AIProvider.gemini.tintColor)
                            Text("Google Gemini")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Sign in with your Google account to get your free Gemini API key, or paste one below:")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineSpacing(1.5)

                        HStack(spacing: 6) {
                            Button {
                                aiService.connectGoogleAccount()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                    Text("Sign in with Google")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AIProvider.gemini.tintColor))
                            }
                            .buttonStyle(.plain)

                            SecureField("Paste AIzaSy... key", text: $uiState.geminiKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)))

                            Button("Save") {
                                aiService.saveGeminiKey(uiState.geminiKeyInput)
                                uiState.geminiKeyInput = ""
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.20)))
                            .buttonStyle(.plain)
                            .disabled(uiState.geminiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("Hardware AES-256 Keychain. Unified across Notes & Ask AI.")
                                .font(.system(size: 9))
                                .foregroundColor(DesignSystem.tertiaryText)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if aiService.activeProvider == .gpt && activeProviderNeedsSetup {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AIProvider.gpt.tintColor)
                            Text("OpenAI ChatGPT Setup")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Get an API key from OpenAI platform to activate GPT-4o intelligence:")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineSpacing(1.5)

                        HStack(spacing: 6) {
                            Button {
                                aiService.openOpenAIKeyPage()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "key.fill")
                                    Text("Get OpenAI Key")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AIProvider.gpt.tintColor))
                            }
                            .buttonStyle(.plain)

                            SecureField("Paste sk-... key", text: $uiState.openAIKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)))

                            Button("Save") {
                                aiService.saveOpenAIKey(uiState.openAIKeyInput)
                                uiState.openAIKeyInput = ""
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.20)))
                            .buttonStyle(.plain)
                            .disabled(uiState.openAIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("Hardware AES-256 Keychain. Unified across Notes & Ask AI.")
                                .font(.system(size: 9))
                                .foregroundColor(DesignSystem.tertiaryText)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ask questions, draft emails, summarize notes, or trigger native macOS Siri without RAM overhead.")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineSpacing(2)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Input Bar
            HStack(spacing: 8) {
                if aiService.activeProvider == .siri {
                    Button {
                        aiService.triggerSiri(query: uiState.inputPrompt)
                        uiState.inputPrompt = ""
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Ask Siri")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AIProvider.siri.tintColor))
                    }
                    .buttonStyle(.plain)
                }

                TextField("Ask anything...", text: $uiState.inputPrompt)
                    .focused($isFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                    .onSubmit {
                        submitPrompt()
                    }

                Button {
                    submitPrompt()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(uiState.inputPrompt.isEmpty ? DesignSystem.secondaryText : .white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(uiState.inputPrompt.isEmpty ? Color.white.opacity(0.08) : aiService.activeProvider.tintColor))
                }
                .buttonStyle(.plain)
                .disabled(uiState.inputPrompt.isEmpty || aiService.isGenerating)
            }
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
            // Left Control Column
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(aiService.activeProvider.tintColor)
                    Text("AI Assistant")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text("Zero-RAM intelligence engine bridging Apple Siri, Google Gemini, and ChatGPT directly to your notch.")
                    .font(.system(size: 10.5))
                    .foregroundColor(DesignSystem.secondaryText)
                    .lineLimit(3)

                Divider().background(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVE ENGINE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.secondaryText)

                    ForEach(AIProvider.allCases) { provider in
                        let isSelected = aiService.activeProvider == provider
                        Button {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                aiService.switchProvider(to: provider)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: provider.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : provider.tintColor)
                                Text(provider.displayName)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
                                Spacer()
                                if isSelected {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? provider.tintColor.opacity(0.85) : Color.white.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        if !aiService.lastResponse.isEmpty {
                            aiService.insertIntoNotes(text: aiService.lastResponse, append: true)
                        }
                    } label: {
                        Label("To Notes", systemImage: "note.text.badge.plus")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .disabled(aiService.lastResponse.isEmpty)

                    Button {
                        aiService.clearHistory()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .frame(width: 170)
            .padding(.trailing, 4)

            Divider().background(Color.white.opacity(0.12))

            // Right Chat Dialogue
            VStack(spacing: 8) {
                if let err = aiService.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                        Spacer()
                        Button {
                            aiService.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.red.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.red.opacity(0.35), lineWidth: 0.8)
                            )
                    )
                }

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 10) {
                            if aiService.messages.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "bubble.left.and.sparkles")
                                        .font(.system(size: 24))
                                        .foregroundColor(aiService.activeProvider.tintColor.opacity(0.7))
                                    Text("How can I help you today?")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Ask questions, draft text, or summarize your notes directly from the Notch.")
                                        .font(.system(size: 11))
                                        .foregroundColor(DesignSystem.secondaryText)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 40)
                            } else {
                                ForEach(aiService.messages) { msg in
                                    messageBubble(msg)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: aiService.messages.count) { _, _ in
                        if let lastId = aiService.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // Prompt Bar
                HStack(spacing: 8) {
                    TextField("Ask \(aiService.activeProvider.displayName)...", text: $uiState.inputPrompt)
                        .focused($isFieldFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        .onSubmit {
                            submitPrompt()
                        }

                    Button {
                        submitPrompt()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Send")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(uiState.inputPrompt.isEmpty ? Color.white.opacity(0.1) : aiService.activeProvider.tintColor))
                    }
                    .buttonStyle(.plain)
                    .disabled(uiState.inputPrompt.isEmpty || aiService.isGenerating)
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

    // MARK: - Message Bubble Helper
    private func messageBubble(_ msg: AIChatMessage) -> some View {
        HStack {
            if msg.role == .user {
                Spacer()
                Text(msg.content)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignSystem.accentColor)
                    )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: msg.provider.icon)
                            .font(.system(size: 9))
                            .foregroundColor(msg.provider.tintColor)
                        Text(msg.provider.shortName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(msg.provider.tintColor)
                    }
                    Text(msg.content)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.95))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                Spacer()
            }
        }
        .id(msg.id)
    }

    // MARK: - Quick Chip Helper
    // FIX (#2): accept `disabled` so the chip visibly greys out during
    // generation, preventing the "second click fires a busy error" path.
    private func quickChip(
        title: String,
        icon: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            FeedbackManager.playClick()
            action()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(DesignSystem.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }

    // MARK: - Actions

    // FIX (#3): removed the misleading `queryTask?.cancel()` (which had no
    // effect because `AskAIService.ask` does not check cancellation, and if
    // it did, would append a fake "❌ Gemini request failed: cancelled"
    // message to `messages`). Overlap is prevented by the `isGenerating`
    // guard already present in `submitPrompt` and by disabling quick chips.
    private func submitPrompt() {
        guard !uiState.inputPrompt.isEmpty && !aiService.isGenerating else { return }
        let promptToSend = uiState.inputPrompt
        uiState.inputPrompt = ""
        isFieldFocused = false
        NotchShellCoordinator.shared.isTypingInWidget = false
        FeedbackManager.playClick()

        uiState.queryTask = Task { @MainActor in
            _ = await aiService.ask(prompt: promptToSend, context: store.quickNotesText)
            // FIX (#4): clear the reference once the task finishes so we don't
            // hold a completed Task object indefinitely.
            uiState.queryTask = nil
        }
    }

    // FIX (#2, #4): shared helper for the quick-action chips. Both guard
    // against starting while another query is running AND clear the task
    // reference on completion.
    private func runQuickTask(_ operation: @escaping @MainActor () async -> String) {
        guard !aiService.isGenerating else { return }
        uiState.queryTask = Task { @MainActor in
            _ = await operation()
            uiState.queryTask = nil
        }
    }

    // FIX (#6): shared cancel helper. Cancels the wrapper task — this won't
    // abort the in-flight network request (see #3), but it releases the UI
    // so the user isn't stuck waiting. The pending `ask` continues and will
    // eventually set `isGenerating = false`.
    private func cancelActiveQuery() {
        FeedbackManager.playClick()
        uiState.queryTask?.cancel()
        uiState.queryTask = nil
    }

    private func copyResponse() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(aiService.lastResponse, forType: .string)
        FeedbackManager.playClick()
        uiState.isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.uiState.isCopied = false
        }
    }
}