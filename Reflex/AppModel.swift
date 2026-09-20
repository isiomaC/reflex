import AppKit
import ApplicationServices
import Foundation
import Observation

enum AppDestination: Hashable, Sendable {
    case lens
    case inspector
    case replayLab
}

enum ProviderMode: String, CaseIterable, Equatable, Sendable {
    case mock
    case live

    var title: String {
        switch self {
        case .mock: "Mock sample"
        case .live: "Live Jev (Phase 3)"
        }
    }
}

enum DecisionFreshness: Equatable, Sendable {
    case fresh
    case stale
}

protocol ContextCaptureControlling: Sendable {
    func captureNow() async
    func captureClipboardNow() async
    func pause() async
    func resume() async
    func foregroundApplicationDidChange() async
}

extension ContextEngine: ContextCaptureControlling {}

@MainActor
@Observable
final class AppModel {
    private static let providerModeDefaultsKey = "providerMode"
    private static let clipboardCaptureDefaultsKey = "clipboardCaptureEnabled"
    private static let windowMetadataDefaultsKey = "windowMetadataEnabled"
    private static let minimumIntervalDefaultsKey = "contextMinimumInterval"

    var destination: AppDestination = .lens
    var providerMode: ProviderMode {
        didSet {
            defaults.set(providerMode.rawValue, forKey: Self.providerModeDefaultsKey)
            if providerMode == .live {
                requestLiveDecisionForCurrentContext()
            }
        }
    }
    var isPaused = false {
        didSet { updatePausedState() }
    }
    var isClipboardCaptureEnabled: Bool {
        didSet { defaults.set(isClipboardCaptureEnabled, forKey: Self.clipboardCaptureDefaultsKey) }
    }
    var isWindowMetadataEnabled: Bool {
        didSet {
            defaults.set(isWindowMetadataEnabled, forKey: Self.windowMetadataDefaultsKey)
            rebuildContextCaptureControllerIfNeeded()
        }
    }
    var minimumContextInterval: Double {
        didSet {
            let boundedInterval = max(1, minimumContextInterval)
            guard minimumContextInterval == boundedInterval else {
                minimumContextInterval = boundedInterval
                return
            }
            defaults.set(minimumContextInterval, forKey: Self.minimumIntervalDefaultsKey)
            rebuildContextCaptureControllerIfNeeded()
        }
    }
    private(set) var context: SampleContext
    private(set) var decision: MockDecision
    private(set) var decisionUpdatedAt: Date
    private(set) var localContext: ContextSnapshot?
    private(set) var liveDecision: DecisionLensResult?
    private(set) var liveDecisionError: LiveDecisionError?

    private let decisionProvider: any DecisionProvider
    private let liveDecisionProvider: (any LiveDecisionProviding)?
    private let decisionCoordinator = DecisionLensCoordinator()
    private let samples: [SampleContext]
    private let now: () -> Date
    private let defaults: UserDefaults
    private var sampleIndex: Int
    private var contextCaptureController: (any ContextCaptureControlling)?
    private var applicationActivationObserver: NSObjectProtocol?
    private let accessibilityPermissionRequester: @MainActor () -> Void

    var liveModeMessage: String? {
        providerMode == .live ? "Live Jev uses the sanitized payload shown in Lens." : nil
    }

    var isUsingReducedContext: Bool {
        localContext?.activeWindow == nil
    }

    var sanitizedContextJSON: String? {
        try? localContext?.sanitizedJSON()
    }

    init(
        sampleContextProvider: any SampleContextProvider = StaticSampleContextProvider(),
        decisionProvider: any DecisionProvider = MockDecisionProvider(),
        liveDecisionProvider: (any LiveDecisionProviding)? = LiveDecisionProvider(),
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard,
        contextCaptureController: (any ContextCaptureControlling)? = nil,
        accessibilityPermissionRequester: @escaping @MainActor () -> Void = { AppModel.requestAccessibilityPermission() }
    ) {
        let initialContext = sampleContextProvider.currentContext()
        let availableSamples = SampleContext.allCases

        self.decisionProvider = decisionProvider
        self.liveDecisionProvider = liveDecisionProvider
        self.now = now
        self.defaults = defaults
        samples = availableSamples
        providerMode = ProviderMode(rawValue: defaults.string(forKey: Self.providerModeDefaultsKey) ?? "") ?? .mock
        isClipboardCaptureEnabled = defaults.bool(forKey: Self.clipboardCaptureDefaultsKey)
        isWindowMetadataEnabled = defaults.bool(forKey: Self.windowMetadataDefaultsKey)
        let storedMinimumInterval = defaults.double(forKey: Self.minimumIntervalDefaultsKey)
        minimumContextInterval = storedMinimumInterval >= 1 ? storedMinimumInterval : 1
        context = initialContext
        decision = decisionProvider.decision(for: initialContext)
        decisionUpdatedAt = now()
        sampleIndex = availableSamples.firstIndex(of: initialContext) ?? 0
        self.contextCaptureController = contextCaptureController
        self.accessibilityPermissionRequester = accessibilityPermissionRequester
    }

