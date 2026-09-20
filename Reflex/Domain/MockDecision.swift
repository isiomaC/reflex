import Foundation

enum Activity: String, CaseIterable, Hashable, Sendable {
    case coding
    case debugging
    case researching
    case writing
    case communicating
    case browsing
    case idle
    case other
}

enum SuggestedAction: String, CaseIterable, Hashable, Sendable {
    case doNothing
    case explain
    case search
    case openTerminal
    case summarize
    case saveForLater
    case escalate
}

struct ActivityDecision: Equatable, Sendable {
    let selected: Activity
    let rawProbabilities: [Activity: Double]

    var confidence: Double { rawProbabilities[selected] ?? 0 }

    init(selected: Activity, rawProbabilities: [Activity: Double]) {
        self.selected = selected
        self.rawProbabilities = rawProbabilities
    }

    init(selected: Activity, confidence: Double) {
        self.init(selected: selected, rawProbabilities: [selected: confidence])
    }
}

struct InterventionDecision: Equatable, Sendable {
    let selected: Bool
    let rawProbabilities: [Bool: Double]

    var usefulness: Double { rawProbabilities[true] ?? 0 }
}

struct SuggestedActionDecision: Equatable, Sendable {
    let selected: SuggestedAction
    let rawProbabilities: [SuggestedAction: Double]

    var confidence: Double { rawProbabilities[selected] ?? 0 }
}

struct DecisionLensResult: Equatable, Sendable {
    let snapshotID: UUID
    let latency: Duration
    let activity: ActivityDecision
    let intervention: InterventionDecision
    let suggestedAction: SuggestedActionDecision
}

/// A passive suggestion that is rendered inside Reflex only. It deliberately has
/// no execution closure, URL, or desktop-control capability.
struct InAppSuggestion: Equatable, Sendable {
    enum Delivery: Equatable, Sendable {
        case inApp
    }

    let action: SuggestedAction
    let delivery: Delivery = .inApp
    let message: String
}

struct InterventionPolicy: Sendable {
    let minimumActivityConfidence: Double
    let minimumInterventionUsefulness: Double
    let minimumActionConfidence: Double

    init(
        minimumActivityConfidence: Double = 0.60,
        minimumInterventionUsefulness: Double = 0.65,
        minimumActionConfidence: Double = 0.60
    ) {
        self.minimumActivityConfidence = minimumActivityConfidence
        self.minimumInterventionUsefulness = minimumInterventionUsefulness
        self.minimumActionConfidence = minimumActionConfidence
    }

    func suggestion(for result: DecisionLensResult) -> InAppSuggestion? {
        guard result.activity.confidence >= minimumActivityConfidence,
              result.intervention.selected,
              result.intervention.usefulness >= minimumInterventionUsefulness,
              result.suggestedAction.selected != .doNothing,
              result.suggestedAction.confidence >= minimumActionConfidence
        else {
            return nil
        }

        return InAppSuggestion(
            action: result.suggestedAction.selected,
            message: Self.message(for: result.suggestedAction.selected)
        )
    }

    private static func message(for action: SuggestedAction) -> String {
        switch action {
        case .doNothing:
            ""
        case .explain:
            "Offer a concise explanation in Reflex."
        case .search:
            "Suggest a search the user can choose to run."
        case .openTerminal:
            "Suggest opening Terminal; Reflex will not open it."
        case .summarize:
            "Offer a concise summary in Reflex."
        case .saveForLater:
            "Offer to save this for later in Reflex."
        case .escalate:
            "Suggest escalating this decision to the user."
        }
    }
}

struct DecisionRequest: Equatable, Sendable {
    let snapshotID: UUID
    fileprivate let version: UInt64
}

actor DecisionLensCoordinator {
    private var currentSnapshotID: UUID?
    private var version: UInt64 = 0

    func beginRequest(for snapshotID: UUID) -> DecisionRequest {
        version &+= 1
        currentSnapshotID = snapshotID
        return DecisionRequest(snapshotID: snapshotID, version: version)
    }

    func accept(_ result: DecisionLensResult, for request: DecisionRequest) -> DecisionLensResult? {
        guard currentSnapshotID == request.snapshotID,
              result.snapshotID == request.snapshotID,
              request.version == version
        else {
            return nil
        }
        return result
    }
}

struct MockDecision: Sendable {
    let activity: ActivityDecision
    let interventionUsefulness: Double
    let suggestion: String
}
