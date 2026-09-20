import Foundation
import Testing
@testable import Reflex

@MainActor
struct ContextEngineTests {
    @Test func pausedEngineDoesNotEmitSnapshots() async {
        let collector = SnapshotCollector()
        let engine = makeEngine(
            application: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            onSnapshot: { await collector.append($0) }
        )

        await engine.pause()
        await engine.captureNow()

        #expect(await collector.values().isEmpty)
    }

    @Test func pausingCancelsAPendingDebouncedCapture() async {
        let collector = SnapshotCollector()
        let gate = SleepGate()
        let engine = ContextEngine(
            activeApplicationProvider: MutableApplicationProvider(
                application: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
            ),
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(clipboard: nil),
            minimumInterval: .zero,
            sleep: { _ in await gate.wait() },
            onSnapshot: { await collector.append($0) }
        )

        await engine.foregroundApplicationDidChange()
        await Task.yield()
        await engine.pause()
        await gate.release()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(await collector.values().isEmpty)
    }

    @Test func rejectsMateriallyDuplicateSnapshots() async {
        let collector = SnapshotCollector()
        let engine = makeEngine(
            application: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            onSnapshot: { await collector.append($0) }
        )

        await engine.captureNow()
        await engine.captureNow()

        #expect(await collector.values().count == 1)
    }

    @Test func foregroundChangesAreDebouncedBeforeCapture() async {
        let collector = SnapshotCollector()
        let gate = SleepGate()
        let application = MutableApplicationProvider(
            application: ApplicationContext(name: "Safari", bundleIdentifier: "com.apple.Safari")
        )
        let engine = ContextEngine(
            activeApplicationProvider: application,
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(clipboard: nil),
            minimumInterval: .zero,
            now: { Date(timeIntervalSince1970: 1) },
            sleep: { _ in await gate.wait() },
            onSnapshot: { await collector.append($0) }
        )

        await engine.foregroundApplicationDidChange()
        #expect(await collector.values().isEmpty)

        await Task.yield()
        await gate.release()
        await eventually { await collector.values().count == 1 }
    }

    @Test func automaticForegroundCaptureOmitsClipboard() async {
        let collector = SnapshotCollector()
        let gate = SleepGate()
        let engine = ContextEngine(
            activeApplicationProvider: MutableApplicationProvider(
                application: ApplicationContext(name: "Safari", bundleIdentifier: "com.apple.Safari")
            ),
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(
                clipboard: ClipboardContext(kind: .text, text: "private clipboard", wasTruncated: false)
            ),
            minimumInterval: .zero,
            sleep: { _ in await gate.wait() },
            onSnapshot: { await collector.append($0) }
        )

        await engine.foregroundApplicationDidChange()
        await Task.yield()
        await gate.release()

        await eventually { await collector.values().count == 1 }
        #expect(await collector.values().first?.clipboard == nil)
    }

    @Test func explicitClipboardCaptureIncludesClipboard() async {
        let collector = SnapshotCollector()
        let clipboard = ClipboardContext(kind: .text, text: "explicit clipboard", wasTruncated: false)
        let engine = ContextEngine(
            activeApplicationProvider: MutableApplicationProvider(
                application: ApplicationContext(name: "Safari", bundleIdentifier: "com.apple.Safari")
            ),
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(clipboard: clipboard),
            minimumInterval: .zero,
            onSnapshot: { await collector.append($0) }
        )

        await engine.captureClipboardNow()

        #expect(await collector.values().first?.clipboard == clipboard)
    }

    @Test func minimumIntervalSuppressesCaptureUntilEnoughTimePasses() async {
        let collector = SnapshotCollector()
        let clock = TestClock(dates: [
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 11)
        ])
        let elapsed = TestElapsedClock(values: [.zero, .seconds(1), .seconds(11)])
        let app = MutableApplicationProvider(application: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"))
        let engine = ContextEngine(
            activeApplicationProvider: app,
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(clipboard: nil),
            minimumInterval: .seconds(10),
            now: { await clock.next() },
            elapsedNow: { await elapsed.next() },
            onSnapshot: { await collector.append($0) }
        )

        await engine.captureNow()
        app.set(ApplicationContext(name: "Safari", bundleIdentifier: "com.apple.Safari"))
        await engine.captureNow()
        await engine.captureNow()

        #expect(await collector.values().map(\.activeApplication.name) == ["Xcode", "Safari"])
    }

    @Test func wallClockRegressionDoesNotBlockElapsedCapture() async {
        let collector = SnapshotCollector()
        let app = MutableApplicationProvider(application: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"))
        let dates = TestClock(dates: [
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 50)
        ])
        let elapsed = TestElapsedClock(values: [.zero, .milliseconds(20)])
        let engine = ContextEngine(
            activeApplicationProvider: app,
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(clipboard: nil),
            minimumInterval: .milliseconds(20),
            now: { await dates.next() },
            elapsedNow: { await elapsed.next() },
            onSnapshot: { await collector.append($0) }
        )

        await engine.captureNow()
        app.set(ApplicationContext(name: "Safari", bundleIdentifier: "com.apple.Safari"))
        await engine.captureNow()

        #expect(await collector.values().map(\.activeApplication.name) == ["Xcode", "Safari"])
    }

