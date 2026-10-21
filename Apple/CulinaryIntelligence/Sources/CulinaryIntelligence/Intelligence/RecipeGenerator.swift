import FoundationModels
import Foundation
import NaturalLanguage

/// What a new recipe is built from: a dish in the cook's words, what they have in the
/// kitchen, or both.
public struct GenerationRequest: Equatable, Sendable {
    /// The dish, written by the cook. May be empty when they only picked what they have.
    public var description = ""
    /// Ingredient asset names picked from the catalog.
    public var ingredients: [String] = []
    /// Tool asset names picked from the catalog.
    public var tools: [String] = []
    /// Set when the cook wants the picks left out, so the model writes from the dish alone.
    public var ignoresPicks = false
    /// The cook's own words, kept beside a translation of them. The on-device model tells
    /// what 宮保鶏丁 or 親子丼 is made of rather than naming it, and Gemma knows both by name.
    var writtenAs = ""

    public init(
        description: String = "",
        ingredients: [String] = [],
        tools: [String] = [],
        ignoresPicks: Bool = false
    ) {
        self.description = description
        self.ingredients = ingredients
        self.tools = tools
        self.ignoresPicks = ignoresPicks
    }

    /// Nothing to work from, so there is nothing to ask for. Ignoring the picks is itself an
    /// ask, so a recipe can be written from nothing else.
    public var isEmpty: Bool {
        !ignoresPicks && trimmedDescription.isEmpty && ingredients.isEmpty && tools.isEmpty
    }

    /// The request as the model is given it. The picks stay on the form so the next recipe
    /// starts from the same shelf, but nothing built from them reaches a prompt while they
    /// are ignored.
    var asAsked: GenerationRequest {
        guard ignoresPicks else { return self }
        var request = self
        request.ingredients = []
        request.tools = []
        return request
    }

    var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The picked ingredients in English, the language Gemma is asked in. A cook can tap the
    /// whole catalog, which is more than a prompt should carry, so only the first `listLimit`
    /// are named. Narrowing the choice is safe: what is left is still only things they have.
    var ingredientNames: [String] {
        ingredients.prefix(Self.listLimit).map(IconCatalog.englishName)
    }

    /// The picked tools in English, capped the same way.
    var toolNames: [String] { tools.prefix(Self.listLimit).map(IconCatalog.englishName) }

    /// How many picked items a prompt names before it stops listing.
    static let listLimit = 40
}

/// The recipe as the sorting passes leave it, before it is put in the schema's shape.
struct SortedRecipe {
    var title: String
    var time: String
    var serves: String
    /// Each ingredient with the line Gemma wrote for it, which is what its icon is read from.
    var ingredients: [(entry: StructuredIngredient, line: String)]
    var tools: [GeneratedTool]
    var steps: [(title: String, points: [String])]
    var troubleshooting: [GeneratedTroubleshooting]
}

/// The recipe's title, put into the reader's language.
@Generable(description: "A recipe's title")
struct GeneratedTitle {
    @Guide(description: "The recipe's title in title case, two to four words. Name the dish and nothing else.")
    var title: String
}

/// The total time, worked out from the method when Gemma did not give one.
@Generable(description: "How long a recipe takes")
struct GeneratedTime {
    @Guide(description: "Total time written as a minute count, for example '15 min'")
    var time: String
}

/// One ingredient line, sorted.
@Generable(description: "One ingredient of a recipe")
struct StructuredIngredient {
    @Guide(description: "The ingredient's name, without the amount or the prep")
    var item: String

    @Guide(
        description: "Where it is bought: 'fresh' for vegetables, meat, seafood, dairy, bread, and eggs, 'pantry' for shelf-stable items such as oil, soy sauce, salt, sugar, rice, and pasta, or 'optional' when the recipe says it can be skipped",
        .anyOf(["fresh", "pantry", "optional"])
    )
    var section: String

    @Guide(description: "The catalog icon for this ingredient in English, lowercase and hyphenated, such as 'spring-onion'")
    var icon: String

    @Guide(description: "The quantity only, such as '150 g', '1/2', '2 tbsp', or 'to taste'")
    var amount: String

    @Guide(description: "One sentence, only when it changes what you buy. Otherwise leave empty.")
    var note: String
}

/// One step, sorted. What it says is written out as one piece of text and cut into sentences
/// afterwards, so the model has no slots to fill and nothing to pad them with.
@Generable(description: "One step of a recipe")
struct StructuredStep {
    @Guide(description: "A short imperative step title, such as 'Brown pork'")
    var title: String

    @Guide(description: "Everything the step says to do, written out in plain sentences")
    var text: String
}

@Generable(description: "One tool a recipe uses")
struct GeneratedTool {
    @Guide(description: "The tool name on its own, such as 'Pan'. A size or a qualifier goes in the note.")
    var name: String

    @Guide(description: "The catalog icon for this tool, lowercase and hyphenated, such as 'cutting-board'")
    var icon: String

    @Guide(description: "True when the recipe cannot be cooked without it")
    var required: Bool

    @Guide(description: "One sentence, only when the tool needs a size or can be skipped or swapped. Otherwise leave empty.")
    var note: String
}

