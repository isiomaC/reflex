import AppKit
import SwiftUI

@main
struct ReflexApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ReflexRootView(model: model)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    model.destination = .settings
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",")
            }
        }

        MenuBarExtra("Reflex", systemImage: model.isPaused ? "pause.circle" : "sparkle") {
            Button("Open Reflex") {
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(model.isPaused ? "Resume sample context" : "Pause sample context") {
                model.isPaused.toggle()
            }
            .accessibilityLabel(model.isPaused ? "Resume sample context" : "Pause sample context")

            Button("Capture sample context") {
                model.captureNextSample()
            }
            .disabled(model.isPaused)
            .accessibilityLabel("Capture sample context")

            Divider()

            Button("Settings…") {
                model.destination = .settings
                NSApp.activate(ignoringOtherApps: true)
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
                    Label("Inspector", systemImage: "slider.horizontal.3")
                        .tag(AppDestination.inspector)
                    Label("Replay Lab", systemImage: "play.rectangle")
                        .tag(AppDestination.replayLab)
                }

                Section {
                    Label("Settings", systemImage: "gearshape")
                        .tag(AppDestination.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
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
            PhasePlaceholderView(
                title: "Inspector",
                systemImage: "slider.horizontal.3",
                phase: "Phase 4",
                description: "Local decision history arrives in Phase 4."
            )
        case .replayLab:
            PhasePlaceholderView(
                title: "Replay Lab",
                systemImage: "play.rectangle",
                phase: "Phase 5",
                description: "Replay Lab arrives in Phase 5."
            )
        case .settings:
            SettingsView(model: model)
        }
    }
}
