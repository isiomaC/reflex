import Foundation
import Testing
@testable import Reflex

struct ReflexTests {
    @MainActor
    @Test func defaultsToMockProviderMode() {
        let suiteName = "ReflexTests.defaultProviderMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(AppModel(defaults: defaults).providerMode == .mock)
    }
}
