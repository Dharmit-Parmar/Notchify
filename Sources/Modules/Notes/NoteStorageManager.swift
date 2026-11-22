import Foundation
import Combine
import AppKit

/// Strongly-typed save state for user feedback.
public enum NoteSaveState: Equatable, Sendable {
    case saved
    case saving
    case failed(String)
}

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
            currentRevision += 1
            saveState = .saving
            scheduleDebouncedSave()
        }
    }
    
    @Published public var saveState: NoteSaveState = .saved
    private var currentRevision: Int = 0
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
            do {
                try fileStore.writeString(legacy, to: fileURL)
                UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
                self.saveState = .saved
            } catch {
                // Preserve legacy storage in UserDefaults if write failed
                self.isDirty = true
                self.saveState = .failed(error.localizedDescription)
            }
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
        let revision = currentRevision
        let snapshot = text
        saveTask = Task { @MainActor [weak self] in
            // 1.5-second debounce: writes to disk only after user pauses typing
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.commitSnapshot(snapshot, revision: revision)
        }
    }
    
    @discardableResult
    public func saveImmediately() -> Bool {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty && userHasEdited else { return true }
        return commitSnapshot(text, revision: currentRevision)
    }
    
    @discardableResult
    private func commitSnapshot(_ snapshot: String, revision: Int) -> Bool {
        guard userHasEdited else { return true }
        let target = storageURL
        do {
            try fileStore.writeString(snapshot, to: target)
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
            if self.currentRevision == revision {
                self.isDirty = false
                self.saveState = .saved
            }
            return true
        } catch {
            self.isDirty = true
            self.saveState = .failed(error.localizedDescription)
            return false
        }
    }
    
    public func clear() {
        userHasEdited = true
        text = ""
        isDirty = true
        saveImmediately()
    }
}
