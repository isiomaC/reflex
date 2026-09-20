import AppKit

@MainActor
protocol ClipboardProvider {
    func clipboardContents() -> ClipboardContext?
}

enum ClipboardSourceContents {
    case empty
    case text(String)
    case nonText
}

@MainActor
struct NSPasteboardClipboardProvider: ClipboardProvider {
    private let readContents: @MainActor () -> ClipboardSourceContents

    init(readContents: @escaping @MainActor () -> ClipboardSourceContents = Self.readPasteboardContents) {
        self.readContents = readContents
    }

    func clipboardContents() -> ClipboardContext? {
        switch readContents() {
        case .empty:
            return nil
        case let .text(text):
            let sourceLength = text.count
            let boundedSourceText = String(text.prefix(ClipboardContext.maximumTextLength + 1))
            return ClipboardContext(
                kind: .text,
                text: boundedSourceText,
                wasTruncated: sourceLength > ClipboardContext.maximumTextLength,
                textLength: sourceLength
            )
        case .nonText:
            return ClipboardContext(kind: .nonText, text: nil, wasTruncated: false)
        }
    }

    private static func readPasteboardContents() -> ClipboardSourceContents {
        guard let items = NSPasteboard.general.pasteboardItems, !items.isEmpty else {
            return .empty
        }

        if let text = items.lazy.compactMap({ $0.string(forType: .string) }).first, !text.isEmpty {
            return .text(text)
        }

        return .nonText
    }
}
