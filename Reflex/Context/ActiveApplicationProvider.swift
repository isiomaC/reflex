import AppKit

protocol ActiveApplicationProvider: Sendable {
    func activeApplication() -> ApplicationContext?
}

struct NSWorkspaceActiveApplicationProvider: ActiveApplicationProvider {
    func activeApplication() -> ApplicationContext? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return ApplicationContext(
            name: application.localizedName ?? "",
            bundleIdentifier: application.bundleIdentifier ?? ""
        )
    }
}
