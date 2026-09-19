import Testing
import Security
@testable import Reflex

struct CredentialStoreTests {
    @Test func inMemoryStoreSavesLoadsAndRemovesAnAPIKey() throws {
        let store = InMemoryCredentialStore()

        try store.save("jev_test_key")
        #expect(try store.load() == "jev_test_key")

        try store.remove()
        #expect(try store.load() == nil)
    }

    @Test func keychainStoreUsesDeviceOnlyWhenUnlockedAccessibility() {
        #expect(KeychainCredentialStore.accessibility == kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    }

    @Test func keychainStoreMigratesExistingCredentialAccessibilityDuringSave() throws {
        var receivedUpdateAttributes: [String: Any]?
        let store = KeychainCredentialStore(
            updateItem: { _, attributes in
                receivedUpdateAttributes = attributes as? [String: Any]
                return errSecSuccess
            }
        )

        try store.save("jev_test_key")

        #expect(
            receivedUpdateAttributes?[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
    }
}