@Generable(description: "One problem a cook runs into, and its fix")
struct GeneratedTroubleshooting {
    @Guide(description: "A short symptom with no closing period, such as 'The rice turned mushy'")
    var problem: String

    @Guide(description: "One to three full sentences that fix it")
    var solution: String
}

/// How much of the recipe has arrived so far, read off each streamed snapshot.
public struct GenerationProgress: Equatable, Sendable {
    /// The passes the generator runs, in order.
    public enum Stage: Int, Equatable, Sendable {
        case write
        case shopping
        case method

        public var title: LocalizedStringResource {
            switch self {
            case .write: LocalizedStringResource(culinary: "Generate.Progress.Stage.Write")
            case .shopping: LocalizedStringResource(culinary: "Generate.Progress.Stage.Shopping")
            case .method: LocalizedStringResource(culinary: "Generate.Progress.Stage.Method")
            }
        }
    }

    public var stage: Stage = .write
    /// The recipe as Gemma has written it so far, shown while it is the only thing there is.
    public var draft = ""
    /// How many tokens Gemma has written, which is what the bar reads during the first pass.
    public var writtenTokens = 0
    public var title: String?
    public var time: String?
    public var serves: String?
    public var ingredientCount = 0
    public var toolCount = 0
    public var stepCount = 0
    public var troubleshootingCount = 0
    /// The ingredients and tools as they are sorted, each a name with its amount or note.
    public var ingredients: [Line] = []
    public var tools: [Line] = []
    /// The step titles as they stand, so the preview reads the method as it is sorted.
    public var outline: [String] = []
    /// The problems as they are sorted, without their fixes.
    public var problems: [String] = []
    /// Set when the last pass ends, so the bar always lands on full.
    public var isFinished = false
    /// Set when the recipe came off a web page, which has nothing for Gemma to write, so the
    /// sorting is the whole of the work.
    public var readsPage = false

    public init() {}

    /// One sorted ingredient or tool, as the preview lists it.
    public struct Line: Equatable, Sendable {
        public let name: String
        public let detail: String
    }

    /// What the lock screen is told, which is the pass in words and the dish once it has a
    /// name of its own.
    public var activity: ActivityProgress {
        ActivityProgress(
            stage: String(localized: stage.title),
            dish: title,
            fraction: fraction
        )
    }

    /// How far along the model is. Each pass carries the share of the work it does. How long
    /// Gemma writes for is not known ahead, so the first pass is measured against the length
    /// a recipe usually runs to and held short of full until it stops.
    public var fraction: Double {
        guard !isFinished else { return 1 }
        let sorting = sortingFraction
        guard !readsPage else { return sorting.shopping * 0.4 + sorting.method * 0.6 }
        let write = stage.rawValue > Stage.write.rawValue
            ? 1
            : min(Double(writtenTokens) / Self.typicalTokens, 0.95)
        return write * 0.5 + sorting.shopping * 0.2 + sorting.method * 0.3
    }

    /// How far each sorting pass is along, each out of one.
    private var sortingFraction: (shopping: Double, method: Double) {
        let shopping = stage.rawValue > Stage.shopping.rawValue ? 1 : [
            title == nil ? 0 : 1,
            min(Double(ingredientCount) / 6, 1),
            readsPage ? 1 : min(Double(toolCount) / 3, 1),
        ].reduce(0, +) / 3
        let method = readsPage
            ? min(Double(stepCount) / 5, 1)
            : [
                min(Double(stepCount) / 5, 1),
                min(Double(troubleshootingCount) / 2, 1),
            ].reduce(0, +) / 2
        return (shopping, method)
    }

    /// About how many tokens a recipe runs to, read off the Plates Kitchen evals.
    private static let typicalTokens = 550.0
}

/// Writes a new recipe with two models, each doing what it is good at.
///
/// Gemma, running on Workers AI behind PlatesCloud, writes the whole recipe as plain cookbook
/// text in one go, always in English, since a model its size gets the cooking right far more
/// often in English than in Japanese. A request the cook wrote in another language is put into
/// English for it first.
///
/// What Gemma wrote is then cut into its sections in code, and the time and the serving count
/// are read out of it there. Apple Intelligence sorts the rest one line at a time, each line in
/// a session of its own: the title, every ingredient, every tool, every step, and every problem.
/// Handed a whole list at once, it drops lines, merges them, and fills the gaps from elsewhere
/// in the recipe; handed one line, it has nothing to do but put that line where it goes. The
/// sorting passes are asked in the reader's language, so they are where a recipe read in
/// Japanese is put into Japanese. When a section is not in a shape the reading can split, it is
/// sorted from the whole text instead.
///
/// There is no read through at the end. One was tried, and with the sorting faithful line for
/// line it did more harm than good: it rewrote whole lists, dropping and duplicating lines and
/// adding ones Gemma never wrote. What is handed over is Gemma's recipe, sorted.
@MainActor
@Observable
public final class RecipeGenerator {
    public enum State: Equatable {
        case idle
        /// Working out whether to write the request as asked or offer ideas first.
        case planning
        case generating
        case failed(String)
    }

    public internal(set) var state: State = .idle

    /// Every change is passed on to the observer, so the lock screen keeps up with the sheet.
    public internal(set) var progress = GenerationProgress() {
        didSet { observer?.runUpdated(progress.activity) }
    }

