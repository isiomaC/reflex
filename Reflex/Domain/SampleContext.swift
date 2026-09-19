import Foundation

enum SampleContext: String, CaseIterable, Identifiable, Sendable {
    case debugging

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debugging: "Debugging a Swift compiler error"
        }
    }

    var sourceLabel: String { "Sample context" }

    var summary: String {
        switch self {
        case .debugging: "A focused coding session resolving a Swift compiler error."
        }
    }
}
