import Foundation
import Combine
import AppKit

/// Zero-overhead, debounced notes storage manager.
/// Saves notes securely to ~/Library/Application Support/NotchApp/notes.txt (POSIX 0600).
@MainActor
public final class NoteStorageManager: ObservableObject {
    public static let shared = NoteStorageManager()
    
    public static let userDefaultsKey = "NotchApp_QuickNotesText"
    
    @Published public var text: String {
        didSet {
            guard text != oldValue else { return }
            userHasEdited = true
            scheduleDebouncedSave()
        }
    }
    
    private var saveTask: Task<Void, Never>?
    private var isDirty: Bool = false
    private var userHasEdited: Bool = false
    private var observerTokens: [NSObjectProtocol] = []
    
    private let customStorageURL: URL?
    private let fileStore: EncryptedFileStore
    
    private var storageURL: URL {
        if let custom = customStorageURL {
            return custom
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotchApp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        return dir.appendingPathComponent("notes.txt")
    }
    
    public convenience init() {
        self.init(customStorageURL: nil, fileStore: .shared)
    }
    
    public init(customStorageURL: URL? = nil, fileStore: EncryptedFileStore = .shared) {
        self.customStorageURL = customStorageURL
        self.fileStore = fileStore
        
        let fileURL: URL = {
            if let custom = customStorageURL {
                return custom
            }
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("NotchApp/notes.txt")
        }()
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                if let saved = try fileStore.readString(from: fileURL) {
                    self.text = saved
                } else {
                    self.text = ""
                }
            } catch {
                // Invariant 5: on any read error keep the file untouched,
                // run with empty in-memory state, and never write until the user types.
                self.text = ""
                self.isDirty = false
                self.userHasEdited = false
            }
        } else if let legacy = UserDefaults.standard.string(forKey: Self.userDefaultsKey) {
            self.text = legacy
            self.userHasEdited = true
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
            try? fileStore.writeString(legacy, to: fileURL)
        } else {
            self.text = ""
        }
        setupLifecycleObservers()
    }
    
    private func setupLifecycleObservers() {
        let t1 = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveImmediately()
            }
        }
        observerTokens.append(t1)
        
        let t2 = NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveImmediately()
            }
        }
        observerTokens.append(t2)
    }
    
    private func scheduleDebouncedSave() {
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            // 1.5-second debounce: writes to disk only after user pauses typing
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.commitToDisk()
        }
    }
    
    public func saveImmediately() {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty && userHasEdited else { return }
        commitToDisk()
    }
    
    private func commitToDisk() {
        guard userHasEdited else { return }
        let target = storageURL
        try? fileStore.writeString(text, to: target)
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
        isDirty = false
    }
    
    public func clear() {
        userHasEdited = true
        text = ""
        isDirty = true
        saveImmediately()
    }
}