    /// The sorting passes, which check what was written against the schema line by line.
    let passes = ModelPasses()

    /// The passes that plan and translate: what kind of request the cook typed, and the words
    /// of it put into English for Gemma.
    let writer = ModelPasses()

    /// Where Gemma writes, and where Jev picks an idea.
    let cloud = PlatesCloud.shared

    /// Where the run reports how far along it is.
    let observer: (any RunObserver)?

    public init(observer: (any RunObserver)? = nil) {
        self.observer = observer
    }

    /// Every model the run needs has to be there: Gemma to write and Apple Intelligence to
    /// sort.
    public var isAvailable: Bool { passes.isAvailable && cloud.isConfigured }

    /// Why the button is disabled, in words a cook can act on.
    public var unavailableReason: LocalizedStringResource? {
        passes.unavailableReason
            ?? (cloud.isConfigured ? nil : LocalizedStringResource(culinary: "Generate.Unavailable.CloudMissing"))
    }

    /// Writes the recipe the cook asked for, or the idea they picked for it. An idea is written
    /// from Gemma's own English for it, and its title in the reader's language stands in for
    /// the cook's words when the title is sorted.
    public func generate(_ asked: GenerationRequest, idea: RecipeIdea? = nil) async -> Recipe? {
        var request = asked.asAsked
        state = .generating
        progress = GenerationProgress()
        observer?.runStarted(progress.activity)
        passes.beginBackgroundRun(named: "Recipe generation")
        defer { passes.endBackgroundRun() }
        do {
            var english = request
            if let idea {
                english.description = idea.englishSummary.isEmpty
                    ? idea.englishTitle
                    : "\(idea.englishTitle): \(idea.englishSummary)"
                request.description = idea.title
            } else {
                english = await inEnglish(request)
            }
            let text = try await write(english)
            let written = Self.withoutUnusedPicks(WrittenRecipe(parsing: text), request: request)
            let sorted = try await sort(
                written,
                text: text,
                request: request,
                translation: english.writtenAs.isEmpty ? "" : english.description
            )
            var recipe = Self.makeRecipe(sorted)
            recipe.dish = await Dish.asked(for: recipe)
            progress.isFinished = true
            state = .idle
            observer?.runEnded(progress.activity, succeeded: true)
            return recipe
        } catch {
            state = .failed(error.localizedDescription)
            observer?.runEnded(progress.activity, succeeded: false)
            return nil
        }
    }

    // MARK: - Writing

    /// The cook's words put into English before Gemma reads them. A request that is not
    /// already English is translated by Apple Intelligence first. A translation that fails passes the words through as they were
    /// written, which is no worse than not trying.
    func inEnglish(_ request: GenerationRequest) async -> GenerationRequest {
        progress.stage = .write
        let words = request.trimmedDescription
        guard !words.allSatisfy(\.isASCII) else { return request }
        do {
            let english = try await writer.run(instructions: Self.english("Generate.Prompt.Translate")) { session in
                try await session.respond(
                    to: words,
                    options: GenerationOptions(maximumResponseTokens: Self.lineTokenLimit)
                ).content
            }
            let translated = english.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translated.isEmpty else { return request }
            var asked = request
            asked.description = translated
            asked.writtenAs = words
            return asked
        } catch {
            return request
        }
    }

