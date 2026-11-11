import CulinaryIntelligence
import SwiftUI

/// Where the cook enters, replaces, or removes their own key for a provider. The key goes
/// straight into the Keychain and is never shown again.
struct APIKeyView: View {
    @Environment(\.dismiss) private var dismiss

    let provider: WriterProvider

    @State private var key = ""
    @State private var hasKey = false

    static let anthropicConsole = URL(string: "https://console.anthropic.com/settings/keys")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("APIKey.Field", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if hasKey {
                            Text("APIKey.Saved")
                        }
                        Text(footer)
                    }
                }

                Section {
                    Link(getKeyTitle, destination: console)
                }

                if hasKey {
                    Section {
                        Button("APIKey.Remove", role: .destructive) {
                            provider.removeKey()
                            hasKey = false
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("APIKey.Save", role: .confirm) {
                        provider.saveKey(key)
                        dismiss()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { hasKey = provider.hasKey }
        }
    }

    // Claude is the only provider with a key so far. Another one adds its own strings here.
    private var title: LocalizedStringKey { "APIKey.Claude.Title" }
    private var footer: LocalizedStringKey { "APIKey.Claude.Footer" }
    private var getKeyTitle: LocalizedStringKey { "APIKey.Claude.Get" }
    private var console: URL { Self.anthropicConsole }
}
