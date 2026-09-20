import AppKit
import ApplicationServices

protocol ActiveWindowProvider: Sendable {
    func activeWindow() -> WindowContext?
}

struct AXActiveWindowProvider: ActiveWindowProvider {
    func activeWindow() -> WindowContext? {
        guard AXIsProcessTrusted(),
              let application = NSWorkspace.shared.frontmostApplication
        else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedWindowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        ) == .success,
        let focusedWindowValue,
        CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID()
        else {
            return nil
        }
        let focusedWindow = unsafeDowncast(focusedWindowValue, to: AXUIElement.self)

        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedWindow,
            kAXTitleAttribute as CFString,
            &titleValue
        ) == .success,
        let title = titleValue as? String,
        !title.isEmpty
        else {
            return nil
        }

        return WindowContext(title: title)
    }
}
