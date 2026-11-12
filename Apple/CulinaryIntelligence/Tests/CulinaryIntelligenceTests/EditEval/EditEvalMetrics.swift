import Foundation
@testable import CulinaryIntelligence

/// A recipe cut into the lines an edit can change. A line is compared by everything it carries,
/// so an ingredient moved between sections or a tool no longer required counts as changed, and
/// matched against the words of the request by what it says.
struct RecipeLines {
    struct Line: Equatable {
        /// Everything the line carries, for telling whether it changed.
        var key: String
        /// What the line says, for reading and for matching words against.
        var text: String
    }

    var parts: [RecipePart: [Line]]

    init(_ recipe: Recipe) {
        func line(_ fields: String?...) -> Line {
            let text = fields.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
            return Line(key: text, text: text)
        }
        func shelf(_ name: String, _ list: [Ingredient]?) -> [Line] {
            (list ?? []).map { entry in
                var line = line(entry.item, entry.amount, entry.note)
                line.key = name + " | " + line.key
                return line
            }
        }
        parts = [
            .title: [line(recipe.title)],
            .time: [line(recipe.time)],
            .serves: [line(recipe.serves)],
            .ingredients: shelf("supermarket", recipe.ingredients.supermarket)
                + shelf("general", recipe.ingredients.general)
                + shelf("optional", recipe.ingredients.optional),
            .tools: recipe.tools.map { tool in
                var line = line(tool.name, tool.note)
                line.key += tool.required ? "" : " | optional"
                return line
            },
            .steps: recipe.steps.map { line($0.title, $0.points.joined(separator: " ")) },
            .notes: recipe.troubleshooting.map { line($0.problem, $0.solution) },
        ]
    }

    func text(of scope: Set<RecipePart>) -> [String] {
        RecipePart.allCases.filter(scope.contains).flatMap { parts[$0] ?? [] }.map(\.text)
    }
}

/// A line that changed, as it was and as it came back. Nil on one side for a line dropped or
/// added.
struct ChangedLine: Codable, Equatable, Sendable {
    var part: RecipePart
    var before: String?
    var after: String?

    /// Every changed line in a part. Lines kept word for word are taken out first, from both
    /// sides, and what is left is paired in order, so a line rewritten in place reads as one
    /// change rather than a drop and an add.
    static func between(_ original: RecipeLines, _ edited: RecipeLines, in part: RecipePart) -> [ChangedLine] {
        var before = original.parts[part] ?? []
        var after = edited.parts[part] ?? []
        for line in before {
            guard let match = after.firstIndex(where: { $0.key == line.key }),
                  let own = before.firstIndex(of: line) else { continue }
            after.remove(at: match)
            before.remove(at: own)
        }
        return (0..<max(before.count, after.count)).map { index in
            ChangedLine(
                part: part,
                before: before.indices.contains(index) ? before[index].text : nil,
                after: after.indices.contains(index) ? after[index].text : nil
            )
        }
    }

    func names(any words: [String]) -> Bool {
        [before, after].compactMap { $0 }.contains { line in EditScore.contains(line, any: words) }
    }
}

/// How one edited recipe measures against its request: whether every check passed, and which
/// lines changed that the request did not call for.
struct EditScore: Codable, Equatable, Sendable {
    struct CheckResult: Codable, Equatable, Sendable {
        var check: String
        var passed: Bool
    }

    var checks: [CheckResult]
    var met: Bool
    var changed: [ChangedLine]
    /// Changed lines in a part the request may not change, or naming none of its subjects.
    var collateral: [ChangedLine]

    init(_ request: EditEvalRequest, original: Recipe, edited: Recipe) {
        let before = RecipeLines(original)
        let after = RecipeLines(edited)
        let changed = RecipePart.allCases.flatMap { ChangedLine.between(before, after, in: $0) }
        self.changed = changed
        collateral = changed.filter { line in
            !request.mayChange.contains(line.part)
                || (!request.subjects.isEmpty && !line.part.isDetail && !line.names(any: request.subjects))
        }
        checks = request.checks.map { check in
            let passed = switch check {
            case let .has(words, in: scope):
                after.text(of: scope).contains { Self.contains($0, any: words) }
            case let .lacks(words, in: scope):
                !after.text(of: scope).contains { Self.contains($0, any: words) }
            case let .changes(scope):
                changed.contains { scope.contains($0.part) }
            case let .serves(count):
                Recipe.servings(in: edited.serves).map { abs($0 - count) < 0.001 } ?? false
            }
            return CheckResult(check: check.description, passed: passed)
        }
        met = checks.allSatisfy(\.passed)
    }

    static func contains(_ text: String, any words: [String]) -> Bool {
        let text = text.lowercased()
        return words.contains { text.contains($0.lowercased()) }
    }
}

extension RecipePart {
    /// The title, time, and serving count, which a request names by being about them rather
    /// than by naming its subject in them.
    var isDetail: Bool { self == .title || self == .time || self == .serves }
}

/// One planned change, as the editor wrote it before carrying it out.
struct EditEvalPlannedChange: Codable, Sendable {
    var target: String
    var title: String
    var instruction: String
    var line: Int

    init(_ edit: PlannedEdit) {
        target = edit.target.rawValue
        title = edit.title
        instruction = edit.instruction
        line = edit.line
    }
}

/// What one run of one request recorded.
struct EditEvalRun: Codable, Sendable {
    var id: String
    var run: Int
    var language: EditEvalRequest.Language
    var recipe: String
    var request: String
    var expectation: String
    var seconds: Double

    var succeeded: Bool
    var error: String?
    var plan: [EditEvalPlannedChange]
    /// Nil when the edit failed, so a failure is not read as a request met or missed.
    var score: EditScore?
    /// The recipe as it would be saved, so a run can be read by eye afterwards.
    var edited: String?

    init(
        request: EditEvalRequest,
        run: Int,
        seconds: Double,
        plan: [PlannedEdit],
        original: Recipe,
        edited: Recipe?,
        error: String?
    ) {
        id = request.id
        self.run = run
        language = request.language
        recipe = request.recipe
        self.request = request.request
        expectation = request.expectation
        self.seconds = seconds
        succeeded = edited != nil
        self.error = error
        self.plan = plan.map(EditEvalPlannedChange.init)
        score = edited.map { EditScore(request, original: original, edited: $0) }
        self.edited = edited.map { String(decoding: $0.fileContents(), as: UTF8.self) }
    }
}

/// The figures a baseline is read from, over every run in one language.
struct EditEvalSummary: Codable, Sendable {
    var runs: Int
    var succeeded: Int
    /// Runs where every check passed.
    var met: Int
    /// Runs that changed at least one line the request did not call for.
    var runsWithCollateral: Int
    var collateralLines: Int
    /// Runs that met the request and changed nothing else.
    var clean: Int
    var meanSeconds: Double

    init(_ runs: [EditEvalRun]) {
        self.runs = runs.count
        succeeded = runs.filter(\.succeeded).count
        let scores = runs.compactMap(\.score)
        met = scores.filter(\.met).count
        runsWithCollateral = scores.filter { !$0.collateral.isEmpty }.count
        collateralLines = scores.reduce(0) { $0 + $1.collateral.count }
        clean = scores.filter { $0.met && $0.collateral.isEmpty }.count
        meanSeconds = runs.isEmpty ? 0 : runs.reduce(0) { $0 + $1.seconds } / Double(runs.count)
    }
}

/// What one eval writes to disk.
struct EditEvalReport: Codable, Sendable {
    var language: EditEvalRequest.Language
    var startedAt: Date
    var summary: EditEvalSummary
    var runs: [EditEvalRun]
}
