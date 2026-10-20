import Foundation

extension Dish {
    /// The dish a recipe makes, worked out from what the recipe already says: the catalog icons
    /// of its ingredients and tools, which hold in any language, and the words of its title and
    /// steps, read in English and Japanese. The grain or the sauce becomes the food the dish is
    /// built on, the vessel follows from that and from the tools, and the ingredients that can
    /// still be seen once the dish is served are laid on top, each cut the way the recipe cuts it.
    ///
    /// The seed picks between the vessels that suit the food and scatters the pieces. It is the
    /// recipe's `id` the first time, and a fresh one when the cook asks for the icon again.
    public static func planned(for recipe: Recipe, seed: String? = nil) -> Dish {
        DishPlanner(recipe, seed: seed ?? recipe.id).dish.keepingSignature(of: recipe)
    }

    /// The dish, with Jev asked which of the seasonings, aromatics, and optional lines can be
    /// seen once it is served. The words of the title and the last step only say so when the
    /// recipe happens to name the line there. When the Worker cannot be reached, they decide.
    @MainActor
    public static func asked(for recipe: Recipe, seed: String? = nil) async -> Dish {
        let planner = DishPlanner(recipe, seed: seed ?? recipe.id)
        let questions = planner.questions
        guard !questions.isEmpty,
              let answers = try? await PlatesCloud.shared.toppings(
                  dish: recipe.title,
                  steps: recipe.steps.map { (title: $0.title, points: $0.points) },
                  ingredients: questions.map { String($0.line.prefix(300)) }
              ),
              answers.count == questions.count
        else { return planner.dish.keepingSignature(of: recipe) }
        let seen = Dictionary(zip(questions.map(\.asset), answers.map { $0 >= DishPlanner.seenAbove }), uniquingKeysWith: { $0 || $1 })
        return DishPlanner(recipe, seed: seed ?? recipe.id, seen: seen).dish.keepingSignature(of: recipe)
    }

    /// The dish with the signature already decided for the recipe, since drawing the dish again
    /// does not change which dish the recipe makes.
    private func keepingSignature(of recipe: Recipe) -> Dish {
        var dish = self
        dish.signature = recipe.dish?.signature
        return dish
    }
}

