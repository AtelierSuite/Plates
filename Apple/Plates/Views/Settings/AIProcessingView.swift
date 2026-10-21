import CulinaryIntelligence
import SwiftUI

/// What is sent to Gemma and Clef, and the cook's say over it. Turned off, recipes are written
/// by hand and nothing is sent.
struct AIProcessingView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PlatesCloud.allowedKey) private var isAllowed = false

    static let cloudflarePolicy = URL(string: "https://www.cloudflare.com/privacypolicy/")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("AIProcessing.Allow", isOn: $isAllowed)
                } footer: {
                    Text(isAllowed ? "AIProcessing.Footer.On" : "AIProcessing.Footer.Off")
                }

                Section {
                    row("text.page", "Consent.Gemma", "Consent.Gemma.Description")
                    row("dice", "Consent.Clef", "Consent.Clef.Description")
                    row("lock.shield", "Consent.Private", "Consent.Private.Description")
                }

                Section {
                    Link("Consent.Policy.Cloudflare", destination: Self.cloudflarePolicy)
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
