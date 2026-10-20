import FoundationModels
import Foundation

@Generable(description: "What a recipe serves and where the dish comes from")
struct SignatureSortAnswer {
    @Guide(
        description: "The form of what is served, read from what the recipe makes rather than any one word in its name: a pasta salad is a salad, a pizza toast is a toast, a curry udon is a noodle soup",
        .anyOf(SignatureDish.forms)
    )
    var form: String

    @Guide(description: "Where the dish as made here comes from", .anyOf(SignatureDish.cuisines))
    var cuisine: String
}

extension SignatureDish {
    /// The most of a recipe's main ingredients the model is shown.
    private static let ingredientLimit = 8

    /// Room for the two words of an answer and the structure around them.
    private static let sortTokenLimit = 60

    /// Decides whether a recipe makes one of the signature dishes. A title that ends with a
    /// dish's title is decided in code. A title that only has one elsewhere is put to Apple
    /// Intelligence, which sorts the recipe into a form and a cuisine once, in English, so the
    /// answer reads the same in any language. A title that names no signature dish is decided
    /// without asking.
    ///
    /// Returns nil when Apple Intelligence cannot run, so nothing is kept and the recipe is
    /// decided once it can. When the pass itself fails, as it does on a title the guardrails
    /// turn down, the recipe is kept without a signature dish, so it is not asked about again.
    @MainActor
    public static func decide(for recipe: Recipe) async -> SignatureDecision? {
        if let ending = endingID(forTitle: recipe.title) {
            return SignatureDecision(title: recipe.title, id: ending)
        }
        let candidates = candidates(forTitle: recipe.title)
        guard !candidates.isEmpty else { return SignatureDecision(title: recipe.title, id: nil) }
        let passes = ModelPasses()
        guard passes.isAvailable else { return nil }
        let lines = [recipe.ingredients.supermarket, recipe.ingredients.general, recipe.ingredients.optional]
        let icons = Set(lines.compactMap { $0 }.joined().compactMap { IconCatalog.iconName(for: $0.icon) })
        do {
            let sorted = try await passes.run(instructions: String(culinaryEnglish: "Signature.Prompt.Sort")) { session in
                try await session.respond(
                    to: prompt(for: recipe),
                    generating: SignatureSortAnswer.self,
                    options: GenerationOptions(sampling: .greedy, maximumResponseTokens: sortTokenLimit)
                ).content
            }
            let id = decided(candidates: candidates, form: sorted.form, cuisine: sorted.cuisine, icons: icons, title: recipe.title)
            return SignatureDecision(title: recipe.title, id: id)
        } catch is CancellationError {
            return nil
        } catch {
            return SignatureDecision(title: recipe.title, id: nil)
        }
    }

    /// The title and the main ingredients, each by its catalog name in English where it has one.
    /// Both main sections are read, as a recipe can keep its rice or pasta under the general
    /// section: shown only the bacon and cheese of a cheese risotto, the model called it a pasta.
    private static func prompt(for recipe: Recipe) -> String {
        let lines = (recipe.ingredients.supermarket ?? []) + (recipe.ingredients.general ?? [])
        let names = lines.prefix(ingredientLimit).map { line in
            IconCatalog.iconName(for: line.icon).map(IconCatalog.englishName(for:)) ?? line.item
        }
        let ingredients = names.isEmpty
            ? String(culinaryEnglish: "Generate.Prompt.Plan.None")
            : names.joined(separator: String(culinaryEnglish: "Generate.Prompt.Separator"))
        return String(format: String(culinaryEnglish: "Signature.Prompt.Sort.Recipe"), recipe.title, ingredients)
    }
}
