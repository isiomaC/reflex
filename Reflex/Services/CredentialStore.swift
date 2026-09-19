import Foundation
import Security

protocol CredentialStore {
    func save(_ apiKey: String) throws
    func load() throws -> String?
    func remove() throws
}

enum CredentialStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidStoredValue
}

final class KeychainCredentialStore: CredentialStore {
    private let service: String
    private let account: String

    init(service: String = "com.isiomac.Reflex", account: String = "jev-api-key") {
        self.service = service
        self.account = account
    }

    func save(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let query = baseQuery()
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(updateStatus)
        }

        var attributes = query
        attributes[kSecValueData as String] = data
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    func load() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data, let apiKey = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.invalidStoredValue
        }
        return apiKey
    }

    func remove() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class InMemoryCredentialStore: CredentialStore {
    private var apiKey: String?

    func save(_ apiKey: String) throws {
        self.apiKey = apiKey
    }

    func load() throws -> String? {
        apiKey
    }

    func remove() throws {
        apiKey = nil
    }
}
