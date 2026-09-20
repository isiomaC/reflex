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

    @Test func sanitizedJSONNeverSendsRawClipboardOrWindowLabels() throws {
        let clipboardSentinel = "CLIPBOARD-SECRET-DO-NOT-SEND"
        let windowSentinel = "WINDOW-SECRET-DO-NOT-SEND"
        let applicationSentinel = "APPLICATION-SECRET-DO-NOT-SEND"
        let snapshot = ContextSnapshot(
            activeApplication: ApplicationContext(name: applicationSentinel, bundleIdentifier: "com.example.private"),
            activeWindow: WindowContext(title: windowSentinel),
            clipboard: ClipboardContext(kind: .text, text: clipboardSentinel, wasTruncated: false)
        )

        let json = try snapshot.sanitizedJSON()

        #expect(!json.contains(clipboardSentinel))
        #expect(!json.contains(windowSentinel))
        #expect(!json.contains(applicationSentinel))
        #expect(json.contains("\"textLength\" : 27"))
        #expect(json.contains("\"contentKind\" : \"text\""))
        #expect(json.contains("\"redacted\""))
    }

    @Test func decodingNormalizesUntrustedContextValues() throws {
        let oversizedName = String(repeating: "n", count: ApplicationContext.maximumNameLength + 1)
        let oversizedBundle = String(repeating: "b", count: ApplicationContext.maximumBundleIdentifierLength + 1)
        let oversizedTitle = String(repeating: "t", count: WindowContext.maximumTitleLength + 1)
        let oversizedClipboard = String(repeating: "c", count: ClipboardContext.maximumTextLength + 1)
        let apps = (0...ContextSnapshot.maximumRecentApplications).map { index in
            "{\"name\":\"App \\(index)\",\"bundleIdentifier\":\"com.example.\\(index)\"}"
        }.joined(separator: ",")
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "timestamp": "1970-01-01T00:00:00Z",
          "activeApplication": {"name": "\\(oversizedName)", "bundleIdentifier": "\\(oversizedBundle)"},
          "activeWindow": {"title": "\\(oversizedTitle)"},
          "clipboard": {"kind": "unexpected", "text": "\\(oversizedClipboard)", "wasTruncated": false},
          "recentApplications": [\\(apps)]
        }
        """

        let snapshot = try JSONDecoder().decode(ContextSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.activeApplication.name.count == ApplicationContext.maximumNameLength)
        #expect(snapshot.activeApplication.bundleIdentifier.count == ApplicationContext.maximumBundleIdentifierLength)
        #expect(snapshot.activeWindow?.title.count == WindowContext.maximumTitleLength)
        #expect(snapshot.clipboard?.kind == .nonText)
        #expect(snapshot.clipboard?.text == nil)
        #expect(snapshot.recentApplications.count == ContextSnapshot.maximumRecentApplications)
    }
}
