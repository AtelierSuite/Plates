import Foundation
import Testing
@testable import CulinaryIntelligence

/// Checks on the edit eval itself, which need no model.
struct EditEvalHarnessTests {
    @Test func requestIDsAreUnique() {
        #expect(Set(EditEvalRequests.all.map(\.id)).count == EditEvalRequests.all.count)
    }

    @Test func requestsCoverBothLanguagesAndEveryKind() {
        for language in [EditEvalRequest.Language.english, .japanese] {
            let requests = EditEvalRequests.all.filter { $0.language == language }
            #expect(requests.contains { $0.checks.contains { if case .serves = $0 { true } else { false } } })
            #expect(requests.contains { $0.checks.contains { if case .lacks = $0 { true } else { false } } })
            #expect(requests.contains { $0.checks.contains { if case .has = $0 { true } else { false } } })
            #expect(requests.contains { $0.subjects.isEmpty && !$0.mayChange.contains(.serves) })
            #expect(requests.contains { !$0.mayChange.contains(.ingredients) })
        }
    }

    /// A check the sample already passes measures nothing, so every one has to fail on the
    /// recipe as it ships.
    @Test(arguments: EditEvalRequests.all.map(\.id))
    func everyCheckFailsOnTheSample(_ id: String) throws {
        let request = try #require(EditEvalRequests.all.first { $0.id == id })
        let original = try EditEvalSamples.recipe(request.recipe, in: request.language)
        let score = EditScore(request, original: original, edited: original)
        for result in score.checks {
            #expect(!result.passed, "\(request.id): \(result.check)")
        }
        #expect(score.changed.isEmpty)
    }

    @Test func samplesShareFilesAcrossLanguages() throws {
        for name in Set(EditEvalRequests.all.map(\.recipe)) {
            let english = try EditEvalSamples.recipe(name, in: .english)
            let japanese = try EditEvalSamples.recipe(name, in: .japanese)
            #expect(english.id == japanese.id)
        }
    }

    @Test func aCleanSwapMeetsTheRequest() throws {
        let request = try #require(EditEvalRequests.english.first { $0.id == "en-carbonara-bacon" })
        let original = try EditEvalSamples.recipe(request.recipe, in: .english)
        let edited = swapped(original, "guanciale", for: "bacon")
        let score = EditScore(request, original: original, edited: edited)
        #expect(score.met)
        #expect(score.collateral.isEmpty)
        #expect(score.changed.contains { $0.part == .steps })
    }

    @Test func aLineTheRequestNeverNamedIsCollateral() throws {
        let request = try #require(EditEvalRequests.english.first { $0.id == "en-carbonara-bacon" })
        let original = try EditEvalSamples.recipe(request.recipe, in: .english)
        var edited = swapped(original, "guanciale", for: "bacon")
        edited.tools.removeLast()
        edited.steps[2].points = ["Boil the water."]
        let score = EditScore(request, original: original, edited: edited)
        #expect(score.met)
        #expect(score.collateral.count == 2)
        #expect(score.collateral.contains { $0.part == .tools && $0.after == nil })
        #expect(score.collateral.contains { $0.part == .steps && $0.before?.hasPrefix("Boil the water") == true })
    }

    @Test func aScaledRecipeMayChangeEveryAmount() throws {
        let request = try #require(EditEvalRequests.english.first { $0.id == "en-carbonara-for-four" })
        let original = try EditEvalSamples.recipe(request.recipe, in: .english)
        var edited = original
        edited.scaleAmounts(by: 2)
        edited.serves = "4"
        let score = EditScore(request, original: original, edited: edited)
        #expect(score.met, "\(score.checks)")
        #expect(score.collateral.isEmpty)
    }

    @Test func aDroppedLineIsOneChange() throws {
        let request = try #require(EditEvalRequests.english.first { $0.id == "en-garlic-rice-no-butter" })
        let original = try EditEvalSamples.recipe(request.recipe, in: .english)
        var edited = original
        edited.ingredients.supermarket?.removeAll { $0.item == "Butter" }
        let score = EditScore(request, original: original, edited: edited)
        #expect(score.changed == [ChangedLine(part: .ingredients, before: "Butter | 10 g", after: nil)])
        #expect(score.collateral.isEmpty)
        // The method still melts the butter.
        #expect(!score.met)
    }

    @Test func summaryCountsCleanRuns() throws {
        let request = try #require(EditEvalRequests.english.first { $0.id == "en-carbonara-bacon" })
        let original = try EditEvalSamples.recipe(request.recipe, in: .english)
        var messy = swapped(original, "guanciale", for: "bacon")
        messy.tools.removeLast()
        let runs = [
            EditEvalRun(request: request, run: 1, seconds: 10, plan: [], original: original, edited: swapped(original, "guanciale", for: "bacon"), error: nil),
            EditEvalRun(request: request, run: 2, seconds: 20, plan: [], original: original, edited: messy, error: nil),
            EditEvalRun(request: request, run: 3, seconds: 30, plan: [], original: original, edited: nil, error: "failed"),
        ]
        let summary = EditEvalSummary(runs)
        #expect(summary.runs == 3)
        #expect(summary.succeeded == 2)
        #expect(summary.met == 2)
        #expect(summary.clean == 1)
        #expect(summary.runsWithCollateral == 1)
        #expect(summary.collateralLines == 1)
        #expect(summary.meanSeconds == 20)
    }

    /// The recipe with one word swapped for another everywhere, the way a perfect edit would.
    private func swapped(_ recipe: Recipe, _ old: String, for new: String) -> Recipe {
        func swap(_ text: String) -> String {
            text.replacingOccurrences(of: old, with: new, options: .caseInsensitive)
        }
        func swap(_ list: [Ingredient]?) -> [Ingredient]? {
            list?.map { entry in
                var entry = entry
                entry.item = swap(entry.item)
                entry.note = entry.note.map(swap)
                return entry
            }
        }
        var recipe = recipe
        recipe.ingredients = IngredientSections(
            supermarket: swap(recipe.ingredients.supermarket),
            general: swap(recipe.ingredients.general),
            optional: swap(recipe.ingredients.optional)
        )
        recipe.steps = recipe.steps.map { step in
            var step = step
            step.title = swap(step.title)
            step.points = step.points.map(swap)
            return step
        }
        recipe.troubleshooting = recipe.troubleshooting.map {
            Troubleshooting(problem: swap($0.problem), solution: swap($0.solution))
        }
        return recipe
    }
}
