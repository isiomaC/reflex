import AppKit

protocol ClipboardProvider: Sendable {
    func clipboardContents() -> ClipboardContext?
}

struct NSPasteboardClipboardProvider: ClipboardProvider {
    func clipboardContents() -> ClipboardContext? {
        guard let items = NSPasteboard.general.pasteboardItems, !items.isEmpty else {
            return nil
        }

        if let text = items.lazy.compactMap({ $0.string(forType: .string) }).first, !text.isEmpty {
            return ClipboardContext(kind: .text, text: text, wasTruncated: false)
        }

        return ClipboardContext(kind: .nonText, text: nil, wasTruncated: false)
    }
}
