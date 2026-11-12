import Foundation

/// What the Anthropic API answered when it did not write, in words a cook can act on.
public enum ClaudeError: WriterAccountError, Equatable {
    /// No key has been entered for Claude.
    case noKey
    /// Anthropic did not accept the key.
    case badKey
    /// The cook's Anthropic account has no credit left.
    case noCredit
    /// The key is not allowed to use Claude Opus 5.5.
    case notPermitted
    /// Too many requests on the cook's account for now.
    case rateLimited
    /// Anthropic is busy, or had a problem of its own.
    case overloaded
    /// Claude declined to write this.
    case refused
    case server(Int, String?)

    public var errorDescription: String? {
        switch self {
        case .noKey: String(culinary: "Claude.Error.NoKey")
        case .badKey: String(culinary: "Claude.Error.BadKey")
        case .noCredit: String(culinary: "Claude.Error.NoCredit")
        case .notPermitted: String(culinary: "Claude.Error.NotPermitted")
        case .rateLimited: String(culinary: "Claude.Error.RateLimited")
        case .overloaded: String(culinary: "Claude.Error.Overloaded")
        case .refused: String(culinary: "Claude.Error.Refused")
        case let .server(code, message):
            String(format: String(culinary: "Claude.Error.Server"),
                   message ?? HTTPURLResponse.localizedString(forStatusCode: code))
        }
    }

    /// The error for a failed request, from its status and the error object Anthropic sent back.
    static func from(status: Int, type: String?, message: String?) -> ClaudeError {
        if message?.localizedCaseInsensitiveContains("credit balance") == true { return .noCredit }
        switch (status, type) {
        case (401, _), (_, "authentication_error"): return .badKey
        case (402, _), (_, "billing_error"): return .noCredit
        case (403, _), (404, _), (_, "permission_error"), (_, "not_found_error"): return .notPermitted
        case (429, _), (_, "rate_limit_error"): return .rateLimited
        case (500, _), (529, _), (_, "api_error"), (_, "overloaded_error"): return .overloaded
        default: return .server(status, message)
        }
    }
}

extension WriterRole {
    /// The Claude model a role goes to. Opus writes, edits, and draws; Sonnet offers ideas, plans
    /// a request, and reads a shared page; Haiku picks, says what shows on a dish, sorts lines,
    /// and translates.
    var claudeModel: String {
        switch self {
        case .write, .edit, .draw: "claude-opus-5-5"
        case .ideas, .plan, .parse: "claude-sonnet-5-5"
        case .decide, .toppings, .sort, .translate: "claude-haiku-5-5"
        }
    }
}

/// Claude on the cook's own Anthropic account, with each request sent to the model its role
/// calls for, through the Messages API. It is given the same English instructions and prompts
/// as Gemma, and its answers are read the same way. While Claude writes, the passes Apple
/// Intelligence runs on the device are sent here too.
@MainActor
final class ClaudeCloud: KeyedWriter {
    static let shared = ClaudeCloud()

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let version = "2026-10-21"

    /// Every model thinks, and its thinking counts against `max_tokens`, so every request is
    /// given this much on top of the limit its answer has. At medium effort Opus ran past an
    /// allowance of 2,048 on 4 of 24 recipes.
    static let thinkingAllowance = 6000
    static let effort = "medium"

    /// Where the cook's key is read from, the Keychain everywhere but in tests.
    private let key: () -> String?

    init(key: @escaping () -> String? = { WriterProvider.claude.apiKey }) {
        self.key = key
    }

    var isConfigured: Bool { key() != nil }

    var unconfiguredReason: LocalizedStringResource {
        LocalizedStringResource(culinary: "Generate.Unavailable.ClaudeKey")
    }

    func stream(
        _ role: WriterRole,
        system: String,
        example: (ask: String, answer: String)?,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]?
    ) -> AsyncThrowingStream<String, Error> {
        streamedText {
            try await self.send(
                role,
                system: system,
                example: example,
                prompt: prompt,
                maximumTokens: maximumTokens,
                schema: schema
            )
        } text: { try Self.text(inEvent: $0) }
    }

    // MARK: - Requests

    private func send(
        _ role: WriterRole,
        system: String,
        example: (ask: String, answer: String)?,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]?
    ) async throws -> URLSession.AsyncBytes {
        guard UserDefaults.standard.bool(forKey: Plates.allowedKey) else { throw CloudError.notAllowed }
        guard let key = key() else { throw ClaudeError.noKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.version, forHTTPHeaderField: "anthropic-version")
        request.httpBody = Self.body(
            role,
            system: system,
            example: example,
            prompt: prompt,
            maximumTokens: maximumTokens,
            schema: schema
        )
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudError.noResponse }
        guard http.statusCode == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            let failure = try? JSONDecoder().decode(Failure.self, from: data)
            throw ClaudeError.from(status: http.statusCode, type: failure?.error.type, message: failure?.error.message)
        }
        return bytes
    }

    // MARK: - Bodies

    /// No `temperature`, which these models reject, and no `thinking`, which Opus cannot turn
    /// off. The effort, medium for every role, sets how long each one thinks. A schema, when a
    /// pass has one, holds the answer to it.
    nonisolated static func body(
        _ role: WriterRole,
        system: String,
        example: (ask: String, answer: String)? = nil,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]? = nil
    ) -> Data {
        var messages: [[String: String]] = []
        if let example {
            messages.append(["role": "user", "content": example.ask])
            messages.append(["role": "assistant", "content": example.answer])
        }
        messages.append(["role": "user", "content": prompt])
        var output: [String: Any] = ["effort": effort]
        if let schema {
            output["format"] = ["type": "json_schema", "schema": schema]
        }
        let object: [String: Any] = [
            "model": role.claudeModel,
            "max_tokens": maximumTokens + thinkingAllowance,
            "system": system,
            "messages": messages,
            "output_config": output,
            "stream": true,
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    /// The text in one streamed event, if it carries any. Thinking deltas are passed over, a
    /// refusal, an answer cut off at the token limit, or an error event ends the stream with its
    /// error, and every other event is skipped.
    nonisolated static func text(inEvent payload: String) throws -> String? {
        guard let data = payload.trimmingCharacters(in: .whitespaces).data(using: .utf8),
              let event = try? JSONDecoder().decode(StreamEvent.self, from: data)
        else { return nil }
        switch event.type {
        case "content_block_delta":
            guard event.delta?.type == "text_delta", let text = event.delta?.text, !text.isEmpty else { return nil }
            return text
        case "message_delta":
            switch event.delta?.stopReason {
            case "refusal": throw ClaudeError.refused
            case "max_tokens": throw CloudError.cutOff
            default: return nil
            }
        case "error":
            throw ClaudeError.from(status: 0, type: event.error?.type, message: event.error?.message)
        default:
            return nil
        }
    }

    nonisolated private struct StreamEvent: Decodable {
        struct Delta: Decodable {
            let type: String?
            let text: String?
            let stopReason: String?

            enum CodingKeys: String, CodingKey {
                case type, text
                case stopReason = "stop_reason"
            }
        }

        let type: String
        let delta: Delta?
        let error: Failure.Detail?
    }

    nonisolated private struct Failure: Decodable {
        struct Detail: Decodable {
            let type: String?
            let message: String?
        }

        let error: Detail
    }
}
