import Foundation

/// What the OpenAI API answered when it did not write, in words a cook can act on.
public enum OpenAIError: WriterAccountError, Equatable {
    /// No key has been entered for GPT 6.1 Sol.
    case noKey
    /// OpenAI did not accept the key.
    case badKey
    /// The cook's OpenAI account has no credit left, or reached a spend or usage limit.
    case noCredit
    /// The key, or the cook's country, is not allowed to use GPT 6.1 Sol.
    case notPermitted
    /// Too many requests on the cook's account for now.
    case rateLimited
    /// OpenAI is busy, or had a problem of its own.
    case overloaded
    /// GPT 6.1 Sol declined to write this.
    case refused
    case server(Int, String?)

    public var errorDescription: String? {
        switch self {
        case .noKey: String(culinary: "OpenAI.Error.NoKey")
        case .badKey: String(culinary: "OpenAI.Error.BadKey")
        case .noCredit: String(culinary: "OpenAI.Error.NoCredit")
        case .notPermitted: String(culinary: "OpenAI.Error.NotPermitted")
        case .rateLimited: String(culinary: "OpenAI.Error.RateLimited")
        case .overloaded: String(culinary: "OpenAI.Error.Overloaded")
        case .refused: String(culinary: "OpenAI.Error.Refused")
        case let .server(code, message):
            String(format: String(culinary: "OpenAI.Error.Server"),
                   message ?? HTTPURLResponse.localizedString(forStatusCode: code))
        }
    }

    /// The error for a failed request, from its status and the error object OpenAI sent back.
    /// Running out of credit and reaching a spend or usage limit all come back as 429, told
    /// apart from a rate limit by their code.
    static func from(status: Int, type: String?, code: String?, message: String?) -> OpenAIError {
        let names = [type, code].compactMap { $0 }
        if names.contains(where: { name in
            ["insufficient_quota", "credit_balance_exhausted", "spend_limit", "usage_limit"].contains { name.contains($0) }
        }) {
            return .noCredit
        }
        if names.contains(where: { ["invalid_api_key", "authentication_error"].contains($0) }) { return .badKey }
        if names.contains(where: { ["model_not_found", "unsupported_country_region_territory"].contains($0) }) {
            return .notPermitted
        }
        if names.contains(where: { ["rate_limit_exceeded", "rate_limit_error", "slow_down"].contains($0) }) {
            return .rateLimited
        }
        if names.contains(where: { ["server_error", "server_is_overloaded", "service_unavailable_error"].contains($0) }) {
            return .overloaded
        }
        switch status {
        case 401: return .badKey
        case 403, 404: return .notPermitted
        case 429: return .rateLimited
        case 500, 502, 503: return .overloaded
        default: return .server(status, message)
        }
    }
}

/// GPT 6.1 Sol on the cook's own OpenAI account, through the Responses API. It answers every
/// role, at medium effort. It is given the same English instructions and prompts as Claude, and
/// its answers are read the same way. While it writes, the passes Apple Intelligence runs on the
/// device are sent here too.
@MainActor
final class OpenAICloud: KeyedWriter {
    static let shared = OpenAICloud()

    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    static let model = "gpt-6.1-sol"
    static let effort = "medium"

    /// The model reasons before it answers, and its reasoning counts against
    /// `max_output_tokens`, so every request is given this much on top of the limit its answer
    /// has. OpenAI's reasoning guide asks for at least 25,000 for reasoning and output together.
    static let reasoningAllowance = 25_000

    /// Where the cook's key is read from, the Keychain everywhere but in tests.
    private let key: () -> String?

    init(key: @escaping () -> String? = { WriterProvider.openAI.apiKey }) {
        self.key = key
    }

    var isConfigured: Bool { key() != nil }

