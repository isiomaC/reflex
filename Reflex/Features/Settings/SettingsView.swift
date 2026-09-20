import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    private let credentialStore: any CredentialStore

    @State private var draftAPIKey = ""
    @State private var hasStoredAPIKey = false
    @State private var statusMessage: String?

    init(model: AppModel, credentialStore: any CredentialStore = KeychainCredentialStore()) {
        self.model = model
        self.credentialStore = credentialStore
    }

    var body: some View {
        Form {
            Section("Decision provider") {
                Picker("Mode", selection: $model.providerMode) {
                    ForEach(ProviderMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(model.liveModeMessage ?? "Mock mode is active. No network request is made.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Jev API key") {
                SecureField("API key", text: $draftAPIKey)
                    .textContentType(.password)

                HStack {
                    Button(hasStoredAPIKey ? "Replace key" : "Save key", action: saveAPIKey)
                        .disabled(draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove key", action: removeAPIKey)
                        .disabled(!hasStoredAPIKey)
                }

                Text(hasStoredAPIKey ? "A key is stored securely in Keychain. Its value is never displayed." : "No API key is stored.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Local context") {
                Toggle("Include clipboard in explicit captures", isOn: $model.isClipboardCaptureEnabled)
                Text("Off by default. Clipboard content is never sent in mock mode; the Lens only shows its sanitized descriptor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Include active-window metadata", isOn: $model.isWindowMetadataEnabled)
                    .disabled(true)

                Button("Enable window metadata access") {
                    model.requestWindowMetadataAccess()
                }
                .disabled(model.isWindowMetadataEnabled)

                Text("This opens macOS Accessibility permission only after you choose to enable it. Without it, Reflex uses reduced context.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Capture local context") {
                        model.captureLocalContext()
                    }
                    .disabled(model.isPaused)

                    Button("Clear local context") {
                        model.clearLocalContext()
                    }
                    .disabled(model.localContext == nil)
                }
            }

            Section("Developer") {
                Picker("Minimum capture interval", selection: $model.minimumContextInterval) {
                    Text("1 second").tag(1.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                }
                Text("This bounds how often local context may be captured after app changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Phase boundary") {
                Label("Live Jev decisions arrive in Phase 3.", systemImage: "lock.fill")
                Text("Saving a key does not send it or make a network request. Local context is controlled by the privacy settings above.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear(perform: refreshStoredKeyStatus)
    }

    private func saveAPIKey() {
        do {
            try credentialStore.save(draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
            draftAPIKey = ""
            hasStoredAPIKey = true
            statusMessage = "API key saved to Keychain."
        } catch {
            statusMessage = "Unable to save the API key."
        }
    }

    private func removeAPIKey() {
        do {
            try credentialStore.remove()
            draftAPIKey = ""
            hasStoredAPIKey = false
            statusMessage = "API key removed from Keychain."
        } catch {
            statusMessage = "Unable to remove the API key."
        }
    }

    private func refreshStoredKeyStatus() {
        do {
            hasStoredAPIKey = try credentialStore.load() != nil
        } catch {
            statusMessage = "Unable to read Keychain status."
        }
    }
}
