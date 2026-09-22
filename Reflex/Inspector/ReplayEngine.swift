import Foundation

struct ReplayInput: Equatable, Sendable {
    let sourceRecordID: UUID?
    var snapshot: ContextSnapshot
    var isSynthetic: Bool

    init(record: DecisionRecord) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sourceRecordID = record.id
        snapshot = try decoder.decode(ContextSnapshot.self, from: Data(record.sanitizedState.utf8))
        isSynthetic = false
    }

    init(snapshot: ContextSnapshot, sourceRecordID: UUID? = nil, isSynthetic: Bool = true) {
        self.sourceRecordID = sourceRecordID
        self.snapshot = snapshot
        self.isSynthetic = isSynthetic
    }
}

struct ReplayComparison: Equatable, Sendable {
    let original: DecisionLensResult
    let replayed: DecisionLensResult

    var activityDelta: [Activity: Double] {
        Self.deltas(original.activity.rawProbabilities, replayed.activity.rawProbabilities, options: Activity.allCases)
    }

    var actionDelta: [SuggestedAction: Double] {
        Self.deltas(original.suggestedAction.rawProbabilities, replayed.suggestedAction.rawProbabilities, options: SuggestedAction.allCases)
    }

    var latencyDeltaMilliseconds: Int {
        ReplayStatistics.milliseconds(replayed.latency) - ReplayStatistics.milliseconds(original.latency)
    }

    private static func deltas<Option: Hashable>(
        _ original: [Option: Double],
        _ replayed: [Option: Double],
        options: [Option]
    ) -> [Option: Double] {
        Dictionary(uniqueKeysWithValues: options.map { option in
            (option, (replayed[option] ?? 0) - (original[option] ?? 0))
        })
    }
}

struct ReplayStatistics: Equatable, Sendable {
    let outcomeCounts: [Activity: Int]
    let meanSelectedProbability: Double
    let minimumSelectedProbability: Double
    let maximumSelectedProbability: Double
    let standardDeviationSelectedProbability: Double
    let medianLatencyMilliseconds: Int
    let p95LatencyMilliseconds: Int

    init(results: [DecisionLensResult]) {
        let probabilities = results.map(\.activity.confidence).sorted()
        let latencies = results.map { Self.milliseconds($0.latency) }.sorted()

        outcomeCounts = results.reduce(into: [:]) { counts, result in
            counts[result.activity.selected, default: 0] += 1
        }
        guard !probabilities.isEmpty, !latencies.isEmpty else {
            meanSelectedProbability = 0
            minimumSelectedProbability = 0
            maximumSelectedProbability = 0
            standardDeviationSelectedProbability = 0
            medianLatencyMilliseconds = 0
            p95LatencyMilliseconds = 0
            return
        }

        let mean = probabilities.reduce(0, +) / Double(probabilities.count)
        meanSelectedProbability = mean
        minimumSelectedProbability = probabilities[0]
        maximumSelectedProbability = probabilities[probabilities.count - 1]
        standardDeviationSelectedProbability = sqrt(probabilities.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(probabilities.count))
        medianLatencyMilliseconds = Self.median(latencies)
        p95LatencyMilliseconds = latencies[max(0, Int(ceil(Double(latencies.count) * 0.95)) - 1)]
    }

    static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return Int((Double(components.seconds) * 1_000) + (Double(components.attoseconds) / 1_000_000_000_000_000))
    }

    private static func median(_ sortedValues: [Int]) -> Int {
        let middle = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[middle - 1] + sortedValues[middle]) / 2
        }
        return sortedValues[middle]
    }
}

struct ReplayEngine: Sendable {
    func input(for record: DecisionRecord) throws -> ReplayInput {
        try ReplayInput(record: record)
    }

    func comparison(original: DecisionLensResult, replayed: DecisionLensResult) -> ReplayComparison {
        ReplayComparison(original: original, replayed: replayed)
    }

    func statistics(for results: [DecisionLensResult]) -> ReplayStatistics {
        ReplayStatistics(results: results)
    }
}
