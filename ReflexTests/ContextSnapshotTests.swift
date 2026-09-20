import Foundation
import Testing
@testable import Reflex

struct ContextSnapshotTests {
    @Test func materiallyEqualIgnoresIdentityAndTimestamp() {
        let original = ContextSnapshot(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1),
            activeApplication: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            activeWindow: WindowContext(title: "Reflex"),
            clipboard: ClipboardContext(kind: .text, text: "hello", wasTruncated: false),
            recentApplications: [ApplicationContext(name: "Safari", bundleIdentifier: "com.apple.Safari")]
        )
        let sameMaterial = ContextSnapshot(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 2),
            activeApplication: original.activeApplication,
            activeWindow: original.activeWindow,
            clipboard: original.clipboard,
            recentApplications: original.recentApplications
        )

        #expect(original.isMateriallyEqual(to: sameMaterial))
        #expect(!original.isMateriallyEqual(to: ContextSnapshot(activeApplication: ApplicationContext(name: "Terminal", bundleIdentifier: "com.apple.Terminal"))))
        #expect(!original.isMateriallyEqual(to: ContextSnapshot(activeApplication: original.activeApplication, activeWindow: WindowContext(title: "Other"))))
        #expect(!original.isMateriallyEqual(to: ContextSnapshot(activeApplication: original.activeApplication, clipboard: ClipboardContext(kind: .text, text: "other", wasTruncated: false))))
        #expect(!original.isMateriallyEqual(to: ContextSnapshot(activeApplication: original.activeApplication, recentApplications: [])))
    }

    @Test func recentApplicationHistoryKeepsOnlyMostRecentFive() {
        let applications = (1...7).map { ApplicationContext(name: "App \($0)", bundleIdentifier: "com.example.app\($0)") }

        #expect(ContextSnapshot.boundedRecentApplications(applications) == Array(applications.suffix(5)))
    }

    @Test func sanitizedJSONIsStableReadableAndExcludesSecrets() throws {
        let overlongText = String(repeating: "x", count: 1_001)
        let snapshot = ContextSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            timestamp: Date(timeIntervalSince1970: 0),
            activeApplication: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            activeWindow: WindowContext(title: "Reflex"),
            clipboard: ClipboardContext(kind: .text, text: overlongText, wasTruncated: false),
            recentApplications: []
        )

        let json = try snapshot.sanitizedJSON()
        let repeatedJSON = try snapshot.sanitizedJSON()

        #expect(json.contains("\"activeApplication\""))
        #expect(json.contains("\"wasTruncated\" : true"))
        #expect(!json.contains("secret"))
        #expect(!json.contains(String(repeating: "x", count: 1_001)))
        #expect(json == repeatedJSON)
    }
}
