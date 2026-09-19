import Testing
@testable import Reflex

struct ReflexTests {
    @Test func defaultsToMockProviderMode() {
        #expect(AppModel().providerMode == .mock)
    }
}
