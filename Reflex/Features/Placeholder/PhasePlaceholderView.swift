import SwiftUI

struct InspectorView: View {
    let model: AppModel
    @State private var selectedRecordID: UUID?
    @State private var activityFilter = "All"

    private var displayedRecords: [DecisionRecord] {
        let records = model.historyRecords
        if activityFilter == "All" {
            return records
        }
        return records.filter { record in
            record.selectedActivity == activityFilter
        }
    }

    private var selectedRecord: DecisionRecord? {
        guard let selectedRecordID else { return nil }
        for record in model.historyRecords where record.id == selectedRecordID {
            return record
        }
        return nil
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                Picker("Activity", selection: $activityFilter) {
                    Text("All activities").tag("All")
                    ForEach(Array(Set(model.historyRecords.map(\.selectedActivity))).sorted(), id: \.self) { activity in
                        Text(activity.capitalized).tag(activity)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                InspectorHistoryList(records: displayedRecords, selectedRecordID: $selectedRecordID)
            }
            InspectorDetail(record: selectedRecord)
        }
        .navigationTitle("Inspector")
        .toolbar {
            Button("Clear history", role: .destructive) {
                model.clearHistory()
                selectedRecordID = nil
            }
            .disabled(model.historyRecords.isEmpty)
        }
    }
}

private struct InspectorHistoryList: View {
    let records: [DecisionRecord]
    @Binding var selectedRecordID: UUID?

    var body: some View {
        List(records, id: \.id) { record in
            Button {
                selectedRecordID = record.id
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.selectedActivity.capitalized).font(.headline)
                    Text(record.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 220)
    }
}

private struct InspectorDetail: View {
    let record: DecisionRecord?

    var body: some View {
        Group {
            if let record {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Decision detail").font(.largeTitle.bold())
                        LabeledContent("Activity", value: record.selectedActivity)
                        LabeledContent("Suggested action", value: record.selectedAction)
                        LabeledContent("Intervention", value: record.interventionUsefulness.formatted(.percent))
                        LabeledContent("Latency", value: "\(record.latencyMilliseconds) ms")
                        Text("Sanitized state").font(.headline)
                        Text(record.sanitizedState)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(28)
                }
            } else {
                ContentUnavailableView("No stored decisions", systemImage: "clock.arrow.circlepath", description: Text("Capture local context in Live Jev mode to build on-device history."))
            }
        }
        .frame(minWidth: 420)
    }
}

struct PhasePlaceholderView: View {
    let title: String
    let systemImage: String
    let phase: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            VStack(spacing: 8) {
                Text(phase)
                    .font(.headline)
                Text(description)
            }
        }
    }
}
