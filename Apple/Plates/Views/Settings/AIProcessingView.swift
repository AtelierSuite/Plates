import CulinaryIntelligence
import SwiftUI

/// What is sent to Gemma and Clef, or to the provider the cook brought a key for, and the cook's
/// say over it. Turned off, recipes are written by hand and nothing is sent.
struct AIProcessingView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PlatesCloud.allowedKey) private var isAllowed = false
    @AppStorage(WriterProvider.selectedKey) private var provider: WriterProvider = .platesCloud

    static let cloudflarePolicy = URL(string: "https://www.cloudflare.com/privacypolicy/")!
    static let anthropicPolicy = URL(string: "https://www.anthropic.com/legal/privacy")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("AIProcessing.Allow", isOn: $isAllowed)
                } footer: {
                    Text(footer)
                }

                Section {
                    switch provider {
                    case .platesCloud:
                        row("text.page", "Consent.Gemma", "Consent.Gemma.Description")
                        row("dice", "Consent.Clef", "Consent.Clef.Description")
                    case .claude:
                        row("text.page", "Consent.Claude", "Consent.Claude.Description")
                        row("key", "Consent.Claude.Key", "Consent.Claude.Key.Description")
                    }
                    row(
                        "lock.shield",
                        "Consent.Private",
                        provider == .claude ? "Consent.Private.Description.Claude" : "Consent.Private.Description"
                    )
                }

                Section {
                    switch provider {
                    case .platesCloud:
                        Link("Consent.Policy.Cloudflare", destination: Self.cloudflarePolicy)
                    case .claude:
                        Link("Consent.Policy.Anthropic", destination: Self.anthropicPolicy)
                    }
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

    private var footer: LocalizedStringKey {
        switch (provider, isAllowed) {
        case (.platesCloud, true): "AIProcessing.Footer.On"
        case (.platesCloud, false): "AIProcessing.Footer.Off"
        case (.claude, true): "AIProcessing.Footer.On.Claude"
        case (.claude, false): "AIProcessing.Footer.Off.Claude"
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
