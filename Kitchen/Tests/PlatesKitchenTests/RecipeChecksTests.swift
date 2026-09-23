import XCTest
@testable import PlatesKitchen

final class RecipeChecksTests: XCTestCase {
    func testFriedRiceFlagsWokAndMissingEgg() {
        let recipe = EvalRecipe(title: "Fried rice", time: "15 min", serves: "1", ingredients: [
            .init(item: "Rice", amount: "250 g")
        ], tools: ["Wok"], steps: [.init(title: "Fry", points: ["Heat the wok."])], troubleshooting: [])
        let issues = RecipeChecks.evaluate(recipe, caseID: "egg-fried-rice")
        XCTAssertTrue(issues.contains("Egg absent from ingredients"))
        XCTAssertTrue(issues.contains("Wok mentioned"))
    }

    func testCeleryMustAppearInIngredientsAndMethod() {
        let recipe = EvalRecipe(title: "Spaghetti", time: "30 min", serves: "2", ingredients: [
            .init(item: "セロリ", amount: "1本")
        ], tools: ["フライパン"], steps: [.init(title: "煮る", points: ["トマトを煮ます。"])], troubleshooting: [])
        XCTAssertEqual(RecipeChecks.evaluate(recipe, caseID: "tomato-meat-sauce"), ["Celery absent from method"])
    }
}
