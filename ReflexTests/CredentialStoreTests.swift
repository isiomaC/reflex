import Testing
@testable import Reflex

struct CredentialStoreTests {
    @Test func inMemoryStoreSavesLoadsAndRemovesAnAPIKey() throws {
        let store = InMemoryCredentialStore()

        try store.save("jev_test_key")
        #expect(try store.load() == "jev_test_key")

        try store.remove()
        #expect(try store.load() == nil)
    }
}
