import Foundation

/// What the Anthropic API answered when it did not write, in words a cook can act on.
public enum ClaudeError: LocalizedError, Equatable {
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

/// What a request to Claude is for, which sets the model that answers it. Opus writes, edits,
/// and draws; Sonnet offers ideas, plans a request, and reads a shared page; Haiku picks, says
/// what shows on a dish, sorts lines, and translates.
enum ClaudeRole: Sendable {
    case write, edit, draw
    case ideas, plan, parse
    case decide, toppings, sort, translate

    var model: String {
        switch self {
        case .write, .edit, .draw: "claude-opus-5-5"
        case .ideas, .plan, .parse: "claude-sonnet-5-5"
        case .decide, .toppings, .sort, .translate: "claude-haiku-5-5"
        }
    }
}

/// Claude on the cook's own Anthropic account, with each request sent to the model its role
/// calls for. Requests go from the device straight to the Messages API with the cook's key, so
/// neither App Attest nor Plates' daily limits apply. It is given the same English
/// instructions and prompts as Gemma, and its answers are read the same way. While Claude
/// writes, the passes Apple Intelligence runs on the device are sent here too.
@MainActor
final class ClaudeCloud: RecipeWriting {
    static let shared = ClaudeCloud()

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let version = "2026-10-21"

    /// Every model thinks, and its thinking counts against `max_tokens`, so every request is
    /// given this much on top of the limit its answer has. At medium effort Opus ran past an
    /// allowance of 2,048 on 4 of 24 recipes.
    static let thinkingAllowance = 6000
    static let effort = "medium"

    /// How many dish icon questions are in flight at once, to stay inside a new account's rate
    /// limits.
    private static let toppingsAtOnce = 3

    /// Where the cook's key is read from, the Keychain everywhere but in tests.
    private let key: () -> String?

    init(key: @escaping () -> String? = { WriterProvider.claude.apiKey }) {
        self.key = key
    }

    var isConfigured: Bool { key() != nil }

    var unconfiguredReason: LocalizedStringResource {
        LocalizedStringResource(culinary: "Generate.Unavailable.ClaudeKey")
    }

    var isAllowed: Bool { UserDefaults.standard.bool(forKey: Plates.allowedKey) }

    /// The cook's own key has no daily limit from us.
    var writesRemaining: Int? { .max }

    // MARK: - Writing

    /// Opus 5.5 takes no sampling settings, so the temperature is left out.
    func write(
        instructions: String,
        example: (ask: String, answer: String)?,
        prompt: String,
        maximumTokens: Int,
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
        stream(.write, system: instructions, example: example, prompt: prompt, maximumTokens: maximumTokens)
    }

