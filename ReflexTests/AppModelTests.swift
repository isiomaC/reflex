import Testing
@testable import Reflex

struct AppModelTests {
    @Test func debuggingSamplePrefersDebugging() {
        let result = MockDecisionProvider().decision(for: .debugging)

        #expect(result.activity.selected == .debugging)
        #expect(result.activity.confidence == 0.92)
    }

    @Test func mockDecisionProviderCanBeUsedThroughDecisionProviderBoundary() {
        let provider: any DecisionProvider = MockDecisionProvider()

        #expect(provider.decision(for: .debugging).activity.selected == .debugging)
    }

    @Test func staticSampleContextProviderReturnsDebuggingContext() {
        let provider: any SampleContextProvider = StaticSampleContextProvider()

        #expect(provider.currentContext() == .debugging)
    }
}
