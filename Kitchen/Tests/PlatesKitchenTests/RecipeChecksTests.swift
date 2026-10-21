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

    func testGrilledCheeseNeedsCheeseAndCookingSteps() {
        let recipe = EvalRecipe(title: "Grilled cheese", time: "10 min", serves: "1", ingredients: [
            .init(item: "Bread", amount: "2 slices")
        ], tools: ["Pan"], steps: [.init(title: "Preheat", points: ["Heat the pan."])], troubleshooting: [])
        let issues = RecipeChecks.evaluate(recipe, caseID: "grilled-cheese")
        XCTAssertTrue(issues.contains("Cheese absent from ingredients"))
        XCTAssertTrue(issues.contains("Method has fewer than two steps"))
    }

    func testSavedRunsFromBeforeAppleStructuringStillDecode() throws {
        let old = """
            {"id":"00000000-0000-0000-0000-000000000001","modelID":"granite4-1b","modelFile":"model.gguf","caseID":"grilled-cheese","language":"English","repetition":1,"startedAt":0,"durationSeconds":1.0,"rawText":"Bread and cheese","recipe":null,"checks":[],"error":"Old parser failed","review":{"reviewed":false,"feasible":false,"constraintsMet":false,"ingredientUse":false,"clearSteps":false,"languageQuality":false,"criticalFailure":false,"notes":""}}
            """
        let run = try JSONDecoder().decode(EvalRun.self, from: Data(old.utf8))
        XCTAssertNil(run.structuredByApple)
        XCTAssertEqual(run.rawText, "Bread and cheese")
    }
}
