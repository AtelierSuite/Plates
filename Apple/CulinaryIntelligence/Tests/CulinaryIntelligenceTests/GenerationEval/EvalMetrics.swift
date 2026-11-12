import Foundation
@testable import CulinaryIntelligence

/// How one list came through a run: the lines Gemma wrote, the lines left once code dropped the
/// picks the method never uses, and the lines in the recipe handed over.
struct ListCount: Codable, Equatable, Sendable {
    /// Lines the reading found in Gemma's text. Nil when the section was sorted from the whole
    /// text, where there were no lines to count.
    var written: Int?
    /// Lines left after code dropped unused picks, which is what the recipe should carry.
    var kept: Int?
    /// Lines code added on purpose, such as the oven a baking method needs.
    var addedByCode: Int
    var final: Int

    /// Lines the sorting and assembly lost against what was kept.
    var lost: Int? { kept.map { max(0, $0 + addedByCode - final) } }
    /// Lines the sorting and assembly added that Gemma never wrote.
    var added: Int? { kept.map { max(0, final - $0 - addedByCode) } }
}

/// What one run of one request recorded.
struct EvalRun: Codable, Sendable {
    var id: String
    var run: Int
    var language: EvalRequest.Language
    var description: String
    var ingredients: [String]
    var tools: [String]
    var seconds: Double

    var succeeded: Bool
    var error: String?
    /// Nil when the run cannot tell. See `GenerationTrace.cutOff`.
    var cutOff: Bool?
    /// Nil until the draft checks exist. See `GenerationTrace.draftCheckFailures`.
    var draftCheckFailures: [String]?
    var sortedWholeShopping: Bool
    var sortedWholeMethod: Bool

    var ingredientLines: ListCount?
    var toolLines: ListCount?
    var stepLines: ListCount?
    var troubleshootingLines: ListCount?

    var translation: String
    var draft: String
    /// About how many tokens Gemma wrote, worked out from the length as the progress bar does.
    var draftTokens: Int
    /// The recipe as it would be saved, so a run can be read by eye afterwards.
    var recipe: String?

    init(request: EvalRequest, run: Int, seconds: Double, trace: GenerationTrace) {
        id = request.id
        self.run = run
        language = request.language
        description = request.description
        ingredients = request.ingredients
        tools = request.tools
        self.seconds = seconds
        succeeded = trace.recipe != nil
        error = trace.error.map { String(describing: $0) }
        cutOff = trace.cutOff
        draftCheckFailures = trace.draftCheckFailures
        sortedWholeShopping = trace.sortedWholeShopping
        sortedWholeMethod = trace.sortedWholeMethod
        translation = trace.translation
        draft = trace.draft
        draftTokens = trace.draft.count / 4
        if let recipe = trace.recipe {
            let counts = Self.counts(trace: trace, recipe: recipe)
            ingredientLines = counts.ingredients
            toolLines = counts.tools
            stepLines = counts.steps
            troubleshootingLines = counts.troubleshooting
            self.recipe = String(decoding: recipe.fileContents(), as: UTF8.self)
        }
    }

    /// Each list counted at each stage. A section sorted from the whole text has no written or
    /// kept count, since the reading found no lines in it.
    static func counts(
        trace: GenerationTrace,
        recipe: Recipe
    ) -> (ingredients: ListCount, tools: ListCount, steps: ListCount, troubleshooting: ListCount) {
        let written = trace.written ?? WrittenRecipe(parsing: "")
        let kept = trace.kept ?? written
        let shopping = !trace.sortedWholeShopping
        let method = !trace.sortedWholeMethod
        let finalIngredients = [recipe.ingredients.supermarket, recipe.ingredients.general, recipe.ingredients.optional]
            .compactMap { $0 }
            .reduce(0) { $0 + $1.count }
        return (
            ListCount(
                written: shopping ? written.ingredients.count : nil,
                kept: shopping ? kept.ingredients.count : nil,
                addedByCode: 0,
                final: finalIngredients
            ),
            ListCount(
                written: shopping ? written.tools.count : nil,
                kept: shopping ? kept.tools.count : nil,
                addedByCode: trace.addedOven ? 1 : 0,
                final: recipe.tools.count
            ),
            ListCount(
                written: method ? written.steps.count : nil,
                kept: method ? kept.steps.count : nil,
                addedByCode: 0,
                final: recipe.steps.count
            ),
            ListCount(
                written: method ? written.problems.count : nil,
                kept: method ? kept.problems.count : nil,
                addedByCode: 0,
                final: recipe.troubleshooting.count
            )
        )
    }
}

/// The figures a baseline is read from, over every run in one language.
struct EvalSummary: Codable, Sendable {
    var runs: Int
    var succeeded: Int
    /// Runs the draft checks failed, out of the runs they were applied to. Nil until they exist.
    var draftCheckFailed: Int?
    var cutOff: Int?
    var sortedWholeShopping: Int
    var sortedWholeMethod: Int
    var linesLost: Int
    var linesAdded: Int
    /// Runs that lost or added at least one line.
    var runsChangingLines: Int

    init(_ runs: [EvalRun]) {
        self.runs = runs.count
        succeeded = runs.filter(\.succeeded).count
        let checked = runs.compactMap(\.draftCheckFailures)
        draftCheckFailed = checked.isEmpty ? nil : checked.filter { !$0.isEmpty }.count
        let cut = runs.compactMap(\.cutOff)
        cutOff = cut.isEmpty ? nil : cut.filter { $0 }.count
        sortedWholeShopping = runs.filter(\.sortedWholeShopping).count
        sortedWholeMethod = runs.filter(\.sortedWholeMethod).count
        func lists(_ run: EvalRun) -> [ListCount] {
            [run.ingredientLines, run.toolLines, run.stepLines, run.troubleshootingLines].compactMap { $0 }
        }
        linesLost = runs.flatMap(lists).compactMap(\.lost).reduce(0, +)
        linesAdded = runs.flatMap(lists).compactMap(\.added).reduce(0, +)
        runsChangingLines = runs.filter { run in
            lists(run).contains { ($0.lost ?? 0) + ($0.added ?? 0) > 0 }
        }.count
    }
}

/// What one eval writes to disk.
struct EvalReport: Codable, Sendable {
    var language: EvalRequest.Language
    var startedAt: Date
    var summary: EvalSummary
    var runs: [EvalRun]
}
