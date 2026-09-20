import Foundation

struct ApplicationContext: Codable, Equatable, Sendable {
    static let maximumNameLength = 128
    static let maximumBundleIdentifierLength = 255

    let name: String
    let bundleIdentifier: String

    init(name: String, bundleIdentifier: String) {
        self.name = Self.bounded(name, maximumLength: Self.maximumNameLength)
        self.bundleIdentifier = Self.bounded(bundleIdentifier, maximumLength: Self.maximumBundleIdentifierLength)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
            bundleIdentifier: try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? ""
        )
    }

    private static func bounded(_ value: String, maximumLength: Int) -> String {
        String(value.filter { !$0.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) }.prefix(maximumLength))
    }
}

struct WindowContext: Codable, Equatable, Sendable {
    static let maximumTitleLength = 256

    let title: String

    init(title: String) {
        self.title = String(title.filter { !$0.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) }.prefix(Self.maximumTitleLength))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(title: try container.decodeIfPresent(String.self, forKey: .title) ?? "")
    }
}

struct ClipboardContext: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case text
        case nonText

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = Self(rawValue: value) ?? .nonText
        }
    }

    static let maximumTextLength = 1_000

    let kind: Kind
    let text: String?
    let wasTruncated: Bool
    let textLength: Int

    init(kind: Kind, text: String?, wasTruncated: Bool, textLength: Int? = nil) {
        let originalLength = text?.count ?? 0
        let boundedText = text.map { String($0.prefix(Self.maximumTextLength)) }
        let hasText = !(boundedText?.isEmpty ?? true)

        self.kind = kind == .text && hasText ? .text : .nonText
        self.text = self.kind == .text ? boundedText : nil
        self.wasTruncated = wasTruncated || originalLength > Self.maximumTextLength
        self.textLength = max(originalLength, textLength ?? 0)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .nonText,
            text: try container.decodeIfPresent(String.self, forKey: .text),
            wasTruncated: try container.decodeIfPresent(Bool.self, forKey: .wasTruncated) ?? false,
            textLength: try container.decodeIfPresent(Int.self, forKey: .textLength)
        )
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestampString = try container.decodeIfPresent(String.self, forKey: .timestamp)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            timestamp: timestampString.flatMap { try? Date($0, strategy: .iso8601) } ?? Date(timeIntervalSince1970: 0),
            activeApplication: try container.decodeIfPresent(ApplicationContext.self, forKey: .activeApplication) ?? ApplicationContext(name: "", bundleIdentifier: ""),
            activeWindow: try container.decodeIfPresent(WindowContext.self, forKey: .activeWindow),
            clipboard: try container.decodeIfPresent(ClipboardContext.self, forKey: .clipboard),
            recentApplications: try container.decodeIfPresent([ApplicationContext].self, forKey: .recentApplications) ?? []
        )
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
        let data = try encoder.encode(SanitizedContextSnapshot(snapshot: self))
        return String(decoding: data, as: UTF8.self)
    }
}

private struct SanitizedContextSnapshot: Codable {
    let id: UUID
    let timestamp: Date
    let activeApplication: SanitizedApplicationContext
    let activeWindow: SanitizedWindowContext?
    let clipboard: SanitizedClipboardContext?
    let recentApplications: [SanitizedApplicationContext]

    init(snapshot: ContextSnapshot) {
        id = snapshot.id
        timestamp = snapshot.timestamp
        activeApplication = SanitizedApplicationContext(snapshot.activeApplication)
        activeWindow = snapshot.activeWindow.map(SanitizedWindowContext.init)
        clipboard = snapshot.clipboard.map(SanitizedClipboardContext.init)
        recentApplications = snapshot.recentApplications.map(SanitizedApplicationContext.init)
    }
}

private struct SanitizedApplicationContext: Codable {
    let name: String
    let bundleIdentifier: String

    init(_ context: ApplicationContext) {
        name = "redacted"
        bundleIdentifier = context.bundleIdentifier
    }
}

private struct SanitizedWindowContext: Codable {
    let title: String

    init(_: WindowContext) {
        title = "redacted"
    }
}

private struct SanitizedClipboardContext: Codable {
    let contentKind: ClipboardContext.Kind
    let textLength: Int
    let wasTruncated: Bool

    init(_ context: ClipboardContext) {
        contentKind = context.kind
        textLength = context.textLength
        wasTruncated = context.wasTruncated
    }
}
