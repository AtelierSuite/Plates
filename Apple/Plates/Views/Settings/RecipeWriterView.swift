import CulinaryIntelligence
import SwiftUI

/// Who writes the recipes, picked at the top, with whatever that writer needs in the sections
/// below it. Claude needs the cook's own key, which goes straight into the Keychain and is never
/// shown again.
struct RecipeWriterView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(WriterProvider.selectedKey) private var provider: WriterProvider = .plates

    @State private var key = ""
    @State private var hasKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Menu.Writer", selection: $provider) {
                        ForEach(WriterProvider.offered) { provider in
                            Text(provider.name).tag(provider)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text(provider.writerFooter)
                }

                if provider.needsKey {
                    keySections
                }
            }
            .navigationTitle("Menu.Writer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .onAppear { hasKey = provider.hasKey }
            .onChange(of: provider) {
                key = ""
                hasKey = provider.hasKey
            }
        }
    }

    /// The key the writer runs on: entered or replaced, where to get a new one, and removing it.
    @ViewBuilder
    private var keySections: some View {
        Section {
            SecureField("APIKey.Field", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
            Button("APIKey.Save") {
                provider.saveKey(key)
                key = ""
                hasKey = provider.hasKey
            }
            .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text(provider.keyTitle)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(hasKey ? "APIKey.Saved" : "APIKey.Missing")
                Text(provider.keyFooter)
            }
        }

        Section {
            Link(destination: provider.newKey) {
                Label(provider.newKeyName, systemImage: "arrow.up.forward.app")
            }
        }

        if hasKey {
            Section {
                Button("APIKey.Remove", role: .destructive) {
                    provider.removeKey()
                    hasKey = false
                }
            }
        }
    }
}
