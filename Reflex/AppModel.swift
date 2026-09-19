import Foundation
import Observation

enum AppDestination: Hashable, Sendable {
    case lens
    case inspector
    case replayLab
}

enum ProviderMode: String, CaseIterable, Equatable, Sendable {
    case mock
    case live

    var title: String {
        switch self {
        case .mock: "Mock sample"
        case .live: "Live Jev (Phase 3)"
        }
    }
}

enum DecisionFreshness: Equatable, Sendable {
    case fresh
    case stale
}

@MainActor
@Observable
final class AppModel {
    var destination: AppDestination = .lens
    var providerMode: ProviderMode = .mock
    var isPaused = false
    private(set) var context: SampleContext
    private(set) var decision: MockDecision
    private(set) var decisionUpdatedAt: Date

    private let decisionProvider: any DecisionProvider
    // Reserved for Phase 3. It is deliberately never invoked in this release.
    private let liveDecisionProvider: (any DecisionProvider)?
    private let samples: [SampleContext]
    private let now: () -> Date
    private var sampleIndex: Int

    var liveModeMessage: String? {
        providerMode == .live ? "Live Jev decisions arrive in Phase 3." : nil
    }

    init(
        sampleContextProvider: any SampleContextProvider = StaticSampleContextProvider(),
        decisionProvider: any DecisionProvider = MockDecisionProvider(),
        liveDecisionProvider: (any DecisionProvider)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        let initialContext = sampleContextProvider.currentContext()
        let availableSamples = SampleContext.allCases

        self.decisionProvider = decisionProvider
        self.liveDecisionProvider = liveDecisionProvider
        self.now = now
        samples = availableSamples
        context = initialContext
        decision = decisionProvider.decision(for: initialContext)
        decisionUpdatedAt = now()
        sampleIndex = availableSamples.firstIndex(of: initialContext) ?? 0
    }

    func captureNextSample() {
        guard !isPaused, !samples.isEmpty else { return }

        sampleIndex = (sampleIndex + 1) % samples.count
        context = samples[sampleIndex]
        decision = decisionProvider.decision(for: context)
        decisionUpdatedAt = now()
    }

    func decisionFreshness(at date: Date) -> DecisionFreshness {
        date.timeIntervalSince(decisionUpdatedAt) <= 60 ? .fresh : .stale
    }
}
