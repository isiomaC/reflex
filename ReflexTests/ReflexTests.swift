import Testing
@testable import Reflex

struct ReflexTests {
    @MainActor
    @Test func defaultsToMockProviderMode() {
        #expect(AppModel().providerMode == .mock)
    }
}
