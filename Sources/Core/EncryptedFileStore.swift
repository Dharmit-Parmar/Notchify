import Foundation
import CryptoKit
import Security

// MARK: - EncryptedFileStoreError
/// Strongly-typed error domain for EncryptedFileStore operations.
public enum EncryptedFileStoreError: Error, LocalizedError, Equatable {
    case keyMissing
    case keychainSaveFailed
    case verificationFailed
    case corruptedData
    case unsupportedVersion(UInt8)
    case invalidEncoding
    
    public var errorDescription: String? {
        switch self {
        case .keyMissing:
            return "Encryption key is missing from Keychain for an existing ciphertext file"
        case .keychainSaveFailed:
            return "Failed to securely save encryption key to Keychain"
        case .verificationFailed:
            return "Integrity check failed: decrypted ciphertext does not match original data"
        case .corruptedData:
            return "Corrupted encrypted data or authentication tag mismatch"
        case .unsupportedVersion(let v):
            return "Unsupported encrypted file version: \(v)"
        case .invalidEncoding:
            return "Failed to encode/decode string"
        }
    }
}

// MARK: - EncryptedFileStore
/// High-performance, zero-overhead encrypted file store using CryptoKit AES-256-GCM (SEC-A-1, SEC-A-2).
/// Encrypts files at rest with hardware-backed Keychain key management and in-memory key caching.
/// Format: Magic bytes "NOTCHENC1" (9 bytes) + Version 0x01 (1 byte) + AES-GCM combined payload (nonce + ciphertext + tag).
public final class EncryptedFileStore: @unchecked Sendable {
    public static let shared = EncryptedFileStore()
    
    public static let magicHeader = Data("NOTCHENC1".utf8) // 9 bytes: 'N','O','T','C','H','E','N','C','1'
    public static let currentVersion: UInt8 = 0x01
    public static let keychainKeyAccount = "notch_file_encryption_key"
    
    public typealias KeyProvider = @Sendable (URL?) throws -> SymmetricKey
    
    private let keyProvider: KeyProvider?
    private let keychain: KeychainManaging
    private let managedDirectoryURL: URL?
    private let lock = NSLock()
    private var cachedKey: SymmetricKey?
    
    /// Optional testing hook to intercept and mutate encrypted packets during migration verification.
    public var migrationVerificationHook: (@Sendable (Data) -> Data)?
    
    /// Initializes an EncryptedFileStore.
    /// - Parameters:
    ///   - key: Optional explicit key (used directly, ideal for testing).
    ///   - keychain: KeychainManaging implementation (defaults to `KeychainHelper.shared`).
    ///   - managedDirectoryURL: Optional directory containing managed ciphertext files (defaults to `~/Library/Application Support/NotchApp`).
    ///   - keyProvider: Optional custom key provider closure.
    public init(
        key: SymmetricKey? = nil,
        keychain: KeychainManaging = KeychainHelper.shared,
        managedDirectoryURL: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("NotchApp"),
        keyProvider: KeyProvider? = nil
    ) {
        self.keychain = keychain
        self.managedDirectoryURL = managedDirectoryURL
        if let explicitKey = key {
            self.cachedKey = explicitKey
            self.keyProvider = { _ in explicitKey }
        } else if let customProvider = keyProvider {
            self.keyProvider = customProvider
        } else {
            self.keyProvider = nil
        }
    }
    
    // MARK: - Key Management & In-Memory Caching (Invariants 1, 2, 3)
    
    /// Returns the cached symmetric key, or resolves it from Keychain.
    /// Invariant 1: NEVER creates a key if a target ciphertext file exists. Throws `keyMissing` instead.
    /// Invariant 2: Creates a key ONLY when no encrypted file exists, and verifies `saveSecret` succeeded; if failed, throws `keychainSaveFailed`.
    /// Invariant 3: Caches the key in memory after the first load (zero Keychain IPC overhead per save).
    public func getKey(for targetURL: URL? = nil) throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        
        // Invariant 3: Cache the key in memory after first load
        if let cached = cachedKey {
            return cached
        }
        
        // If an explicit keyProvider was injected, invoke it
        if let provider = self.keyProvider {
            let key = try provider(targetURL)
            self.cachedKey = key
            return key
        }
        
        // Try loading existing secret from Keychain
        if let savedBase64 = keychain.loadSecret(forKey: Self.keychainKeyAccount),
           let keyData = Data(base64Encoded: savedBase64),
           keyData.count == 32 {
            let loadedKey = SymmetricKey(data: keyData)
            self.cachedKey = loadedKey
            return loadedKey
        }
        
        // Key is missing from Keychain.
        // Invariant 1: keyProvider must NEVER create a key if the target ciphertext file exists.
        let targetIsCiphertext = targetURL.map { Self.isCiphertextFile(at: $0) } ?? false
        let managedDirCiphertextExists = hasCiphertextInManagedDirectory(excluding: targetURL)
        
        if targetIsCiphertext || managedDirCiphertextExists {
            throw EncryptedFileStoreError.keyMissing
        }
        
        // Invariant 2: Create a key only when no encrypted file exists.
        // Check that saveSecret succeeded; if it failed, throw and write nothing.
        let newKey = SymmetricKey(size: .bits256)
        let base64 = newKey.withUnsafeBytes { Data($0).base64EncodedString() }
        let saved = keychain.saveSecret(base64, forKey: Self.keychainKeyAccount)
        guard saved else {
            throw EncryptedFileStoreError.keychainSaveFailed
        }
        