private nonisolated struct DishPlanner {
    private struct Entry {
        let asset: String
        let section: Section
        let amount: String
        /// The line as the recipe writes it, with its note, for asking whether it can be seen.
        let line: String
        /// The entry's own words and every step point that names it, lowercased, for reading
        /// how it is cut.
        let text: String
    }

    private enum Section {
        case main, optional
    }

    private let recipe: Recipe
    private let seed: String
    private let entries: [Entry]
    private let assets: Set<String>
    private let tools: Set<String>
    private let title: String
    private let method: String
    private let finish: String
    /// Whether an ingredient the words cannot settle can be seen on the served dish, as Jev
    /// answered it, by catalog name.
    private let seen: [String: Bool]

    /// How sure Jev has to be that an ingredient can be seen before it is drawn. Pepper on
    /// carbonara comes back near 0.9 and pepper seasoned into fried rice near 0.3.
    static let seenAbove = 0.6

    init(_ recipe: Recipe, seed: String, seen: [String: Bool] = [:]) {
        self.recipe = recipe
        self.seed = seed
        self.seen = seen
        title = recipe.title.lowercased()
        method = recipe.steps.flatMap { [$0.title] + $0.points }.joined(separator: "\n").lowercased()
        finish = recipe.steps.last.map { ([$0.title] + $0.points).joined(separator: "\n") }?.lowercased() ?? ""
        tools = Set(recipe.tools.compactMap { IconCatalog.iconName(for: $0.icon) })
        let points = recipe.steps.flatMap(\.points).map { $0.lowercased() }
        var seen = Set<String>()
        var entries: [Entry] = []
        let sections: [([Ingredient]?, Section)] = [
            (recipe.ingredients.supermarket, .main),
            (recipe.ingredients.general, .main),
            (recipe.ingredients.optional, .optional),
        ]
        for (list, section) in sections {
            for ingredient in list ?? [] {
                guard let asset = IconCatalog.iconName(for: ingredient.icon), seen.insert(asset).inserted else { continue }
                let item = ingredient.item.lowercased()
                let mentions = points.filter { !item.isEmpty && $0.contains(item) }
                let text = ([ingredient.item, ingredient.amount, ingredient.note ?? ""].map { $0.lowercased() } + mentions)
                    .joined(separator: "\n")
                let line = [ingredient.item, ingredient.note].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: ", ")
                entries.append(Entry(asset: asset, section: section, amount: ingredient.amount, line: line, text: text))
            }
        }
        self.entries = entries
        assets = seen
    }

    // MARK: Words

    private static let soupWords = [
        "soup", "ramen", "udon", "soba", "pho", "broth", "stew", "chowder", "laksa", "noodle soup",
        "スープ", "ラーメン", "うどん", "そば", "蕎麦", "汁", "鍋", "シチュー", "ポタージュ", "フォー",
    ]
    private static let friedRiceWords = [
        "fried rice", "garlic rice", "butter rice", "nasi goreng", "pilaf", "pilau", "paella",
        "チャーハン", "炒飯", "焼き飯", "焼飯", "ピラフ", "パエリア", "ガーリックライス", "バターライス",
    ]
    private static let bowlWords = ["bowl", "donburi", "bibimbap", "poke", "丼", "どんぶり", "ビビンバ"]
    private static let saladWords = ["salad", "サラダ"]
    private static let mashWords = ["mash", "マッシュ"]
    private static let meltWords = [
        "gratin", "melt", "cheese toast", "mac and cheese", "macaroni cheese", "lasagn", "pizza", "quesadilla",
        "グラタン", "ドリア", "チーズ焼き", "とろける", "ピザ",
    ]
    private static let omeletteWords = ["omelet", "frittata", "tamagoyaki", "okonomiyaki", "オムレツ", "卵焼き", "玉子焼き", "お好み焼き", "オムライス"]
    private static let curryWords = ["curry", "カレー"]

    /// Words that say how an ingredient is cut, each with the variant names they point to, in
    /// the order they are tried.
    private static let cuts: [(words: [String], variants: [String])] = [
        (["fried egg", "sunny", "目玉焼き"], ["fried"]),
        (["boiled egg", "soft-boiled", "hard-boiled", "jammy", "ゆで卵", "ゆでたまご", "半熟", "煮卵", "味玉"], ["boiled"]),
        (["yolk", "卵黄", "黄身"], ["yolk"]),
        (["scrambl", "beaten", "炒り卵", "いり卵", "溶き", "ふわふわ"], ["scrambled"]),
        (["chip", "crisp", "チップ", "カリカリ"], ["chips", "crispy", "bits", "crushed"]),
        (["julienne", "matchstick", "shred", "千切り", "せん切り", "細切り"], ["julienne", "shredded", "strips", "slivers", "sliced"]),
        (["ring", "輪切り", "小口切り", "小口"], ["rings", "coins", "slices"]),
        (["dice", "cube", "cubed", "角切り", "さいの目", "サイコロ"], ["diced", "cubes", "chunks", "lardons"]),
        (["wedge", "quarter", "くし切り", "くし形"], ["wedges", "segments", "quartered", "quarters", "halves"]),
        (["half", "halve", "半分"], ["halves", "half"]),
        (["grate", "おろし", "すりおろ"], ["grated", "crumbs"]),
        (["mince", "chop", "みじん"], ["chopped", "minced", "diced", "crumbled", "bits", "flecks", "snipped"]),
        (["tear", "torn", "ちぎ"], ["torn", "leaves", "chopped"]),
        (["slice", "sliced", "薄切り", "スライス", "そぎ切り"], ["sliced", "slices", "coins", "half-moons", "rashers", "sashimi", "ribbons", "strips"]),
        (["chunk", "bite-size", "一口大", "ぶつ切り", "乱切り"], ["chunks", "pieces", "cubes", "chopped"]),
        (["crumbl", "ほぐ"], ["crumbled", "flaked"]),
        (["melt", "とろけ"], ["melted"]),
    ]

    private func says(_ words: [String], in text: String) -> Bool {
        words.contains { text.contains($0) }
    }

    /// Whether the title or the last step names an ingredient, in the reader's language or in
    /// English. What the last step names is what goes on top as the dish is served.
    private func named(_ asset: String, in text: String) -> Bool {
        let names = [IconCatalog.displayName(for: asset), IconCatalog.englishName(for: asset)]
            .map { $0.lowercased() }
            .filter { $0.count > 1 }
        return names.contains { text.contains($0) }
    }

    private func isGrain(_ asset: String) -> Bool {
        IngredientCategory.grains.icons.contains(asset)
    }

    // MARK: Planning

    /// The lines that are drawn only when they can be seen on the dish as it is served, which
    /// the words of the recipe can only guess at.
    var questions: [(asset: String, line: String)] {
        entries.filter { isDrawable($0) && isUnsettled($0) }.map { ($0.asset, $0.line) }
    }

    private func isDrawable(_ entry: Entry) -> Bool {
        !DishParts.isHidden(entry.asset) && !DishParts.variants(of: entry.asset).isEmpty
    }

    /// Seasonings, aromatics, and optional lines, which go into most dishes unseen.
    private func isUnsettled(_ entry: Entry) -> Bool {
        entry.section == .optional || IconCatalog.shelf(of: entry.asset) == .pantry || Self.aromatics.contains(entry.asset)
    }

    var dish: Dish {
        var random = SeededRandom(seed)
        var consumed = Set<String>()
        var fills: [DishLayer] = []
        let soupy = says(Self.soupWords, in: title)
        let visible = entries.filter(isDrawable)

        // The food the dish is built on.
        let grain = visible.first { $0.section == .main && isGrain($0.asset) && hasFill($0.asset) }
        let sauce = Self.sauces.first { asset in
            visible.contains { $0.asset == asset && $0.section == .main } && !(grain.map { Self.pastaTakesSauce($0.asset) } ?? false)
        }
        var kind = vesselKind(grain: grain?.asset, sauce: sauce, soupy: soupy)

        if let grain {
            let variant = grainVariant(grain.asset, kind: kind, soupy: soupy, consumed: &consumed)
            if let variant {
                fills.append(DishLayer(grain.asset, variant))
                consumed.insert(grain.asset)
            }
        }
        if let sauce, let variant = fillVariant(sauce, kind: kind, roles: [.sauce, .soup]) {
            fills.append(DishLayer(sauce, variant))
            consumed.insert(sauce)
        }
        if fills.isEmpty, soupy {
            let soup = Self.soups.first { assets.contains($0) } ?? "dashi"
            if let variant = fillVariant(soup, kind: "bowl", roles: [.soup]) {
                kind = "bowl"
                fills.append(DishLayer(soup, variant))
                consumed.insert(soup)
            }
        }
        if fills.isEmpty, says(Self.omeletteWords, in: title), assets.contains("egg") {
            kind = "plate"
            fills.append(DishLayer("egg", "omelette"))
            consumed.insert("egg")
        }
        if fills.isEmpty, says(Self.mashWords, in: title),
           let mash = visible.first(where: { DishParts.part($0.asset, "mash") != nil }) {
            fills.append(DishLayer(mash.asset, "mash"))
            consumed.insert(mash.asset)
        }
        if fills.isEmpty, let bed = visible.first(where: { $0.section == .main && DishParts.part($0.asset, "bed") != nil }),
           says(Self.saladWords, in: title) || !visible.contains(where: { isGrain($0.asset) }) {
            if kind == "pan" || kind == "pot" { kind = "plate" }
            fills.append(DishLayer(bed.asset, "bed"))
            consumed.insert(bed.asset)
        }
        if says(Self.meltWords, in: title) || says(Self.meltWords, in: finish),
           let cheese = visible.first(where: { DishParts.part($0.asset, "melted") != nil }), !fills.isEmpty {
            fills.append(DishLayer(cheese.asset, "melted"))
            consumed.insert(cheese.asset)
        }

        // An egg beaten into a batter or a coating is not seen on the plate.
        if assets.contains("panko") || assets.contains("breadcrumbs") || assets.contains("flour") && !says(Self.omeletteWords, in: title) {
            if !(entries.first { $0.asset == "egg" }.map { says(["fried egg", "目玉焼き", "boiled", "ゆで卵"], in: $0.text) } ?? false) {
                consumed.insert("egg")
            }
        }

        let base = fills.first.map { $0.ingredient }
        let pieces = toppings(on: base, kind: kind, visible: visible, consumed: consumed)
        let vessel = pickVessel(kind: kind, under: fills.first, random: &random)
        return Dish(vessel: vessel, seed: seed, layers: fills + pieces)
    }

    /// Sauces that fill a region of their own, most telling first.
    private static let sauces = [
        "curry-roux", "thai-curry-paste", "coconut-milk", "lentils", "bolognese-sauce", "arrabbiata-sauce", "puttanesca-sauce",
        "vodka-sauce", "marinara-sauce", "passata", "canned-tomatoes", "carbonara-sauce", "alfredo-sauce",
        "mentaiko-pasta-sauce", "tarako-pasta-sauce", "pesto", "tianmianjiang", "beans",
    ]
    private static let soups = ["miso", "doenjang", "pumpkin", "butternut-squash", "dashi"]

    /// Pasta that takes its sauce into its own fill, so the sauce is not drawn beside it.
    private static func pastaTakesSauce(_ asset: String) -> Bool {
        ["pasta", "spaghetti", "fettuccine", "penne", "rigatoni", "fusilli", "macaroni", "orzo", "gnocchi", "ravioli", "lasagna"]
            .contains(asset)
    }

    private func hasFill(_ asset: String) -> Bool {
        DishParts.variants(of: asset).contains { $0.part.kind == .fill }
    }

    private func vesselKind(grain: String?, sauce: String?, soupy: Bool) -> String {
        if soupy { return "bowl" }
        if says(Self.bowlWords, in: title) { return "bowl" }
        if says(Self.curryWords, in: title), sauce != nil { return "plate" }
        if let grain, !DishParts.variants(of: grain).contains(where: { $0.part.kind == .fill && ($0.part.vessels ?? []).contains("plate") }) {
            return "bowl"
        }
        if ["bread", "tortilla", "pita", "naan", "rice-paper"].contains(grain) { return "plate" }
        let hasPlate = tools.contains("plate")
        let hasBowl = tools.contains("bowl")
        if !hasPlate, !hasBowl, tools.contains("pan") || tools.contains("wok") { return "pan" }
        if hasBowl, !hasPlate, grain != nil { return "bowl" }
        return "plate"
    }

    /// The variant a grain is drawn as: fried rice for fried rice, broth for noodle soup, the
    /// pasta in the sauce the recipe gives it.
    private func grainVariant(_ grain: String, kind: String, soupy: Bool, consumed: inout Set<String>) -> String? {
        switch grain {
        case "rice":
            if says(Self.friedRiceWords, in: title) || tools.contains("wok") && !says(Self.curryWords, in: title) {
                let red = ["kimchi", "gochujang", "ketchup", "gochugaru", "canned-tomatoes", "tomato-paste"].contains { assets.contains($0) }
                return red ? "red-fried" : "fried"
            }
            return kind == "bowl" || kind == "pot" ? "bowl" : "mound"
        case "spaghetti", "fettuccine":
            let roe = ["mentaiko-pasta-sauce", "tarako-pasta-sauce", "mentaiko"].first { assets.contains($0) }
            if grain == "spaghetti", let roe {
                consumed.insert(roe)
                return "roe"
            }
            let tomato = [
                "bolognese-sauce", "arrabbiata-sauce", "puttanesca-sauce", "vodka-sauce", "marinara-sauce", "tomato", "passata",
                "canned-tomatoes", "tomato-paste", "ketchup",
            ].first { assets.contains($0) }
            if grain == "spaghetti", let tomato {
                consumed.insert(tomato)
                return "tomato"
            }
            let creamy = ["carbonara-sauce", "alfredo-sauce", "cream", "egg", "milk", "cream-cheese", "mascarpone"]
                .filter { assets.contains($0) }
            if grain == "spaghetti", !creamy.isEmpty {
                consumed.formUnion(creamy)
                return "creamy"
            }
            return fillVariant(grain, kind: kind, roles: [.base])
        case "bread":
            if ["egg", "milk"].allSatisfy({ assets.contains($0) }) && tools.contains("pan") || title.contains("french toast") || title.contains("フレンチトースト") {
                consumed.formUnion(["egg", "milk", "cream"])
                return "french-toast"
            }
            return tools.contains("toaster") || tools.contains("oven") || title.contains("toast") || title.contains("トースト") ? "toast" : "slice"
        default:
            if soupy, DishParts.part(grain, "broth") != nil { return "broth" }
            return fillVariant(grain, kind: kind, roles: [.base])
        }
    }

    /// The lowest ranked fill of an ingredient that goes in this kind of vessel.
    private func fillVariant(_ asset: String, kind: String, roles: Set<DishParts.Role>) -> String? {
        let fills = DishParts.variants(of: asset).filter { $0.part.kind == .fill && roles.contains($0.part.role ?? .base) }
        return (fills.first { ($0.part.vessels ?? []).contains(kind) } ?? fills.first)?.name
    }

    // MARK: Toppings

    /// Ingredients that are cooked into nearly every dish and only seen when the dish is named
    /// for them or served with them on top.
    private static let aromatics: Set<String> = ["onion", "garlic", "ginger", "shallot", "butter", "milk", "cream", "red-onion"]

    private func toppings(on base: String?, kind: String, visible: [Entry], consumed: Set<String>) -> [DishLayer] {
        var scattered: [DishLayer] = []
        var centered: [DishLayer] = []
        var garnish: [DishLayer] = []
        let onBread = ["bread", "egg", "tofu", "yogurt", "tortilla", "pita"].contains(base ?? "")

        for entry in visible where !consumed.contains(entry.asset) {
            if isUnsettled(entry) {
                let shown = named(entry.asset, in: title) || named(entry.asset, in: finish)
                let butterOnBread = entry.asset == "butter" && onBread
                guard seen[entry.asset] ?? (shown || butterOnBread) else { continue }
            }
            guard let (variant, part) = pieceVariant(entry) else { continue }
            let whole = part.most.flatMap { most in Self.number(in: entry.amount).map { min(max($0, 1), most) } }
            let layer = DishLayer(entry.asset, variant, count: whole)
            switch part.tier ?? .scattered {
            case .scattered: scattered.append(layer)
            case .centered: centered.append(layer)
            case .garnish: garnish.append(layer)
            }
        }

        scattered = Array(scattered.prefix(3))
        let share = [1.0, 1.0, 0.8, 0.6][min(scattered.count, 3)] * (kind == "plate" || kind == "pan" ? 1 : 1.1)
        scattered = scattered.map { layer in
            guard layer.count == nil else { return layer }
            let count = DishParts.part(layer.ingredient, layer.variant)?.count ?? 4
            return DishLayer(layer.ingredient, layer.variant, count: max(2, Int((Double(count) * share).rounded())))
        }
        return scattered + Array(centered.prefix(2)) + Array(garnish.prefix(3))
    }

    private static let numberWords = [
        "a": 1, "an": 1, "one": 1, "half": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    ]

    /// How many of a thing an amount gives: 2 in "2", "2 large", and "２個", 1 in "1 to 2" and
    /// "one", nil in "to taste". A fraction counts as one, since there is still one on the plate.
    private static func number(in amount: String) -> Int? {
        var digits = ""
        for character in amount {
            if character.unicodeScalars.first?.properties.numericType == .decimal, let value = character.wholeNumberValue {
                digits.append(String(value))
            } else if !digits.isEmpty {
                break
            }
        }
        if let value = Int(digits) { return max(value, 1) }
        if amount.contains("½") || amount.contains("¼") || amount.contains("半") { return 1 }
        if let kanji = amount.first(where: { "一二三四五六".contains($0) }) { return kanji.wholeNumberValue }
        let words = amount.lowercased().split { !$0.isLetter }
        return words.lazy.compactMap { numberWords[String($0)] }.first
    }

    /// The piece an ingredient is drawn as, read off how the recipe cuts it, or its most usual
    /// piece when the recipe does not say.
    private func pieceVariant(_ entry: Entry) -> (String, DishParts.Part)? {
        let pieces = DishParts.variants(of: entry.asset).filter { $0.part.kind == .piece }
        guard !pieces.isEmpty else { return nil }
        let text = entry.text + (entry.asset == "egg" ? "\n" + title : "")
        for cut in Self.cuts where says(cut.words, in: text) {
            for name in cut.variants {
                if let match = pieces.first(where: { $0.name == name }) { return (match.name, match.part) }
            }
        }
        if entry.asset == "egg" {
            let fried = says(Self.friedRiceWords, in: title) || method.contains("scrambl") || method.contains("炒り")
            let name = fried ? "scrambled" : "fried"
            if let match = pieces.first(where: { $0.name == name }) { return (match.name, match.part) }
        }
        return (pieces[0].name, pieces[0].part)
    }

    /// One of the vessels of a kind, chosen so the food stands apart from the dish it is on.
    /// Every colour far enough from the food is a fair pick, and the recipe's own seed picks
    /// between them, so a grid of recipes is not all on the one plate.
    private func pickVessel(kind: String, under base: DishLayer?, random: inout SeededRandom) -> String {
        let vessels = DishParts.vessels(ofKind: kind)
        guard !vessels.isEmpty else { return "plate" }
        guard let base, let tone = DishParts.part(base.ingredient, base.variant)?.tones.first,
              let food = DishLayout.Color(hex: tone)
        else { return random.pick(vessels) ?? vessels[0] }
        let scored = vessels.compactMap { name -> (String, Double)? in
            guard let well = DishParts.vessels[name].flatMap({ DishLayout.Color(hex: $0.tone) }) else { return nil }
            return (name, well.distance(to: food))
        }
        let clear = scored.filter { $0.1 >= 25 }.map(\.0)
        return random.pick(clear) ?? scored.max { $0.1 < $1.1 }?.0 ?? vessels[0]
    }
}
