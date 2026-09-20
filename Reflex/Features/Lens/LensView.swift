import SwiftUI

struct LensView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                privacyNotice
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    decisionStatus(at: timeline.date)
                }
                contextCard
                sentContextCard
                decisionGrid
                controls
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle("Lens")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(model.isPaused ? "Resume" : "Pause", systemImage: model.isPaused ? "play.fill" : "pause.fill") {
                    model.isPaused.toggle()
                }
                .accessibilityLabel(model.isPaused ? "Resume local context" : "Pause local context")

                Button("Capture", systemImage: "arrow.clockwise") {
                    model.captureLocalContext()
                }
                .disabled(model.isPaused)
                .accessibilityLabel("Capture local context")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Decision Lens")
                .font(.largeTitle.bold())
            Text(model.isPaused ? "Local context capture paused" : "Local context stays on this Mac in mock mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var privacyNotice: some View {
        Label("Mock mode — sanitized local context remains on this Mac", systemImage: "eye.slash")
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: .rect(cornerRadius: 14))
    }

    private func decisionStatus(at date: Date) -> some View {
        let isFresh = model.decisionFreshness(at: date) == .fresh

        return HStack(spacing: 12) {
            Label(providerModeTitle, systemImage: providerModeSystemImage)
                .font(.headline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Label(isFresh ? "Fresh decision" : "Stale decision", systemImage: isFresh ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isFresh ? Color.primary : Color.orange)
                Text(model.decisionUpdatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
    }

    private var providerModeTitle: String {
        switch model.providerMode {
        case .mock:
            "Mock decisions — local-only context"
        case .live:
            "Live Jev selected — unavailable until Phase 3"
        }
    }

    private var providerModeSystemImage: String {
        model.providerMode == .mock ? "circle.fill" : "lock.fill"
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Local context", systemImage: "macwindow")
                .font(.headline)
                .foregroundStyle(.secondary)
            if let context = model.localContext {
                HStack {
                    Text(context.activeApplication.name.isEmpty ? "Unknown app" : context.activeApplication.name)
                        .font(.title3.bold())
                    if model.isUsingReducedContext {
                        Label("Reduced context", systemImage: "rectangle.badge.xmark")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
                Text(context.activeWindow?.title ?? "Window metadata is unavailable or not enabled.")
                    .foregroundStyle(.secondary)
            } else {
                Text("No local context captured")
                    .font(.title3.bold())
                Text("Capture local context to inspect the privacy-bounded snapshot on this Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var sentContextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sent to Jev", systemImage: "shield.lefthalf.filled")
                .font(.headline)
            Text("This exact sanitized payload remains local in mock mode. No Jev request is made.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(model.sanitizedContextJSON ?? "Capture local context to preview the sanitized payload.")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary, in: .rect(cornerRadius: 10))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var decisionGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                decisionCard("Activity", value: model.decision.activity.selected.rawValue.capitalized, systemImage: "bolt.fill")
                decisionCard("Confidence", value: Text(model.decision.activity.confidence, format: .percent.precision(.fractionLength(0))), systemImage: "chart.bar.fill")
            }
            GridRow {
                decisionCard("Intervention", value: Text(model.decision.interventionUsefulness, format: .percent.precision(.fractionLength(0))), systemImage: "hand.raised.fill")
                suggestionCard
            }
        }
    }

    private func decisionCard(_ title: String, value: String, systemImage: String) -> some View {
        decisionCard(title, value: Text(value), systemImage: systemImage)
    }

    private func decisionCard(_ title: String, value: Text, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            value
                .font(.title2.bold())
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
    }

    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suggestion", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(model.decision.suggestion)
                .font(.body)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(model.isPaused ? "Resume local context" : "Pause local context") {
                model.isPaused.toggle()
            }
            .accessibilityLabel(model.isPaused ? "Resume local context" : "Pause local context")

            Button("Capture local context") {
                model.captureLocalContext()
            }
            .disabled(model.isPaused)
            .accessibilityLabel("Capture local context")
        }
        .controlSize(.large)
    }
}
