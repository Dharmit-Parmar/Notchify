import Foundation
import CoreFoundation
import Security
import CryptoKit
import LocalAuthentication
import IOKit

// MARK: - KeychainManaging Protocol

/// Abstraction for Keychain secret management.
///
/// The synchronous requirements are intentionally retained so existing
/// call sites and dependency-injection code do not need to change.
public protocol KeychainManaging: Sendable {
    func loadSecret(forKey account: String) -> String?

    @discardableResult
    func saveSecret(_ secret: String, forKey account: String) -> Bool

    @discardableResult
    func deleteSecret(forKey account: String) -> Bool
}

// MARK: - KeychainHelper

/// Stores application secrets using the macOS Keychain Services API.
///
/// Generic-password items are stored in the user's Keychain using
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. This accessibility
/// class does not make a generic-password item a Secure Enclave item.
///
/// The class serializes Keychain operations because it is shared by multiple
/// modules and may be called from different executors.
public final class KeychainHelper: KeychainManaging, @unchecked Sendable {

    public static let shared = KeychainHelper()

    public let serviceName: String

    private let lock = NSLock()

    // Each account has at most one scheduled debounced save.
    // Tokens prevent an already-awakened, cancelled task from saving stale data.
    private var pendingSaveTasks: [String: Task<Void, Never>] = [:]
    private var pendingSaveTokens: [String: UUID] = [:]

    private static let defaultDebounceDelay: TimeInterval = 0.50
    private static let maximumDebounceDelay: TimeInterval = 300

    // MARK: Initialization

    public init(serviceName: String = "com.notch.NotchApp") {
        self.serviceName = serviceName
        _ = migrateLegacyVaultIfNeeded()
    }

    // MARK: Authentication Context

