import Foundation
import Security

protocol SecureValueStoring: Sendable {
    func data(for key: String) throws -> Data?
    func set(_ data: Data, for key: String) throws
}

struct KeychainStore: SecureValueStoring {
    let service: String

    func data(for key: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw SecureStorageError.status(status) }
        return data
    }

    func set(_ data: Data, for key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query; attributes.forEach { newItem[$0.key] = $0.value }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw SecureStorageError.status(addStatus) }
        } else if status != errSecSuccess { throw SecureStorageError.status(status) }
    }
}

enum SecureStorageError: Error { case status(OSStatus), invalidValue }

struct InstallationIdentityStore: Sendable {
    let storage: SecureValueStoring
    private let key = "installation-id-v1"

    func identifier() throws -> String {
        if let data = try storage.data(for: key), let value = String(data: data, encoding: .utf8), UUID(uuidString: value) != nil { return value }
        let value = UUID().uuidString
        try storage.set(Data(value.utf8), for: key)
        return value
    }
}

struct RefreshCredentialStore: Sendable {
    let storage: SecureValueStoring
    private let key = "refresh-credential-v1"
    func credential() throws -> String? { try storage.data(for: key).flatMap { String(data: $0, encoding: .utf8) } }
    func save(_ value: String) throws { try storage.set(Data(value.utf8), for: key) }
}