    private func stream(
        _ role: ClaudeRole,
        system: String,
        example: (ask: String, answer: String)? = nil,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bytes = try await self.send(
                        role,
                        system: system,
                        example: example,
                        prompt: prompt,
                        maximumTokens: maximumTokens,
                        schema: schema
                    )
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        if let text = try Self.text(inEvent: String(line.dropFirst(5))) {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func ideate(instructions: String, prompt: String, maximumTokens: Int, temperature: Double) async throws -> String {
        try await answer(.ideas, system: instructions, prompt: prompt, maximumTokens: maximumTokens)
    }

    func edit(instructions: String, prompt: String, maximumTokens: Int) async throws -> String {
        try await answer(.edit, system: instructions, prompt: prompt, maximumTokens: maximumTokens)
    }

    // MARK: - Passes

    /// A pass Apple Intelligence would otherwise run, answered as JSON that holds to the pass's
    /// own schema.
    func structured(
        _ role: ClaudeRole,
        system: String,
        prompt: String,
        schema: [String: Any],
        maximumTokens: Int
    ) async throws -> String {
        try await answer(role, system: system, prompt: prompt, maximumTokens: maximumTokens, schema: schema)
    }

    /// A pass that answers in plain text, such as a translation.
    func plain(_ role: ClaudeRole, system: String, prompt: String, maximumTokens: Int) async throws -> String {
        try await answer(role, system: system, prompt: prompt, maximumTokens: maximumTokens)
    }

    // MARK: - Deciding

    func decide(
        requestID: String,
        request: String,
        ingredients: [String],
        tools: [String],
        ideas: [(title: String, summary: String)]
    ) async throws -> CloudPick {
        let none = Self.english("Generate.Prompt.Plan.None")
        let separator = Self.english("Generate.Prompt.Separator")
        let listed = ideas.enumerated().map { index, idea in
            idea.summary.isEmpty ? "\(index + 1). \(idea.title)" : "\(index + 1). \(idea.title): \(idea.summary)"
        }
        let prompt = Self.english(
            "Claude.Prompt.Decide.Ask",
            request,
            ingredients.isEmpty ? none : ingredients.joined(separator: separator),
            tools.isEmpty ? none : tools.joined(separator: separator),
            listed.joined(separator: "\n")
        )
        let answer = try await answer(.decide, system: Self.english("Claude.Prompt.Decide"), prompt: prompt, maximumTokens: 16)
        guard let number = Self.firstNumber(in: answer), number == number.rounded(),
              ideas.indices.contains(Int(number) - 1)
        else { throw CloudError.noResponse }
        return CloudPick(index: Int(number) - 1, remaining: nil)
    }

    func decisionsRemaining() async -> Int? { nil }

    // MARK: - Dish icons

    /// One question per line, as Clef is asked, a few at a time.
    func toppings(dish: String, steps: [(title: String, points: [String])], ingredients: [String]) async throws -> [Double] {
        let method = steps.map { step in
            ([step.title] + step.points.map { "- \($0)" }).joined(separator: "\n")
        }.joined(separator: "\n\n")
        let system = Self.english("Claude.Prompt.Toppings")
        return try await withThrowingTaskGroup(of: (Int, Double).self) { group in
            var answers = Array(repeating: 0.0, count: ingredients.count)
            var next = 0
            func ask(_ index: Int) {
                let prompt = Self.english("Claude.Prompt.Toppings.Ask", dish, method, ingredients[index])
                group.addTask {
                    let answer = try await self.answer(.toppings, system: system, prompt: prompt, maximumTokens: 16)
                    guard let value = Self.firstNumber(in: answer) else { throw CloudError.noResponse }
                    return (index, min(max(value, 0), 1))
                }
            }
            while next < min(Self.toppingsAtOnce, ingredients.count) {
                ask(next)
                next += 1
            }
            while let (index, value) = try await group.next() {
                answers[index] = value
                if next < ingredients.count {
                    ask(next)
                    next += 1
                }
            }
            return answers
        }
    }

    // MARK: - Drawing

    /// Room for a dish icon's SVG, which runs to a few thousand tokens.
    static let drawingTokens = 6000

    /// Claude's drawing of the dish as an SVG, from its title, its ingredient lines, and the
    /// last step, which says how it is served.
    func drawDish(title: String, ingredients: [String], finish: String) async throws -> String {
        let prompt = Self.english(
            "Claude.Prompt.DishIcon.Ask",
            title,
            ingredients.map { "- \($0)" }.joined(separator: "\n"),
            finish
        )
        return try await answer(.draw, system: Self.english("Claude.Prompt.DishIcon"), prompt: prompt, maximumTokens: Self.drawingTokens)
    }

    // MARK: - Requests

    /// The whole answer to one request, streamed and put together.
    private func answer(
        _ role: ClaudeRole,
        system: String,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]? = nil
    ) async throws -> String {
        var text = ""
        for try await piece in stream(role, system: system, prompt: prompt, maximumTokens: maximumTokens, schema: schema) {
            text += piece
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CloudError.noResponse }
        return trimmed
    }

    private func send(
        _ role: ClaudeRole,
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
        _ role: ClaudeRole,
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
            "model": role.model,
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

    nonisolated static func firstNumber(in text: String) -> Double? {
        guard let range = text.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[range])
    }

    nonisolated private static func english(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(culinaryEnglish: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
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
