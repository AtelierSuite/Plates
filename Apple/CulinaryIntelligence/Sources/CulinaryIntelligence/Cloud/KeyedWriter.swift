import Foundation

/// What a request to a writer on the cook's own key is for. Claude sends each role to the model
/// it calls for; GPT 6.1 Sol answers every one.
enum WriterRole: Sendable {
    case write, edit, draw
    case ideas, plan, parse
    case decide, toppings, sort, translate
}

/// An error a writer on the cook's own key answered with, about the key, the account, or the
/// request. A pass that meets one is not tried again.
nonisolated protocol WriterAccountError: LocalizedError {}

/// A writer on the cook's own key, such as Claude or GPT 6.1 Sol. Requests go from the device
/// straight to the provider, so neither App Attest nor Plates' daily limits apply. Each one
/// only streams an answer to a request; picking, the dish icon questions, drawing, and the passes
/// Apple Intelligence would otherwise run are asked the same way of all of them.
@MainActor
protocol KeyedWriter: RecipeWriting {
    /// The answer to one request, a piece at a time, after an example exchange when one is
    /// given, and held to a JSON Schema when one is given. An answer that ran out of tokens ends
    /// in `CloudError.cutOff`.
    func stream(
        _ role: WriterRole,
        system: String,
        example: (ask: String, answer: String)?,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]?
    ) -> AsyncThrowingStream<String, Error>
}

/// How many dish icon questions are in flight at once, to stay inside a new account's rate limits.
nonisolated private let toppingsAtOnce = 3

/// Room for a dish icon's SVG, which runs to a few thousand tokens.
nonisolated let drawingTokens = 6000

extension KeyedWriter {
    var isAllowed: Bool { UserDefaults.standard.bool(forKey: Plates.allowedKey) }

    /// The cook's own key has no daily limit from us.
    var writesRemaining: Int? { .max }

    // MARK: - Writing

    /// These models take no sampling settings, so the temperature is left out.
    func write(
        instructions: String,
        example: (ask: String, answer: String)?,
        prompt: String,
        maximumTokens: Int,
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
        stream(.write, system: instructions, example: example, prompt: prompt, maximumTokens: maximumTokens, schema: nil)
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
        _ role: WriterRole,
        system: String,
        prompt: String,
        schema: [String: Any],
        maximumTokens: Int
    ) async throws -> String {
        try await answer(role, system: system, prompt: prompt, maximumTokens: maximumTokens, schema: schema)
    }

    /// A pass that answers in plain text, such as a translation.
    func plain(_ role: WriterRole, system: String, prompt: String, maximumTokens: Int) async throws -> String {
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
        let none = writerEnglish("Generate.Prompt.Plan.None")
        let separator = writerEnglish("Generate.Prompt.Separator")
        let listed = ideas.enumerated().map { index, idea in
            idea.summary.isEmpty ? "\(index + 1). \(idea.title)" : "\(index + 1). \(idea.title): \(idea.summary)"
        }
        let prompt = writerEnglish(
            "Writer.Prompt.Decide.Ask",
            request,
            ingredients.isEmpty ? none : ingredients.joined(separator: separator),
            tools.isEmpty ? none : tools.joined(separator: separator),
            listed.joined(separator: "\n")
        )
        let answer = try await answer(.decide, system: writerEnglish("Writer.Prompt.Decide"), prompt: prompt, maximumTokens: 16)
        guard let number = firstNumber(in: answer), number == number.rounded(),
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
        let system = writerEnglish("Writer.Prompt.Toppings")
        return try await withThrowingTaskGroup(of: (Int, Double).self) { group in
            var answers = Array(repeating: 0.0, count: ingredients.count)
            var next = 0
            func ask(_ index: Int) {
                let prompt = writerEnglish("Writer.Prompt.Toppings.Ask", dish, method, ingredients[index])
                group.addTask {
                    let answer = try await self.answer(.toppings, system: system, prompt: prompt, maximumTokens: 16)
                    guard let value = firstNumber(in: answer) else { throw CloudError.noResponse }
                    return (index, min(max(value, 0), 1))
                }
            }
            while next < min(toppingsAtOnce, ingredients.count) {
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

    /// The writer's drawing of the dish as an SVG, from its title, its ingredient lines, and the
    /// last step, which says how it is served.
    func drawDish(title: String, ingredients: [String], finish: String) async throws -> String {
        let prompt = writerEnglish(
            "Writer.Prompt.DishIcon.Ask",
            title,
            ingredients.map { "- \($0)" }.joined(separator: "\n"),
            finish
        )
        return try await answer(.draw, system: writerEnglish("Writer.Prompt.DishIcon"), prompt: prompt, maximumTokens: drawingTokens)
    }

    // MARK: - Requests

    /// The whole answer to one request, streamed and put together.
    func answer(
        _ role: WriterRole,
        system: String,
        prompt: String,
        maximumTokens: Int,
        schema: [String: Any]? = nil
    ) async throws -> String {
        var text = ""
        for try await piece in stream(role, system: system, example: nil, prompt: prompt, maximumTokens: maximumTokens, schema: schema) {
            text += piece
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CloudError.noResponse }
        return trimmed
    }
}

/// The first number in an answer, such as the idea picked or how likely a topping shows.
nonisolated func firstNumber(in text: String) -> Double? {
    guard let range = text.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
    return Double(text[range])
}

/// A prompt as it is sent, always in English.
nonisolated func writerEnglish(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
    let format = String(culinaryEnglish: key)
    return arguments.isEmpty ? format : String(format: format, arguments: arguments)
}

/// Reads the lines of a streamed answer and hands each `data:` payload to `text`, which returns
/// the text it carries or throws the error that ends the answer.
func streamedText(
    from send: @escaping @MainActor () async throws -> URLSession.AsyncBytes,
    text: @escaping @Sendable (String) throws -> String?
) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        let task = Task { @MainActor in
            do {
                let bytes = try await send()
                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }
                    if let piece = try text(String(line.dropFirst(5))) {
                        continuation.yield(piece)
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
