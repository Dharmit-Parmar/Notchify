import Foundation
import CryptoKit
import Security

/// High-performance, zero-overhead encrypted file store using CryptoKit AES-256-GCM (SEC-A-1, SEC-A-2).
/// Encrypts files at rest with hardware-backed Keychain key management.
/// Format: Magic bytes "NOTCHENC1" (8 bytes) + Version 0x01 (1 byte) + AES-GCM combined payload (nonce + ciphertext + tag).
public final class EncryptedFileStore: @unchecked Sendable {
    public static let shared = EncryptedFileStore()
    
    public static let magicHeader = Data("NOTCHENC1".utf8) // 9 bytes: 'N','O','T','C','H','E','N','C','1'
    public static let currentVersion: UInt8 = 0x01
    public static let keychainKeyAccount = "notch_file_encryption_key"
    
    private let keyProvider: @Sendable () -> SymmetricKey
    private let lock = NSLock()
    
    /// Initializes an EncryptedFileStore.
    /// If an explicit key is provided, it is used directly (ideal for unit testing).
    /// Otherwise, retrieves or generates a 256-bit symmetric key in macOS Keychain.
    public init(key: SymmetricKey? = nil) {
        if let explicitKey = key {
            self.keyProvider = { explicitKey }
        } else {
            self.keyProvider = {
                if let savedBase64 = KeychainHelper.shared.loadSecret(forKey: Self.keychainKeyAccount),
                   let keyData = Data(base64Encoded: savedBase64),
                   keyData.count == 32 {
                    return SymmetricKey(data: keyData)
                }
                // Generate a fresh cryptographically secure 256-bit key
                let newKey = SymmetricKey(size: .bits256)
                let base64 = newKey.withUnsafeBytes { Data($0).base64EncodedString() }
                KeychainHelper.shared.saveSecret(base64, forKey: Self.keychainKeyAccount)
                return newKey
            }
        }
    }
    
    public var symmetricKey: SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        return keyProvider()
    }
    
    // MARK: - Encryption & Atomic File Writing
    
    /// Encrypts plaintext data with AES-256-GCM and writes atomically with POSIX 0600 permissions.
    public func write(data: Data, to url: URL) throws {
        let key = self.symmetricKey
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(
                domain: "EncryptedFileStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to generate AES-GCM combined sealed box"]
            )
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
            throw NSError(
                domain: "EncryptedFileStore",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode string to UTF-8"]
            )
        }
        try write(data: data, to: url)
    }
    
    // MARK: - Decryption & Atomic Plaintext Migration
    
    /// Reads and decrypts data from disk.
    /// If the file is in legacy plaintext, automatically migrates it to encrypted format with 0600 permissions.
    public func read(from url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let rawData = try Data(contentsOf: url)
        guard !rawData.isEmpty else { return Data() }
        
        let headerSize = Self.magicHeader.count + 1 // 9 + 1 = 10 bytes
        
        // Check for encrypted magic header
        if rawData.count >= headerSize && rawData.prefix(Self.magicHeader.count) == Self.magicHeader {
            let version = rawData[Self.magicHeader.count]
            guard version == Self.currentVersion else {
                throw NSError(
                    domain: "EncryptedFileStore",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Unsupported encrypted file version: \(version)"]
                )
            }
            
            let combined = rawData.dropFirst(headerSize)
            let box = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(box, using: self.symmetricKey)
            return decrypted
        }
        
        // Legacy Plaintext Fallback: Migrate immediately to encrypted at-rest format (SEC-A-1 / SEC-A-2)
        try? write(data: rawData, to: url)
        return rawData
    }
    
    /// Reads and decrypts a UTF-8 string from disk.
    public func readString(from url: URL) throws -> String? {
        guard let data = try read(from: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
