import Foundation

/// A recipe as a web page gives it, line for line, before any model has sorted it. The share
/// extension reads it off the page's structured data and leaves it in the inbox, and the app
/// sorts it the way it sorts what Gemma writes.
public struct SharedPage: Codable, Equatable, Sendable {
    public var title: String
    /// The total time as the extension read it, such as "30 min", or empty when the page
    /// gave none.
    public var time: String
    public var serves: String
    public var ingredients: [String]
    /// Each step's text, with the page's own name for it in front when it had one.
    public var steps: [String]
    public var url: String?

    public init(
        title: String,
        time: String,
        serves: String,
        ingredients: [String],
        steps: [String],
        url: String? = nil
    ) {
        self.title = title
        self.time = time
        self.serves = serves
        self.ingredients = ingredients
        self.steps = steps
        self.url = url
    }
}

extension RecipeGenerator {
    /// Whether a shared page can be sorted here. Only Apple Intelligence sorts, so no cloud
    /// is needed.
    public var canSortPages: Bool { passes.isAvailable }

    /// Why a shared page cannot be sorted here, in words a cook can act on, or nil when it can.
    public var pageUnavailableReason: LocalizedStringResource? { passes.unavailableReason }

    /// Sorts a recipe read off a web page into the recipe the app keeps. The page has already
    /// written it, so there is nothing for Gemma to do, and its lines go straight to the same
    /// sorting a written recipe goes through: one line per session, in the reader's language,
    /// with the icons, sections, and measures put right in code. A page lists no tools, so the
    /// ones its method names are read from it in code, and a page with no time has one
    /// estimated from its method.
    public func sortPage(_ page: SharedPage) async -> Recipe? {
        state = .generating
        progress = GenerationProgress()
        progress.readsPage = true
        progress.stage = .shopping
        observer?.runStarted(progress.activity)
        passes.beginBackgroundRun(named: "Recipe import")
        defer { passes.endBackgroundRun() }
        do {
            var written = WrittenRecipe(parsing: "")
            written.title = page.title
            written.time = page.time
            written.serves = page.serves
            written.ingredients = page.ingredients.compactMap(Self.pageLine)
            written.steps = page.steps.compactMap(Self.pageLine)
            let text = ([written.title] + written.ingredients + written.steps).joined(separator: "\n")
            let tools = Self.namedTools(in: written.steps).map { asset in
                GeneratedTool(name: IconCatalog.displayName(for: asset), icon: asset, required: true, note: "")
            }
            let sorted = try await sort(written, text: text, request: GenerationRequest(), found: tools)
            var recipe = Self.makeRecipe(sorted)
            recipe.dish = await Dish.asked(for: recipe)
            progress.isFinished = true
            state = .idle
            observer?.runEnded(progress.activity, succeeded: true)
            return recipe
        } catch {
            state = .failed(error.localizedDescription)
            observer?.runEnded(progress.activity, succeeded: false)
            return nil
        }
    }

    /// A page's line with its spacing tidied, or nil when nothing is left of it.
    private static func pageLine(_ line: String) -> String? {
        let text = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    /// What pages and Gemma call a tool that the catalog names another way.
    private static let toolAliases: [String: String] = [
        "skillet": "pan",
        "frying pan": "pan",
        "fry pan": "pan",
        "nonstick pan": "pan",
        "sheet pan": "baking-sheet",
        "baking tray": "baking-sheet",
        "loaf pan": "loaf-tin",
        "stockpot": "pot",
        "stock pot": "pot",
        "mixing bowl": "bowl",
        "strainer": "sieve",
        "cake pan": "cake-tin",
        "aluminum foil": "foil",
        "aluminium foil": "foil",
        "rubber spatula": "spatula",
        "chef s knife": "knife",
        "pastry cutter": "cookie-cutter",
        "biscuit cutter": "cookie-cutter",
        "ramekin": "bowl",
        "cooling rack": "wire-rack",
    ]

    /// Tools whose English name is mostly read as something else in a method: "fork tender",
    /// "spoon over", "plate up".
    private static let ambiguousTools: Set<String> = ["fork", "spoon", "plate"]

    /// The catalog tools a method names, in the order it first names them. English is read a
    /// word at a time, longest run first, so a loaf pan is a loaf tin and not also a pan. A
    /// method in a language written without spaces is searched for the catalog's names in the
    /// reader's language instead.
    static func namedTools(in steps: [String], limit: Int = 8) -> [String] {
        var phrases = toolAliases
        for asset in IconCatalog.tools where !ambiguousTools.contains(asset) {
            for name in [asset.replacingOccurrences(of: "-", with: " "), IconCatalog.englishName(for: asset)] {
                let key = words(of: name).joined(separator: " ")
                if !key.isEmpty, phrases[key] == nil { phrases[key] = asset }
            }
        }
        let localized = IconCatalog.tools
            .map { (name: IconCatalog.displayName(for: $0), asset: $0) }
            .filter { !$0.name.allSatisfy(\.isASCII) && $0.name.count >= 2 }
            .sorted { $0.name.count > $1.name.count }

        var found: [String] = []
        func add(_ asset: String) {
            if !found.contains(asset) { found.append(asset) }
        }
        for step in steps {
            let stepWords = words(of: step)
            var index = 0
            while index < stepWords.count {
                var matched = 0
                for length in stride(from: min(3, stepWords.count - index), through: 1, by: -1) {
                    let phrase = stepWords[index..<(index + length)].joined(separator: " ")
                    if let asset = phrases[phrase] ?? phrases[singular(phrase)] {
                        add(asset)
                        matched = length
                        break
                    }
                }
                index += max(matched, 1)
            }
            var rest = step
            for entry in localized where rest.contains(entry.name) {
                add(entry.asset)
                rest = rest.replacingOccurrences(of: entry.name, with: " ")
            }
        }
        return Array(found.prefix(limit))
    }

    /// A phrase's words, lowercased, letters only.
    private static func words(of text: String) -> [String] {
        text.lowercased()
            .map { $0.isLetter && $0.isASCII ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .map(String.init)
    }

    /// A phrase with a plural on its last word taken off, so "bowls" finds the bowl.
    private static func singular(_ phrase: String) -> String {
        if phrase.hasSuffix("es"), ["shes", "ches", "xes"].contains(where: phrase.hasSuffix) {
            return String(phrase.dropLast(2))
        }
        if phrase.hasSuffix("s"), !phrase.hasSuffix("ss") { return String(phrase.dropLast()) }
        return phrase
    }
}
