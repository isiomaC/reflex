import AppKit
import SwiftUI

@main
struct ReflexApp: App {
    @State private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    init() {
        _model = State(initialValue: AppModel(decisionHistoryStore: try? DecisionHistoryStore.persistent()))
    }

    var body: some Scene {
        WindowGroup("Reflex", id: "reflex-main") {
            ReflexRootView(model: model)
                .task {
                    model.startLocalContextCapture()
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text("Settings…")
                }
                .keyboardShortcut(",")
            }
        }

        Settings {
            SettingsView(model: model)
                .frame(width: 520)
        }

        MenuBarExtra("Reflex", systemImage: model.isPaused ? "pause.circle" : "sparkle") {
            Button("Open Reflex") {
                openWindow(id: "reflex-main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(model.isPaused ? "Resume local context" : "Pause local context") {
                model.isPaused.toggle()
            }
            .accessibilityLabel(model.isPaused ? "Resume local context" : "Pause local context")

            Button("Capture local context") {
                model.captureLocalContext()
            }
            .disabled(model.isPaused)
            .accessibilityLabel("Capture local context")

            Divider()

            SettingsLink {
                Text("Settings…")
            }

            Divider()

            Button("Quit Reflex") {
                NSApp.terminate(nil)
            }
        }
    }
}

private struct ReflexRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.destination) {
                Section("Reflex") {
                    Label("Lens", systemImage: "scope")
                        .tag(AppDestination.lens)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Label("Inspector", systemImage: "slider.horizontal.3")
                        .tag(AppDestination.inspector)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Label("Replay Lab", systemImage: "play.rectangle")
                        .tag(AppDestination.replayLab)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
        } detail: {
            destinationView
        }
        .frame(minWidth: 780, minHeight: 520)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch model.destination {
        case .lens:
            LensView(model: model)
        case .inspector:
            InspectorView(model: model)
        case .replayLab:
            ReplayLabView(model: model)
        }
    }
}
