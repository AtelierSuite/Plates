import Foundation
import Testing
@testable import CulinaryIntelligence

struct DraftCheckTests {
    /// A draft written the way Gemma writes one, which passes every check.
    static let draft = """
    **Egg Fried Rice**

    Total Time: 20 minutes
    Serves: 2

    **Ingredients:**
    - 2 cups cooked jasmine rice, chilled
    - 2 large eggs
    - 2 spring onions, sliced
    - 1 tablespoon soy sauce
    - 1/2 teaspoon salt
    - 2 tablespoons vegetable oil
    - White pepper, to taste

    **Tools:**
    - Wok
    - Spatula

    **Method:**
    1. Beat the eggs with a pinch of the salt.
    2. Heat the oil in the wok over high heat for 1 minute. Scramble the eggs for 1 minute and set them aside.
    3. Fry the rice for 4 to 5 minutes, breaking up any clumps.
    4. Add the soy sauce, the rest of the salt, the eggs, and the spring onions. Toss for 1 minute.

    **Common Problems:**
    - The rice is mushy: use rice cooked the day before.
    - The rice sticks: heat the wok until it smokes before the oil goes in.
    """

    static let request = GenerationRequest(description: "Egg fried rice")

    static func failures(_ text: String, request: GenerationRequest = request) -> [DraftCheck] {
        DraftCheck.failures(in: WrittenRecipe(parsing: text), request: request)
    }

    @Test func goodDraftPasses() {
        #expect(Self.failures(Self.draft) == [])
    }

    @Test func missingSectionsFail() {
        let text = """
        Egg Fried Rice

        Ingredients:
        - 2 cups cooked rice
        - 2 eggs

        Method:
        1. Fry the rice and the eggs.
        """
        let failures = Self.failures(text)
        #expect(failures.contains(.time))
        #expect(failures.contains(.serves))
        #expect(failures.contains(.steps))
        #expect(failures.contains(.problems))
        #expect(!failures.contains(.title))
    }

    @Test func unusedIngredientFails() {
        let text = Self.draft.replacingOccurrences(of: "- 2 large eggs", with: "- 2 large eggs\n- 1 carrot, diced")
        #expect(Self.failures(text) == [.unusedIngredient])
        #expect(DraftCheck.unusedIngredients(in: WrittenRecipe(parsing: text)) == ["1 carrot, diced"])
    }

    @Test func linesToTasteAndBracketsCount() {
        let text = Self.draft
            .replacingOccurrences(of: "- 2 large eggs", with: "- 2 large eggs\n- Chili oil (optional)\n- 1 (8 oz) can sweetcorn, drained")
            .replacingOccurrences(of: "the eggs, and the spring onions", with: "the eggs, the sweetcorn, and the spring onions")
        #expect(Self.failures(text) == [])
    }

    @Test func unlistedIngredientFails() {
        let text = Self.draft.replacingOccurrences(of: "Fry the rice for", with: "Fry 2 cloves of garlic, then the rice for")
        #expect(Self.failures(text) == [.unlistedIngredient])
        #expect(DraftCheck.unlistedIngredients(in: WrittenRecipe(parsing: text)) == ["garlic"])
    }

    @Test func waterAndShortNamesAreNotUnlisted() {
        let written = WrittenRecipe(parsing: """
        Spaghetti with Parmesan

        Total Time: 20 minutes
        Serves: 2

        Ingredients:
        - 200 g spaghetti
        - 50 g grated Parmesan cheese
        - 2 tablespoons butter

        Method:
        1. Boil the spaghetti in salted water for 9 minutes.
        2. Melt the butter in a pan.
        3. Toss the spaghetti with the butter and the Parmesan.

        Problems:
        - Clumps: add a splash of the water.
        - Bland: add more cheese.
        """)
        #expect(DraftCheck.unlistedIngredients(in: written) == [])
        #expect(DraftCheck.failures(in: written, request: GenerationRequest(description: "Spaghetti with Parmesan")) == [])
    }

    @Test func starchTheDishNamesMustBeListed() {
        let text = Self.draft.replacingOccurrences(of: "- 2 cups cooked jasmine rice, chilled\n", with: "")
        #expect(Self.failures(text).contains(.missingStarch))
        #expect(DraftCheck.starches(namedIn: "Egg fried rice") == ["rice"])
        #expect(DraftCheck.starches(namedIn: "Spaghetti carbonara") == ["pasta"])
        #expect(DraftCheck.starches(namedIn: "Mushroom risotto") == ["rice"])
        #expect(DraftCheck.starches(namedIn: "Cucumber salad with rice vinegar") == [])
        #expect(DraftCheck.starches(namedIn: "Chicken stir fry") == [])
    }

