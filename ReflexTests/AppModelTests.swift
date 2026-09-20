import Foundation
import Testing
@testable import Reflex

struct AppModelTests {
    @MainActor
    @Test func localContextCaptureDoesNothingWhilePaused() async {
        let captureController = CaptureController()
        let model = AppModel(contextCaptureController: captureController)
        model.isPaused = true

        model.captureLocalContext()
        await Task.yield()

        #expect(await captureController.captureCount == 0)
    }

    @MainActor
    @Test func localContextCaptureUsesTheExplicitCapturePath() async {
        let captureController = CaptureController()
        let model = AppModel(contextCaptureController: captureController)

        model.captureLocalContext()
        await Task.yield()

        #expect(await captureController.captureCount == 1)
    }

    @MainActor
    @Test func clipboardCaptureUsesItsDedicatedExplicitPath() async {
        let captureController = CaptureController()
        let model = AppModel(contextCaptureController: captureController)
        model.isClipboardCaptureEnabled = true

        model.captureClipboardNow()
        await Task.yield()

        #expect(await captureController.clipboardCaptureCount == 1)
        #expect(await captureController.captureCount == 0)
    }

    @MainActor
    @Test func missingWindowMetadataIsReportedAsReducedContext() {
        let model = AppModel()
        let snapshot = ContextSnapshot(
            activeApplication: ApplicationContext(name: "Reflex", bundleIdentifier: "com.isiomac.Reflex")
        )

        model.receiveLocalContext(snapshot)

        #expect(model.isUsingReducedContext)
        #expect(model.sanitizedContextJSON?.contains("com.isiomac.Reflex") == true)
    }

    @MainActor
    @Test func providerModeRestoresFromTheSameDefaultsStore() {
        let suiteName = "ReflexTests.providerMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunch = AppModel(defaults: defaults)
        firstLaunch.providerMode = .live

        let relaunchedModel = AppModel(defaults: defaults)

        #expect(relaunchedModel.providerMode == .live)
    }

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
    @Test func decisionIsFreshForOneMinuteAfterItsUpdate() {
        let updatedAt = Date(timeIntervalSinceReferenceDate: 100)
        let model = AppModel(now: { updatedAt })

        #expect(model.decisionFreshness(at: updatedAt.addingTimeInterval(60)) == .fresh)
        #expect(model.decisionFreshness(at: updatedAt.addingTimeInterval(60.1)) == .stale)
    }

    @MainActor
    @Test func liveModeShowsPhaseThreeDisclosureWithoutMakingALiveRequest() {
        let liveProvider = CountingDecisionProvider()
        let suiteName = "ReflexTests.liveMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AppModel(liveDecisionProvider: liveProvider, defaults: defaults)

        model.providerMode = .live

        #expect(model.liveModeMessage == "Live Jev decisions arrive in Phase 3.")
        #expect(liveProvider.requestCount == 0)
    }

    @Test func debuggingSamplePrefersDebugging() {
        let result = MockDecisionProvider().decision(for: .debugging)

        #expect(result.activity.selected == .debugging)
        #expect(result.activity.confidence == 0.92)
    }

    @Test func writingSamplePrefersWriting() {
        let result = MockDecisionProvider().decision(for: .writing)

        #expect(result.activity.selected == .writing)
        #expect(result.activity.confidence == 0.89)
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

private actor CaptureController: ContextCaptureControlling {
    private(set) var captureCount = 0
    private(set) var clipboardCaptureCount = 0

    func captureNow() {
        captureCount += 1
    }

    func captureClipboardNow() {
        clipboardCaptureCount += 1
    }

    func pause() {}
    func resume() {}
    func foregroundApplicationDidChange() {}
}

private final class CountingDecisionProvider: DecisionProvider, @unchecked Sendable {
    private(set) var requestCount = 0

    func decision(for context: SampleContext) -> MockDecision {
        requestCount += 1
        return MockDecisionProvider().decision(for: context)
    }
}
