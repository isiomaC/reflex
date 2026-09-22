import Foundation
import Testing
@testable import Reflex

@MainActor
struct ReplayRunnerTests {
    @Test func repeatedRunsReportSequentialProgress() async throws {
        let provider = ReplayTestProvider()
        let runner = ReplayRunner(provider: provider, minimumInterval: .zero)
        var progress: [ReplayProgress] = []

        let results = try await runner.run(input: input, count: 3) { progress.append($0) }

        #expect(results.count == 3)
        #expect(provider.requestCount == 3)
        #expect(progress == [ReplayProgress(completed: 1, total: 3), ReplayProgress(completed: 2, total: 3), ReplayProgress(completed: 3, total: 3)])
    }

    @Test func runnerRejectsCountsOutsideTheSupportedRange() async {
        let runner = ReplayRunner(provider: ReplayTestProvider(), minimumInterval: .zero)

        await #expect(throws: ReplayRunError.invalidCount) {
            try await runner.run(input: input, count: 101) { _ in }
        }
    }

    private var input: ReplayInput {
        ReplayInput(snapshot: ContextSnapshot(activeApplication: ApplicationContext(name: "redacted", bundleIdentifier: "com.example.app")))
    }
}

@MainActor
private final class ReplayTestProvider: LiveDecisionProviding {
    private(set) var requestCount = 0

    func decide(for snapshot: ContextSnapshot) async throws -> DecisionLensResult {
        requestCount += 1
        return DecisionLensResult(
            snapshotID: snapshot.id,
            latency: .milliseconds(10),
            activity: ActivityDecision(selected: .debugging, rawProbabilities: [.debugging: 0.8]),
            intervention: InterventionDecision(selected: false, rawProbabilities: [false: 1]),
            suggestedAction: SuggestedActionDecision(selected: .doNothing, rawProbabilities: [.doNothing: 1])
        )
    }
}
