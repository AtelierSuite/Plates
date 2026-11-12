import CulinaryIntelligence
import SwiftUI

/// Who writes the recipes, picked at the top, with whatever that writer needs in the sections
/// below it. Claude needs the cook's own key, which goes straight into the Keychain and is
/// never shown again.
struct RecipeWriterView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(WriterProvider.selectedKey) private var provider: WriterProvider = .platesCloud

    @State private var key = ""
    @State private var hasKey = false

    /// Where a new key is issued, on Claude Platform.
    static let claudePlatformKeys = URL(string: "https://platform.claude.com/settings/keys")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Menu.Writer", selection: $provider) {
                        ForEach(WriterProvider.allCases) { provider in
                            Text(provider.name).tag(provider)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text(footer)
                }

                if provider == .claude {
                    claudeKey
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

    private var footer: LocalizedStringKey {
        switch provider {
        case .platesCloud: "Writer.Footer.PlatesCloud"
        case .claude: "Writer.Footer.Claude"
        }
    }

    /// The key Claude runs on: entered or replaced, where to get a new one, and removing it.
    @ViewBuilder
    private var claudeKey: some View {
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
            Text("APIKey.Claude.Title")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(hasKey ? "APIKey.Saved" : "APIKey.Missing")
                Text("APIKey.Claude.Footer")
            }
        }

        Section {
            Link(destination: Self.claudePlatformKeys) {
                Label("APIKey.Claude.Get", systemImage: "arrow.up.forward.app")
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
