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
                return try LocalShareFileStreamWriter(destinationURL: candidateURL, trustedRootURL: sessionDirectory)
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
    
    public init(destinationURL: URL, trustedRootURL: URL? = nil) throws {
        self.destinationURL = destinationURL
        
        let rootURL = (trustedRootURL ?? destinationURL.deletingLastPathComponent()).standardizedFileURL
        let targetURL = destinationURL.standardizedFileURL
        
        let rootPath = rootURL.path
        let targetPath = targetURL.path
        
        // Strict containment check: destination must reside within trusted root
        guard targetPath.hasPrefix(rootPath) else {
            throw LocalShareError.invalidURL
        }
        
        // Extract relative path components beneath trusted root
        let relPath = String(targetPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = relPath.components(separatedBy: "/").filter { !$0.isEmpty }
        guard !components.isEmpty else {
            throw LocalShareError.invalidFileName
        }
        
        // Validate each component against directory traversal, slashes, nulls, and control characters
        for comp in components {
            guard !comp.isEmpty,
                  comp != ".",
                  comp != "..",
                  !comp.contains("/"),
                  !comp.contains("\0") else {
                throw LocalShareError.invalidFileName
            }
        }
        
        let leafName = components.last!
        let intermediateDirs = components.dropLast()
        
        // 1. Establish trusted root directory descriptor
        var rootFd: Int32 = -1
        let rootOpenErr = rootURL.withUnsafeFileSystemRepresentation { pathPtr -> Int32 in
            guard let pathPtr = pathPtr else { return EINVAL }
            rootFd = open(pathPtr, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            return rootFd >= 0 ? 0 : errno
        }
        
        guard rootOpenErr == 0, rootFd >= 0 else {
            throw LocalShareError.serverError("Unable to open trusted root directory (errno \(rootOpenErr))")
        }
        
        var intermediateFdsToClose: [Int32] = [rootFd]
        defer {
            for fd in intermediateFdsToClose {
                close(fd)
            }
        }
        
        // 2. Verify trusted root descriptor with fstat
        var rootStat = stat()
        guard fstat(rootFd, &rootStat) == 0,
              (rootStat.st_mode & S_IFMT) == S_IFDIR,
              rootStat.st_uid == getuid() else {
            throw LocalShareError.serverError("Trusted root directory validation failed (invalid directory or ownership)")
        }
        
        // 3. Walk intermediate directory components relative to descriptor
        var currentDirFd = rootFd
        for dirName in intermediateDirs {
            let nextDirFd = openat(currentDirFd, dirName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard nextDirFd >= 0 else {
                let err = errno
                if err == ELOOP {
                    throw LocalShareError.fileExists
                }
                throw LocalShareError.serverError("Intermediate directory '\(dirName)' access failed (errno \(err))")
            }
            intermediateFdsToClose.append(nextDirFd)
            
            var dirStat = stat()
            guard fstat(nextDirFd, &dirStat) == 0,
                  (dirStat.st_mode & S_IFMT) == S_IFDIR,
                  dirStat.st_uid == getuid() else {
                throw LocalShareError.serverError("Intermediate directory '\(dirName)' verification failed")
            }
            currentDirFd = nextDirFd
        }
        
        // 4. Create leaf file atomically relative to verified parent directory descriptor
        let leafFd = openat(currentDirFd, leafName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard leafFd >= 0 else {
            let err = errno
            if err == EEXIST || err == ELOOP {
                throw LocalShareError.fileExists
            }
            throw LocalShareError.serverError("Unable to initialize destination file '\(leafName)' on disk (errno \(err))")
        }
        
        self.fileHandle = FileHandle(fileDescriptor: leafFd, closeOnDealloc: true)
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
