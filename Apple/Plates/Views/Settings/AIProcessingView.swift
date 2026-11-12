import CulinaryIntelligence
import SwiftUI

/// What is sent to Gemma and Clef, or to the provider the cook brought a key for, and the cook's
/// say over it. Turned off, recipes are written by hand and nothing is sent.
struct AIProcessingView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PlatesCloud.allowedKey) private var isAllowed = false
    @AppStorage(WriterProvider.selectedKey) private var provider: WriterProvider = .platesCloud

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("AIProcessing.Allow", isOn: $isAllowed)
                } footer: {
                    Text(provider.processingFooter(isAllowed: isAllowed))
                }

                Section {
                    ForEach(provider.consentRows, id: \.icon) { item in
                        row(item.icon, item.title, item.description)
                    }
                    row("lock.shield", "Consent.Private", provider.privateDescription)
                }

                Section {
                    Link(provider.policyName, destination: provider.policy)
                }
            }
            .navigationTitle("AIProcessing.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ description: LocalizedStringKey) -> some View {
        Label {
            Text(title)
            Text(description)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint)
        }
    }
}
