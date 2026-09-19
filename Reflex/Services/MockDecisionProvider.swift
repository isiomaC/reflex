protocol DecisionProvider: Sendable {
    func decision(for context: SampleContext) -> MockDecision
}

struct MockDecisionProvider: DecisionProvider {
    func decision(for context: SampleContext) -> MockDecision {
        switch context {
        case .debugging:
            MockDecision(
                activity: ActivityDecision(selected: .debugging, confidence: 0.92),
                interventionUsefulness: 0.28,
                suggestion: "Keep the compiler error visible and isolate the failing expression."
            )
        }
    }
}
