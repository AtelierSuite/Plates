import XCTest
@testable import PlatesKitchen

final class AppleRecipeStructurerTests: XCTestCase {
    @MainActor
    func testStructuresPlainCookbookRecipeWhenAvailable() async throws {
        let structurer = AppleRecipeStructurer()
        try XCTSkipUnless(structurer.isAvailable, "Apple Intelligence is unavailable on this Mac")
        let source = """
            Grilled Cheese. 10 minutes. Serves 1.
            Ingredients: 2 slices bread, 1 slice cheddar cheese, 1 tsp butter.
            Tool: frying pan.
            1. Put the cheese between the bread slices.
            2. Butter the outside and cook in the frying pan over medium-low heat until both sides are golden and the cheese melts.
            """
        let testCase = try XCTUnwrap(EvalCase.all.first { $0.id == "grilled-cheese" })
        let recipe = try await structurer.structure(source, for: testCase, language: .english)
        XCTAssertFalse(recipe.steps.isEmpty)
        XCTAssertTrue(recipe.ingredients.contains { $0.item.localizedCaseInsensitiveContains("cheese") })
    }
}
