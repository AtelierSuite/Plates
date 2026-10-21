import XCTest
@testable import PlatesKitchen

final class JevRequestTests: XCTestCase {
    func testIDsDropTheAmountBracketsAndPreparation() {
        XCTAssertEqual(JevRequest.id(for: "1 lb spaghetti", amount: "1 lb"), "spaghetti")
        XCTAssertEqual(JevRequest.id(for: "1 can (14 oz) crushed tomatoes", amount: "1 can (14 oz)"), "crushed-tomatoes")
        XCTAssertEqual(JevRequest.id(for: "1 onion, diced", amount: "1"), "onion")
        XCTAssertEqual(JevRequest.id(for: "1 celery stalk, chopped", amount: "1 celery stalk"), "celery-stalk")
        XCTAssertEqual(JevRequest.id(for: "1/2 cup celery, chopped", amount: "1/2 cup celery, chopped"), "celery")
        XCTAssertEqual(JevRequest.id(for: "2 slices of bread", amount: ""), "bread")
        XCTAssertEqual(JevRequest.id(for: "2 cloves garlic, minced", amount: "2"), "garlic")
        XCTAssertEqual(JevRequest.id(for: "1 (14 oz) can crushed tomatoes", amount: ""), "crushed-tomatoes")
        XCTAssertEqual(JevRequest.id(for: "Large pot", amount: ""), "large-pot")
        XCTAssertEqual(JevRequest.id(for: "Canola oil", amount: ""), "canola-oil")
        XCTAssertEqual(JevRequest.id(for: "Grilling pan or skillet", amount: ""), "grilling-pan-or-skillet")
        XCTAssertEqual(JevRequest.id(for: "卵（Mサイズ）", amount: "2個"), "卵")
    }

    func testQuestionsAreKeyedInRecipeOrderWithUniqueIDs() throws {
        let recipe = EvalRecipe(title: "Toast", time: "5 min", serves: "1", ingredients: [
            .init(item: "bread", amount: "2 slices"),
            .init(item: "Bread", amount: "1 slice"),
            .init(item: "", amount: "1 tbsp")
        ], tools: ["Pan"], steps: [
            .init(title: "Toast", points: ["Toast the bread."]),
            .init(title: "Serve", points: ["Serve."])
        ], troubleshooting: [])
        let json = JevRequest.questions(for: recipe).json()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: [String: Any]])
        XCTAssertEqual(Set(object.keys), ["bread", "bread-2", "ingredient-3", "ingredients_missing", "pan", "tools_missing", "step_1", "step_2"])
        XCTAssertEqual(object["bread-2"]?["instructions"] as? String, "Review the ingredient bread-2.")
        XCTAssertEqual(object["step_2"]?["instructions"] as? String, "Review step 2.")
        XCTAssertEqual(object["pan"]?["type"] as? String, "choice")
        let keyOrder = ["\"bread\"", "\"bread-2\"", "\"ingredient-3\"", "\"ingredients_missing\"", "\"pan\"", "\"tools_missing\"", "\"step_1\"", "\"step_2\""]
            .compactMap { json.range(of: $0 + ": {")?.lowerBound }
        XCTAssertEqual(keyOrder, keyOrder.sorted())
        XCTAssertEqual(keyOrder.count, 8)
    }

    func testStateCarriesTheRequestAndTheRecipe() throws {
        let recipe = EvalRecipe(title: "Grilled cheese", time: "10 min", serves: "1", ingredients: [
            .init(item: "cheese", amount: "2 slices")
        ], tools: ["Pan"], steps: [.init(title: "Cook", points: ["Cook it \"slowly\"."])], troubleshooting: [])
        let run = EvalRun(id: UUID(), modelID: "granite4-1b", modelFile: "", caseID: "grilled-cheese", language: .english,
                          repetition: 1, startedAt: .now, durationSeconds: 1, rawText: "Grilled cheese\n- 2 slices cheese",
                          recipe: recipe, checks: [], error: nil, structuringError: nil, structureDurationSeconds: nil,
                          structuredByApple: true, review: Review())
        let json = JevRequest.state(for: run, recipe: recipe).json()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(object["request"] as? String, "Make a simple grilled cheese sandwich.")
        XCTAssertEqual(object["rawText"] as? String, "Grilled cheese\n- 2 slices cheese")
        let steps = try XCTUnwrap((object["recipe"] as? [String: Any])?["steps"] as? [[String: Any]])
        XCTAssertEqual(steps.first?["points"] as? [String], ["Cook it \"slowly\"."])
    }
}
