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
        let sanitized = LocalShareSecurity.sanitizeFilename(fileName)
        guard LocalShareSecurity.isContained(fileName: sanitized, within: sessionDirectory) else {
            throw LocalShareError.invalidURL
        }
        
        let baseName = (sanitized as NSString).deletingPathExtension
        let ext = (sanitized as NSString).pathExtension
        
        // Atomically claim the destination file using O_CREAT | O_EXCL | O_NOFOLLOW
        // If a file or symlink exists at candidate, try (1), (2), etc.
        for counter in 0...9999 {
            let candidateName: String
            if counter == 0 {
                candidateName = sanitized
            } else if ext.isEmpty {
                candidateName = "\(baseName) (\(counter))"
            } else {
                candidateName = "\(baseName) (\(counter)).\(ext)"
            }
            let candidateURL = sessionDirectory.appendingPathComponent(candidateName)
            do {
                return try LocalShareFileStreamWriter(destinationURL: candidateURL)
            } catch LocalShareError.fileExists {
                continue
            }
        }
        throw LocalShareError.serverError("Unable to acquire unique non-colliding destination file")
    }

    // MARK: - Partial File & Session Cleanup
    
    /// Deletes a specific file if present on disk.
    public func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Moves completed files from the isolated session folder to the root receive directory.
    @discardableResult
    public func promoteSessionFiles(sessionId: String, sessionDirectory: URL) -> [URL] {
        let fm = FileManager.default
        let baseDir = activeReceiveDirectory
        _ = try? ensureBaseDirectoryExists()
        var promotedURLs: [URL] = []
        
        guard let files = try? fm.contentsOfDirectory(at: sessionDirectory, includingPropertiesForKeys: nil) else {
            purgeSessionDirectory(sessionId: sessionId)
            return []
        }
        
        for file in files {
            let baseName = file.deletingPathExtension().lastPathComponent
            let ext = file.pathExtension
            var moved = false
            for counter in 0...9999 {
                let candidateName: String
                if counter == 0 {
                    candidateName = file.lastPathComponent
                } else if ext.isEmpty {
                    candidateName = "\(baseName) (\(counter))"
                } else {
                    candidateName = "\(baseName) (\(counter)).\(ext)"
                }
                let destURL = baseDir.appendingPathComponent(candidateName)
                if !fm.fileExists(atPath: destURL.path) {
                    do {
                        try fm.moveItem(at: file, to: destURL)
                        LocalShareFileManager.applyQuarantineAttribute(to: destURL)
                        promotedURLs.append(destURL)
                        moved = true
                        break
                    } catch {
                        continue
                    }
                }
            }
            if !moved {
                promotedURLs.append(file)
            }
        }
        
        try? fm.removeItem(at: sessionDirectory)
        return promotedURLs
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
    
    /// Checks if macOS quarantine attribute is present on the file.
    public static func hasQuarantineAttribute(at url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { fsPath in
            guard let fsPath = fsPath else { return false }
            return getxattr(fsPath, "com.apple.quarantine", nil, 0, 0, 0) >= 0
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
        
        let parentDirURL = destinationURL.deletingLastPathComponent().standardizedFileURL
        let fileName = destinationURL.lastPathComponent
        
        // Guard against path traversal in leaf component
        guard !fileName.isEmpty, fileName != ".", fileName != "..", !fileName.contains("/") else {
            throw LocalShareError.invalidFileName
        }
        
        var fd: Int32 = -1
        let errCode = parentDirURL.withUnsafeFileSystemRepresentation { dirPath -> Int32 in
            guard let dirPath = dirPath else { return EINVAL }
            // Open parent directory descriptor with O_RDONLY | O_DIRECTORY | O_CLOEXEC
            let dirFd = open(dirPath, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
            guard dirFd >= 0 else { return errno }
            defer { close(dirFd) }
            
            // Verify directory integrity with fstat
            var st = stat()
            guard fstat(dirFd, &st) == 0 else { return errno }
            guard (st.st_mode & S_IFMT) == S_IFDIR else { return ENOTDIR }
            
            // openat: relative to trusted directory descriptor
            // O_WRONLY: Write only
            // O_CREAT: Create file if missing
            // O_EXCL: Fail atomically with EEXIST if file already exists
            // O_NOFOLLOW: Fail with ELOOP if the leaf is a symlink
            // O_CLOEXEC: Do not leak FD across exec
            // 0o600: POSIX owner read/write only
            fd = openat(dirFd, fileName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            return fd >= 0 ? 0 : errno
        }
        
        if errCode != 0 || fd < 0 {
            if errCode == EEXIST || errCode == ELOOP {
                throw LocalShareError.fileExists
            }
            throw LocalShareError.serverError("Unable to initialize destination file on disk (errno \(errCode))")
        }
        
        self.fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
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
        
        try fileHandle.synchronize()
        try fileHandle.close()
        
        // 1. Verify byte size
        if bytesWritten != expectedSize {
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
