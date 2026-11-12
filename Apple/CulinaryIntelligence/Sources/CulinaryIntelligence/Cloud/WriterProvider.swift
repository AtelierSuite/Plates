import Foundation

/// Where a recipe is written, ideas are offered and picked, and a dish is asked what can be seen
/// on it. Plates is the default. Any other provider runs on the cook's own API key, which is
/// kept in the Keychain and sent from the device straight to that provider, never to Plates.
/// Apple Intelligence sorts on the device whichever one writes.
public enum WriterProvider: String, CaseIterable, Identifiable, Sendable {
    case plates = "Plates"
    case claude = "Claude"

    public var id: String { rawValue }

    /// Where the choice is kept, for views that follow it with `@AppStorage`.
    nonisolated public static let selectedKey = "Writer.Provider"

    /// The provider the cook picked in the menu.
    public static var current: WriterProvider {
        get {
            UserDefaults.standard.string(forKey: selectedKey).flatMap(WriterProvider.init(rawValue:)) ?? .plates
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: selectedKey) }
    }

    public var name: LocalizedStringResource {
        switch self {
        case .plates: LocalizedStringResource(culinary: "Writer.Provider.Plates")
        case .claude: LocalizedStringResource(culinary: "Writer.Provider.Claude")
        }
    }

    /// Whether the provider runs on a key the cook brings, with no daily limits from Plates.
    public var needsKey: Bool { self != .plates }

    // MARK: - Key

    private var keyAccount: String { "\(rawValue).APIKey" }

    /// The cook's key for this provider. It is only ever read to sign a request to the provider.
    var apiKey: String? {
        guard needsKey, let key = Keychain.read(account: keyAccount), !key.isEmpty else { return nil }
        return key
    }

    public var hasKey: Bool { apiKey != nil }

    public func saveKey(_ key: String) {
        guard needsKey else { return }
        Keychain.write(key.trimmingCharacters(in: .whitespacesAndNewlines), account: keyAccount, thisDeviceOnly: true)
    }

    public func removeKey() {
        Keychain.write(nil, account: keyAccount)
    }

    // MARK: - Service

    var service: any RecipeWriting {
        switch self {
        case .plates: Plates.shared
        case .claude: ClaudeCloud.shared
        }
    }
}

/// The calls a run makes on whoever writes, so the passes never know which provider answers.
@MainActor
protocol RecipeWriting: AnyObject {
    /// Whether requests can be sent at all: an address for Plates, a key for the others.
    var isConfigured: Bool { get }

    /// Why requests cannot be sent, when they cannot.
    var unconfiguredReason: LocalizedStringResource { get }

    /// Whether the cook has allowed requests to leave the device.
    var isAllowed: Bool { get }

    /// How many recipes are left today after the last write, or nil before one has answered.
    /// A provider with no daily limit answers `Int.max`, so a draft can be written again.
    var writesRemaining: Int? { get }

    /// The recipe, streamed back a piece at a time, after an example exchange when one is
    /// given. An answer that ran out of tokens ends in `CloudError.cutOff`. A provider that
    /// takes no sampling settings leaves the temperature out.
    func write(
        instructions: String,
        example: (ask: String, answer: String)?,
        prompt: String,
        maximumTokens: Int,
        temperature: Double
    ) -> AsyncThrowingStream<String, Error>

    /// Dish ideas, whole.
    func ideate(instructions: String, prompt: String, maximumTokens: Int, temperature: Double) async throws -> String

    /// An answer to a question the recipe editor asks, whole.
    func edit(instructions: String, prompt: String, maximumTokens: Int) async throws -> String

    /// Which of the ideas fits the cook's request best.
    func decide(
        requestID: String,
        request: String,
        ingredients: [String],
        tools: [String],
        ideas: [(title: String, summary: String)]
    ) async throws -> CloudPick

    /// How likely each ingredient is to be seen on the dish as it is served, in the order the
    /// lines went out.
    func toppings(dish: String, steps: [(title: String, points: [String])], ingredients: [String]) async throws -> [Double]

    /// How many picks are left today, or nil when there is no daily limit or it cannot be found out.
    func decisionsRemaining() async -> Int?
}

extension RecipeWriting {
    func write(
        instructions: String,
        example: (ask: String, answer: String)? = nil,
        prompt: String,
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
        write(instructions: instructions, example: example, prompt: prompt, maximumTokens: 1400, temperature: temperature)
    }
}
