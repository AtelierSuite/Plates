import Foundation
import Testing
@testable import CulinaryIntelligence

/// Checks on the eval itself, which need no model.
struct EvalHarnessTests {
    @Test func requestsCoverBothLanguagesWithAndWithoutPicks() {
        for language in [EvalRequest.Language.english, .japanese] {
            let requests = EvalRequests.all.filter { $0.language == language }
            #expect(requests.contains { $0.hasPicks })
            #expect(requests.contains { !$0.hasPicks })
            #expect(requests.contains { $0.hasPicks && $0.description.isEmpty })
        }
    }

    @Test func requestIDsAreUnique() {
        #expect(Set(EvalRequests.all.map(\.id)).count == EvalRequests.all.count)
    }

    @Test func picksAreCatalogAssets() {
        for request in EvalRequests.all {
            for ingredient in request.ingredients {
                #expect(IconCatalog.ingredients.contains(ingredient), "\(request.id): \(ingredient)")
            }
            for tool in request.tools {
                #expect(IconCatalog.tools.contains(tool), "\(request.id): \(tool)")
            }
        }
    }

    @Test func listCountSeparatesLostFromAdded() {
        let lost = ListCount(written: 9, kept: 8, addedByCode: 0, final: 6)
        #expect(lost.lost == 2)
        #expect(lost.added == 0)
        let oven = ListCount(written: 2, kept: 2, addedByCode: 1, final: 3)
        #expect(oven.lost == 0)
        #expect(oven.added == 0)
        let added = ListCount(written: 4, kept: 4, addedByCode: 0, final: 5)
        #expect(added.added == 1)
        let whole = ListCount(written: nil, kept: nil, addedByCode: 0, final: 7)
        #expect(whole.lost == nil)
        #expect(whole.added == nil)
    }

    @Test func countsReadEachStage() {
        let trace = GenerationTrace()
        trace.written = WrittenRecipe(parsing: """
            Title: Fried Rice

            Ingredients:
            - 2 cups cooked rice
            - 2 eggs
            - 1 tbsp soy sauce

            Tools:
            - Wok

            Method:
            1. Scramble the eggs in the wok.
            2. Add the rice and soy sauce and fry.

            Troubleshooting:
            - The rice is mushy: use day old rice.
            """)
        trace.kept = trace.written
        let recipe = Recipe(
            id: "fried-rice",
            title: "Fried Rice",
            time: "15 min",
            serves: "2",
            tried: nil,
            ingredients: IngredientSections(
                supermarket: [Ingredient(item: "Eggs", icon: "egg", amount: "2", note: nil)],
                general: [Ingredient(item: "Rice", icon: "rice", amount: "2 cups", note: nil)],
                optional: nil
            ),
            tools: [Tool(name: "Wok", icon: "wok", required: true, note: nil)],
            steps: [Step(title: "Fry", icons: nil, points: ["Fry it all."])],
            troubleshooting: []
        )
        let counts = EvalRun.counts(trace: trace, recipe: recipe)
        #expect(counts.ingredients == ListCount(written: 3, kept: 3, addedByCode: 0, final: 2))
        #expect(counts.ingredients.lost == 1)
        #expect(counts.tools.lost == 0)
        #expect(counts.steps.lost == 1)
        #expect(counts.troubleshooting.lost == 1)

        trace.sortedWholeMethod = true
        #expect(EvalRun.counts(trace: trace, recipe: recipe).steps.written == nil)
    }

    @Test func summaryLeavesHooksEmptyUntilTheyAreFilled() {
        let trace = GenerationTrace()
        let request = EvalRequests.english[0]
        let summary = EvalSummary([EvalRun(request: request, run: 1, seconds: 0, trace: trace)])
        #expect(summary.runs == 1)
        #expect(summary.succeeded == 0)
        #expect(summary.cutOff == nil)
        #expect(summary.draftCheckFailed == nil)
    }
}
