import CulinaryIntelligence
import SwiftUI

/// What the views say about each writer that runs on the cook's own key, and where they link to.
extension WriterProvider {
    /// The footer under the picker on the Recipe Writer page.
    var writerFooter: LocalizedStringKey {
        switch self {
        case .platesCloud: "Writer.Footer.PlatesCloud"
        case .claude: "Writer.Footer.Claude"
        case .openAI: "Writer.Footer.OpenAI"
        }
    }

    /// The footer under the toggle that lets requests leave the device.
    func processingFooter(isAllowed: Bool) -> LocalizedStringKey {
        switch (self, isAllowed) {
        case (.platesCloud, true): "AIProcessing.Footer.On"
        case (.platesCloud, false): "AIProcessing.Footer.Off"
        case (.claude, true): "AIProcessing.Footer.On.Claude"
        case (.claude, false): "AIProcessing.Footer.Off.Claude"
        case (.openAI, true): "AIProcessing.Footer.On.OpenAI"
        case (.openAI, false): "AIProcessing.Footer.Off.OpenAI"
        }
    }

    /// What the writer is sent and what keeps the key safe, as two rows of title and description.
    var consentRows: [(icon: String, title: LocalizedStringKey, description: LocalizedStringKey)] {
        switch self {
        case .platesCloud: [
            ("text.page", "Consent.Gemma", "Consent.Gemma.Description"),
            ("dice", "Consent.Clef", "Consent.Clef.Description"),
        ]
        case .claude: [
            ("text.page", "Consent.Claude", "Consent.Claude.Description"),
            ("key", "Consent.Claude.Key", "Consent.Claude.Key.Description"),
        ]
        case .openAI: [
            ("text.page", "Consent.OpenAI", "Consent.OpenAI.Description"),
            ("key", "Consent.OpenAI.Key", "Consent.OpenAI.Key.Description"),
        ]
        }
    }

    var privateDescription: LocalizedStringKey {
        switch self {
        case .platesCloud: "Consent.Private.Description"
        case .claude: "Consent.Private.Description.Claude"
        case .openAI: "Consent.Private.Description.OpenAI"
        }
    }

    var onboardingDescription: LocalizedStringKey {
        switch self {
        case .platesCloud: "Onboarding.Consent.Description"
        case .claude: "Onboarding.Consent.Description.Claude"
        case .openAI: "Onboarding.Consent.Description.OpenAI"
        }
    }

    var policyName: LocalizedStringKey {
        switch self {
        case .platesCloud: "Consent.Policy.Cloudflare"
        case .claude: "Consent.Policy.Anthropic"
        case .openAI: "Consent.Policy.OpenAI"
        }
    }

    var policy: URL {
        switch self {
        case .platesCloud: URL(string: "https://www.cloudflare.com/privacypolicy/")!
        case .claude: URL(string: "https://www.anthropic.com/legal/privacy")!
        case .openAI: URL(string: "https://openai.com/policies/privacy-policy/")!
        }
    }

    /// What the limits page says in place of PlatesCloud's daily limits.
    var limits: LocalizedStringKey {
        switch self {
        case .platesCloud, .claude: "Limits.Claude"
        case .openAI: "Limits.OpenAI"
        }
    }

    // MARK: - Key

    var keyTitle: LocalizedStringKey {
        switch self {
        case .platesCloud, .claude: "APIKey.Claude.Title"
        case .openAI: "APIKey.OpenAI.Title"
        }
    }

    var keyFooter: LocalizedStringKey {
        switch self {
        case .platesCloud, .claude: "APIKey.Claude.Footer"
        case .openAI: "APIKey.OpenAI.Footer"
        }
    }

    var newKeyName: LocalizedStringKey {
        switch self {
        case .platesCloud, .claude: "APIKey.Claude.Get"
        case .openAI: "APIKey.OpenAI.Get"
        }
    }

    /// Where a new key is issued: Claude Platform or OpenAI Platform.
    var newKey: URL {
        switch self {
        case .platesCloud, .claude: URL(string: "https://platform.claude.com/settings/keys")!
        case .openAI: URL(string: "https://platform.openai.com/settings/organization/api-keys")!
        }
    }
}
