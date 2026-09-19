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

            Section("Phase boundary") {
                Label("Live Jev decisions arrive in Phase 3.", systemImage: "lock.fill")
                Text("Saving a key does not send it, make a network request, or enable desktop observation.")
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
