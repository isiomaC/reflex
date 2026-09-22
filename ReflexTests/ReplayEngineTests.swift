import Foundation
import Testing
@testable import Reflex

struct ReplayEngineTests {
    @Test func replayInputDecodesAStoredSanitizedSnapshot() throws {
        let snapshot = ContextSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            timestamp: Date(timeIntervalSince1970: 10),
            activeApplication: ApplicationContext(name: "Sensitive App", bundleIdentifier: "com.example.app")
        )
        let record = DecisionRecord(DecisionRecordDraft(
            timestamp: .now,
            snapshotID: snapshot.id,
            sanitizedState: try snapshot.sanitizedJSON(),
            selectedActivity: "debugging",
            activityProbabilities: "{}",
            interventionUsefulness: 0.5,
            selectedAction: "doNothing",
            actionProbabilities: "{}",
            latencyMilliseconds: 20,
            errorMessage: nil
        ))

        let input = try ReplayInput(record: record)

        #expect(input.snapshot.id == snapshot.id)
        #expect(input.snapshot.activeApplication.name == "redacted")
        #expect(input.isSynthetic == false)
    }

    @Test func comparisonReportsOptionDeltas() {
        let original = result(activity: .debugging, activityProbability: 0.8, action: .explain, actionProbability: 0.7, milliseconds: 20)
        let replayed = result(activity: .researching, activityProbability: 0.6, action: .search, actionProbability: 0.9, milliseconds: 40)

        let comparison = ReplayComparison(original: original, replayed: replayed)

        #expect(comparison.activityDelta[.debugging] == -0.8)
        #expect(comparison.activityDelta[.researching] == 0.6)
        #expect(comparison.actionDelta[.explain] == -0.7)
        #expect(comparison.actionDelta[.search] == 0.9)
        #expect(comparison.latencyDeltaMilliseconds == 20)
    }

    @Test func statisticsSummariseSelectedProbabilityAndLatency() {
        let statistics = ReplayStatistics(results: [
            result(activity: .debugging, activityProbability: 0.2, action: .doNothing, actionProbability: 1, milliseconds: 10),
            result(activity: .debugging, activityProbability: 0.8, action: .doNothing, actionProbability: 1, milliseconds: 30),
        ])

        #expect(statistics.outcomeCounts == [.debugging: 2])
        #expect(statistics.meanSelectedProbability == 0.5)
        #expect(statistics.minimumSelectedProbability == 0.2)
        #expect(statistics.maximumSelectedProbability == 0.8)
        #expect(abs(statistics.standardDeviationSelectedProbability - 0.3) < 0.000_001)
        #expect(statistics.medianLatencyMilliseconds == 20)
        #expect(statistics.p95LatencyMilliseconds == 30)
    }

    private func result(activity: Activity, activityProbability: Double, action: SuggestedAction, actionProbability: Double, milliseconds: Int) -> DecisionLensResult {
        DecisionLensResult(
            snapshotID: UUID(),
            latency: .milliseconds(milliseconds),
            activity: ActivityDecision(selected: activity, rawProbabilities: [activity: activityProbability]),
            intervention: InterventionDecision(selected: false, rawProbabilities: [false: 1]),
            suggestedAction: SuggestedActionDecision(selected: action, rawProbabilities: [action: actionProbability])
        )
    }
}
