import Foundation
import JevKit

enum LiveDecisionError: Error, Equatable, Sendable {
    case missingAPIKey
    case authentication
    case invalidResponse
    case offline
    case timeout
    case rateLimited
    case server

    var message: String {
        switch self {
        case .missingAPIKey: "Add a Jev API key in Settings to use live decisions."
        case .authentication: "Jev rejected the stored API key. Update it in Settings."
        case .invalidResponse: "Jev returned a response Reflex could not use."
        case .offline: "Jev could not be reached. Check your connection."
        case .timeout: "Jev took too long to respond. Try again."
        case .rateLimited: "Jev is rate limiting requests. Try again shortly."
        case .server: "Jev encountered a server error. Try again shortly."
        }
    }
}

@MainActor
protocol LiveDecisionProviding: AnyObject {
    func decide(for snapshot: ContextSnapshot) async throws -> DecisionLensResult
}

@MainActor
final class LiveDecisionProvider: LiveDecisionProviding {
    private let credentialStore: any CredentialStore
    private let transport: (any JevTransport)?

    init(credentialStore: any CredentialStore = KeychainCredentialStore(), transport: (any JevTransport)? = nil) {
        self.credentialStore = credentialStore
        self.transport = transport
    }

    func decide(for snapshot: ContextSnapshot) async throws -> DecisionLensResult {
        let apiKey: String
        do {
            guard let storedKey = try credentialStore.load()?.trimmingCharacters(in: .whitespacesAndNewlines), !storedKey.isEmpty else {
                throw LiveDecisionError.missingAPIKey
            }
            apiKey = storedKey
        } catch let error as LiveDecisionError {
            throw error
        } catch {
            throw LiveDecisionError.offline
        }

        do {
            let state = try JSONDecoder().decode(JSONValue.self, from: Data(try snapshot.sanitizedJSON().utf8))
            let configuration = try JevConfiguration(apiKey: apiKey)
            let client = transport.map { JevClient(configuration: configuration, transport: $0) } ?? JevClient(configuration: configuration)
            let batch = try await client.evaluate(state: state, questions: Self.questions)
            return try Self.result(snapshotID: snapshot.id, batch: batch)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LiveDecisionError {
            throw error
        } catch let error as JevError {
            throw Self.map(error)
        } catch {
            throw LiveDecisionError.invalidResponse
        }
    }

    private static let questions: [String: WireQuestion] = [
        "activity": .choice(instructions: .string("Select the user's current broad activity from the supplied sanitized context."), criteria: Dictionary(uniqueKeysWithValues: Activity.allCases.map { ($0.rawValue, .null) })),
        "intervention": .noul(instructions: .string("Would a brief, passive in-app suggestion be useful right now?"), criteria: ["true": .string("A small in-app suggestion would help."), "false": .string("Do not interrupt; a suggestion would not help.")]),
        "suggestedAction": .choice(instructions: .string("Select the safest passive in-app suggestion. This application cannot take desktop actions."), criteria: Dictionary(uniqueKeysWithValues: SuggestedAction.allCases.map { ($0.rawValue, .null) })),
    ]

    private static func result(snapshotID: UUID, batch: BatchDecision) throws -> DecisionLensResult {
        guard case let .choice(activityValue, activityProbabilities, _)? = batch.answers["activity"], let activity = Activity(rawValue: activityValue), let mappedActivity = map(activityProbabilities, options: Activity.allCases), case let .noul(interventionProbability)? = batch.answers["intervention"], (0...1).contains(interventionProbability), case let .choice(actionValue, actionProbabilities, _)? = batch.answers["suggestedAction"], let action = SuggestedAction(rawValue: actionValue), let mappedAction = map(actionProbabilities, options: SuggestedAction.allCases) else { throw LiveDecisionError.invalidResponse }
        return DecisionLensResult(snapshotID: snapshotID, latency: batch.metadata.latency, activity: ActivityDecision(selected: activity, rawProbabilities: mappedActivity), intervention: InterventionDecision(selected: interventionProbability >= 0.5, rawProbabilities: [true: interventionProbability, false: 1 - interventionProbability]), suggestedAction: SuggestedActionDecision(selected: action, rawProbabilities: mappedAction))
    }

    private static func map<Option: RawRepresentable & Hashable>(_ values: [String: Double], options: [Option]) -> [Option: Double]? where Option.RawValue == String {
        guard Set(values.keys) == Set(options.map(\.rawValue)), values.values.allSatisfy({ (0...1).contains($0) }) else { return nil }
        return Dictionary(uniqueKeysWithValues: options.compactMap { option in values[option.rawValue].map { (option, $0) } })
    }

    private static func map(_ error: JevError) -> LiveDecisionError {
        switch error {
        case .authentication: .authentication
        case .timeout: .timeout
        case .rateLimited: .rateLimited
        case .server: .server
        case .transport: .offline
        case .invalidConfiguration, .invalidRequest, .invalidResponse, .decoding: .invalidResponse
        case .cancelled: .offline
        }
    }
}
