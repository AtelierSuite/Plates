import Foundation
import Testing
@testable import CulinaryIntelligence

struct PanTests {
    private static let samples = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../../Plates/SampleRecipes")
        .standardized

    private func sample(_ name: String, _ language: String = "en-US") throws -> Recipe {
        let url = Self.samples.appending(path: "\(language).lproj/\(name).json")
        return try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: url))
    }

    private func scaled(_ recipe: Recipe, to serves: String) -> Recipe {
        var recipe = recipe
        recipe.resizePans(to: serves)
        recipe.serves = serves
        return recipe
    }

    @Test func panPastTheLargestSizeCooksInBatches() throws {
        let recipe = scaled(try sample("kimchi-fried-rice"), to: "6")
        #expect(recipe.tools[0].note == "About 24 cm. A second small pan for the eggs saves wiping this one out. "
            + "Serves 6 instead of 2: use one about 30 cm across and cook in 2 batches.")
        #expect(recipe.steps[3].points.last == "From here on, cook in 2 batches so the pan is not crowded.")
        #expect(recipe.steps.map(\.points.count) == (try sample("kimchi-fried-rice")).steps.enumerated().map {
            $0.element.points.count + ($0.offset == 3 ? 1 : 0)
        })
    }

    @Test func writesInTheRecipesLanguage() throws {
        let recipe = scaled(try sample("kimchi-fried-rice", "ja"), to: "6")
        #expect(recipe.tools[0].note == "24cmほど。卵用にもう一つ小さいフライパンがあると、こちらを拭かずに済みます。"
            + "2人分ではなく6人分なら、30cmほどのものを使い、2回に分けて作ります。")
        #expect(recipe.steps[3].points.last == "ここからは2回に分けて作り、詰め込みすぎないようにします。")
        var counted = try sample("seafood-curry", "ja")
        counted.serves = "2人分"
        #expect(scaled(counted, to: "6人分").tools[0].note == "20cmほど。2人分ではなく6人分なら、28cmほどのものを使います。")
    }

    @Test func wokNoteKeepsItsStandIn() throws {
        let recipe = scaled(try sample("egg-fried-rice"), to: "4")
        #expect(recipe.tools[0].note == "A 24 cm frying pan works. It holds less heat, so cook one portion at a time "
            + "and stir less. Serves 4 instead of 1: use one about 28 cm across and cook in 3 batches.")
        #expect(recipe.steps[2].title == "Heat the wok")
        #expect(recipe.steps[2].points.last == "From here on, cook in 3 batches so the pan is not crowded.")
    }

    @Test func sameSizePanOnlyCountsBatches() throws {
        let recipe = scaled(try sample("garlic-fried-rice"), to: "2")
        #expect(recipe.tools[0].note == "About 24 cm. Serves 2 instead of 1: cook in 2 batches.")
    }

    @Test func potGrowsAndShrinksByVolume() throws {
        let curry = try sample("seafood-curry")
        #expect(scaled(curry, to: "6").tools[0].note == "About 20 cm. Serves 6 instead of 2: use one about 28 cm across.")
        #expect(scaled(curry, to: "1").tools[0].note == "About 20 cm. Serves 1 instead of 2: use one about 16 cm across.")
    }

    @Test func panWithNoSizeOnlyCountsBatches() throws {
        let curry = try sample("seafood-curry")
        #expect(scaled(curry, to: "6").tools[2].note
            == "For the seafood, which is cooked apart from the curry. Serves 6 instead of 2: cook in 2 batches.")
        #expect(scaled(curry, to: "6").steps[6].points.last == "From here on, cook in 2 batches so the pan is not crowded.")
        #expect(scaled(curry, to: "1").tools[2] == curry.tools[2])
    }

    @Test func smallerPanStopsAtTwentyCentimeters() throws {
        let recipe = scaled(try sample("kimchi-fried-rice"), to: "1")
        #expect(recipe.tools[0].note?.hasSuffix("Serves 1 instead of 2: use one about 20 cm across.") == true)
        #expect(recipe.steps == (try sample("kimchi-fried-rice")).steps)
    }

    @Test func leavesWhatGivesNoSize() throws {
        let carbonara = try sample("spaghetti-carbonara")
        #expect(scaled(carbonara, to: "1").tools[0] == carbonara.tools[0])
        let toast = try sample("butter-toast")
        #expect(scaled(toast, to: "4") == toast.with(serves: "4"))
    }

    @Test(arguments: ["butter-toast", "egg-fried-rice", "french-toast", "garlic-fried-rice",
                      "kimchi-fried-rice", "seafood-curry", "spaghetti-carbonara"])
    func scalingBackGivesTheRecipeBack(_ name: String) throws {
        for language in ["en-US", "ja"] {
            let recipe = try sample(name, language)
            for serves in ["1", "3", "4", "6", "12"] {
                let there = scaled(recipe, to: serves)
                #expect(scaled(scaled(there, to: "5"), to: recipe.serves) == recipe, "\(language) \(serves)")
            }
        }
    }

    @Test func rescalingReplacesTheLine() throws {
        let recipe = scaled(scaled(try sample("kimchi-fried-rice"), to: "6"), to: "4")
        #expect(recipe.tools[0].note == "About 24 cm. A second small pan for the eggs saves wiping this one out. "
            + "Serves 4 instead of 2: cook in 2 batches.")
        #expect(recipe.steps.flatMap(\.points).filter { $0.contains("batches") }.count == 1)
    }

    @Test(arguments: [
        "About 24 cm. For 6 servings, use a 30 cm pan and fry it in two batches.",
        "24cmほど。6人分なら30cmのフライパンで2回に分けて炒めます。",
    ])
    func leavesALineSomeoneReworded(_ note: String) throws {
        var recipe = try sample("kimchi-fried-rice")
        recipe.serves = "6"
        recipe.tools[0].note = note
        let rescaled = scaled(recipe, to: "4")
        #expect(rescaled.tools[0].note == note)
        #expect(rescaled.steps == recipe.steps)
    }

    @Test func addsNoPointToAStepThatAlreadyBatches() throws {
        var recipe = try sample("kimchi-fried-rice")
        recipe.steps[3].points.append("With more than two servings, cook the pork in batches.")
        let rescaled = scaled(recipe, to: "6")
        #expect(rescaled.steps[3] == recipe.steps[3])
        #expect(rescaled.tools[0].note?.hasSuffix("cook in 2 batches.") == true)
    }

    @Test func wokNotesAboutOnePortionAreNotACount() {
        #expect(!Recipe.mentionsServings("A 24 cm frying pan works. It holds less heat, so cook one portion at a time."))
        #expect(!Recipe.mentionsServings("24cmのフライパンでも作れます。一人分ずつ炒めます。"))
        #expect(Recipe.mentionsServings("Serves 6: a 30 cm pan."))
    }

    @Test func readsSizesInBothLanguages() {
        #expect(Recipe.centimeters(in: "About 24 cm.") == 24)
        #expect(Recipe.centimeters(in: "24cmほど。") == 24)
        #expect(Recipe.centimeters(in: "24cmのフライパンでも作れます。") == 24)
        #expect(Recipe.centimeters(in: "Big enough for 2 litres at a rolling boil.") == nil)
    }
}

private extension Recipe {
    func with(serves: String) -> Recipe {
        var recipe = self
        recipe.serves = serves
        return recipe
    }
}
