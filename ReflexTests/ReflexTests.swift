import Foundation
import SwiftData
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

struct DecisionLensDomainTests {
    @Test func policyProducesOnlyAnInAppSuggestionAboveAllThresholds() {
        let snapshotID = UUID()
        let result = DecisionLensResult(
            snapshotID: snapshotID,
            latency: .milliseconds(180),
            activity: ActivityDecision(
                selected: .coding,
                rawProbabilities: [.coding: 0.82, .other: 0.18]
            ),
            intervention: InterventionDecision(
                selected: true,
                rawProbabilities: [true: 0.79, false: 0.21]
            ),
            suggestedAction: SuggestedActionDecision(
                selected: .explain,
                rawProbabilities: [.explain: 0.74, .doNothing: 0.26]
            )
        )

        let suggestion = InterventionPolicy().suggestion(for: result)

        #expect(suggestion?.action == .explain)
        #expect(suggestion?.delivery == .inApp)
        #expect(suggestion?.message == "Offer a concise explanation in Reflex.")
    }

    @Test func policySuppressesSuggestionBelowInterventionThreshold() {
        let result = DecisionLensResult(
            snapshotID: UUID(),
            latency: .zero,
            activity: ActivityDecision(selected: .debugging, rawProbabilities: [.debugging: 0.9]),
            intervention: InterventionDecision(selected: true, rawProbabilities: [true: 0.64, false: 0.36]),
            suggestedAction: SuggestedActionDecision(selected: .search, rawProbabilities: [.search: 0.9])
        )

        #expect(InterventionPolicy().suggestion(for: result) == nil)
    }

    @Test func policyNeverSuggestsDoNothing() {
        let result = DecisionLensResult(
            snapshotID: UUID(),
            latency: .zero,
            activity: ActivityDecision(selected: .writing, rawProbabilities: [.writing: 0.9]),
            intervention: InterventionDecision(selected: true, rawProbabilities: [true: 0.9]),
            suggestedAction: SuggestedActionDecision(selected: .doNothing, rawProbabilities: [.doNothing: 0.9])
        )

        #expect(InterventionPolicy().suggestion(for: result) == nil)
    }

    @Test func coordinatorRejectsAResponseForASupersededSnapshot() async {
        let coordinator = DecisionLensCoordinator()
        let olderSnapshot = UUID()
        let newerSnapshot = UUID()
        let olderRequest = await coordinator.beginRequest(for: olderSnapshot)
        _ = await coordinator.beginRequest(for: newerSnapshot)
        let olderResult = DecisionLensResult(
            snapshotID: olderSnapshot,
            latency: .milliseconds(500),
            activity: ActivityDecision(selected: .other, rawProbabilities: [.other: 1]),
            intervention: InterventionDecision(selected: false, rawProbabilities: [false: 1]),
            suggestedAction: SuggestedActionDecision(selected: .doNothing, rawProbabilities: [.doNothing: 1])
        )

        let accepted = await coordinator.accept(olderResult, for: olderRequest)

        #expect(accepted == nil)
    }
}

struct LiveDecisionProviderTests {
    @MainActor
    @Test func liveProviderRequiresAStoredAPIKeyBeforeMakingARequest() async {
        let provider = LiveDecisionProvider(credentialStore: InMemoryCredentialStore())
        let snapshot = ContextSnapshot(
            activeApplication: ApplicationContext(name: "Sensitive app name", bundleIdentifier: "com.example.app"),
            activeWindow: WindowContext(title: "Sensitive title"),
            clipboard: ClipboardContext(kind: .text, text: "Sensitive clipboard", wasTruncated: false)
        )

        await #expect(throws: LiveDecisionError.missingAPIKey) {
            try await provider.decide(for: snapshot)
        }
    }
}

@MainActor
struct DecisionHistoryTests {
    @Test func recordStoresOnlySanitizedStateAndDecisionDetails() throws {
        let store = try DecisionHistoryStore.inMemory()
        let snapshot = ContextSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            timestamp: Date(timeIntervalSince1970: 0),
            activeApplication: ApplicationContext(name: "Sensitive app", bundleIdentifier: "com.example.app"),
            activeWindow: WindowContext(title: "Sensitive window"),
            clipboard: ClipboardContext(kind: .text, text: "Sensitive clipboard", wasTruncated: false)
        )
        let decision = DecisionLensResult(
            snapshotID: snapshot.id,
            latency: .milliseconds(120),
            activity: ActivityDecision(selected: .coding, rawProbabilities: [.coding: 0.8, .other: 0.2]),
            intervention: InterventionDecision(selected: true, rawProbabilities: [true: 0.7, false: 0.3]),
            suggestedAction: SuggestedActionDecision(selected: .explain, rawProbabilities: [.explain: 0.9, .doNothing: 0.1])
        )

        let record = try store.record(snapshot: snapshot, decision: decision, at: Date(timeIntervalSince1970: 10))

        #expect(record.sanitizedState.contains("com.example.app"))
        #expect(!record.sanitizedState.contains("Sensitive app"))
        #expect(!record.sanitizedState.contains("Sensitive window"))
        #expect(!record.sanitizedState.contains("Sensitive clipboard"))
        #expect(record.selectedActivity == Activity.coding.rawValue)
        #expect(record.selectedAction == SuggestedAction.explain.rawValue)
        let exported = try record.exportJSON()
        #expect(exported.contains("com.example.app"))
        #expect(!exported.contains("Sensitive clipboard"))
    }

    @Test func retentionKeepsMostRecentBoundedRecords() throws {
        let store = try DecisionHistoryStore.inMemory(maximumRecords: 2)
        try store.record(sampleRecord(timestamp: 1))
        try store.record(sampleRecord(timestamp: 2))
        try store.record(sampleRecord(timestamp: 3))

        #expect(try store.records().map(\.timestamp) == [Date(timeIntervalSince1970: 3), Date(timeIntervalSince1970: 2)])
    }

    private func sampleRecord(timestamp: TimeInterval) -> DecisionRecordDraft {
        DecisionRecordDraft(timestamp: Date(timeIntervalSince1970: timestamp), snapshotID: UUID(), sanitizedState: "{}", selectedActivity: "coding", activityProbabilities: "{}", interventionUsefulness: 0.5, selectedAction: "doNothing", actionProbabilities: "{}", latencyMilliseconds: 1, errorMessage: nil)
    }
}
