import Foundation
import SwiftData

@Model
final class DecisionRecord {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var snapshotID: UUID
    var sanitizedState: String
    var selectedActivity: String
    var activityProbabilities: String
    var interventionUsefulness: Double
    var selectedAction: String
    var actionProbabilities: String
    var latencyMilliseconds: Int
    var errorMessage: String?

    init(_ draft: DecisionRecordDraft) {
        id = UUID()
        timestamp = draft.timestamp
        snapshotID = draft.snapshotID
        sanitizedState = draft.sanitizedState
        selectedActivity = draft.selectedActivity
        activityProbabilities = draft.activityProbabilities
        interventionUsefulness = draft.interventionUsefulness
        selectedAction = draft.selectedAction
        actionProbabilities = draft.actionProbabilities
        latencyMilliseconds = draft.latencyMilliseconds
        errorMessage = draft.errorMessage
    }

    func exportJSON() throws -> String {
        let export = DecisionRecordExport(
            timestamp: timestamp,
            snapshotID: snapshotID,
            sanitizedState: sanitizedState,
            selectedActivity: selectedActivity,
            activityProbabilities: activityProbabilities,
            interventionUsefulness: interventionUsefulness,
            selectedAction: selectedAction,
            actionProbabilities: actionProbabilities,
            latencyMilliseconds: latencyMilliseconds,
            errorMessage: errorMessage
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(export), as: UTF8.self)
    }
}

private struct DecisionRecordExport: Codable {
    let timestamp: Date
    let snapshotID: UUID
    let sanitizedState: String
    let selectedActivity: String
    let activityProbabilities: String
    let interventionUsefulness: Double
    let selectedAction: String
    let actionProbabilities: String
    let latencyMilliseconds: Int
    let errorMessage: String?
}

struct DecisionRecordDraft: Sendable {
    let timestamp: Date
    let snapshotID: UUID
    let sanitizedState: String
    let selectedActivity: String
    let activityProbabilities: String
    let interventionUsefulness: Double
    let selectedAction: String
    let actionProbabilities: String
    let latencyMilliseconds: Int
    let errorMessage: String?
}

@MainActor
final class DecisionHistoryStore {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let maximumRecords: Int

    init(modelContainer: ModelContainer, maximumRecords: Int = 200) {
        self.modelContainer = modelContainer
        modelContext = modelContainer.mainContext
        self.maximumRecords = max(1, maximumRecords)
    }

    static func inMemory(maximumRecords: Int = 200) throws -> DecisionHistoryStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DecisionRecord.self, configurations: configuration)
        return DecisionHistoryStore(modelContainer: container, maximumRecords: maximumRecords)
    }

    static func persistent(maximumRecords: Int = 200) throws -> DecisionHistoryStore {
        let container = try ModelContainer(for: DecisionRecord.self)
        return DecisionHistoryStore(modelContainer: container, maximumRecords: maximumRecords)
    }

    @discardableResult
    func record(snapshot: ContextSnapshot, decision: DecisionLensResult, at timestamp: Date = .now) throws -> DecisionRecord {
        let draft = DecisionRecordDraft(
            timestamp: timestamp,
            snapshotID: snapshot.id,
            sanitizedState: try snapshot.sanitizedJSON(),
            selectedActivity: decision.activity.selected.rawValue,
            activityProbabilities: try Self.encode(decision.activity.rawProbabilities),
            interventionUsefulness: decision.intervention.usefulness,
            selectedAction: decision.suggestedAction.selected.rawValue,
            actionProbabilities: try Self.encode(decision.suggestedAction.rawProbabilities),
            latencyMilliseconds: Self.milliseconds(decision.latency),
            errorMessage: nil
        )
        return try record(draft)
    }

    @discardableResult
    func record(_ draft: DecisionRecordDraft) throws -> DecisionRecord {
        let record = DecisionRecord(draft)
        modelContext.insert(record)
        try enforceRetention()
        try modelContext.save()
        return record
    }

    func records() throws -> [DecisionRecord] {
        try modelContext.fetch(FetchDescriptor<DecisionRecord>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
    }

    func clear() throws {
        for record in try records() {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    private func enforceRetention() throws {
        let retained = try records()
        for record in retained.dropFirst(maximumRecords) {
            modelContext.delete(record)
        }
    }

    private static func encode<Option: RawRepresentable>(_ probabilities: [Option: Double]) throws -> String where Option.RawValue == String {
        let values = Dictionary(uniqueKeysWithValues: probabilities.map { ($0.key.rawValue, $0.value) })
        return String(decoding: try JSONEncoder().encode(values), as: UTF8.self)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return Int((Double(components.seconds) * 1_000) + (Double(components.attoseconds) / 1_000_000_000_000_000))
    }
}
