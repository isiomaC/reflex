import Observation

enum AppDestination: Hashable, Sendable {
    case lens
    case inspector
    case replayLab
    case settings
}

enum ProviderMode: Equatable, Sendable {
    case mock
    case live
}

@MainActor
@Observable
final class AppModel {
    var destination: AppDestination = .lens
    var providerMode: ProviderMode = .mock
    var isPaused = false
    private(set) var context: SampleContext
    private(set) var decision: MockDecision

    private let decisionProvider: any DecisionProvider
    private let samples: [SampleContext]
    private var sampleIndex: Int

    var liveModeMessage: String? {
        providerMode == .live ? "Live Jev decisions arrive in Phase 3." : nil
    }

    init(
        sampleContextProvider: any SampleContextProvider = StaticSampleContextProvider(),
        decisionProvider: any DecisionProvider = MockDecisionProvider()
    ) {
        let initialContext = sampleContextProvider.currentContext()
        let availableSamples = SampleContext.allCases

        self.decisionProvider = decisionProvider
        samples = availableSamples
        context = initialContext
        decision = decisionProvider.decision(for: initialContext)
        sampleIndex = availableSamples.firstIndex(of: initialContext) ?? 0
    }

    func captureNextSample() {
        guard !isPaused, !samples.isEmpty else { return }

        sampleIndex = (sampleIndex + 1) % samples.count
        context = samples[sampleIndex]
        decision = decisionProvider.decision(for: context)
    }
}