    @Test func tooMuchSaltOrSugarFails() {
        let salty = Self.draft.replacingOccurrences(of: "- 1/2 teaspoon salt", with: "- 3 tablespoons salt")
        #expect(Self.failures(salty) == [.salt])
        let sweet = Self.draft.replacingOccurrences(of: "- 1/2 teaspoon salt", with: "- 1/2 teaspoon salt\n- 2 cups sugar")
            .replacingOccurrences(of: "the rest of the salt", with: "the sugar, the rest of the salt")
        #expect(Self.failures(sweet) == [.sugar])
        let pastaWater = Self.draft.replacingOccurrences(of: "- 1/2 teaspoon salt", with: "- 3 tablespoons salt, for the pasta water")
        #expect(!Self.failures(pastaWater).contains(.salt))
        #expect(DraftCheck.measure(in: "1½ tbsp salt")?.0 == 1.5)
        #expect(DraftCheck.measure(in: "2 to 3 teaspoons sugar")?.1 == "tsp")
    }

    @Test func ovenTemperatureIsChecked() {
        let hot = Self.draft.replacingOccurrences(of: "Beat the eggs", with: "Preheat the oven to 1800°F. Beat the eggs")
        #expect(Self.failures(hot) == [.ovenTemperature])
        let fine = Self.draft.replacingOccurrences(of: "Beat the eggs", with: "Preheat the oven to 200°C (400°F). Beat the eggs")
        #expect(Self.failures(fine) == [])
        let doneness = Self.draft.replacingOccurrences(of: "Beat the eggs", with: "Roast until the chicken reaches 74°C inside. Beat the eggs")
        #expect(!Self.failures(doneness).contains(.ovenTemperature))
    }

    @Test func stepTimesOverTheTotalFail() {
        let long = Self.draft.replacingOccurrences(of: "Fry the rice for 4 to 5 minutes", with: "Fry the rice for 1 hour")
        #expect(Self.failures(long) == [.stepTimes])
    }

    /// The recipes the app once shipped as samples, written out as cookbook text, are what a
    /// good draft looks like, so none should fail a check on what it says. They run longer than
    /// Gemma is asked to write, so the section counts are not checked.
    @Test(arguments: ["egg-fried-rice", "butter-toast", "kimchi-fried-rice", "spaghetti-carbonara", "garlic-fried-rice", "seafood-curry", "french-toast"])
    func sampleRecipesPass(_ name: String) throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Fixtures/SampleRecipes/en-US.lproj/\(name).json")
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: url))
        var lines = [recipe.title, "", "Total Time: \(recipe.time.replacingOccurrences(of: "min", with: "minutes"))", "Serves: \(recipe.serves)", "", "Ingredients:"]
        let sections = [recipe.ingredients.supermarket, recipe.ingredients.general].compactMap { $0 }.flatMap { $0 }
        for ingredient in sections {
            lines.append("- \(ingredient.amount) \(ingredient.item)" + (ingredient.note.map { ", \($0)" } ?? ""))
        }
        for ingredient in recipe.ingredients.optional ?? [] {
            lines.append("- \(ingredient.amount) \(ingredient.item) (optional)")
        }
        lines += ["", "Tools:"] + recipe.tools.map { "- \($0.name)" }
        lines += ["", "Method:"]
        for (index, step) in recipe.steps.enumerated() {
            lines.append("\(index + 1). \(step.title). " + step.points.joined(separator: " "))
        }
        lines += ["", "Common Problems:"] + recipe.troubleshooting.map { "- \($0.problem): \($0.solution)" }
        let text = lines.joined(separator: "\n")
        let written = WrittenRecipe(parsing: text)
        let failures = DraftCheck.failures(in: written, request: GenerationRequest(description: recipe.title))
            .filter { ![.steps, .problems].contains($0) }
        #expect(failures == [], "\(failures): unused \(DraftCheck.unusedIngredients(in: written)), unlisted \(DraftCheck.unlistedIngredients(in: written))")
    }
}
