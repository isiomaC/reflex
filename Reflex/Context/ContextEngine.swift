import Foundation

actor ContextEngine {
    typealias SnapshotHandler = @Sendable (ContextSnapshot) async -> Void
    typealias Now = @Sendable () async -> Date
    typealias ElapsedNow = @Sendable () async -> Duration
    typealias Sleeper = @Sendable (Duration) async throws -> Void

    private let activeApplication: @MainActor () -> ApplicationContext?
    private let activeWindow: @MainActor () -> WindowContext?
    private let clipboard: @MainActor () -> ClipboardContext?
    private let minimumInterval: Duration
    private let debounceInterval: Duration
    private let now: Now
    private let elapsedNow: ElapsedNow
    private let sleep: Sleeper
    private let onSnapshot: SnapshotHandler

    private var isPaused = false
    private var lastEmittedSnapshot: ContextSnapshot?
    private var lastEmissionElapsed: Duration?
    private var recentApplications: [ApplicationContext] = []
    private var debounceTask: Task<Void, Never>?

    @MainActor
    init(
        activeApplicationProvider: some ActiveApplicationProvider,
        activeWindowProvider: some ActiveWindowProvider,
        clipboardProvider: some ClipboardProvider,
        minimumInterval: Duration = .seconds(1),
        debounceInterval: Duration = .seconds(1),
        now: @escaping Now = { Date() },
        elapsedNow: ElapsedNow? = nil,
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) },
        onSnapshot: @escaping SnapshotHandler
    ) {
        activeApplication = { activeApplicationProvider.activeApplication() }
        activeWindow = { activeWindowProvider.activeWindow() }
        clipboard = { clipboardProvider.clipboardContents() }
        self.minimumInterval = minimumInterval
        self.debounceInterval = debounceInterval
        self.now = now
        if let elapsedNow {
            self.elapsedNow = elapsedNow
        } else {
            let start = ContinuousClock.now
            self.elapsedNow = { ContinuousClock.now - start }
        }
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
        await capture(includeClipboard: false)
    }

    func captureClipboardNow() async {
        await capture(includeClipboard: true)
    }

    private func capture(includeClipboard: Bool) async {
        guard !isPaused, let application = await activeApplication() else {
            return
        }

        let elapsed = await elapsedNow()
        guard canEmit(at: elapsed) else {
            return
        }
        let timestamp = await now()

        record(application)
        let snapshot = ContextSnapshot(
            timestamp: timestamp,
            activeApplication: application,
            activeWindow: await activeWindow(),
            clipboard: includeClipboard ? await clipboard() : nil,
            recentApplications: recentApplications
        )

        guard !snapshotMatchesLastEmission(snapshot) else {
            return
        }

        lastEmittedSnapshot = snapshot
        lastEmissionElapsed = elapsed
        await onSnapshot(snapshot)
    }

    func foregroundApplicationDidChange() {
        guard !isPaused else {
            return
        }

        debounceTask?.cancel()
        debounceTask = Task { [weak self, sleep] in
            do {
                try await sleep(self?.debounceInterval ?? .seconds(1))
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            await self?.captureNow()
        }
    }

    private func canEmit(at elapsed: Duration) -> Bool {
        guard let lastEmissionElapsed else {
            return true
        }
        return elapsed >= lastEmissionElapsed + minimumInterval
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
