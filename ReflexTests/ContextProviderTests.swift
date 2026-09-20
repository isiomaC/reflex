import Testing
@testable import Reflex

struct ContextProviderTests {
    @Test func fakeActiveWindowProviderReturnsNoWindowWithoutPermission() {
        let provider = FakeActiveWindowProvider(window: nil)

        #expect(provider.activeWindow() == nil)
    }

    @Test func fakeClipboardProviderReturnsNilForEmptyClipboard() {
        let provider = FakeClipboardProvider(clipboard: nil)

        #expect(provider.clipboardContents() == nil)
    }

    @Test func fakeClipboardProviderReturnsNonTextDescriptorWithoutText() {
        let provider = FakeClipboardProvider(
            clipboard: ClipboardContext(kind: .nonText, text: "private", wasTruncated: false)
        )

        let clipboard = provider.clipboardContents()

        #expect(clipboard?.kind == .nonText)
        #expect(clipboard?.text == nil)
    }

    @Test func fakeClipboardProviderReturnsTextNormalizedByDomainInitializer() {
        let oversizedText = String(repeating: "x", count: ClipboardContext.maximumTextLength + 1)
        let provider = FakeClipboardProvider(
            clipboard: ClipboardContext(kind: .text, text: oversizedText, wasTruncated: false)
        )

        let clipboard = provider.clipboardContents()

        #expect(clipboard?.text?.count == ClipboardContext.maximumTextLength)
        #expect(clipboard?.wasTruncated == true)
        #expect(clipboard?.textLength == oversizedText.count)
    }
}

private struct FakeActiveWindowProvider: ActiveWindowProvider {
    let window: WindowContext?

    func activeWindow() -> WindowContext? {
        window
    }
}

private struct FakeClipboardProvider: ClipboardProvider {
    let clipboard: ClipboardContext?

    func clipboardContents() -> ClipboardContext? {
        clipboard
    }
}
