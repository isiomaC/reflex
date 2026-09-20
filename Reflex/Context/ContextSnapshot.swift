import Foundation

struct ApplicationContext: Codable, Equatable, Sendable {
    let name: String
    let bundleIdentifier: String
}

struct WindowContext: Codable, Equatable, Sendable {
    let title: String
}

struct ClipboardContext: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case text
        case nonText
    }

    static let maximumTextLength = 1_000

    let kind: Kind
    let text: String?
    let wasTruncated: Bool

    init(kind: Kind, text: String?, wasTruncated: Bool) {
        let boundedText = text.map { String($0.prefix(Self.maximumTextLength)) }
        self.kind = kind
        self.text = boundedText
        self.wasTruncated = wasTruncated || (text?.count ?? 0) > Self.maximumTextLength
    }
}

struct ContextSnapshot: Codable, Equatable, Sendable {
    static let maximumRecentApplications = 5

    let id: UUID
    let timestamp: Date
    let activeApplication: ApplicationContext
    let activeWindow: WindowContext?
    let clipboard: ClipboardContext?
    let recentApplications: [ApplicationContext]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        activeApplication: ApplicationContext,
        activeWindow: WindowContext? = nil,
        clipboard: ClipboardContext? = nil,
        recentApplications: [ApplicationContext] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.activeApplication = activeApplication
        self.activeWindow = activeWindow
        self.clipboard = clipboard
        self.recentApplications = Self.boundedRecentApplications(recentApplications)
    }

    func isMateriallyEqual(to other: ContextSnapshot) -> Bool {
        activeApplication == other.activeApplication
            && activeWindow == other.activeWindow
            && clipboard == other.clipboard
            && recentApplications == other.recentApplications
    }

    static func boundedRecentApplications(_ applications: [ApplicationContext]) -> [ApplicationContext] {
        Array(applications.suffix(maximumRecentApplications))
    }

    func sanitizedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}
