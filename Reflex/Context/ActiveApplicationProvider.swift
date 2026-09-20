import AppKit

@MainActor
protocol ActiveApplicationProvider {
    func activeApplication() -> ApplicationContext?
}

@MainActor
struct NSWorkspaceActiveApplicationProvider: ActiveApplicationProvider {
    private let frontmostApplication: () -> NSRunningApplication?

    init(frontmostApplication: @escaping () -> NSRunningApplication? = {
        NSWorkspace.shared.frontmostApplication
    }) {
        self.frontmostApplication = frontmostApplication
    }

    func activeApplication() -> ApplicationContext? {
        guard let application = frontmostApplication() else {
            return nil
        }

        return ApplicationContext(
            name: application.localizedName ?? "",
            bundleIdentifier: application.bundleIdentifier ?? ""
        )
    }
}