    var unconfiguredReason: LocalizedStringResource {
        LocalizedStringResource(culinary: "Generate.Unavailable.OpenAIKey")
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
        system: String,
        example: (ask: String, answer: String)?,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]?
    ) async throws -> URLSession.AsyncBytes {
        guard UserDefaults.standard.bool(forKey: Plates.allowedKey) else { throw CloudError.notAllowed }
        guard let key = key() else { throw OpenAIError.noKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = Self.body(
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
            throw OpenAIError.from(
                status: http.statusCode,
                type: failure?.error.type,
                code: failure?.error.code,
                message: failure?.error.message
            )
        }
        return bytes
    }

    // MARK: - Bodies

    /// No `temperature` or `top_p`, which a reasoning model does not take, and `store` off, so
    /// OpenAI keeps no copy of the response to fetch later. A schema, when a pass has one, holds
    /// the answer to it: strictly when every property in it is required, as strict mode asks.
    nonisolated static func body(
        system: String,
        example: (ask: String, answer: String)? = nil,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]? = nil
    ) -> Data {
        var input: [[String: String]] = []
        if let example {
            input.append(["role": "user", "content": example.ask])
            input.append(["role": "assistant", "content": example.answer])
        }
        input.append(["role": "user", "content": prompt])
        var object: [String: Any] = [
            "model": model,
            "instructions": system,
            "input": input,
            "max_output_tokens": maximumTokens + reasoningAllowance,
            "reasoning": ["effort": effort],
            "store": false,
            "stream": true,
        ]
        if let schema {
            let strict = strictSchema(schema)
            object["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": "answer",
                    "schema": strict ?? schema,
                    "strict": strict != nil,
                ] as [String: Any],
            ]
        }
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    /// The schema as strict mode takes it, with `additionalProperties` turned off on every
    /// object, or nil when an object leaves a property out of `required`, which strict mode
    /// does not allow.
    nonisolated static func strictSchema(_ schema: [String: Any]) -> [String: Any]? {
        func strict(_ value: Any) -> Any? {
            if let array = value as? [Any] {
                var kept: [Any] = []
                for item in array {
                    guard let item = strict(item) else { return nil }
                    kept.append(item)
                }
                return kept
            }
            guard var object = value as? [String: Any] else { return value }
            if let properties = object["properties"] as? [String: Any] {
                let required = Set(object["required"] as? [String] ?? [])
                guard required == Set(properties.keys) else { return nil }
                var kept: [String: Any] = [:]
                for (name, property) in properties {
                    guard let property = strict(property) else { return nil }
                    kept[name] = property
                }
                object["properties"] = kept
                object["additionalProperties"] = false
            }
            for key in ["items", "anyOf", "$defs"] {
                guard let child = object[key] else { continue }
                if key == "$defs", let definitions = child as? [String: Any] {
                    var kept: [String: Any] = [:]
                    for (name, definition) in definitions {
                        guard let definition = strict(definition) else { return nil }
                        kept[name] = definition
                    }
                    object[key] = kept
                } else {
                    guard let child = strict(child) else { return nil }
                    object[key] = child
                }
            }
            return object
        }
        return strict(schema) as? [String: Any]
    }

    /// The text in one streamed event, if it carries any. Reasoning is passed over, a refusal,
    /// an answer cut off at the token limit, a failed response, or an error event ends the
    /// stream with its error, and every other event is skipped.
    nonisolated static func text(inEvent payload: String) throws -> String? {
        guard let data = payload.trimmingCharacters(in: .whitespaces).data(using: .utf8),
              let event = try? JSONDecoder().decode(StreamEvent.self, from: data)
        else { return nil }
        switch event.type {
        case "response.output_text.delta":
            guard let text = event.delta, !text.isEmpty else { return nil }
            return text
        case "response.refusal.delta", "response.refusal.done":
            throw OpenAIError.refused
        case "response.incomplete":
            switch event.response?.incompleteDetails?.reason {
            case "max_output_tokens": throw CloudError.cutOff
            case "content_filter": throw OpenAIError.refused
            default: throw CloudError.noResponse
            }
        case "response.failed":
            let error = event.response?.error
            throw OpenAIError.from(status: 0, type: nil, code: error?.code, message: error?.message)
        case "error":
            let error = event.error
            throw OpenAIError.from(
                status: 0,
                type: error?.type,
                code: event.code ?? error?.code,
                message: event.message ?? error?.message
            )
        default:
            return nil
        }
    }

    nonisolated private struct StreamEvent: Decodable {
        struct Response: Decodable {
            struct Incomplete: Decodable {
                let reason: String?
            }

            let incompleteDetails: Incomplete?
            let error: Failure.Detail?

            enum CodingKeys: String, CodingKey {
                case error
                case incompleteDetails = "incomplete_details"
            }
        }

        let type: String
        let delta: String?
        let response: Response?
        let code: String?
        let message: String?
        let error: Failure.Detail?
    }

    nonisolated private struct Failure: Decodable {
        struct Detail: Decodable {
            let type: String?
            let code: String?
            let message: String?
        }

        let error: Detail
    }
}
