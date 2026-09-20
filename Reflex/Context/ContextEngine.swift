import Foundation

actor ContextEngine {
    typealias SnapshotHandler = @Sendable (ContextSnapshot) async -> Void
    typealias Now = @Sendable () async -> Date
    typealias Sleeper = @Sendable (Duration) async throws -> Void

    private let activeApplication: @MainActor () -> ApplicationContext?
    private let activeWindow: @MainActor () -> WindowContext?
    private let clipboard: @MainActor () -> ClipboardContext?
    private let minimumInterval: Duration
    private let now: Now
    private let sleep: Sleeper
    private let onSnapshot: SnapshotHandler

    private var isPaused = false
    private var lastEmittedSnapshot: ContextSnapshot?
    private var lastEmissionDate: Date?
    private var recentApplications: [ApplicationContext] = []
    private var debounceTask: Task<Void, Never>?

    @MainActor
    init(
        activeApplicationProvider: some ActiveApplicationProvider,
        activeWindowProvider: some ActiveWindowProvider,
        clipboardProvider: some ClipboardProvider,
        minimumInterval: Duration = .seconds(1),
        now: @escaping Now = { Date() },
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) },
        onSnapshot: @escaping SnapshotHandler
    ) {
        activeApplication = { activeApplicationProvider.activeApplication() }
        activeWindow = { activeWindowProvider.activeWindow() }
        clipboard = { clipboardProvider.clipboardContents() }
        self.minimumInterval = minimumInterval
        self.now = now
        self.sleep = sleep
        self.onSnapshot = onSnapshot
    }

    deinit {
        debounceTask?.cancel()
    }

    func pause() {
        isPaused = true
        debounceTask?.cancel()
        debounceTask = nil
    }

    func resume() {
        isPaused = false
    }

    func captureNow() async {
        guard !isPaused, let application = await activeApplication() else {
            return
        }

        let timestamp = await now()
        guard canEmit(at: timestamp) else {
            return
        }

        record(application)
        let snapshot = ContextSnapshot(
            timestamp: timestamp,
            activeApplication: application,
            activeWindow: await activeWindow(),
            clipboard: await clipboard(),
            recentApplications: recentApplications
        )

        guard !snapshotMatchesLastEmission(snapshot) else {
            return
        }

        lastEmittedSnapshot = snapshot
        lastEmissionDate = timestamp
        await onSnapshot(snapshot)
    }

    func foregroundApplicationDidChange() {
        guard !isPaused else {
            return
        }

        debounceTask?.cancel()
        debounceTask = Task { [weak self, sleep] in
            do {
                try await sleep(.seconds(1))
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            await self?.captureNow()
        }
    }

    private func canEmit(at timestamp: Date) -> Bool {
        guard let lastEmissionDate else {
            return true
        }
        return timestamp.timeIntervalSince(lastEmissionDate) >= minimumInterval.timeInterval
    }

    private func record(_ application: ApplicationContext) {
        recentApplications.removeAll { $0.bundleIdentifier == application.bundleIdentifier }
        recentApplications.append(application)
        recentApplications = ContextSnapshot.boundedRecentApplications(recentApplications)
    }

    private func snapshotMatchesLastEmission(_ snapshot: ContextSnapshot) -> Bool {
        lastEmittedSnapshot?.isMateriallyEqual(to: snapshot) ?? false
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
