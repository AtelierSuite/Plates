import CulinaryIntelligence
import Foundation
import Observation

/// Reads and writes recipe JSON in whichever folder the user picked, one file per recipe.
@MainActor
@Observable
final class RecipeStore {
    private(set) var recipes: [Recipe] = []
    private(set) var loadError: String?

    var location: StorageLocation {
        didSet {
            guard location != oldValue else { return }
            UserDefaults.standard.set(location.rawValue, forKey: Self.locationKey)
            load()
        }
    }

    private static let locationKey = "storageLocation"

    private let decoder = JSONDecoder()

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.locationKey)
        let saved = stored.flatMap(StorageLocation.init(rawValue:)) ?? .onMyIPhone
        location = saved.isAvailable ? saved : .onMyIPhone
        load()
    }

    /// The folder currently in use, falling back to the local Documents folder when iCloud is unavailable.
    var directory: URL? {
        location.directory ?? StorageLocation.onMyIPhone.directory
    }

    func load() {
        loadError = nil
        guard let directory else {
            recipes = []
            loadError = String(localized: "Storage.Error.NoDirectory")
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
            recipes = files.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Recipe.self, from: data)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            recipes = []
            loadError = error.localizedDescription
        }
        decideSignatures()
    }

    /// Recipes whose signature dish has been asked about while the app has been open, by id and
    /// title, so a decision that cannot be written is not asked for again on every load.
    private var askedSignatures: Set<String> = []
    private var signatureTask: Task<Void, Never>?

    /// Asks, one recipe at a time, whether each recipe that could make a signature dish does, and
    /// writes the answer into its dish. This covers new, generated, imported, and renamed recipes
    /// alike, and the ones saved before signature icons were drawn.
    private func decideSignatures() {
        guard signatureTask == nil else { return }
        let waiting = recipes.filter { SignatureDish.needsDecision($0) && !askedSignatures.contains(Self.signatureKey($0)) }
        guard !waiting.isEmpty else { return }
        signatureTask = Task {
            for recipe in waiting {
                askedSignatures.insert(Self.signatureKey(recipe))
                guard let decision = await SignatureDish.decide(for: recipe) else { continue }
                guard var current = recipes.first(where: { $0.id == recipe.id }),
                      current.title == recipe.title else { continue }
                var dish = current.dish ?? Dish.planned(for: current)
                dish.signature = decision
                current.dish = dish
                save(current)
            }
            signatureTask = nil
            decideSignatures()
        }
    }

    private static func signatureKey(_ recipe: Recipe) -> String {
        recipe.id + "\n" + recipe.title
    }

    /// Recipes read off web pages that are waiting to be sorted, oldest first. Each one opens
    /// in the import sheet, and stays in the inbox until the cook saves or discards it.
    private(set) var sharedPages: [SharedImport] = []

    /// Moves complete recipes from the App Group inbox into the selected storage location, and
    /// holds back the ones read off web pages for the import sheet to sort. A file stays in the
    /// inbox if saving fails, so the next app launch can retry it.
    func importSharedRecipes() {
        do {
            var pages: [SharedImport] = []
            for pending in try SharedRecipeInbox.pendingRecipes() {
                if pending.page != nil {
                    pages.append(pending)
                    continue
                }
                guard save(asRead(pending.recipe), isNew: true) else { return }
                try SharedRecipeInbox.remove(pending.url)
            }
            sharedPages = pages
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// A shared recipe as the extension read it, with an icon on each ingredient the catalog
    /// knows by name, for when it is not sorted.
    func asRead(_ recipe: Recipe) -> Recipe {
        var recipe = recipe
        recipe.ingredients.supermarket = importedIcons(in: recipe.ingredients.supermarket)
        recipe.ingredients.general = importedIcons(in: recipe.ingredients.general)
        recipe.ingredients.optional = importedIcons(in: recipe.ingredients.optional)
        return recipe
    }

    /// Saves a shared page's recipe, or discards the page when there is none, and takes it out
    /// of the inbox. A recipe that fails to save leaves the page where it was.
    @discardableResult
    func finish(_ shared: SharedImport, saving recipe: Recipe?) -> Bool {
        if let recipe, !save(recipe, isNew: true) { return false }
        try? SharedRecipeInbox.remove(shared.url)
        sharedPages.removeAll { $0.id == shared.id }
        return true
    }

    private func importedIcons(in ingredients: [Ingredient]?) -> [Ingredient]? {
        ingredients?.map { ingredient in
            var ingredient = ingredient
            if ingredient.icon.isEmpty,
               let name = IconCatalog.ingredient(named: ingredient.item) {
                ingredient.icon = IconCatalog.ingredientPath(for: name)
            }
            return ingredient
        }
    }

    /// Writes a recipe out. New recipes get a unique id so a second "Tomato Egg" does not
    /// overwrite the first; existing ones keep the file they came from. A new recipe that came
    /// without a dish, from the share extension or the samples, has one worked out before it is
    /// written, and Clef's answer replaces it once it comes back, the way a generated recipe's
    /// dish is asked.
    @discardableResult
    func save(_ recipe: Recipe, isNew: Bool = false) -> Bool {
        guard let directory else { return false }
        let recipe = isNew ? prepared(recipe) : recipe
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try recipe.fileContents().write(to: url(for: recipe.id, in: directory), options: .atomic)
            load()
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    /// Writes out a new recipe and hands back what was written, with its id and dish, so the
    /// view that goes on editing it saves over the same file.
    func create(_ recipe: Recipe) -> Recipe? {
        let recipe = prepared(recipe)
        return save(recipe) ? recipe : nil
    }

    /// A new recipe with an id of its own, and a dish when it came without one.
    private func prepared(_ recipe: Recipe) -> Recipe {
        var recipe = recipe
        recipe.id = uniqueID(for: recipe)
        if recipe.dish == nil {
            recipe.dish = Dish.planned(for: recipe)
            askDish(for: recipe)
        }
        return recipe
    }

    /// Asks for a new recipe's dish and writes it in, unless its dish was redrawn while Clef
    /// was being asked. A signature dish decided in the meantime is kept.
    private func askDish(for recipe: Recipe) {
        Task {
            var dish = await Dish.asked(for: recipe)
            guard dish != recipe.dish, var current = recipes.first(where: { $0.id == recipe.id }),
                  Self.drawing(of: current.dish) == Self.drawing(of: recipe.dish) else { return }
            dish.signature = current.dish?.signature
            current.dish = dish
            save(current)
        }
    }

    /// A dish as its layers draw it, leaving out the signature decision.
    private static func drawing(of dish: Dish?) -> Dish? {
        dish.map { Dish(vessel: $0.vessel, seed: $0.seed, layers: $0.layers) }
    }

    func delete(_ recipe: Recipe) {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: url(for: recipe.id, in: directory))
        load()
    }

    func delete(atOffsets offsets: IndexSet, in list: [Recipe]) {
        for index in offsets {
            delete(list[index])
        }
    }

    /// Copies the recipes bundled with the app into the current folder, but only into an empty
    /// one. The samples ship in every language the app is written in, so the reader's language is
    /// the one that gets copied over.
    func addSampleRecipes() {
        guard recipes.isEmpty else { return }
        let language = Bundle.main.preferredLocalizations.first ?? "en-US"
        let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: nil,
            localization: language
        ) ?? []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let recipe = try? decoder.decode(Recipe.self, from: data) else { continue }
            save(recipe, isNew: true)
        }
    }

    private func url(for id: String, in directory: URL) -> URL {
        directory.appending(path: "\(id).json", directoryHint: .notDirectory)
    }

    private func uniqueID(for recipe: Recipe) -> String {
        let base = recipe.id.isEmpty ? Recipe.makeID(from: recipe.title) : recipe.id
        guard recipes.contains(where: { $0.id == base }) else { return base }
        var suffix = 2
        while recipes.contains(where: { $0.id == "\(base)-\(suffix)" }) {
            suffix += 1
        }
        return "\(base)-\(suffix)"
    }
}
