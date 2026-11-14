import Foundation
import CryptoKit
import AppKit

// MARK: - LocalShare File Storage Manager
public final class LocalShareFileManager: @unchecked Sendable {
    public static let shared = LocalShareFileManager()
    
    private let lock = NSLock()
    private var customReceiveFolder: URL?
    
    public init() {}
    
    // MARK: - Base Directory Management
    
    /// Default root receive directory (~/Downloads/LocalShare).
    public var defaultReceiveDirectory: URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return downloads.appendingPathComponent("LocalShare", isDirectory: true)
    }
    
    /// Active receive directory (custom or default).
    public var activeReceiveDirectory: URL {
        lock.lock()
        defer { lock.unlock() }
        return customReceiveFolder ?? defaultReceiveDirectory
    }
    
    public func setCustomReceiveFolder(_ url: URL?) {
        lock.lock()
        defer { lock.unlock() }
        customReceiveFolder = url
    }
    
    /// Ensures the base receive directory exists with safe permissions.
    @discardableResult
    public func ensureBaseDirectoryExists() throws -> URL {
        let dir = activeReceiveDirectory
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        }
        return dir
    }
    
    // MARK: - Per-Session Isolated Folder Creation (Mode 0700)
    
    /// Creates an isolated session directory with restricted POSIX mode 0700.
    public func createSessionDirectory(sessionId: String) throws -> URL {
        let baseDir = try ensureBaseDirectoryExists()
        let cleanId = LocalShareSecurity.sanitizeFilename(sessionId)
        let sessionDir = baseDir.appendingPathComponent("session-\(cleanId)", isDirectory: true)
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: sessionDir.path) {
            try fm.createDirectory(at: sessionDir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700 // Owner-only read, write, execute
            ])
        }
        return sessionDir
    }
    
    // MARK: - Streaming Atomic File Sink
    
    /// Prepares an active atomic file writer in the session directory.
    public func beginFileStream(
        fileName: String,
        sessionDirectory: URL
    ) throws -> LocalShareFileStreamWriter {
        guard LocalShareSecurity.isContained(fileName: fileName, within: sessionDirectory) else {
            throw LocalShareError.invalidURL
        }
        
        let targetURL = LocalShareSecurity.uniqueDestinationURL(for: fileName, in: sessionDirectory)
        return try LocalShareFileStreamWriter(destinationURL: targetURL)
    }
    
    // MARK: - Partial File & Session Cleanup
    
    /// Deletes a specific file if present on disk.
    public func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Purges an entire session folder and any partially received files.
    public func purgeSessionDirectory(sessionId: String) {
        let baseDir = activeReceiveDirectory
        let cleanId = LocalShareSecurity.sanitizeFilename(sessionId)
        let sessionDir = baseDir.appendingPathComponent("session-\(cleanId)", isDirectory: true)
        try? FileManager.default.removeItem(at: sessionDir)
    }
    
    // MARK: - Safe Finder Interaction (Zero Auto-Open / Auto-Execution)
    
    /// Safely highlights the received file in Finder without opening, executing, or previewing it.
    @MainActor
    public func revealInFinder(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
    
    /// Applies macOS quarantine attribute (com.apple.quarantine) to received files.
    public static func applyQuarantineAttribute(to url: URL) {
        let quarantineValue = "0083;65432100;LocalShare;com.notch.NotchApp"
        url.withUnsafeFileSystemRepresentation { fsPath in
            guard let fsPath = fsPath else { return }
            _ = setxattr(fsPath, "com.apple.quarantine", quarantineValue, quarantineValue.utf8.count, 0, 0)
        }
    }
}

// MARK: - Streaming File Writer with Incremental SHA-256 Verification
public final class LocalShareFileStreamWriter: @unchecked Sendable {
    public let destinationURL: URL
    private let fileHandle: FileHandle
    private var hasher = SHA256()
    private var bytesWritten: Int64 = 0
    private var isFinalized = false
    private let lock = NSLock()
    
    public init(destinationURL: URL) throws {
        self.destinationURL = destinationURL
        let fm = FileManager.default
        
        // Create empty file
        if !fm.createFile(atPath: destinationURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) {
            throw LocalShareError.serverError("Unable to initialize destination file on disk")
        }
        
        guard let handle = try? FileHandle(forWritingTo: destinationURL) else {
            try? fm.removeItem(at: destinationURL)
            throw LocalShareError.serverError("Failed to open file handle for writing")
        }
        self.fileHandle = handle
    }
    
    /// Writes a chunk of data directly to disk, updating the incremental SHA-256 checksum.
    public func writeChunk(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinalized else {
            throw LocalShareError.serverError("Attempted to write to finalized stream")
        }
        
        try fileHandle.write(contentsOf: data)
        hasher.update(data: data)
        bytesWritten += Int64(data.count)
    }
    
    /// Finalizes the file stream, optionally verifying against expected SHA-256 and expected size.
    public func finalize(expectedSha256: String?, expectedSize: Int64) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinalized else { return }
        isFinalized = true
        
        try? fileHandle.synchronize()
        try? fileHandle.close()
        
        // 1. Verify byte size
        if expectedSize > 0 && bytesWritten != expectedSize {
            try? FileManager.default.removeItem(at: destinationURL)
            throw LocalShareError.serverError("Received size mismatch (expected \(expectedSize), got \(bytesWritten))")
        }
        
        // 2. Verify SHA-256 if provided by sender
        if let expectedHash = expectedSha256, !expectedHash.isEmpty {
            let digest = hasher.finalize()
            let computedHex = digest.map { String(format: "%02x", $0) }.joined()
            if computedHex.caseInsensitiveCompare(expectedHash) != .orderedSame {
                try? FileManager.default.removeItem(at: destinationURL)
                throw LocalShareError.checksumMismatch
            }
        }
        
        // 3. Apply macOS quarantine attribute
        LocalShareFileManager.applyQuarantineAttribute(to: destinationURL)
    }
    
    /// Cancels and deletes the incomplete file from disk.
    public func abort() {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinalized else { return }
        isFinalized = true
        try? fileHandle.close()
        try? FileManager.default.removeItem(at: destinationURL)
    }
    
    deinit {
        if !isFinalized {
            try? fileHandle.close()
            try? FileManager.default.removeItem(at: destinationURL)
        }
    }
}
