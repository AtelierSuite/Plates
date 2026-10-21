import FoundationModels
import Foundation

/// A dish Gemma suggested for a request that named goals or nothing in particular. The list
/// shows it in the reader's language, and Gemma writes it from its own English.
public struct RecipeIdea: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let summary: String
    let englishTitle: String
    let englishSummary: String
}

/// What to do with a request: write it as asked, or offer ideas to pick from first. A set of
/// ideas carries the ID a Decide for me pick of it is sent with, so a retry is not counted twice.
public enum RecipePlan: Equatable, Sendable {
    case write
    case ideas([RecipeIdea], requestID: String)
}

/// The three kinds of request, which decide whether ideas are offered and how they are chosen.
enum RequestKind: String {
    /// One dish, named: written as asked when the cook's kitchen can make it.
    case dish
    /// What the meal should be or have, such as "high protein with noodles".
    case goals
    /// Anything that fits, such as "something easy when I'm tired".
    case open
}

@Generable(description: "What kind of request a cook typed")
struct RequestKindAnswer {
    @Guide(
        description: "'dish' when it names one dish to cook, 'goals' when it lists what the meal should be or have, such as 'high protein with noodles', or 'open' when anything that fits will do, such as 'something easy tonight'",
        .anyOf(["dish", "goals", "open"])
    )
    var kind: String
}

@Generable(description: "Whether a dish can be cooked from what the cook has")
struct MakeableAnswer {
    @Guide(description: "True when the dish can be cooked properly from the listed ingredients and tools, adding nothing but salt, pepper, oil, and water")
    var makeable: Bool
}

/// The starch a dish is built on, read without the cook's list in view. Asked whether the picks
/// can make the dish, the model says yes to a tomato pasta with no pasta in them, so whether the
/// starch is among the picks is checked in code.
@Generable(description: "The starch a dish is built on")
struct StapleAnswer {
    @Guide(
        description: "The starch the dish is built on: 'pasta' for a pasta dish such as a tomato pasta or a carbonara, 'rice' for a dish such as a fried rice, a risotto, or a rice bowl, 'noodles' for a noodle dish such as a ramen or a yakisoba, 'bread' for a sandwich or a toast, or 'none' when it is not built on one of these",
        .anyOf(["pasta", "rice", "noodles", "bread", "none"])
    )
    var staple: String
}

@Generable(description: "A dish idea put into the reader's language")
struct GeneratedIdea {
    @Guide(description: "The dish's name, two to five words")
    var title: String

    @Guide(description: "One plain sentence saying what the dish is and roughly how long it takes")
    var summary: String
}

