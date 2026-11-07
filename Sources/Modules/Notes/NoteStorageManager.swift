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
            scheduleDebouncedSave()
        }
    }
    
    private var saveTask: Task<Void, Never>?
    private var isDirty: Bool = false
    private var observerTokens: [NSObjectProtocol] = []
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotchApp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        return dir.appendingPathComponent("notes.txt")
    }
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fileURL = appSupport.appendingPathComponent("NotchApp/notes.txt")
        if FileManager.default.fileExists(atPath: fileURL.path),
           let saved = try? String(contentsOf: fileURL, encoding: .utf8) {
            self.text = saved
        } else if let legacy = UserDefaults.standard.string(forKey: Self.userDefaultsKey) {
            self.text = legacy
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
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
        guard isDirty else { return }
        commitToDisk()
    }
    
    private func commitToDisk() {
        let target = storageURL
        if let data = text.data(using: .utf8) {
            try? data.write(to: target, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        }
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
        isDirty = false
    }
    
    public func clear() {
        text = ""
        saveImmediately()
    }
}
