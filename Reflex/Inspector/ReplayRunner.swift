import Foundation

enum ReplayRunError: Error, Equatable, Sendable {
    case invalidCount
}

struct ReplayProgress: Equatable, Sendable {
    let completed: Int
    let total: Int
}

@MainActor
final class ReplayRunner {
    private let provider: any LiveDecisionProviding
    private let minimumInterval: Duration

    init(provider: any LiveDecisionProviding, minimumInterval: Duration = .milliseconds(250)) {
        self.provider = provider
        self.minimumInterval = minimumInterval
    }

    func run(
        input: ReplayInput,
        count: Int,
        onProgress: @MainActor (ReplayProgress) -> Void
    ) async throws -> [DecisionLensResult] {
        guard (1...100).contains(count) else { throw ReplayRunError.invalidCount }

        var results: [DecisionLensResult] = []
        results.reserveCapacity(count)

        for index in 0..<count {
            try Task.checkCancellation()
            if index > 0, minimumInterval > .zero {
                try await Task.sleep(for: minimumInterval)
            }
            let result = try await provider.decide(for: input.snapshot)
            results.append(result)
            onProgress(ReplayProgress(completed: index + 1, total: count))
        }

        return results
    }
}
