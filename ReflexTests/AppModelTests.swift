import Foundation
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
    @Test func captureNextSampleRefreshesDecisionTimestamp() {
        let firstUpdate = Date(timeIntervalSinceReferenceDate: 100)
        let refreshedUpdate = Date(timeIntervalSinceReferenceDate: 200)
        var updates = [firstUpdate, refreshedUpdate]
        let model = AppModel(now: { updates.removeFirst() })

        #expect(model.decisionUpdatedAt == firstUpdate)

        model.captureNextSample()

        #expect(model.decisionUpdatedAt == refreshedUpdate)
    }

    @MainActor
    @Test func liveModeShowsPhaseThreeDisclosureWithoutMakingALiveRequest() {
        let liveProvider = CountingDecisionProvider()
        let model = AppModel(liveDecisionProvider: liveProvider)

        model.providerMode = .live

        #expect(model.liveModeMessage == "Live Jev decisions arrive in Phase 3.")
        #expect(liveProvider.requestCount == 0)
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

private final class CountingDecisionProvider: DecisionProvider, @unchecked Sendable {
    private(set) var requestCount = 0

    func decision(for context: SampleContext) -> MockDecision {
        requestCount += 1
        return MockDecisionProvider().decision(for: context)
    }
}
