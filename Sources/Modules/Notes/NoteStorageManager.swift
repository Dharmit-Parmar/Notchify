import Foundation
import Combine
import AppKit

/// Zero-overhead, debounced notes storage manager.
/// Completely eliminates full Notch UI invalidations and disk I/O thrashing during typing.
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
    
    private init() {
        self.text = UserDefaults.standard.string(forKey: Self.userDefaultsKey) ?? ""
        setupLifecycleObservers()
    }
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveImmediately()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveImmediately()
            }
        }
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
        UserDefaults.standard.set(text, forKey: Self.userDefaultsKey)
        isDirty = false
    }
    
    public func clear() {
        text = ""
        saveImmediately()
    }
}
