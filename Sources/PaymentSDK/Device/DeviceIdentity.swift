import Foundation
import Security
import UIKit

/// Where the device ID is persisted.
protocol DeviceIDStore {
    func read() -> String?
    /// Returns `false` when the value could not be saved.
    @discardableResult func write(_ value: String) -> Bool
}

struct KeychainDeviceIDStore: DeviceIDStore {
    var service = "com.paymentsdk.device"
    var account = "DeviceID"

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }

    @discardableResult
    func write(_ value: String) -> Bool {
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }

        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}

struct UserDefaultsDeviceIDStore: DeviceIDStore {
    var defaults: UserDefaults = .standard
    var key = "com.paymentsdk.deviceID"

    func read() -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }

    @discardableResult
    func write(_ value: String) -> Bool {
        defaults.set(value, forKey: key)
        return true
    }
}

/// Resolves a stable device ID: the first value seen is persisted (Keychain, falling back to
/// UserDefaults) and reused, so it survives IDFV changes after a reinstall.
final class DeviceIdentity {
    private let primary: DeviceIDStore
    private let fallback: DeviceIDStore
    private let vendorID: () -> String?
    private var cached: String?
    private let lock = NSLock()

    init(primary: DeviceIDStore = KeychainDeviceIDStore(),
         fallback: DeviceIDStore = UserDefaultsDeviceIDStore(),
         vendorID: @escaping () -> String? = { DeviceIdentity.currentVendorID() }) {
        self.primary = primary
        self.fallback = fallback
        self.vendorID = vendorID
    }

    var deviceID: String {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let value = resolve()
        cached = value
        return value
    }

    private func resolve() -> String {
        if let stored = primary.read() { return stored }
        if let stored = fallback.read() {
            // Keychain failed earlier; move the value there if it works now.
            primary.write(stored)
            return stored
        }
        let fresh = (vendorID()?.nonEmptyTrimmed ?? UUID().uuidString).uppercased()
        if !primary.write(fresh) {
            fallback.write(fresh)
        }
        return fresh
    }

    static func currentVendorID() -> String? {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { UIDevice.current.identifierForVendor?.uuidString }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { UIDevice.current.identifierForVendor?.uuidString }
        }
    }
}
