import Foundation

/// A well known dish with an icon drawn for it by hand, shown in place of the dish put together
/// from parts when a recipe makes it. The titles each dish answers to, in English and Japanese,
/// and the forms of food its icon can stand for are read from `SignatureDishes.json`.
///
/// Code reads the title for the dishes it could be, the candidates, and Apple Intelligence sorts
/// the recipe into a form and a cuisine once. A candidate is drawn when the form is one its icon
/// shows, so a "Pesto Pasta Salad" is a salad and not a pesto pasta, and a "Mapo Tofu Rice Bowl"
/// is still mapo tofu. Asked whether a picture showed the recipe, the model said yes to a lasagna
/// soup and a pancake mix muffin; asked what the recipe is, it got both right.
///
/// The answer is kept on the recipe's dish with the title it was decided for, and a recipe whose
/// title has changed is decided again. Until then, and wherever Apple Intelligence cannot run, a
/// title names a dish when it ends with one of the dish's titles.
public nonisolated enum SignatureDish {
    /// The forms a recipe is sorted into. Every form a dish lists is one of these.
    static let forms = [
        "pasta", "pizza", "noodle soup", "noodles", "soup", "stew", "curry", "rice dish", "rice bowl",
        "fried rice", "salad", "sandwich", "burger", "toast", "wrap or flatbread", "tacos", "dumplings",
        "sweet pancakes", "savory pancake", "egg dish", "fried food", "grilled or roast meat",
        "braised meat", "stir fry", "raw fish", "dip or spread", "baked casserole", "pie or tart",
        "baked goods", "dessert", "other",
    ]

    /// The cuisines a recipe is sorted into. Only the dishes whose form is shared with dishes that
    /// look different list one: a Japanese curry and a Thai curry are both curries. The model's
    /// cuisine was wrong for one recipe in four, so nothing else depends on it.
    static let cuisines = [
        "italian", "french", "spanish", "british", "american", "mexican", "latin american",
        "caribbean", "japanese", "chinese", "korean", "thai", "vietnamese", "indian",
        "middle eastern", "african", "eastern european", "german", "greek", "filipino",
        "indonesian", "hawaiian", "other",
    ]

    /// How many candidates the model's answer is checked against, nearest the end of the title
    /// first.
    static let candidateLimit = 3

    private struct File: Decodable {
        struct Entry: Decodable {
            let id: String
            let forms: [String]
            let cuisines: [String]?
            let signs: [String]?
            let titles: [String]
            let unless: [String]?
        }

        let fillers: [String]
        let clauses: [String]
        let dishes: [Entry]
    }

    private struct Phrase {
        let key: String
        let id: String
        /// Whether the phrase starts with a Latin letter or a digit, and so has to sit on words.
        let isLatin: Bool
    }

    private struct Rule {
        let forms: Set<String>
        let cuisines: Set<String>?
        /// Catalog ingredients that settle the cuisine on their own, such as curry roux.
        let signs: Set<String>
        /// Words that mean a title is some other dish.
        let unless: [String]
    }

    private struct Table {
        /// Fillers made of Latin letters, which are only taken out as whole words.
        var wordFillers: [String] = []
        /// Fillers in any other script, which are taken out wherever they appear.
        var otherFillers: [String] = []
        /// Words that start a clause after the dish, such as "with".
        var clauses: Set<String> = []
        var phrases: [Phrase] = []
        var rules: [String: Rule] = [:]
    }

    /// A title made ready for matching: its words with the fillers taken out, joined with nothing
    /// between them, the offsets in the joined text where each word starts, and the offset where a
    /// clause such as "with peanuts" starts, or the end when there is none.
    private struct Reading {
        let words: [String]
        let joined: String
        let starts: Set<Int>
        let cut: Int
    }

    /// One place a dish's title was found in a recipe's title.
    private struct Found {
        let id: String
        let end: Int
        let length: Int
    }

    private static let table: Table = {
        guard let url = Bundle.module.url(forResource: "SignatureDishes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            return Table()
        }
        var table = Table()
        let fillers = file.fillers.map(folded).sorted { $0.count > $1.count }
        table.wordFillers = fillers.filter(isLatin)
        table.otherFillers = fillers.filter { !isLatin($0) }.map { $0.replacingOccurrences(of: " ", with: "") }
        table.clauses = Set(file.clauses.map(folded))
        for dish in file.dishes {
            for title in dish.titles {
                let key = reading(of: title, in: table).joined
                guard let first = key.unicodeScalars.first else { continue }
                table.phrases.append(Phrase(key: key, id: dish.id, isLatin: first.isASCII))
            }
            table.rules[dish.id] = Rule(
                forms: Set(dish.forms),
                cuisines: dish.cuisines.map(Set.init),
                signs: Set(dish.signs ?? []),
                unless: (dish.unless ?? []).map { folded($0).split(separator: " ").joined(separator: " ") }
            )
        }
        return table
    }()

    // MARK: - Reading a recipe

    /// The signature dish a recipe's icon is drawn as, such as `spaghetti-carbonara`, or nil.
    public static func id(for recipe: Recipe) -> String? {
        if let decision = recipe.dish?.signature, decision.title == recipe.title {
            return decision.id
        }
        return endingID(forTitle: recipe.title)
    }

    /// Whether the recipe's title could name a signature dish and nothing has been decided for
    /// it as it is now titled.
    public static func needsDecision(_ recipe: Recipe) -> Bool {
        recipe.dish?.signature?.title != recipe.title && !candidates(forTitle: recipe.title).isEmpty
    }

    /// The asset a recipe's signature icon is drawn from, such as `DishSignatureSpaghettiCarbonara`.
    public static func assetName(for recipe: Recipe) -> String? {
        id(for: recipe).map(assetName(id:))
    }

    public static func assetName(id: String) -> String {
        "DishSignature" + id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Every dish with a signature icon, by id.
    public static var ids: Set<String> { Set(table.rules.keys) }

    // MARK: - Candidates

    /// The dishes a title could name, the one whose title ends nearest the end of the recipe's
    /// first, as that is where the dish sits in an English or a Japanese title: "Roast Chicken
    /// Fried Rice" is a fried rice before it is a roast chicken. A dish's title only counts where
    /// it starts before a clause such as "with chili oil", and not where its `unless` words come
    /// in front of it.
    static func candidates(forTitle title: String) -> [String] {
        var best: [String: (score: Double, length: Int)] = [:]
        for part in parts(of: title) {
            let reading = reading(of: part, in: table, cuttingClauses: true)
            guard reading.cut > 0 else { continue }
            for found in occurrences(in: reading) {
                let score = Double(min(found.end, reading.cut)) / Double(reading.cut)
                if let current = best[found.id],
                   (current.score, current.length) >= (score, found.length) { continue }
                best[found.id] = (score, found.length)
            }
        }
        return best
            .sorted { ($0.value.score, $0.value.length) > ($1.value.score, $1.value.length) }
            .prefix(candidateLimit)
            .map(\.key)
    }

    /// The dish a title ends with, for when Apple Intelligence has not been asked.
    static func endingID(forTitle title: String) -> String? {
        var best: Found?
        for part in parts(of: title) {
            let reading = reading(of: part, in: table, cuttingClauses: true)
            for found in occurrences(in: reading) where found.end >= reading.cut {
                if found.length > best?.length ?? 0 {
                    best = found
                }
            }
        }
        return best?.id
    }

    /// The first candidate whose icon shows the form the recipe was sorted into. A dish that
    /// lists cuisines also needs the recipe's cuisine, or one of the ingredients that settle it.
    static func decided(candidates: [String], form: String, cuisine: String, icons: Set<String>) -> String? {
        candidates.first { id in
            guard let rule = table.rules[id], rule.forms.contains(form) else { return false }
            guard let cuisines = rule.cuisines else { return true }
            return cuisines.contains(cuisine) || !rule.signs.isDisjoint(with: icons)
        }
    }

    /// Every place a dish's title is found in the reading, starting before its clause and on
    /// words where the title is written in Latin letters.
    private static func occurrences(in reading: Reading) -> [Found] {
        let text = Array(reading.joined)
        var found: [Found] = []
        for phrase in table.phrases {
            let key = Array(phrase.key)
            guard key.count <= text.count else { continue }
            for start in 0...(text.count - key.count) where start < reading.cut {
                guard text[start..<start + key.count].elementsEqual(key) else { continue }
                let end = start + key.count
                if phrase.isLatin && (!reading.starts.contains(start) || !(reading.starts.contains(end) || end == text.count)) {
                    continue
                }
                if isRuledOut(phrase.id, before: start, in: reading) { continue }
                found.append(Found(id: phrase.id, end: end, length: key.count))
            }
        }
        return found
    }

    private static func isRuledOut(_ id: String, before offset: Int, in reading: Reading) -> Bool {
        guard let unless = table.rules[id]?.unless, !unless.isEmpty else { return false }
        let front = String(reading.joined.prefix(offset))
        var count = 0
        var words: [String] = []
        for word in reading.words where count < offset {
            words.append(word)
            count += word.count
        }
        let spaced = " " + words.joined(separator: " ") + " "
        return unless.contains { word in
            isLatin(word) ? spaced.contains(" \(word) ") : front.contains(word)
        }
    }

    /// A title split where it gives a dish more than one name, as in "Weeknight Dinner: Chicken
    /// Adobo".
    private static func parts(of title: String) -> [String] {
        title.components(separatedBy: CharacterSet(charactersIn: ":|｜/–—~〜～"))
    }

    private static func reading(of title: String, in table: Table, cuttingClauses: Bool = false) -> Reading {
        var text = folded(title)
        for filler in table.otherFillers {
            text = text.replacingOccurrences(of: filler, with: " ")
        }
        var words = text.split(separator: " ").map(String.init)
        for filler in table.wordFillers {
            let parts = filler.split(separator: " ").map(String.init)
            var index = 0
            while index + parts.count <= words.count {
                if Array(words[index..<index + parts.count]) == parts {
                    words.removeSubrange(index..<index + parts.count)
                } else {
                    index += 1
                }
            }
        }
        let clause = cuttingClauses
            ? words.indices.dropFirst().first { table.clauses.contains(words[$0]) }
            : nil
        var starts: Set<Int> = []
        var offset = 0
        var cut = 0
        for (index, word) in words.enumerated() {
            if index == clause { cut = offset }
            starts.insert(offset)
            offset += word.count
        }
        return Reading(words: words, joined: words.joined(), starts: starts, cut: clause == nil ? offset : cut)
    }

    private static func isLatin(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy(\.isASCII)
    }

    /// A title with case, accents, and character width set aside, and anything in brackets left
    /// out, so "Crêpes (Sweet)" and "crepes" read the same.
    private static func folded(_ text: String) -> String {
        var text = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        for (open, close) in [("(", ")"), ("[", "]"), ("【", "】"), ("〔", "〕")] {
            while let start = text.range(of: open),
                  let end = text.range(of: close, range: start.upperBound..<text.endIndex) {
                text.removeSubrange(start.lowerBound..<end.upperBound)
            }
        }
        return text
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
    }
}

/// What was decided about a recipe's signature dish, and for which title. A recipe that is
/// renamed is decided again, and one decided to have none keeps a decision with no id, so it is
/// not asked about again.
public nonisolated struct SignatureDecision: Decodable, Hashable, Sendable {
    public var title: String
    public var id: String?

    public init(title: String, id: String?) {
        self.title = title
        self.id = id
    }

    public var json: JSONValue {
        .object(
            [(key: "title", value: JSONValue.string(title))]
                + (id.map { [(key: "id", value: JSONValue.string($0))] } ?? [])
        )
    }
}