    func captureNextSample() {
        guard !isPaused, !samples.isEmpty else { return }

        sampleIndex = (sampleIndex + 1) % samples.count
        context = samples[sampleIndex]
        decision = decisionProvider.decision(for: context)
        decisionUpdatedAt = now()
    }

    func startLocalContextCapture() {
        guard contextCaptureController == nil else { return }
        contextCaptureController = makeContextCaptureController()
        applicationActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.foregroundApplicationDidChange()
            }
        }
    }

    func captureLocalContext() {
        guard !isPaused else { return }
        let controller = contextCaptureController
        Task { await controller?.captureNow() }
    }

    func captureClipboardNow() {
        guard !isPaused, isClipboardCaptureEnabled else { return }
        let controller = contextCaptureController
        Task { await controller?.captureClipboardNow() }
    }

    func clearLocalContext() {
        localContext = nil
    }

    func requestWindowMetadataAccess() {
        guard !isWindowMetadataEnabled else { return }
        isWindowMetadataEnabled = true
        accessibilityPermissionRequester()
    }

    func receiveLocalContext(_ snapshot: ContextSnapshot) {
        localContext = snapshot
        requestLiveDecision(for: snapshot)
    }

    func requestLiveDecisionForCurrentContext() {
        guard let localContext else { return }
        requestLiveDecision(for: localContext)
    }

    func decisionFreshness(at date: Date) -> DecisionFreshness {
        date.timeIntervalSince(decisionUpdatedAt) <= 60 ? .fresh : .stale
    }

    private func updatePausedState() {
        let controller = contextCaptureController
        Task {
            if isPaused {
                await controller?.pause()
            } else {
                await controller?.resume()
            }
        }
    }

    private func foregroundApplicationDidChange() {
        let controller = contextCaptureController
        Task { await controller?.foregroundApplicationDidChange() }
    }

    private func requestLiveDecision(for snapshot: ContextSnapshot) {
        guard providerMode == .live, !isPaused, let liveDecisionProvider else { return }
        liveDecisionError = nil
        let coordinator = decisionCoordinator
        Task {
            let request = await coordinator.beginRequest(for: snapshot.id)
            do {
                let result = try await liveDecisionProvider.decide(for: snapshot)
                guard let accepted = await coordinator.accept(result, for: request) else { return }
                liveDecision = accepted
                decisionUpdatedAt = now()
            } catch is CancellationError {
                return
            } catch let error as LiveDecisionError {
                guard await coordinator.accept(errorResult(for: snapshot), for: request) != nil else { return }
                liveDecisionError = error
            } catch {
                guard await coordinator.accept(errorResult(for: snapshot), for: request) != nil else { return }
                liveDecisionError = .offline
            }
        }
    }

    private func errorResult(for snapshot: ContextSnapshot) -> DecisionLensResult {
        DecisionLensResult(snapshotID: snapshot.id, latency: .zero, activity: ActivityDecision(selected: .other, rawProbabilities: [.other: 1]), intervention: InterventionDecision(selected: false, rawProbabilities: [false: 1]), suggestedAction: SuggestedActionDecision(selected: .doNothing, rawProbabilities: [.doNothing: 1]))
    }

    private func rebuildContextCaptureControllerIfNeeded() {
        guard contextCaptureController is ContextEngine else { return }
        contextCaptureController = makeContextCaptureController()
        if isPaused { updatePausedState() }
    }

    private func makeContextCaptureController() -> ContextEngine {
        ContextEngine(
            activeApplicationProvider: NSWorkspaceActiveApplicationProvider(),
            activeWindowProvider: ConditionalWindowProvider(
                isEnabled: { [weak self] in self?.isWindowMetadataEnabled ?? false },
                source: AXActiveWindowProvider()
            ),
            clipboardProvider: ConditionalClipboardProvider(
                isEnabled: { [weak self] in self?.isClipboardCaptureEnabled ?? false },
                source: NSPasteboardClipboardProvider()
            ),
            minimumInterval: .seconds(minimumContextInterval),
            onSnapshot: { [weak self] snapshot in
                await self?.receiveLocalContext(snapshot)
            }
        )
    }

    private static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

@MainActor
private struct ConditionalWindowProvider<Source: ActiveWindowProvider>: ActiveWindowProvider {
    let isEnabled: @MainActor () -> Bool
    let source: Source

    func activeWindow() -> WindowContext? {
        isEnabled() ? source.activeWindow() : nil
    }
}

@MainActor
private struct ConditionalClipboardProvider<Source: ClipboardProvider>: ClipboardProvider {
    let isEnabled: @MainActor () -> Bool
    let source: Source

    func clipboardContents() -> ClipboardContext? {
        isEnabled() ? source.clipboardContents() : nil
    }
}
