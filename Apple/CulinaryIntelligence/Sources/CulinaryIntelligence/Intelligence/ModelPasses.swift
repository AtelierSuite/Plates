import FoundationModels
import Foundation
import UIKit

/// What can go wrong in a pass, in words a cook can act on.
enum IntelligenceError: LocalizedError {
    case empty
    /// Too big for this iPhone, with no cloud to send it to.
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .empty: String(culinary: "Generate.Error.Empty")
        case .tooLarge: String(culinary: "Generate.Error.TooLarge")
        }
    }
}

/// The model, the cloud a pass falls back to, and the time the app asks for to finish a pass
/// once it is off screen. Writing a recipe and rewriting one both run their passes through one
/// of these, so availability, the fallback, and the background time are written down once.
/// While Claude or GPT 6.1 Sol writes on the cook's own key, every pass goes to it instead, and
/// Apple Intelligence is not needed.
@MainActor
final class ModelPasses {
    private let model = SystemLanguageModel.default

    /// Where a pass goes when it does not fit on device. Held rather than made per pass so
    /// availability and quota are read from one place.
    private let cloud = PrivateCloudComputeLanguageModel()

    /// Held while the model works, so walking away from the app does not suspend a pass part
    /// way through. iOS grants around half a minute, which is enough for the pass in flight to
    /// land.
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// The writer on the cook's own key, when it has a key saved and the cook allowed requests
    /// to leave the device. Nil sends every pass to Apple Intelligence.
    var keyed: (any KeyedWriter)? {
        guard let writer = WriterProvider.current.keyedWriter, writer.isConfigured, writer.isAllowed else { return nil }
        return writer
    }

    /// The role a sorting pass is sent under: sorting what was written, or reading a page the
    /// cook shared.
    var sortingRole: WriterRole = .sort

    var isAvailable: Bool { keyed != nil || model.availability == .available }

