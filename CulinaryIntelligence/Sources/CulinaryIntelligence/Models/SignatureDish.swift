import Foundation

/// A well known dish with an icon drawn for it by hand, shown in place of the dish put together
/// from parts whenever a recipe's title names it. The titles each dish answers to, in English and
/// Japanese, are read from `SignatureDishes.json`.
///
/// A title names a dish when it ends with one of the dish's titles, since that is where the dish
/// sits in an English or a Japanese title: "Creamy Mushroom Risotto" and "鮭チャーハン" are a
/// risotto and a fried rice. What follows "with" is left out, so "Chicken Pad Thai with Peanuts"
/// is a pad thai. The longest title that fits decides, so "Kimchi Fried Rice" is not plain fried
/// rice, and a dish can rule out words in front of it, so "Korean Pancakes" are not pancakes.
public nonisolated enum SignatureDish {
    private struct File: Decodable {
        struct Entry: Decodable {
            let id: String
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
        /// Whether the phrase starts with a Latin letter or a digit, and so has to start on a word.
        let startsWord: Bool
    }

    private struct Table {
        /// Fillers made of Latin letters, which are only taken out as whole words.
        var wordFillers: [String] = []
        /// Fillers in any other script, which are taken out wherever they appear.
        var otherFillers: [String] = []
        /// Words that start a clause after the dish, such as "with".
        var clauses: Set<String> = []
        var phrases: [Phrase] = []
        /// Words that mean a title is some other dish, by dish id.
        var unless: [String: [String]] = [:]
    }

    /// A title made ready for matching: its words with the fillers taken out, joined with nothing
    /// between them, and the offsets in the joined text where each word starts.
    private struct Reading {
        let words: [String]
        let joined: String
        let starts: Set<Int>
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
                let key = reading(of: title, in: table, cuttingClauses: false).joined
                guard let first = key.unicodeScalars.first else { continue }
                table.phrases.append(Phrase(key: key, id: dish.id, startsWord: first.isASCII))
            }
            if let unless = dish.unless {
                table.unless[dish.id] = unless.map { folded($0).split(separator: " ").joined(separator: " ") }
            }
        }
        table.phrases.sort { $0.key.count > $1.key.count }
        return table
    }()

    /// The id of the dish a recipe's title names, such as `spaghetti-carbonara`.
    public static func id(for recipe: Recipe) -> String? {
        id(forTitle: recipe.title)
    }

    public static func id(forTitle title: String) -> String? {
        let separators = CharacterSet(charactersIn: ":|｜/–—~〜～")
        var best: Phrase?
        for part in title.components(separatedBy: separators) {
            guard let phrase = match(reading(of: part, in: table, cuttingClauses: true)) else { continue }
            if phrase.key.count > best?.key.count ?? 0 {
                best = phrase
            }
        }
        return best?.id
    }

    /// The asset a recipe's signature icon is drawn from, such as `DishSignatureSpaghettiCarbonara`.
    public static func assetName(for recipe: Recipe) -> String? {
        id(for: recipe).map(assetName(id:))
    }

    public static func assetName(id: String) -> String {
        "DishSignature" + id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Every dish with a signature icon, by id.
    public static var ids: Set<String> { Set(table.phrases.map(\.id)) }

    /// The longest phrase the reading ends with, unless the words in front of it rule it out.
    private static func match(_ reading: Reading) -> Phrase? {
        let length = reading.joined.count
        for phrase in table.phrases where reading.joined.hasSuffix(phrase.key) {
            let start = length - phrase.key.count
            if phrase.startsWord && !reading.starts.contains(start) { continue }
            let front = String(reading.joined.prefix(start))
            let frontWords = " " + wordsBefore(start, in: reading).joined(separator: " ") + " "
            let ruledOut = (table.unless[phrase.id] ?? []).contains { word in
                isLatin(word) ? frontWords.contains(" \(word) ") : front.contains(word)
            }
            if !ruledOut { return phrase }
        }
        return nil
    }

    private static func wordsBefore(_ offset: Int, in reading: Reading) -> [String] {
        var count = 0
        var words: [String] = []
        for word in reading.words where count < offset {
            words.append(word)
            count += word.count
        }
        return words
    }

    private static func reading(of title: String, in table: Table, cuttingClauses: Bool) -> Reading {
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
        if cuttingClauses, let cut = words.indices.dropFirst().first(where: { table.clauses.contains(words[$0]) }) {
            words.removeSubrange(cut...)
        }
        var starts: Set<Int> = []
        var offset = 0
        for word in words {
            starts.insert(offset)
            offset += word.count
        }
        return Reading(words: words, joined: words.joined(), starts: starts)
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