        self.cachedKey = newKey
        return newKey
    }
    
    /// Clears the in-memory key cache (for unit testing lifecycle transitions).
    public func clearMemoryCacheForTesting() {
        lock.lock()
        defer { lock.unlock() }
        cachedKey = nil
    }
    
    /// Synchronous convenience accessor for symmetric key.
    public var symmetricKey: SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedKey {
            return cached
        }
        if let key = try? getKey(for: nil) {
            return key
        }
        fatalError("EncryptedFileStore.symmetricKey accessed when key could not be resolved. Use getKey(for:) throws instead.")
    }
    
    // MARK: - Ciphertext Detection
    
    /// Inspects the file header to determine whether the file is an encrypted NOTCHENC1 file.
    public static func isCiphertextFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: magicHeader.count) else { return false }
        return prefix == magicHeader
    }
    
    private func hasCiphertextInManagedDirectory(excluding targetURL: URL?) -> Bool {
        guard let dir = managedDirectoryURL, FileManager.default.fileExists(atPath: dir.path) else {
            return false
        }
        let candidates = [
            dir.appendingPathComponent("notes.txt"),
            dir.appendingPathComponent("contacts.json")
        ]
        for candidate in candidates {
            if let target = targetURL, candidate.standardizedFileURL == target.standardizedFileURL {
                continue
            }
            if Self.isCiphertextFile(at: candidate) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Encryption & Atomic File Writing
    
    /// Encrypts plaintext data with AES-256-GCM and writes atomically with POSIX 0600 permissions.
    public func write(data: Data, to url: URL) throws {
        let key = try getKey(for: url)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptedFileStoreError.corruptedData
        }
        
        var packet = Data()
        packet.append(Self.magicHeader)
        packet.append(Self.currentVersion)
        packet.append(combined)
        
        // Ensure parent directory exists with 0700 permissions
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        
        // Atomic write: writes to temporary file and renames to prevent partial corruption
        try packet.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    
    /// Encrypts and writes a string to disk atomically.
    public func writeString(_ string: String, to url: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw EncryptedFileStoreError.invalidEncoding
        }
        try write(data: data, to: url)
    }
    
    // MARK: - Decryption & Atomic Plaintext Migration
    
    /// Reads and decrypts data from disk.
    /// If the file is in legacy plaintext, automatically migrates it to encrypted format with two-phase verification.
    public func read(from url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let rawData = try Data(contentsOf: url)
        guard !rawData.isEmpty else { return Data() }
        
        let headerSize = Self.magicHeader.count + 1 // 9 + 1 = 10 bytes
        
        // Check for encrypted magic header
        if rawData.count >= headerSize && rawData.prefix(Self.magicHeader.count) == Self.magicHeader {
            let version = rawData[Self.magicHeader.count]
            guard version == Self.currentVersion else {
                throw EncryptedFileStoreError.unsupportedVersion(version)
            }
            
            let combined = rawData.dropFirst(headerSize)
            do {
                let box = try AES.GCM.SealedBox(combined: combined)
                let key = try getKey(for: url)
                let decrypted = try AES.GCM.open(box, using: key)
                return decrypted
            } catch let error as EncryptedFileStoreError {
                throw error
            } catch {
                throw EncryptedFileStoreError.corruptedData
            }
        }
        
        // Legacy Plaintext Fallback: Migrate with round-trip verification (Invariant 4)
        do {
            try migratePlaintextFile(at: url, plaintext: rawData)
        } catch {
            // On any error keep the original file untouched on disk
        }
        return rawData
    }
    
    /// Reads and decrypts a UTF-8 string from disk.
    public func readString(from url: URL) throws -> String? {
        guard let data = try read(from: url) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncryptedFileStoreError.invalidEncoding
        }
        return string
    }
    
    // MARK: - Plaintext Migration Verification (Invariant 4)
    
    /// In plaintext migration: write encrypted, decrypt it again and compare to original, only then replace.
    /// On any error keep the original file untouched.
    public func migratePlaintextFile(at url: URL, plaintext: Data) throws {
        let key = try getKey(for: url)
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptedFileStoreError.corruptedData
        }
        
        var packet = Data()
        packet.append(Self.magicHeader)
        packet.append(Self.currentVersion)
        packet.append(combined)
        
        if let hook = migrationVerificationHook {
            packet = hook(packet)
        }
        
        // In-memory round trip verification
        let headerSize = Self.magicHeader.count + 1
        guard packet.count >= headerSize,
              packet.prefix(Self.magicHeader.count) == Self.magicHeader else {
            throw EncryptedFileStoreError.verificationFailed
        }
        let inMemoryCombined = packet.dropFirst(headerSize)
        do {
            let inMemoryBox = try AES.GCM.SealedBox(combined: inMemoryCombined)
            let inMemoryDecrypted = try AES.GCM.open(inMemoryBox, using: key)
            guard inMemoryDecrypted == plaintext else {
                throw EncryptedFileStoreError.verificationFailed
            }
        } catch {
            throw EncryptedFileStoreError.verificationFailed
        }
        
        // Two-phase staging: write to a sidecar temp file in the same directory
        let tempURL = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).migration_\(UUID().uuidString).tmp")
        do {
            try packet.write(to: tempURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)
            
            // Read back temp file from disk and verify
            let diskTempData = try Data(contentsOf: tempURL)
            guard diskTempData.count >= headerSize,
                  diskTempData.prefix(Self.magicHeader.count) == Self.magicHeader else {
                throw EncryptedFileStoreError.verificationFailed
            }
            let diskCombined = diskTempData.dropFirst(headerSize)
            let diskBox = try AES.GCM.SealedBox(combined: diskCombined)
            let diskDecrypted = try AES.GCM.open(diskBox, using: key)
            guard diskDecrypted == plaintext else {
                throw EncryptedFileStoreError.verificationFailed
            }
            
            // Verification succeeded: atomically replace original file
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL, backupItemName: nil, options: [])
        } catch {
            // Invariant 4: On any error keep the original file untouched
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
}