    /// Why Apple Intelligence cannot run here, in words a cook can act on, or nil when it can.
    var unavailableReason: LocalizedStringResource? {
        if keyed != nil { return nil }
        return switch model.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            LocalizedStringResource(culinary: "Generate.Unavailable.DeviceNotEligible")
        case .unavailable(.appleIntelligenceNotEnabled):
            LocalizedStringResource(culinary: "Generate.Unavailable.AppleIntelligenceNotEnabled")
        case .unavailable(.modelNotReady):
            LocalizedStringResource(culinary: "Generate.Unavailable.ModelNotReady")
        case .unavailable:
            LocalizedStringResource(culinary: "Generate.Unavailable.Unknown")
        }
    }

    /// Runs one pass on device, and runs it again on Private Cloud Compute when the request
    /// does not fit the on-device window. Nothing leaves the device until the on-device model
    /// has turned the pass down, and a pass small enough to run at home never reaches the
    /// cloud at all.
    func run<Value>(
        tools: [any FoundationModels.Tool] = [],
        instructions: String,
        _ body: (LanguageModelSession) async throws -> Value
    ) async throws -> Value {
        do {
            return try await body(LanguageModelSession(tools: tools, instructions: instructions))
        } catch let error as LanguageModelError {
            guard case .contextSizeExceeded = error else { throw error }
            guard cloud.isAvailable else { throw IntelligenceError.tooLarge }
            return try await body(
                LanguageModelSession(
                    model: cloud,
                    tools: cloud.capabilities.contains(.toolCalling) ? tools : [],
                    instructions: instructions
                )
            )
        }
    }

    /// One answer in a session of its own, held to a response length. A pass that fails is
    /// tried again, waiting longer each time. The usual failure is the system holding back a
    /// run that has gone on in the background, which clears after a short wait.
    /// On the cook's own key, the pass's own schema holds the answer, and the role says what the
    /// pass is for: sorting when none is given.
    func respond<Content: Generable>(
        _ type: Content.Type,
        to prompt: String,
        instructions: String,
        tokenLimit: Int,
        role: WriterRole? = nil,
        greedy: Bool = false,
        retries: Bool = true
    ) async throws -> Content {
        try await retrying(retries) {
            if let keyed {
                let json = try await keyed.structured(
                    role ?? sortingRole,
                    system: instructions,
                    prompt: prompt,
                    schema: Self.jsonSchema(Content.generationSchema),
                    maximumTokens: tokenLimit
                )
                return try Content(GeneratedContent(json: json))
            }
            return try await run(instructions: instructions) { session in
                try await session.respond(
                    to: prompt,
                    generating: Content.self,
                    options: GenerationOptions(sampling: greedy ? .greedy : nil, maximumResponseTokens: tokenLimit)
                ).content
            }
        }
    }

    /// One answer held to a schema built while the app runs, such as a whole section's lists.
    func respond(
        to prompt: String,
        schema: GenerationSchema,
        instructions: String,
        tokenLimit: Int,
        role: WriterRole? = nil
    ) async throws -> GeneratedContent {
        if let keyed {
            let json = try await keyed.structured(
                role ?? sortingRole,
                system: instructions,
                prompt: prompt,
                schema: Self.jsonSchema(schema),
                maximumTokens: tokenLimit
            )
            return try GeneratedContent(json: json)
        }
        return try await run(instructions: instructions) { session in
            try await session.respond(
                to: prompt,
                schema: schema,
                options: GenerationOptions(maximumResponseTokens: tokenLimit)
            ).content
        }
    }

    /// One answer in plain text, such as a translation.
    func respondText(to prompt: String, instructions: String, tokenLimit: Int, role: WriterRole) async throws -> String {
        if let keyed {
            return try await keyed.plain(role, system: instructions, prompt: prompt, maximumTokens: tokenLimit)
        }
        return try await run(instructions: instructions) { session in
            try await session.respond(
                to: prompt,
                options: GenerationOptions(maximumResponseTokens: tokenLimit)
            ).content
        }
    }

    /// Runs a pass, and runs it again when it fails, waiting longer each time. An answer from
    /// the provider about the key, the account, or the request is not tried again.
    private func retrying<Value>(_ retries: Bool, _ pass: () async throws -> Value) async throws -> Value {
        var waits: [Duration] = retries ? [.seconds(1), .seconds(4), .seconds(10)] : []
        while true {
            do {
                return try await pass()
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as any WriterAccountError {
                throw error
            } catch CloudError.notAllowed {
                throw CloudError.notAllowed
            } catch {
                guard !waits.isEmpty else { throw error }
                try await Task.sleep(for: waits.removeFirst())
            }
        }
    }

    /// A pass's schema as the JSON Schema structured outputs take. The keywords they
    /// do not take, such as array lengths and FoundationModels' own property order, are left out.
    nonisolated static func jsonSchema(_ schema: GenerationSchema) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(schema))
        guard let schema = stripped(object) as? [String: Any] else { throw IntelligenceError.empty }
        return schema
    }

    nonisolated private static let unsupported: Set<String> = [
        "x-order", "minItems", "maxItems", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum",
        "multipleOf", "minLength", "maxLength", "pattern",
    ]

    /// The keys of `properties` are the pass's own names, so they are kept whatever they are.
    nonisolated private static func stripped(_ value: Any, naming: Bool = false) -> Any {
        if let object = value as? [String: Any] {
            if naming { return object.mapValues { stripped($0) } }
            var kept: [String: Any] = [:]
            for (key, child) in object where !unsupported.contains(key) {
                kept[key] = stripped(child, naming: key == "properties" || key == "$defs")
            }
            return kept
        }
        if let array = value as? [Any] {
            return array.map { stripped($0) }
        }
        return value
    }

    // MARK: - Running in the background

    /// Asks for the time to finish once the app is no longer on screen. The system takes it
    /// back when it runs out, and whatever is left carries on when the cook comes back.
    func beginBackgroundRun(named name: String) {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: name) {
            [weak self] in self?.endBackgroundRun()
        }
    }

    func endBackgroundRun() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Prompts

    /// Every word the model is given is written in the reader's language, so what comes back
    /// is in the language the app is being read in.
    static func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(culinary: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    /// A list as the reader's language punctuates one.
    static func joined(_ items: [String]) -> String {
        items.joined(separator: text("Generate.Prompt.Separator"))
    }
}
