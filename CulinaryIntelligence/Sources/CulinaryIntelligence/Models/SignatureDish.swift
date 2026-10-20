import Foundation

/// A well known dish with an icon drawn for it by hand, shown in place of the dish put together
/// from parts whenever a recipe's title names it. The titles each dish answers to, in English and
/// Japanese, are read from `SignatureDishes.json`.
///
/// A title has to name the dish and nothing else, give or take words like "easy" or "簡単", so
/// "Carbonara" and "簡単カルボナーラ" are drawn as carbonara and "Seafood Carbonara" is not.
public nonisolated enum SignatureDish {
    private struct File: Decodable {
        struct Entry: Decodable {
            let id: String
            let titles: [String]
        }

        let fillers: [String]
        let dishes: [Entry]
    }

    private struct Table {
        /// Fillers made of Latin letters, which are only taken out as whole words.
        let wordFillers: [String]
        /// Fillers in any other script, which are taken out wherever they appear.
        let otherFillers: [String]
        /// Every title as `key(for:)` writes it, to the dish's id.
        let ids: [String: String]
    }

    private static let table: Table = {
        guard let url = Bundle.module.url(forResource: "SignatureDishes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            return Table(wordFillers: [], otherFillers: [], ids: [:])
        }
        let fillers = file.fillers.map(folded).sorted { $0.count > $1.count }
        let isWord = { (filler: String) in filler.unicodeScalars.allSatisfy { $0.isASCII } }
        let unkeyed = Table(wordFillers: fillers.filter(isWord), otherFillers: fillers.filter { !isWord($0) }, ids: [:])
        var ids: [String: String] = [:]
        for dish in file.dishes {
            for title in dish.titles {
                ids[key(for: title, in: unkeyed)] = dish.id
            }
        }
        return Table(wordFillers: unkeyed.wordFillers, otherFillers: unkeyed.otherFillers, ids: ids)
    }()

    /// The id of the dish a recipe's title names, such as `spaghetti-carbonara`.
    public static func id(for recipe: Recipe) -> String? {
        id(forTitle: recipe.title)
    }

    public static func id(forTitle title: String) -> String? {
        let key = key(for: title, in: table)
        guard !key.isEmpty else { return nil }
        return table.ids[key]
    }

    /// The asset a recipe's signature icon is drawn from, such as `DishSignatureSpaghettiCarbonara`.
    public static func assetName(for recipe: Recipe) -> String? {
        id(for: recipe).map(assetName(id:))
    }

    public static func assetName(id: String) -> String {
        "DishSignature" + id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Every dish with a signature icon, by id.
    public static var ids: Set<String> { Set(table.ids.values) }

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

    /// A title with the fillers taken out and nothing but its letters and numbers left.
    private static func key(for title: String, in table: Table) -> String {
        var words = folded(title).split(separator: " ").map(String.init)
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
        var key = words.joined()
        for filler in table.otherFillers {
            key = key.replacingOccurrences(of: filler.replacingOccurrences(of: " ", with: ""), with: "")
        }
        return key
    }
}
