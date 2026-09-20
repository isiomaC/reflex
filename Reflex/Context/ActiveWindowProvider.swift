import AppKit
import ApplicationServices

@MainActor
protocol ActiveWindowProvider {
    func activeWindow() -> WindowContext?
}

@MainActor
struct AXActiveWindowProvider: ActiveWindowProvider {
    private let isProcessTrusted: @MainActor () -> Bool
    private let frontmostProcessIdentifier: @MainActor () -> pid_t?
    private let focusedWindowValue: @MainActor (pid_t) -> CFTypeRef?
    private let windowTitleValue: @MainActor (AXUIElement) -> CFTypeRef?

    init(
        isProcessTrusted: @escaping @MainActor () -> Bool = { AXIsProcessTrusted() },
        frontmostProcessIdentifier: @escaping @MainActor () -> pid_t? = {
            NSWorkspace.shared.frontmostApplication?.processIdentifier
        },
        focusedWindowValue: @escaping @MainActor (pid_t) -> CFTypeRef? = Self.copyFocusedWindowValue,
        windowTitleValue: @escaping @MainActor (AXUIElement) -> CFTypeRef? = Self.copyWindowTitleValue
    ) {
        self.isProcessTrusted = isProcessTrusted
        self.frontmostProcessIdentifier = frontmostProcessIdentifier
        self.focusedWindowValue = focusedWindowValue
        self.windowTitleValue = windowTitleValue
    }

    func activeWindow() -> WindowContext? {
        guard isProcessTrusted(),
              let processIdentifier = frontmostProcessIdentifier()
        else {
            return nil
        }

        guard let focusedWindowValue = focusedWindowValue(processIdentifier),
              CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID()
        else {
            return nil
        }
        // The Core Foundation type ID above establishes this bridge is valid.
        let focusedWindow = focusedWindowValue as! AXUIElement

        guard let titleValue = windowTitleValue(focusedWindow),
              let title = titleValue as? String,
        !title.isEmpty
        else {
            return nil
        }

        return WindowContext(title: title)
    }

    private static func copyFocusedWindowValue(processIdentifier: pid_t) -> CFTypeRef? {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        var focusedWindowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        ) == .success else {
            return nil
        }
        return focusedWindowValue
    }

    private static func copyWindowTitleValue(window: AXUIElement) -> CFTypeRef? {
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleValue
        ) == .success else {
            return nil
        }
        return titleValue
    }
}