    @Test func rapidForegroundChangesCaptureOnlyTheLatestApplication() async {
        let collector = SnapshotCollector()
        let sleeper = RecordingSleeper()
        let application = MutableApplicationProvider(
            application: ApplicationContext(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
        )
        let engine = ContextEngine(
            activeApplicationProvider: application,
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(clipboard: nil),
            minimumInterval: .zero,
            debounceInterval: .milliseconds(5),
            sleep: { duration in try await sleeper.sleep(for: duration) },
            onSnapshot: { await collector.append($0) }
        )

        await engine.foregroundApplicationDidChange()
        await eventually { await sleeper.waitingCount() == 1 }
        application.set(ApplicationContext(name: "Safari", bundleIdentifier: "com.apple.Safari"))
        await engine.foregroundApplicationDidChange()
        await eventually { await sleeper.waitingCount() == 2 }
        await sleeper.releaseAll()

        await eventually { await collector.values().count == 1 }
        #expect(await collector.values().map(\.activeApplication.name) == ["Safari"])
        #expect(await sleeper.requestedDurations() == [.milliseconds(5), .milliseconds(5)])
    }

    @Test func recentApplicationHistoryIsCappedAtFive() async throws {
        let collector = SnapshotCollector()
        let app = MutableApplicationProvider(application: ApplicationContext(name: "App 1", bundleIdentifier: "com.example.1"))
        let engine = ContextEngine(
            activeApplicationProvider: app,
            activeWindowProvider: FakeActiveWindowProvider(window: nil),
            clipboardProvider: FakeClipboardProvider(clipboard: nil),
            minimumInterval: .zero,
            onSnapshot: { await collector.append($0) }
        )

        for index in 1...6 {
            app.set(ApplicationContext(name: "App \(index)", bundleIdentifier: "com.example.\(index)"))
            await engine.captureNow()
        }

        let values = await collector.values()
        let snapshot = try #require(values.last)
        #expect(snapshot.recentApplications.map(\.name) == ["App 2", "App 3", "App 4", "App 5", "App 6"])
    }
}

@MainActor
private func makeEngine(
    application: ApplicationContext,
    onSnapshot: @escaping @Sendable (ContextSnapshot) async -> Void
) -> ContextEngine {
    ContextEngine(
        activeApplicationProvider: MutableApplicationProvider(application: application),
        activeWindowProvider: FakeActiveWindowProvider(window: nil),
        clipboardProvider: FakeClipboardProvider(clipboard: nil),
        minimumInterval: .zero,
        onSnapshot: onSnapshot
    )
}

private actor SnapshotCollector {
    private var snapshots: [ContextSnapshot] = []
    func append(_ snapshot: ContextSnapshot) { snapshots.append(snapshot) }
    func values() -> [ContextSnapshot] { snapshots }
}

private actor TestClock {
    private var dates: [Date]
    init(dates: [Date]) { self.dates = dates }
    func next() -> Date { dates.removeFirst() }
}

private actor TestElapsedClock {
    private var values: [Duration]
    init(values: [Duration]) { self.values = values }
    func next() -> Duration { values.removeFirst() }
}

private actor SleepGate {
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async { await withCheckedContinuation { continuation = $0 } }
    func release() { continuation?.resume(); continuation = nil }
}

private actor RecordingSleeper {
    private var durations: [Duration] = []
    private var continuations: [CheckedContinuation<Void, Error>] = []

    func sleep(for duration: Duration) async throws {
        durations.append(duration)
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitingCount() -> Int { continuations.count }
    func requestedDurations() -> [Duration] { durations }

    func releaseAll() {
        let pending = continuations
        continuations = []
        for continuation in pending {
            continuation.resume()
        }
    }
}

@MainActor
private final class MutableApplicationProvider: ActiveApplicationProvider, @unchecked Sendable {
    private var application: ApplicationContext?
    init(application: ApplicationContext?) { self.application = application }
    func activeApplication() -> ApplicationContext? { application }
    func set(_ application: ApplicationContext?) { self.application = application }
}

@MainActor
private struct FakeActiveWindowProvider: ActiveWindowProvider {
    let window: WindowContext?
    func activeWindow() -> WindowContext? { window }
}

@MainActor
private struct FakeClipboardProvider: ClipboardProvider {
    let clipboard: ClipboardContext?
    func clipboardContents() -> ClipboardContext? { clipboard }
}

private func eventually(
    timeout: Duration = .seconds(1),
    condition: @escaping @Sendable () async -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while !(await condition()) && ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
}
