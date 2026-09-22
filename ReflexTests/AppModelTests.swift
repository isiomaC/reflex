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
        await captureController.waitForCaptureCount(1)

        #expect(await captureController.captureCount == 1)
    }

    @MainActor
    @Test func clipboardCaptureUsesItsDedicatedExplicitPath() async {
        let captureController = CaptureController()
        let model = AppModel(contextCaptureController: captureController)
        model.isClipboardCaptureEnabled = true

        model.captureClipboardNow()
        await captureController.waitForClipboardCaptureCount(1)

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
    @Test func liveModeWaitsForLocalContextBeforeMakingARequest() {
        let liveProvider = CountingDecisionProvider()
        let suiteName = "ReflexTests.liveMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AppModel(liveDecisionProvider: liveProvider, defaults: defaults)

        model.providerMode = .live

        #expect(model.liveModeMessage == "Live Jev uses the sanitized payload shown in Lens.")
        #expect(liveProvider.requestCount == 0)
    }

    @MainActor
    @Test func selectingAStoredRecordForReplayCreatesSyntheticInputAndNavigatesToReplayLab() throws {
        let snapshot = ContextSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            activeApplication: ApplicationContext(name: "Sensitive App", bundleIdentifier: "com.example.app")
        )
        let record = DecisionRecord(DecisionRecordDraft(
            timestamp: .now,
            snapshotID: snapshot.id,
            sanitizedState: try snapshot.sanitizedJSON(),
            selectedActivity: "debugging",
            activityProbabilities: "{}",
            interventionUsefulness: 0,
            selectedAction: "doNothing",
            actionProbabilities: "{}",
            latencyMilliseconds: 1,
            errorMessage: nil
        ))
        let model = AppModel()

        model.selectRecordForReplay(record)

        #expect(model.destination == .replayLab)
        #expect(model.replayInput?.sourceRecordID == record.id)
        #expect(model.replayInput?.isSynthetic == true)
    }

    @MainActor
    @Test func singleReplayPublishesTheLiveProviderResult() async throws {
        let suiteName = "ReflexTests.singleReplay.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = CountingDecisionProvider()
        let snapshot = ContextSnapshot(activeApplication: ApplicationContext(name: "Sensitive App", bundleIdentifier: "com.example.app"))
        let record = DecisionRecord(DecisionRecordDraft(timestamp: .now, snapshotID: snapshot.id, sanitizedState: try snapshot.sanitizedJSON(), selectedActivity: "debugging", activityProbabilities: "{}", interventionUsefulness: 0, selectedAction: "doNothing", actionProbabilities: "{}", latencyMilliseconds: 1, errorMessage: nil))
        let model = AppModel(liveDecisionProvider: provider, defaults: defaults)
        model.providerMode = .live
        model.selectRecordForReplay(record)

        await model.replayOnce()

        #expect(provider.requestCount == 1)
        #expect(model.replayResult?.snapshotID == snapshot.id)
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

    func waitForCaptureCount(_ expected: Int) async {
        while captureCount < expected {
            await Task.yield()
        }
    }

    func waitForClipboardCaptureCount(_ expected: Int) async {
        while clipboardCaptureCount < expected {
            await Task.yield()
        }
    }
}

@MainActor
private final class CountingDecisionProvider: LiveDecisionProviding {
    private(set) var requestCount = 0

    func decide(for snapshot: ContextSnapshot) async throws -> DecisionLensResult {
        requestCount += 1
        return DecisionLensResult(
            snapshotID: snapshot.id,
            latency: .zero,
            activity: ActivityDecision(selected: .other, rawProbabilities: [.other: 1]),
            intervention: InterventionDecision(selected: false, rawProbabilities: [false: 1]),
            suggestedAction: SuggestedActionDecision(selected: .doNothing, rawProbabilities: [.doNothing: 1])
        )
    }
}
