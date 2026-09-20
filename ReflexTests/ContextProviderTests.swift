import ApplicationServices
import Testing
@testable import Reflex

@MainActor
struct ContextProviderTests {
    @Test func workspaceProviderReturnsNilWhenThereIsNoFrontmostApplication() {
        let provider = NSWorkspaceActiveApplicationProvider(frontmostApplication: { nil })

        #expect(provider.activeApplication() == nil)
    }

    @Test func accessibilityProviderReturnsNilWhenAccessibilityIsUntrusted() {
        let provider = AXActiveWindowProvider(
            isProcessTrusted: { false },
            frontmostProcessIdentifier: { 42 },
            focusedWindowValue: { _ in AXUIElementCreateSystemWide() },
            windowTitleValue: { _ in "A window" as CFString }
        )

        #expect(provider.activeWindow() == nil)
    }

    @Test func accessibilityProviderReturnsNilWhenThereIsNoFrontmostApplication() {
        let provider = AXActiveWindowProvider(
            isProcessTrusted: { true },
            frontmostProcessIdentifier: { nil },
            focusedWindowValue: { _ in AXUIElementCreateSystemWide() },
            windowTitleValue: { _ in "A window" as CFString }
        )

        #expect(provider.activeWindow() == nil)
    }

    @Test func accessibilityProviderReturnsNilForANonAccessibilityFocusedWindowValue() {
        let provider = AXActiveWindowProvider(
            isProcessTrusted: { true },
            frontmostProcessIdentifier: { 42 },
            focusedWindowValue: { _ in "not an accessibility element" as CFString },
            windowTitleValue: { _ in "A window" as CFString }
        )

        #expect(provider.activeWindow() == nil)
    }

    @Test func accessibilityProviderReturnsNilForANonStringWindowTitle() {
        let provider = AXActiveWindowProvider(
            isProcessTrusted: { true },
            frontmostProcessIdentifier: { 42 },
            focusedWindowValue: { _ in AXUIElementCreateSystemWide() },
            windowTitleValue: { _ in 1 as CFNumber }
        )

        #expect(provider.activeWindow() == nil)
    }

    @Test func accessibilityProviderReturnsNilForAnEmptyWindowTitle() {
        let provider = AXActiveWindowProvider(
            isProcessTrusted: { true },
            frontmostProcessIdentifier: { 42 },
            focusedWindowValue: { _ in AXUIElementCreateSystemWide() },
            windowTitleValue: { _ in "" as CFString }
        )

        #expect(provider.activeWindow() == nil)
    }
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

    @Test func pasteboardProviderReturnsTextContent() {
        let provider = NSPasteboardClipboardProvider(readContents: { .text("copied text") })

        let clipboard = provider.clipboardContents()

        #expect(clipboard == ClipboardContext(kind: .text, text: "copied text", wasTruncated: false))
    }

    @Test func pasteboardProviderReturnsANonTextDescriptor() {
        let provider = NSPasteboardClipboardProvider(readContents: { .nonText })

        #expect(provider.clipboardContents() == ClipboardContext(kind: .nonText, text: nil, wasTruncated: false))
    }

    @Test func pasteboardProviderBoundsSourceTextBeforeCreatingContext() {
        let original = String(repeating: "x", count: ClipboardContext.maximumTextLength + 10)
        let provider = NSPasteboardClipboardProvider(readContents: { .text(original) })

        let clipboard = provider.clipboardContents()

        #expect(clipboard?.text?.count == ClipboardContext.maximumTextLength)
        #expect(clipboard?.wasTruncated == true)
        #expect(clipboard?.textLength == original.count)
    }
}

@MainActor
private struct FakeActiveWindowProvider: ActiveWindowProvider {
    let window: WindowContext?

    func activeWindow() -> WindowContext? {
        window
    }
}

@MainActor
private struct FakeClipboardProvider: ClipboardProvider {
    let clipboard: ClipboardContext?

    func clipboardContents() -> ClipboardContext? {
        clipboard
    }
}