    /// Gemma writes the recipe as a cookbook would print it, put on screen a finished line at a
    /// time. It arrives in pieces rather than tokens, so the count shown is worked out from the
    /// length.
    private func write(_ request: GenerationRequest) async throws -> String {
        progress.stage = .write
        var written = ""
        let stream = cloud.write(instructions: Self.writeInstructions(for: request), prompt: Self.prompt(for: request))
        for try await piece in stream {
            written += piece
            guard piece.contains("\n"), let end = written.lastIndex(of: "\n") else { continue }
            show(String(written[..<end]), of: written)
        }
        show(written, of: written)
        let text = written.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CloudError.noResponse }
        return text
    }

    /// Puts the finished lines on screen.
    private func show(_ lines: String, of written: String) {
        var shown = progress
        shown.draft = lines
        shown.writtenTokens = written.count / 4
        progress = shown
    }

    // MARK: - Sorting

    /// Sorts what Gemma wrote into the recipe, a line at a time. A recipe read off a web page
    /// lists no tools, so the ones its method names are found in code and handed in as `found`.
    /// `translation` is the cook's request as Gemma was given it, when it had to be put into
    /// English.
    func sort(
        _ written: WrittenRecipe,
        text: String,
        request: GenerationRequest,
        translation: String = "",
        found: [GeneratedTool]? = nil
    ) async throws -> SortedRecipe {
        progress.stage = .shopping
        progress.time = Self.time(from: written.time)
        progress.serves = Self.serves(from: written.serves)
        let title = try await sortTitle(written, text: text, request: request, translation: translation)
        progress.title = title

        var ingredients: [(entry: StructuredIngredient, line: String)] = []
        var tools: [GeneratedTool] = []
        if written.ingredients.isEmpty || (written.tools.isEmpty && found == nil) {
            let whole = try await sortWholeShopping(text: text)
            ingredients = whole.0.map { ($0, "") }
            tools = whole.1
            progress.ingredients = ingredients.map { .init(name: $0.entry.item.withoutLeakedSyntax, detail: $0.entry.amount.withoutLeakedSyntax) }
            progress.tools = tools.map { .init(name: $0.name.withoutLeakedSyntax, detail: "") }
        } else {
            for line in written.ingredients {
                let measured = Measures.forReader(line)
                var prompt = Self.text("Generate.Prompt.Structure.Ingredient.Ask", measured)
                // The catalog's own name for what the line names, so the pass translates
                // "frozen peas" with the word for peas rather than one it half remembers. A
                // reader in English is not given it: there is nothing to translate, and handed
                // the catalog's word the pass wrote it in place of the line's, so ground pork
                // came back as minced meat and lemon juice as lemon. Nor is it given when the line
                // only reaches the catalog through another word for it, as "chicken stock" does
                // the bouillon, which in Japanese is a stock cube.
                if !Self.readsInEnglish, let asset = Self.namedIngredient(in: line),
                   line.lowercased().contains(IconCatalog.englishName(for: asset).lowercased()) {
                    prompt += "\n" + Self.text("Generate.Prompt.Structure.Ingredient.Known", IconCatalog.displayName(for: asset))
                }
                var entry = try await sortLine(StructuredIngredient.self, prompt)
                entry.amount = Self.amount(entry.amount, from: measured)
                entry.section = Self.section(for: entry, line: line)
                ingredients.append((entry, line))
                progress.ingredients.append(.init(name: entry.item.withoutLeakedSyntax, detail: entry.amount.withoutLeakedSyntax))
                progress.ingredientCount = ingredients.count
            }
            if let found {
                tools = found
                progress.tools = found.map { .init(name: $0.name, detail: "") }
                progress.toolCount = found.count
            }
            for line in written.tools where found == nil {
                var tool = try await sortLine(
                    GeneratedTool.self,
                    Self.text("Generate.Prompt.Structure.Tool.Ask", Measures.forReader(line))
                )
                // Gemma says when a tool can be done without. The pass has marked the only pan
                // in a recipe as optional, so its guess is not asked for.
                tool.required = !Self.isOptional(line)
                // The icon is read from Gemma's English, as an ingredient's is. The pass has put
                // a cutting board on a knife and a cast iron skillet on a non-stick one.
                if let named = Self.namedTools(in: [line], limit: 1).first {
                    tool.icon = named
                }
                tools.append(tool)
                progress.tools.append(.init(name: tool.name.withoutLeakedSyntax, detail: ""))
                progress.toolCount = tools.count
            }
            // Gemma lists the tins a cake bakes in and leaves out the oven, in every baking
            // recipe the evals asked for. One the method bakes in is listed for it.
            if found == nil, !tools.contains(where: { $0.icon == "oven" }),
               Self.namedTools(in: written.steps).contains("oven") {
                let oven = GeneratedTool(name: IconCatalog.displayName(for: "oven"), icon: "oven", required: true, note: "")
                tools.append(oven)
                progress.tools.append(.init(name: oven.name, detail: ""))
                progress.toolCount = tools.count
            }
        }

        progress.stage = .method
        progress.outline = []
        var steps: [(title: String, points: [String])] = []
        var notes: [GeneratedTroubleshooting] = []
        if written.steps.isEmpty {
            (steps, notes) = try await sortWholeMethod(text: text)
        } else {
            for line in written.steps {
                let prompt = Self.text("Generate.Prompt.Structure.Step.Ask", Measures.forReader(line))
                var step = try await sortLine(StructuredStep.self, prompt)
                // In Japanese, a step has come back with English left in it, "cooked riceを".
                // Asked again it is usually put into Japanese the whole way.
                if !Self.readsInEnglish, Self.leavesEnglish(step.title + " " + step.text) {
                    step = (try? await sortLine(StructuredStep.self, prompt)) ?? step
                }
                steps.append((step.title.withoutLeakedSyntax, Self.sentences(in: step.text.withoutLeakedSyntax)))
                progress.outline.append(step.title.withoutLeakedSyntax)
                progress.stepCount = steps.count
            }
            for line in written.problems {
                let note = try await sortLine(
                    GeneratedTroubleshooting.self,
                    Self.text("Generate.Prompt.Structure.Problem.Ask", Measures.forReader(line))
                )
                notes.append(note)
                progress.problems.append(note.problem.withoutLeakedSyntax)
                progress.troubleshootingCount = notes.count
            }
        }
        guard !ingredients.isEmpty, !steps.isEmpty else { throw IntelligenceError.empty }
        if progress.time?.isEmpty ?? true {
            progress.time = try await estimateTime(written, text: text)
        }
        return SortedRecipe(
            title: title,
            time: progress.time ?? "",
            serves: progress.serves ?? "",
            ingredients: ingredients,
            tools: tools,
            steps: steps,
            troubleshooting: notes
        )
    }

    /// The title in the reader's language. The cook's own words for the dish go with it, so it
    /// reads the way they asked for it rather than as a translation of Gemma's.
    private func sortTitle(
        _ written: WrittenRecipe,
        text: String,
        request: GenerationRequest,
        translation: String
    ) async throws -> String {
        // A cook who named a dish in their own language and got that dish has the best title
        // for it already. Asked to write one, the pass called わかめ 海苔 and misspelled
        // アラビアータ, with the cook's words in front of it.
        if !translation.isEmpty, request.trimmedDescription.count <= 20,
           Self.namesSameDish(written.title, translation) {
            return request.trimmedDescription
        }
        var lines = [
            written.title.isEmpty
                ? Self.text("Generate.Prompt.Structure.Source", text)
                : Self.text("Generate.Prompt.Structure.Title", written.title),
        ]
        if !request.trimmedDescription.isEmpty {
            lines.append(Self.text("Generate.Prompt.Structure.Request", request.trimmedDescription))
        }
        lines.append(Self.text("Generate.Prompt.Structure.Title.Ask"))
        do {
            let title = try await sortLine(GeneratedTitle.self, lines.joined(separator: "\n")).title.withoutLeakedSyntax
            return Self.titleCased(title)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The guardrails have turned down a dish's own name, "Oyakodon", with every other
            // line of the recipe sorted. The cook's words name the dish in the reader's
            // language, and Gemma's do for a reader in English, so the recipe is not lost to
            // its title.
            let fallback = request.trimmedDescription.isEmpty && !Measures.readsJapanese
                ? written.title
                : request.trimmedDescription
            guard !fallback.isEmpty else { throw error }
            return fallback.prefix(1).uppercased() + fallback.dropFirst()
        }
    }

    /// A title the pass wrote all in lower case, "mapo tofu", put in title case. One with any
    /// capital in it is left as written, so "Penne all'arrabbiata" keeps its small words.
    static func titleCased(_ title: String) -> String {
        guard title.contains(where: \.isLetter), title == title.lowercased(), title.allSatisfy(\.isASCII) else { return title }
        let small: Set<String> = ["a", "an", "and", "in", "of", "on", "or", "the", "with"]
        return title.split(separator: " ").enumerated().map { index, word in
            index > 0 && small.contains(String(word)) ? String(word) : word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }

    /// Whether Gemma's title names the dish the cook asked for: half the words of the request,
    /// as it was put into English, are in the title. "Tofu and seaweed miso soup" is "Miso Soup
    /// with Tofu and Wakame", and "Spicy chicken pieces" is not "Kung Pao Chicken".
    static func namesSameDish(_ title: String, _ asked: String) -> Bool {
        let filler: Set<String> = ["and", "with", "the", "for", "in", "of", "a"]
        func stems(_ text: String) -> Set<String> {
            Set(words(in: text).filter { !filler.contains($0) }.map(stem))
        }
        let askedWords = stems(asked)
        guard !askedWords.isEmpty else { return false }
        return Double(askedWords.intersection(stems(title)).count) / Double(askedWords.count) >= 0.5
    }

    /// The total time from the method, for a recipe Gemma gave none for. The answer is read
    /// back through `time(from:)`, so what is kept is a minute count however it was written.
    private func estimateTime(_ written: WrittenRecipe, text: String) async throws -> String {
        let method = written.steps.isEmpty ? text : written.steps.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let estimate = try await sortLine(GeneratedTime.self, Self.text("Generate.Prompt.Structure.Time.Ask", method))
        return Self.time(from: estimate.time)
    }

    /// One line sorted in a session of its own. A line cannot be left out without the recipe
    /// being wrong, so a pass that fails is tried again.
    func sortLine<Content: Generable>(_ type: Content.Type, _ prompt: String) async throws -> Content {
        try await passes.respond(
            type,
            to: prompt,
            instructions: Self.structureInstructions,
            tokenLimit: Self.lineTokenLimit
        )
    }

    /// The most a pass sorting one line may write. A line of Gemma's runs to a few dozen
    /// tokens, and its sorted form, translated, to a few hundred at most. A pass has been seen to
    /// run on past seven thousand without stopping, and without a limit that overruns the
    /// window and is taken for a request too large for the device. With one, it fails like any
    /// other pass and is tried again.
    static let lineTokenLimit = 600

    /// The same limit for a section sorted from the whole text, which writes every line of it.
    private static let wholeTokenLimit = 2400

    /// The shopping list sorted from the whole text in one pass, for when Gemma wrote it in a
    /// shape the reading could not split into lines.
    private func sortWholeShopping(text: String) async throws -> ([StructuredIngredient], [GeneratedTool]) {
        let schema = try Self.wholeSchema(
            name: "SortedShopping",
            description: "A recipe's shopping list and tools, taken from a written recipe",
            lists: [
                ("ingredients", "The recipe's ingredients in the order it gives them", DynamicGenerationSchema(type: StructuredIngredient.self), 1...16),
                ("tools", "The pans, pots, knives and bowls the recipe uses", DynamicGenerationSchema(type: GeneratedTool.self), 1...8),
            ]
        )
        let prompt = [
            Self.text("Generate.Prompt.Structure.Source", Measures.forReader(text)),
            "",
            Self.text("Generate.Prompt.Structure.Shopping.Ask"),
        ].joined(separator: "\n")
        let content = try await passes.run(instructions: Self.structureInstructions) { session in
            try await session.respond(
                to: prompt,
                schema: schema,
                options: GenerationOptions(maximumResponseTokens: Self.wholeTokenLimit)
            ).content
        }
        return (
            try content.value([GeneratedContent].self, forProperty: "ingredients").map(StructuredIngredient.init),
            try content.value([GeneratedContent].self, forProperty: "tools").map(GeneratedTool.init)
        )
    }

    /// The method sorted from the whole text in one pass, for when Gemma wrote it in a shape
    /// the reading could not split into steps.
    private func sortWholeMethod(
        text: String
    ) async throws -> ([(title: String, points: [String])], [GeneratedTroubleshooting]) {
        let schema = try Self.wholeSchema(
            name: "SortedMethod",
            description: "A recipe's method and troubleshooting, taken from a written recipe",
            lists: [
                ("steps", "The recipe's steps in the order it gives them", DynamicGenerationSchema(type: StructuredStep.self), 1...10),
                ("troubleshooting", "The problems the recipe warns about and their fixes", DynamicGenerationSchema(type: GeneratedTroubleshooting.self), 0...5),
            ]
        )
        let prompt = [
            Self.text("Generate.Prompt.Structure.Source", Measures.forReader(text)),
            "",
            Self.text("Generate.Prompt.Structure.Method.Ask"),
        ].joined(separator: "\n")
        let content = try await passes.run(instructions: Self.structureInstructions) { session in
            try await session.respond(
                to: prompt,
                schema: schema,
                options: GenerationOptions(maximumResponseTokens: Self.wholeTokenLimit)
            ).content
        }
        let steps = try content.value([GeneratedContent].self, forProperty: "steps")
            .map(StructuredStep.init)
            .map { (title: $0.title.withoutLeakedSyntax, points: Self.sentences(in: $0.text.withoutLeakedSyntax)) }
        progress.outline = steps.map(\.title)
        progress.stepCount = steps.count
        let notes = try content.value([GeneratedContent].self, forProperty: "troubleshooting")
            .map(GeneratedTroubleshooting.init)
        progress.problems = notes.map(\.problem.withoutLeakedSyntax)
        progress.troubleshootingCount = notes.count
        return (steps, notes)
    }

    // MARK: - Reading what Gemma wrote

    /// An amount with its unit put back when the pass wrote the figure alone. "1 lb (450g)"
    /// has come back as "450", and "1/2 teaspoon salt" as "1/2", from a pass that was told to
    /// keep the unit. The unit is taken from the line as the reader reads it: a metric unit
    /// after the figure, a spoon or cup before it in Japanese, and in English a spoon, cup, or
    /// count after it.
    static func amount(_ amount: String, from line: String) -> String {
        let figure = amount.trimmingCharacters(in: .whitespaces)
        guard !figure.isEmpty, figure.allSatisfy({ $0.isNumber || $0 == "." || $0 == "/" }) else { return amount }
        let escaped = NSRegularExpression.escapedPattern(for: figure)
        let metric = "kg|g|ml|l|kilograms?|grams?|millilit(?:er|re)s?|lit(?:er|re)s?"
        let units = Measures.readsJapanese
            ? metric
            : metric + "|teaspoons?|tablespoons?|tsp|tbsp|cups?|cloves?|slices?|pinch(?:es)?|cans?|stalks?"
        let patterns = [
            #"(?<![\d/.])"# + escaped + #"\s*(?:"# + units + #")\b"#,
            #"(?:小さじ|大さじ|カップ)"# + escaped + #"(?![\d/.])"#,
        ]
        for pattern in patterns {
            if let range = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                return String(line[range])
            }
        }
        return amount
    }

    /// Whether a translation has an English word of four letters or more left in it. Units and
    /// short marks such as "g", "ml", and "IH" are allowed.
    static func leavesEnglish(_ text: String) -> Bool {
        text.contains(#/[A-Za-z]{4,}/#)
    }

    /// Whether a line Gemma wrote says the recipe can do without it.
    static func isOptional(_ line: String) -> Bool {
        line.lowercased().contains("optional")
    }

    /// The section an ingredient goes in. Whether it is optional is what Gemma's line says,
    /// and an ingredient the pass called optional that the line does not is put on the shelf
    /// its icon sits on.
    static func section(for entry: StructuredIngredient, line: String) -> String {
        if isOptional(line) { return "optional" }
        guard entry.section == "optional" else { return entry.section }
        let asset = ingredientIcon(line: line, guess: entry.icon, item: entry.item)
        return IconCatalog.shelf(of: asset) == .pantry ? "pantry" : "fresh"
    }

    /// Words that count an ingredient rather than name one, so "2 cloves garlic" is not read as
    /// the spice.
    private static let measureWords: Set<String> = [
        "can", "cans", "clove", "cloves", "stalk", "stalks", "slice", "slices", "piece", "pieces",
        "head", "heads", "bunch", "sprig", "sprigs", "pinch", "dash", "handful", "sheet", "sheets",
    ]

    /// The catalog ingredient the line Gemma wrote names outright: the longest run of its
    /// words the catalog knows, aliases included, so "chopped green onions" is a spring onion
    /// and "1 onion, diced" an onion. The sorting pass names an icon too, but it guesses from a
    /// translated name and has put a spring onion on an onion, so the English is read first.
    static func ingredientIcon(line: String, guess: String, item: String) -> String {
        namedIngredient(in: line) ?? IconCatalog.resolveIngredient(guess, itemName: item)
    }

    /// The catalog ingredient a line names outright, when it names one.
    static func namedIngredient(in line: String) -> String? {
        let words = line.lowercased()
            .map { $0.isLetter ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .map(String.init)
            .filter { !measureWords.contains($0) }
        // The longest run wins, and among runs of one length the first: "Salt and pepper" is
        // salt, and "grated Parmesan cheese" is Parmesan rather than cheese.
        for length in stride(from: min(3, words.count), through: 1, by: -1) {
            for start in 0...(words.count - length) {
                let phrase = words[start..<(start + length)].joined(separator: " ")
                if let asset = IconCatalog.ingredient(named: phrase) { return asset }
            }
        }
        return nil
    }

    /// Gemma's lists without the picks its method never uses. A cook's picks are what they
    /// have, not what the dish needs, and a model this size tends to list every one of them. A
    /// line is dropped only when it names something the cook picked and no step mentions it, so
    /// what Gemma added on its own, and anything seasoned "to taste", stays. Of the tools,
    /// only pans, pots, and appliances are checked: a method names the pan it cooks in, but
    /// seldom the knife or the board.
    static func withoutUnusedPicks(_ written: WrittenRecipe, request: GenerationRequest) -> WrittenRecipe {
        guard !written.steps.isEmpty else { return written }
        let method = Set(words(in: written.steps.joined(separator: " ")).map(stem))
        // The line's own word for the thing, which is the last word before any comma or
        // bracket, and the catalog's name for it, first word or last: the step may say
        // "scallions" where the catalog says spring onion, or "Parmesan" for Parmesan cheese.
        // Words such as "large" are left out of it, since "large skillet" says nothing of a pot.
        func mentioned(line: String, name: String) -> Bool {
            let head = line.split(whereSeparator: { $0 == "," || $0 == "(" }).first.map(String.init) ?? line
            let named = words(in: name).map(stem)
            let candidates = [words(in: head).last.map(stem), named.first, named.last].compactMap { $0 }
            return candidates.contains(where: method.contains)
        }
        var trimmed = written
        let picked = Set(request.ingredients)
        trimmed.ingredients = written.ingredients.filter { line in
            guard let asset = namedIngredient(in: line), picked.contains(asset),
                  !line.lowercased().contains("to taste") else { return true }
            return mentioned(line: line, name: IconCatalog.englishName(for: asset))
        }
        let cookware = request.tools
            .filter { !ToolCategory.utensils.icons.contains($0) }
            .sorted { $0.count > $1.count }
        trimmed.tools = written.tools.filter { line in
            let lineWords = Set(words(in: line))
            guard let asset = cookware.first(where: { Set(words(in: IconCatalog.englishName(for: $0))).isSubset(of: lineWords) })
            else { return true }
            return mentioned(line: line, name: IconCatalog.englishName(for: asset))
        }
        return trimmed
    }

    /// A line's words, lowercased, letters only.
    private static func words(in text: String) -> [String] {
        text.lowercased()
            .map { $0.isLetter ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .map(String.init)
    }

    /// A word without its plural, so "tomatoes" in a step matches "tomato" in the list.
    private static func stem(_ word: String) -> String {
        var word = word
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("s"), !word.hasSuffix("ss") { word.removeLast() }
        if word.hasSuffix("e") { word.removeLast() }
        return word
    }

    /// The total time as a minute count, read the way the app reads every time, so "1 hour 20
    /// minutes" is "80 min" rather than whatever a model makes of it.
    static func time(from written: String) -> String {
        Recipe.minutes(in: written).map { "\($0) min" } ?? ""
    }

    /// The serving count as the figures in it: "Makes 4 servings" is "4", and "Serves 4 to 6" is
    /// "4 to 6".
    static func serves(from written: String) -> String {
        let figures = written.matches(of: #/\d+/#).map { String(written[$0.range]) }
        switch figures.count {
        case 0: return ""
        case 1: return figures[0]
        default: return figures[0] + " to " + figures[1]
        }
    }

    /// A step's text cut into its sentences, with any sentence said twice kept once.
    static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var seen: Set<String> = []
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).compactMap { range in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty, seen.insert(sentence).inserted else { return nil }
            return sentence
        }
    }

    // MARK: - Prompts

    /// The prompt shorthands, so a prompt below reads as prose rather than as calls.
    static func text(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(culinary: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static func joined(_ items: [String]) -> String { ModelPasses.joined(items) }

    /// The prompt shorthand for Gemma, which is always asked in English.
    static func english(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(culinaryEnglish: key)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    /// What Gemma is told before the cook's request. The cook's kitchen and tools, when they
    /// listed them, are limits on the whole recipe, so they are set here rather than asked for.
    static func writeInstructions(for request: GenerationRequest) -> String {
        var instructions = english("Generate.Prompt.HouseStyle") + "\n\n" + english("Generate.Prompt.Write")
        if !request.ingredients.isEmpty {
            instructions += "\n\n" + english("Generate.Prompt.Write.Kitchen")
        }
        if !request.tools.isEmpty {
            instructions += "\n\n" + english("Generate.Prompt.Write.Tools")
        }
        return instructions
    }

    /// The sorting passes are not given the house style. Its rules are about how to cook, and a
    /// pass handed them sorts them into the method as steps. The few that are about wording,
    /// and the language to write in, are in the sorting instructions themselves.
    static var structureInstructions: String {
        text("Generate.Prompt.Structure")
    }

    private static func prompt(for request: GenerationRequest) -> String {
        let separator = english("Generate.Prompt.Separator")
        var lines: [String] = []
        if request.trimmedDescription.isEmpty {
            lines.append(english(request.ingredients.isEmpty ? "Generate.Prompt.Ask.Any" : "Generate.Prompt.Ask.FromKitchen"))
        } else {
            lines.append(english("Generate.Prompt.Ask.Dish", request.trimmedDescription))
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

    /// The answer for a section sorted from the whole text, where nothing could be counted.
    private static func wholeSchema(
        name: String,
        description: String,
        lists: [(name: String, description: String, element: DynamicGenerationSchema, range: ClosedRange<Int>)]
    ) throws -> GenerationSchema {
        let root = DynamicGenerationSchema(
            name: name,
            description: description,
            properties: lists.map { list in
                .init(
                    name: list.name,
                    description: list.description,
                    schema: DynamicGenerationSchema(
                        arrayOf: list.element,
                        minimumElements: list.range.lowerBound,
                        maximumElements: list.range.upperBound
                    )
                )
            }
        )
        return try GenerationSchema(root: root, dependencies: [])
    }

    // MARK: - Assembly

    /// Maps the sorted recipe onto the on-disk schema, pinning every icon to one that exists.
    static func makeRecipe(_ sorted: SortedRecipe) -> Recipe {
        func entries(in section: String) -> [(entry: StructuredIngredient, line: String)] {
            sorted.ingredients.filter { $0.entry.section == section }
        }
        // Anything the pass did not mark as pantry or optional is bought fresh, so no line is
        // lost to a section name it wrote some other way.
        let sections = IngredientSections(
            supermarket: section(sorted.ingredients.filter { !["pantry", "optional"].contains($0.entry.section) }),
            general: section(entries(in: "pantry")),
            optional: section(entries(in: "optional"))
        )
        // Two lines Gemma wrote for the same tool, such as a wooden spoon and a spatula that
        // both come back as 木べら, are listed once.
        var named: Set<String> = []
        let unique = sorted.tools.filter { named.insert($0.name.withoutLeakedSyntax.lowercased()).inserted }
        let tools = unique.map { tool in
            Tool(
                name: tool.name.withoutLeakedSyntax,
                icon: IconCatalog.toolPath(for: IconCatalog.resolveTool(tool.icon, itemName: tool.name)),
                required: tool.required,
                note: trimmed(tool.note.withoutLeakedSyntax)
            )
        }
        let ingredients = [sections.supermarket, sections.general, sections.optional]
            .compactMap { $0 }
            .flatMap { $0 }
        return Recipe(
            id: Recipe.makeID(from: sorted.title),
            title: sorted.title,
            time: sorted.time,
            serves: sorted.serves,
            tried: nil,
            ingredients: sections,
            tools: tools,
            steps: withoutRepeats(sorted.steps).map { step in
                Step(
                    title: step.title,
                    icons: Step.icons(
                        forText: ([step.title] + step.points).joined(separator: " "),
                        ingredients: ingredients,
                        tools: tools
                    ),
                    points: step.points
                )
            },
            troubleshooting: sorted.troubleshooting.map {
                Troubleshooting(problem: $0.problem.withoutLeakedSyntax, solution: $0.solution.withoutLeakedSyntax)
            }
        )
    }

    /// Drops a step that is the step above it written out again. A step that only shares a
    /// title keeps its place, since what it says is still part of the method.
    private static func withoutRepeats(
        _ steps: [(title: String, points: [String])]
    ) -> [(title: String, points: [String])] {
        var seen: Set<String> = []
        return steps.compactMap { step in
            let title = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !step.points.isEmpty,
                  seen.insert(Step.comparable(([title] + step.points).joined(separator: " "))).inserted
            else { return nil }
            return (title, step.points)
        }
    }

    /// A section is written only when it holds entries. Each entry is pinned to the icon its
    /// English line names, then to the one the sorting pass guessed, then to a search on its
    /// name.
    private static func section(_ entries: [(entry: StructuredIngredient, line: String)]) -> [Ingredient]? {
        guard !entries.isEmpty else { return nil }
        return entries.map { entry, line in
            Ingredient(
                item: entry.item.withoutLeakedSyntax,
                icon: IconCatalog.ingredientPath(
                    for: ingredientIcon(line: line, guess: entry.icon, item: entry.item)
                ),
                // The measure words are put right once more here, in case the pass wrote an
                // amount back the way Gemma had it.
                amount: Measures.tidied(
                    Measures.readsJapanese
                        ? Measures.japanese(entry.amount.withoutLeakedSyntax)
                        : entry.amount.withoutLeakedSyntax
                ),
                note: trimmed(entry.note.withoutLeakedSyntax)
            )
        }
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
