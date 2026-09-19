import SwiftUI

struct LensView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                privacyNotice
                contextCard
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
                .accessibilityLabel(model.isPaused ? "Resume sample context" : "Pause sample context")

                Button("Capture", systemImage: "arrow.clockwise") {
                    model.captureNextSample()
                }
                .disabled(model.isPaused)
                .accessibilityLabel("Capture sample context")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Decision Lens")
                .font(.largeTitle.bold())
            Text(model.isPaused ? "Sample feed paused" : "Mock decisions for transparent sample context")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var privacyNotice: some View {
        Label("Mock sample — no desktop context is being observed", systemImage: "eye.slash")
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: .rect(cornerRadius: 14))
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(model.context.sourceLabel, systemImage: "document.text")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(model.context.title)
                .font(.title3.bold())
            Text(model.context.summary)
                .foregroundStyle(.secondary)
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
            Button(model.isPaused ? "Resume sample context" : "Pause sample context") {
                model.isPaused.toggle()
            }
            .accessibilityLabel(model.isPaused ? "Resume sample context" : "Pause sample context")

            Button("Capture sample context") {
                model.captureNextSample()
            }
            .disabled(model.isPaused)
            .accessibilityLabel("Capture sample context")
        }
        .controlSize(.large)
    }
}