    /// Prevents Keychain Services from presenting an unexpected authentication
    /// prompt. Items requiring interactive authentication will fail closed.
    private func nonInteractiveContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }

    // MARK: Public Secret Storage API

    /// Saves a secret synchronously and verifies that the saved value can be read.
    @discardableResult
    public func saveSecret(_ secret: String, forKey account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // A pending debounced save must not overwrite this newer synchronous save.
        cancelPendingSaveLocked(forKey: account)
        return saveSecretLocked(secret, forKey: account)
    }

    /// Schedules a debounced save away from the calling thread.
    ///
    /// A newer scheduled save, synchronous save, or delete for the same account
    /// invalidates the previous task so that stale text cannot overwrite newer data.
    public func saveSecretAsync(
        _ secret: String,
        forKey account: String,
        debounceDelay: TimeInterval = 0.50
    ) {
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = UUID()
        let delay = Self.sanitizedDebounceDelay(debounceDelay)
        let nanoseconds = UInt64(delay * 1_000_000_000)

        lock.lock()

        cancelPendingSaveLocked(forKey: account)
        pendingSaveTokens[account] = token

        let task = Task.detached(priority: .utility) { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.performDebouncedSave(
                trimmedSecret,
                forKey: account,
                token: token
            )
        }

        pendingSaveTasks[account] = task
        lock.unlock()
    }

    private static func sanitizedDebounceDelay(_ delay: TimeInterval) -> TimeInterval {
        guard delay.isFinite else {
            return defaultDebounceDelay
        }

        return min(max(delay, 0), maximumDebounceDelay)
    }

    /// Commits a scheduled save only if it is still the newest request for the account.
    private func performDebouncedSave(
        _ secret: String,
        forKey account: String,
        token: UUID
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard pendingSaveTokens[account] == token else {
            return
        }

        pendingSaveTokens.removeValue(forKey: account)
        pendingSaveTasks.removeValue(forKey: account)
        _ = saveSecretLocked(secret, forKey: account)
    }

    /// Must be called while `lock` is held.
    private func cancelPendingSaveLocked(forKey account: String) {
        pendingSaveTasks[account]?.cancel()
        pendingSaveTasks.removeValue(forKey: account)
        pendingSaveTokens.removeValue(forKey: account)
    }

    /// Must be called while `lock` is held.
    private func saveSecretLocked(_ secret: String, forKey account: String) -> Bool {
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !account.isEmpty else {
            return false
        }

        if trimmedSecret.isEmpty {
            return deleteSecretLocked(forKey: account)
        }

        let secretData = Data(trimmedSecret.utf8)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationContext as String: nonInteractiveContext()
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var status = SecItemUpdate(
            baseQuery as CFDictionary,
            attributesToUpdate as CFDictionary
        )

        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = secretData
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            status = SecItemAdd(addQuery as CFDictionary, nil)

            // Another process may have inserted the same item between update and add.
            if status == errSecDuplicateItem {
                status = SecItemUpdate(
                    baseQuery as CFDictionary,
                    attributesToUpdate as CFDictionary
                )
            }
        }

        guard status == errSecSuccess else {
            return false
        }

        // Read-back verification uses the locked helper to avoid recursively locking NSLock.
        return loadSecretLocked(forKey: account) == trimmedSecret
    }

    /// Loads a secret from Keychain without presenting an authentication prompt.
    public func loadSecret(forKey account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard !account.isEmpty else { return nil }
        return loadSecretLocked(forKey: account)
    }

    /// Must be called while `lock` is held.
    private func loadSecretLocked(forKey account: String) -> String? {
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

        guard status == errSecSuccess,
              let data = item as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            return nil
        }

        return secret
    }

    /// Deletes a secret. Deleting a missing item is treated as success.
    @discardableResult
    public func deleteSecret(forKey account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !account.isEmpty else { return false }

        // Do not allow a pending debounced save to recreate a deleted secret.
        cancelPendingSaveLocked(forKey: account)
        return deleteSecretLocked(forKey: account)
    }

    /// Must be called while `lock` is held.
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

    // MARK: Secret Masking

    /// Returns a masked display value without exposing overlapping prefix/suffix characters.
    public static func maskKey(_ key: String) -> String {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else { return "" }

        // Six prefix characters plus four suffix characters must not overlap.
        guard clean.count > 10 else {
            return "••••••••"
        }

        let prefix = clean.prefix(6)
        let suffix = clean.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }

    // MARK: - Legacy Vault Migration

    /// Migrates the legacy encrypted vault into Keychain.
    ///
    /// The legacy file is retained unless every secret has been saved and verified.
    /// If a migration is interrupted after some Keychain writes, retrying is safe:
    /// the same account values are updated rather than duplicated.
    @discardableResult
    public func migrateLegacyVaultIfNeeded(at customURL: URL? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let candidateURLs: [URL] = {
            if let customURL {
                return [customURL]
            }

            guard let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                return []
            }

            return [
                appSupport.appendingPathComponent("NotchApp/vault.enc"),
                appSupport.appendingPathComponent("Notch/vault.enc")
            ]
        }()

        var anyMigrated = false

        for vaultURL in candidateURLs {
            guard FileManager.default.fileExists(atPath: vaultURL.path),
                  let encryptedData = try? Data(contentsOf: vaultURL),
                  !encryptedData.isEmpty else {
                continue
            }

            let legacyKey = legacyVaultKey()
            guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData),
                  let decryptedData = try? AES.GCM.open(sealedBox, using: legacyKey),
                  let secrets = try? JSONDecoder().decode(
                    [String: String].self,
                    from: decryptedData
                  ) else {
                // Preserve the legacy vault if the key, ciphertext, or payload is invalid.
                continue
            }

            var allSucceeded = true

            for (account, secret) in secrets {
                guard !account.isEmpty else {
                    allSucceeded = false
                    break
                }

                // A migration value supersedes any older pending UI debounce for this account.
                cancelPendingSaveLocked(forKey: account)

                if !saveSecretLocked(secret, forKey: account) {
                    allSucceeded = false
                    break
                }
            }

            guard allSucceeded else {
                // Keep the source file so a later launch can retry the migration.
                continue
            }

            do {
                // Remove the encrypted source only after every destination item has
                // been read back and verified. Avoid claiming that overwriting an
                // APFS/SSD file securely erases all underlying storage blocks.
                try FileManager.default.removeItem(at: vaultURL)
                anyMigrated = true
            } catch {
                // The original encrypted vault remains available for a later retry.
                continue
            }
        }

        return anyMigrated
    }

    /// Reconstructs the legacy vault key using the original derivation inputs.
    /// This must remain compatible with the previous vault implementation.
    private func legacyVaultKey() -> SymmetricKey {
        // Keep the original key derivation inputs unchanged so existing vaults remain
        // decryptable. The fallback UUID is intentionally retained for compatibility.
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        let machineUUID: String = {
            guard platformExpert != 0 else {
                return "NOTCH_FALLBACK_UUID_LOCAL"
            }

            defer { IOObjectRelease(platformExpert) }

            guard let property = IORegistryEntryCreateCFProperty(
                platformExpert,
                "IOPlatformUUID" as CFString,
                kCFAllocatorDefault,
                0
            ) else {
                return "NOTCH_FALLBACK_UUID_LOCAL"
            }

            return property.takeRetainedValue() as? String
                ?? "NOTCH_FALLBACK_UUID_LOCAL"
        }()

        let seed = "\(machineUUID):\(NSUserName()):com.notch.NotchApp.vault.salt.v2.com.notch.NotchApp.secrets"
        let digest = SHA256.hash(data: Data(seed.utf8))
        return SymmetricKey(data: Data(digest))
    }
}
