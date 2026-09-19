import Testing
@testable import Reflex

struct AppModelTests {
    @MainActor
    @Test func captureNextSampleDoesNothingWhilePaused() {
        let model = AppModel()
        let initialContext = model.context

        model.isPaused = true
        model.captureNextSample()

        #expect(model.context == initialContext)
    }

    @MainActor
    @Test func captureNextSampleRotatesContextWhenRunning() {
        let model = AppModel()
        let initialContext = model.context

        model.captureNextSample()

        #expect(model.context != initialContext)
    }

    @MainActor
    @Test func liveModeShowsPhaseThreeDisclosure() {
        let model = AppModel()

        model.providerMode = .live

        #expect(model.liveModeMessage == "Live Jev decisions arrive in Phase 3.")
    }

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
