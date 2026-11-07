import Foundation
import Security
import CryptoKit
import LocalAuthentication

// MARK: - KeychainHelper: Native Apple Keychain Secure Secret Vault
/// Provides native macOS Keychain Services (`kSecClassGenericPassword`) for secure storage
/// of credentials (API keys, bot tokens) protected by macOS Secure Enclave and login keychain.
public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()
    
    public let serviceName: String
    private let lock = NSLock()
    
    private func nonInteractiveContext() -> LAContext {
        let ctx = LAContext()
        ctx.interactionNotAllowed = true
        return ctx
    }
    
    public init(serviceName: String = "com.notch.NotchApp") {
        self.serviceName = serviceName
        migrateLegacyVaultIfNeeded()
    }
    
    // MARK: - Public Secret Storage API
    
    /// Securely saves a secret using native macOS Keychain Services.
    @discardableResult
    public func saveSecret(_ secret: String, forKey account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return saveSecretLocked(secret, forKey: account)
    }
    
    private func saveSecretLocked(_ secret: String, forKey account: String) -> Bool {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return deleteSecretLocked(forKey: account)
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationContext as String: nonInteractiveContext()
        ]
        SecItemDelete(query as CFDictionary)
        
        var newQuery = query
        newQuery[kSecValueData as String] = Data(trimmed.utf8)
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        
        let status = SecItemAdd(newQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Securely retrieves and decrypts a secret from the native macOS Keychain.
    public func loadSecret(forKey account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: nonInteractiveContext()
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    /// Securely deletes a secret from the native macOS Keychain.
    @discardableResult
    public func deleteSecret(forKey account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return deleteSecretLocked(forKey: account)
    }
    
    private func deleteSecretLocked(forKey account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationContext as String: nonInteractiveContext()
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Returns a masked display version of a key (e.g., "AIzaSy••••••••1823") to prevent shoulder surfing.
    public static func maskKey(_ key: String) -> String {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > 8 else {
            return clean.isEmpty ? "" : "••••••••"
        }
        let prefix = clean.prefix(6)
        let suffix = clean.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }
    
    // MARK: - Legacy Vault Migration
    
    private func migrateLegacyVaultIfNeeded() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let vaultURL = appSupport.appendingPathComponent("NotchApp/vault.enc")
        guard FileManager.default.fileExists(atPath: vaultURL.path),
              let encryptedData = try? Data(contentsOf: vaultURL), !encryptedData.isEmpty else { return }
        
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        let uuid: String = {
            guard platformExpert != 0 else { return "NOTCH_FALLBACK_UUID_LOCAL" }
            defer { IOObjectRelease(platformExpert) }
            if let prop = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) {
                return (prop.takeRetainedValue() as? String) ?? "NOTCH_FALLBACK_UUID_LOCAL"
            }
            return "NOTCH_FALLBACK_UUID_LOCAL"
        }()
        let seed = "\(uuid):\(NSUserName()):com.notch.NotchApp.vault.salt.v2.com.notch.NotchApp.secrets"
        let legacyKey = SymmetricKey(data: SHA256.hash(data: Data(seed.utf8)))
        
        if let box = try? AES.GCM.SealedBox(combined: encryptedData),
           let decrypted = try? AES.GCM.open(box, using: legacyKey),
           let dict = try? JSONDecoder().decode([String: String].self, from: decrypted) {
            for (acc, secret) in dict {
                _ = saveSecretLocked(secret, forKey: acc)
            }
        }
        try? FileManager.default.removeItem(at: vaultURL)
    }
}