extension RecipeGenerator {
    /// Works out whether a request is written as asked or offered as ideas first. A named dish
    /// the cook's kitchen can make is written straight away. Goals, an open request, or a dish
    /// the kitchen cannot make get five ideas from Gemma, put into the reader's language.
    public func plan(_ asked: GenerationRequest) async -> RecipePlan? {
        let request = asked.asAsked
        state = .planning
        passes.beginBackgroundRun(named: "Recipe planning")
        defer { passes.endBackgroundRun() }
        do {
            let kind = try await kind(of: request)
            if kind == .dish, try await canMake(request) {
                state = .idle
                return .write
            }
            let ideas = try await ideas(for: request, kind: kind)
            state = .idle
            return .ideas(ideas, requestID: UUID().uuidString)
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Asks Jev to pick one of the ideas for the cook. It reads Gemma's English for them, the
    /// cook's own words for the request, and what they picked in the catalog.
    public func decide(_ asked: GenerationRequest, ideas: [RecipeIdea], requestID: String) async throws -> CloudPick {
        let request = asked.asAsked
        return try await cloud.decide(
            requestID: requestID,
            request: request.trimmedDescription.isEmpty ? Self.english("Generate.Prompt.Ask.Any") : request.trimmedDescription,
            ingredients: request.ingredientNames,
            tools: request.toolNames,
            ideas: ideas.map { (title: $0.englishTitle, summary: $0.englishSummary) }
        )
    }

    /// How many Decide for me picks are left today, or nil when that cannot be found out.
    public func decisionsRemaining() async -> Int? {
        try? await cloud.limits().decide.remaining
    }

    // MARK: - Planning

    /// A request with no words is open: the cook only showed what they have.
    private func kind(of request: GenerationRequest) async throws -> RequestKind {
        let words = request.trimmedDescription
        guard !words.isEmpty else { return .open }
        let answer = try await writer.run(instructions: Self.text("Generate.Prompt.Plan")) { session in
            try await session.respond(
                to: Self.text("Generate.Prompt.Plan.Kind", words),
                generating: RequestKindAnswer.self,
                options: GenerationOptions(maximumResponseTokens: Self.lineTokenLimit)
            ).content
        }
        return RequestKind(rawValue: answer.kind) ?? .dish
    }

    /// A dish with no picks to hold it to can always be written. A dish built on a starch the
    /// picks do not have cannot, since Gemma, held to the list, writes it without one.
    private func canMake(_ request: GenerationRequest) async throws -> Bool {
        guard !request.ingredients.isEmpty || !request.tools.isEmpty else { return true }
        if !request.ingredients.isEmpty, let staples = try await staples(of: request),
           staples.isDisjoint(with: request.ingredients) {
            return false
        }
        let none = Self.text("Generate.Prompt.Plan.None")
        let ingredients = request.ingredients.prefix(GenerationRequest.listLimit).map(IconCatalog.displayName)
        let tools = request.tools.prefix(GenerationRequest.listLimit).map(IconCatalog.displayName)
        let answer = try await writer.run(instructions: Self.text("Generate.Prompt.Plan")) { session in
            try await session.respond(
                to: Self.text(
                    "Generate.Prompt.Plan.Makeable",
                    request.trimmedDescription,
                    ingredients.isEmpty ? none : ModelPasses.joined(ingredients),
                    tools.isEmpty ? none : ModelPasses.joined(tools)
                ),
                generating: MakeableAnswer.self,
                options: GenerationOptions(maximumResponseTokens: Self.lineTokenLimit)
            ).content
        }
        return answer.makeable
    }

    /// The catalog ingredients that would stand for the starch the dish is built on, or nil
    /// when it is built on none. Asked in English, so the answer names the same starch in any
    /// language the cook typed in.
    private func staples(of request: GenerationRequest) async throws -> Set<String>? {
        let answer = try await writer.run(instructions: Self.english("Generate.Prompt.Plan")) { session in
            try await session.respond(
                to: Self.english("Generate.Prompt.Plan.Staple", request.trimmedDescription),
                generating: StapleAnswer.self,
                options: GenerationOptions(maximumResponseTokens: Self.lineTokenLimit)
            ).content
        }
        return Self.staples[answer.staple]
    }

    /// Each starch with the catalog ingredients that make it, so a tomato pasta is made with
    /// penne as well as spaghetti.
    static let staples: [String: Set<String>] = [
        "pasta": ["pasta", "spaghetti", "penne", "fusilli", "fettuccine", "rigatoni", "macaroni", "lasagna", "orzo", "ravioli", "gnocchi"],
        "rice": ["rice", "arborio-rice", "glutinous-rice"],
        "noodles": ["noodles", "egg-noodles", "ramen", "udon", "soba", "somen", "rice-noodles", "harusame"],
        "bread": ["bread", "pita", "naan", "baguette", "buns"],
    ]

    /// Five dishes from Gemma, in English, one a line, then put into the reader's language.
    private func ideas(for request: GenerationRequest, kind: RequestKind) async throws -> [RecipeIdea] {
        let english = await inEnglish(request)
        let written = try await cloud.ideate(
            instructions: Self.ideaInstructions(for: english),
            prompt: Self.ideaPrompt(for: english, kind: kind),
            maximumTokens: Self.ideaTokenLimit
        )
        let lines = Self.ideaLines(in: written)
        guard lines.count >= 2 else { throw CloudError.noResponse }
        var ideas: [RecipeIdea] = []
        for (index, line) in lines.enumerated() {
            var title = line.title
            var summary = line.summary
            if !Self.readsInEnglish {
                let translated = try await sortLine(
                    GeneratedIdea.self,
                    Self.text("Generate.Prompt.Structure.Idea.Ask", summary.isEmpty ? title : "\(title): \(summary)")
                )
                title = translated.title.withoutLeakedSyntax
                summary = translated.summary.withoutLeakedSyntax
            }
            ideas.append(RecipeIdea(id: index, title: title, summary: summary, englishTitle: line.title, englishSummary: line.summary))
        }
        return ideas
    }

    /// Enough for five lines and a little over.
    private static let ideaTokenLimit = 500

    /// How many ideas are offered.
    static let ideaCount = 5

    /// Whether the app is read in English, in which case Gemma's ideas are shown as written.
    static var readsInEnglish: Bool {
        Bundle.module.preferredLocalizations.first?.hasPrefix("en") ?? true
    }

    private static func ideaInstructions(for request: GenerationRequest) -> String {
        var instructions = english("Generate.Prompt.HouseStyle") + "\n\n" + english("Generate.Prompt.Ideas")
        if !request.ingredients.isEmpty {
            instructions += "\n\n" + english("Generate.Prompt.Write.Kitchen")
        }
        if !request.tools.isEmpty {
            instructions += "\n\n" + english("Generate.Prompt.Write.Tools")
        }
        return instructions
    }

    private static func ideaPrompt(for request: GenerationRequest, kind: RequestKind) -> String {
        let separator = english("Generate.Prompt.Separator")
        let words = request.trimmedDescription
        var lines: [String] = []
        switch (kind, words.isEmpty) {
        case (_, true): lines.append(english("Generate.Prompt.Ideas.Any"))
        case (.dish, false): lines.append(english("Generate.Prompt.Ideas.Near", words))
        case (.goals, false): lines.append(english("Generate.Prompt.Ideas.Goals", words))
        case (.open, false): lines.append(english("Generate.Prompt.Ideas.Open", words))
        }
        if !request.writtenAs.isEmpty {
            lines.append(english("Generate.Prompt.Ask.WrittenAs", request.writtenAs))
        }
        if !request.ingredients.isEmpty {
            lines.append(english("Generate.Prompt.Have.Ingredients", request.ingredientNames.joined(separator: separator)))
        }
        if !request.tools.isEmpty {
            lines.append(english("Generate.Prompt.Have.Tools", request.toolNames.joined(separator: separator)))
        }
        return lines.joined(separator: "\n")
    }

    /// Gemma's ideas, a title and a summary each, read off lines such as "1. **Egg Fried
    /// Rice**: One pan, 15 minutes." A line with no title, or a heading such as "Here are five
    /// ideas:", is skipped.
    static func ideaLines(in text: String) -> [(title: String, summary: String)] {
        var ideas: [(title: String, summary: String)] = []
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: #"^\s*(?:[-*•]|\d+[.)])\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasSuffix(":") else { continue }
            var summary = ""
            for separator in [": ", " - ", " \u{2013} ", " \u{2014} "] {
                if let range = line.range(of: separator) {
                    summary = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    line = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            guard !line.isEmpty, line.count <= 80, !(summary.isEmpty && line.count > 60) else { continue }
            ideas.append((line, summary))
            if ideas.count == ideaCount { break }
        }
        return ideas
    }
}
