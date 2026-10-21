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

    var isAvailable: Bool { model.availability == .available }

    /// Why Apple Intelligence cannot run here, in words a cook can act on, or nil when it can.
    var unavailableReason: LocalizedStringResource? {
        switch model.availability {
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
    func respond<Content: Generable>(
        _ type: Content.Type,
        to prompt: String,
        instructions: String,
        tokenLimit: Int
    ) async throws -> Content {
        var waits: [Duration] = [.seconds(1), .seconds(4), .seconds(10)]
        while true {
            do {
                return try await run(instructions: instructions) { session in
                    try await session.respond(
                        to: prompt,
                        generating: Content.self,
                        options: GenerationOptions(maximumResponseTokens: tokenLimit)
                    ).content
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard !waits.isEmpty else { throw error }
                try await Task.sleep(for: waits.removeFirst())
            }
        }
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
