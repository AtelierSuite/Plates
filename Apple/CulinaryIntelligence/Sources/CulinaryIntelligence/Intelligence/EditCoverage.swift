import Foundation

/// The ingredients and tools a cook's request names, and whether a plan reaches each of them.
/// The plan model carried out part of a request and skipped the rest, and a plan like that was
/// accepted, so what the request names is read in code and the plan is checked against it.
struct EditCoverage {
    enum List: Equatable {
        case ingredients
        case tools
    }

    /// One ingredient or tool the request names. Lines that carry the same catalog icon are one
    /// thing, so "less oil" is met by a change to either oil the recipe lists.
    struct Named: Equatable {
        var list: List
        /// The lines it answers to, counting from 1 as the plan numbers them.
        var lines: [Int]
        /// Every name it goes by, as the recipe lists it and as the catalog writes it in both
        /// languages, so a step that names it is found in whichever language it is written.
        var names: [String]
    }

    let named: [Named]

    /// Reads what a request names. A line is named when the request names it as the recipe
    /// lists it, or by the catalog's name for its icon in English or Japanese. A name the
    /// request only uses as part of a longer name it also matched is not counted, so "sesame
    /// oil" does not name the oil and "鶏ガラスープ" does not name the chicken.
    init(request: String, ingredients: [Ingredient], tools: [Tool]) {
        struct Line {
            var list: List
            var number: Int
            var key: String
            var names: [String]
        }
        func lines(_ list: List, _ entries: [(name: String, icon: String)]) -> [Line] {
            entries.enumerated().map { index, entry in
                let asset = IconCatalog.iconName(for: entry.icon)
                let catalog = asset.map(IconCatalog.names(for:)) ?? []
                let prefix = list == .ingredients ? "I" : "T"
                let key = catalog.isEmpty ? "\(prefix)#\(index)" : "\(prefix):\(asset ?? "")"
                var names: [String] = []
                for name in [entry.name] + catalog where !names.contains(name) { names.append(name) }
                return Line(list: list, number: index + 1, key: key, names: names)
            }
        }
        let all = lines(.ingredients, ingredients.map { ($0.item, $0.icon) })
            + lines(.tools, tools.map { ($0.name, $0.icon) })
        let matches = all.flatMap { line in
            line.names.filter { Self.mentions($0, in: request) }.map { (line: line, name: $0) }
        }
        let kept = matches.filter { match in
            !matches.contains { other in
                other.line.key != match.line.key && Self.name(match.name, isInside: other.name, in: request)
            }
        }
        var named: [Named] = []
        var keys: [String] = []
        for match in kept {
            if let index = keys.firstIndex(of: match.line.key) {
                if !named[index].lines.contains(match.line.number) {
                    named[index].lines.append(match.line.number)
                    named[index].names += match.line.names.filter { !named[index].names.contains($0) }
                }
            } else {
                keys.append(match.line.key)
                named.append(Named(list: match.line.list, lines: [match.line.number], names: match.line.names))
            }
        }
        self.named = named
    }

    /// What the request names that no change in the plan reaches. A change reaches a named
    /// line when it changes or drops that line, when it rewrites, adds, or drops a step that
    /// names it, or when its instruction names it, as a swap does for what goes in.
    func missed(by plan: [PlannedEdit], steps: [Step]) -> [Named] {
        named.filter { named in
            !plan.contains { Self.edit($0, reaches: named, steps: steps) }
        }
    }

    private static func edit(_ edit: PlannedEdit, reaches named: Named, steps: [Step]) -> Bool {
        let lineTargets: [EditTarget] = named.list == .ingredients
            ? [.changeIngredient, .removeIngredient]
            : [.changeTool, .removeTool]
        if lineTargets.contains(edit.target), named.lines.contains(edit.line) { return true }
        let stepTargets: [EditTarget] = [.step, .addStep, .removeStep]
        guard stepTargets.contains(edit.target) || edit.target == lineTargets[0] else { return false }
        var texts = [edit.instruction]
        if edit.target != .addStep, steps.indices.contains(edit.line - 1) {
            let step = steps[edit.line - 1]
            texts.append(([step.title] + step.points).joined(separator: " "))
        }
        return named.names.contains { name in texts.contains { mentions(name, in: $0) } }
    }

    // MARK: - Reading names

    /// Whether some text names an ingredient or tool. A name written without spaces, as
    /// Japanese is, is looked for as written, with katakana read as hiragana so ネギ is ねぎ.
    static func mentions(_ name: String, in text: String) -> Bool {
        guard Step.runsTogether(name) else { return Step.mentions(name, in: text) }
        let name = folded(name)
        return !name.isEmpty && folded(text).contains(name)
    }

    /// Whether a name is only ever named in the text as part of a longer one. In Japanese
    /// every place the shorter name is written has to sit inside the longer, so "油とごま油"
    /// still names the oil. Other names are compared by their words.
    static func name(_ name: String, isInside longer: String, in text: String) -> Bool {
        switch (Step.runsTogether(name), Step.runsTogether(longer)) {
        case (true, true):
            let name = folded(name)
            let longer = folded(longer)
            guard name != longer, longer.contains(name) else { return false }
            let text = folded(text)
            let spans = ranges(of: longer, in: text)
            return ranges(of: name, in: text).allSatisfy { found in
                spans.contains { $0.lowerBound <= found.lowerBound && found.upperBound <= $0.upperBound }
            }
        case (false, false):
            let words = Set(Step.terms(in: name))
            let longerWords = Set(Step.terms(in: longer))
            return !words.isEmpty && words.isStrictSubset(of: longerWords)
        default:
            return false
        }
    }

    private static func folded(_ text: String) -> String {
        let lowered = text.lowercased()
        return lowered.applyingTransform(.hiraganaToKatakana, reverse: true) ?? lowered
    }

    private static func ranges(of name: String, in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var start = text.startIndex
        while let range = text.range(of: name, range: start..<text.endIndex) {
            found.append(range)
            start = text.index(after: range.lowerBound)
        }
        return found
    }
}
