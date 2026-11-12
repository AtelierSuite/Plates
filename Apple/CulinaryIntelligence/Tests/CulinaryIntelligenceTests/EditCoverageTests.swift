import Testing
@testable import CulinaryIntelligence

@MainActor
struct EditCoverageTests {
    private func ingredient(_ item: String, _ icon: String) -> Ingredient {
        Ingredient(item: item, icon: IconCatalog.ingredientPath(for: icon), amount: "1")
    }

    private func tool(_ name: String, _ icon: String) -> Tool {
        Tool(name: name, icon: IconCatalog.toolPath(for: icon), required: true)
    }

    private var english: (ingredients: [Ingredient], tools: [Tool], steps: [Step]) {
        (
            [
                ingredient("Egg", "egg"),
                ingredient("Spring onion", "spring-onion"),
                ingredient("Rice", "rice"),
                ingredient("Oil", "oil"),
                ingredient("Soy sauce", "soy-sauce"),
                ingredient("Sesame oil", "sesame-oil"),
            ],
            [tool("Wok", "wok"), tool("Rice cooker", "rice-cooker")],
            [
                Step(title: "Cook the rice ahead", points: ["Cook the rice in the rice cooker."]),
                Step(title: "Scramble the eggs", points: ["Beat the eggs and pour them into the wok."]),
                Step(title: "Finish and plate", points: ["Scatter over the spring onion."]),
            ]
        )
    }

    private var japanese: (ingredients: [Ingredient], tools: [Tool], steps: [Step]) {
        (
            [
                ingredient("卵", "egg"),
                ingredient("ねぎ", "spring-onion"),
                ingredient("米", "rice"),
                ingredient("油", "oil"),
                ingredient("しょうゆ", "soy-sauce"),
                ingredient("ごま油", "sesame-oil"),
            ],
            [tool("中華鍋", "wok"), tool("炊飯器", "rice-cooker")],
            [
                Step(title: "前日にごはんを炊く", points: ["炊飯器でごはんを炊きます。"]),
                Step(title: "卵を炒める", points: ["卵を溶いて中華鍋に流し入れます。"]),
                Step(title: "仕上げて盛る", points: ["ねぎを散らします。"]),
            ]
        )
    }

    private func named(_ request: String, in recipe: (ingredients: [Ingredient], tools: [Tool], steps: [Step])) -> [[Int]] {
        EditCoverage(request: request, ingredients: recipe.ingredients, tools: recipe.tools).named.map(\.lines)
    }

    private func edit(_ target: EditTarget, _ line: Int, _ instruction: String = "") -> PlannedEdit {
        PlannedEdit(target: target, title: "Change", instruction: instruction, line: line)
    }

    // MARK: - Matching

    @Test func matchesTheRecipesOwnNames() {
        let coverage = EditCoverage(
            request: "Leave out the spring onions and cook it in a frying pan instead of the wok",
            ingredients: english.ingredients,
            tools: english.tools
        )
        #expect(coverage.named == [
            .init(list: .ingredients, lines: [2], names: ["Spring onion", "ねぎ"]),
            .init(list: .tools, lines: [1], names: ["Wok", "中華鍋"]),
        ])
    }

    @Test func matchesJapaneseRequestsOnAnEnglishRecipe() {
        #expect(named("ねぎは入れないで、中華鍋の代わりにフライパンで", in: english) == [[2], [1]])
    }

    @Test func matchesEnglishRequestsOnAJapaneseRecipe() {
        #expect(named("No spring onion, and less soy sauce please", in: japanese) == [[2], [5]])
    }

    @Test func readsKatakanaAsHiragana() {
        #expect(named("ネギを抜いてください", in: japanese) == [[2]])
    }

    @Test func leavesOutANameInsideALongerOne() {
        #expect(named("Use less sesame oil", in: english) == [[6]])
        #expect(named("ごま油を減らして", in: japanese) == [[6]])
        #expect(named("Use a pot instead of the rice cooker", in: english) == [[2]])
    }

    @Test func keepsAShortNameWrittenOnItsOwnToo() {
        #expect(named("油とごま油を半分に", in: japanese) == [[4], [6]])
    }

    @Test func groupsLinesWithTheSameIcon() {
        let ingredients = [ingredient("Vegetable oil", "oil"), ingredient("Oil for frying", "oil")]
        let coverage = EditCoverage(request: "Use less oil", ingredients: ingredients, tools: [])
        #expect(coverage.named.map(\.lines) == [[1, 2]])
        #expect(coverage.missed(by: [edit(.changeIngredient, 2)], steps: []).isEmpty)
    }

    @Test func namesNothingWhenTheRequestNamesNothing() {
        #expect(named("Make it serve four", in: english).isEmpty)
        #expect(named("4人分にして", in: japanese).isEmpty)
    }

    // MARK: - Coverage

    @Test func aChangeToTheLineCoversIt() {
        let coverage = EditCoverage(request: "No spring onion", ingredients: english.ingredients, tools: english.tools)
        #expect(coverage.missed(by: [edit(.removeIngredient, 2)], steps: english.steps).isEmpty)
        #expect(coverage.missed(by: [edit(.changeIngredient, 1)], steps: english.steps).count == 1)
    }

    @Test func aStepThatNamesItCoversIt() {
        let coverage = EditCoverage(request: "ねぎを抜いて", ingredients: japanese.ingredients, tools: japanese.tools)
        #expect(coverage.missed(by: [edit(.step, 3)], steps: japanese.steps).isEmpty)
        #expect(coverage.missed(by: [edit(.step, 1)], steps: japanese.steps).count == 1)
    }

    @Test func anInstructionThatNamesItCoversIt() {
        let coverage = EditCoverage(request: "Swap the oil for butter", ingredients: english.ingredients, tools: english.tools)
        #expect(coverage.missed(by: [edit(.addStep, 2, "Melt the butter in place of the oil")], steps: english.steps).isEmpty)
        let swapTo = EditCoverage(request: "Use soy sauce instead of oil", ingredients: english.ingredients, tools: english.tools)
        #expect(swapTo.missed(by: [edit(.changeIngredient, 4, "Use soy sauce instead")], steps: english.steps).isEmpty)
    }

    @Test func aChangeToTheOtherListDoesNotCoverIt() {
        let coverage = EditCoverage(request: "Use a pan instead of the wok", ingredients: english.ingredients, tools: english.tools)
        #expect(coverage.missed(by: [edit(.changeIngredient, 1)], steps: english.steps).count == 1)
        #expect(coverage.missed(by: [edit(.changeTool, 1)], steps: english.steps).isEmpty)
        #expect(coverage.missed(by: [edit(.title, 0, "Wok free fried rice")], steps: english.steps).count == 1)
    }

    @Test func reportsEachNamedThingTheyMiss() {
        let coverage = EditCoverage(
            request: "卵を2個増やして、ねぎは抜いて",
            ingredients: japanese.ingredients,
            tools: japanese.tools
        )
        #expect(coverage.missed(by: [edit(.changeIngredient, 1)], steps: japanese.steps).map(\.lines) == [[2]])
        #expect(coverage.missed(by: [], steps: japanese.steps).count == 2)
    }
}
