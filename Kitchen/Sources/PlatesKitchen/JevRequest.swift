import Foundation

/// The state and the questions a Jev evaluation is sent for one structured recipe. Both are
/// written by hand in a fixed key order, since `JSONEncoder` gives its keys back in whatever
/// order its storage holds them, and the option order is part of what Jev reads.
enum JevRequest {
    static func state(for run: EvalRun, recipe: EvalRecipe) -> JSONValue {
        let request = EvalCase.all.first { $0.id == run.caseID }?.request(in: run.language) ?? ""
        return .object([
            ("request", .string(request)),
            ("rawText", .string(run.rawText)),
            ("recipe", .object([
                ("title", .string(recipe.title)),
                ("time", .string(recipe.time)),
                ("serves", .string(recipe.serves)),
                ("ingredients", .array(recipe.ingredients.map {
                    .object([("amount", .string($0.amount)), ("item", .string($0.item))])
                })),
                ("tools", .array(recipe.tools.map { .string($0) })),
                ("steps", .array(recipe.steps.map {
                    .object([("title", .string($0.title)), ("points", .array($0.points.map { .string($0) }))])
                })),
                ("troubleshooting", .array(recipe.troubleshooting.map {
                    .object([("problem", .string($0.problem)), ("solution", .string($0.solution))])
                }))
            ]))
        ])
    }

    static func questions(for recipe: EvalRecipe) -> JSONValue {
        var used: Set<String> = []
        var entries: [(String, JSONValue)] = []
        for (index, ingredient) in recipe.ingredients.enumerated() {
            let id = uniqueID(for: ingredient.item, amount: ingredient.amount, fallback: "ingredient-\(index + 1)", used: &used)
            entries.append((id, Template.ingredient.question("Review the ingredient \(id).")))
        }
        entries.append(("ingredients_missing", Template.ingredientsMissing.question("Review the ingredient list for missing ingredients.")))
        for (index, tool) in recipe.tools.enumerated() {
            let id = uniqueID(for: tool, amount: "", fallback: "tool-\(index + 1)", used: &used)
            entries.append((id, Template.tool.question("Review the tool \(id).")))
        }
        entries.append(("tools_missing", Template.toolsMissing.question("Review the tool list for missing tools.")))
        for number in recipe.steps.indices.map({ $0 + 1 }) {
            entries.append(("step_\(number)", Template.step.question("Review step \(number).")))
        }
        return .object(entries)
    }

    /// The name a line is keyed by: the item without its amount, leading figures, anything in
    /// brackets, or anything after the first comma, in kebab case. "1 can (14 oz) crushed
    /// tomatoes, drained" is keyed `crushed-tomatoes`. When the amount is the whole name, as in
    /// "1 celery stalk, chopped" with "1 celery stalk", the name is kept and only its figures go.
    static func id(for item: String, amount: String) -> String {
        let prefix = amount.trimmingCharacters(in: .whitespaces)
        let full = item.trimmingCharacters(in: .whitespaces)
        if !prefix.isEmpty, full.lowercased().hasPrefix(prefix.lowercased()) {
            let rest = full.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            if let first = rest.first, first != ",", first != "、", !slug(rest).isEmpty { return slug(rest) }
        }
        return slug(full)
    }

    private static func slug(_ text: String) -> String {
        let measure = #"a|an|the|one|of|cups?|tsp|tbsp|teaspoons?|tablespoons?|oz|ounces?|lbs?|pounds?|g|kg|ml|l|cans?|slices?|cloves?|stalks?|inch|packages?|pinch|dash"#
        var name = text.replacingOccurrences(of: #"[(（][^)）]*[)）]"#, with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: #"^(?:[\s\d/.,½¼¾⅓⅔-]+|(?:"# + measure + #")\b\s*)+"#, with: "",
                                         options: [.regularExpression, .caseInsensitive])
        if let comma = name.firstIndex(where: { $0 == "," || $0 == "、" }) { name = String(name[..<comma]) }
        var slug = ""
        for scalar in name.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
            } else if !slug.isEmpty, !slug.hasSuffix("-") {
                slug.append("-")
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return slug
    }

    private static func uniqueID(for item: String, amount: String, fallback: String, used: inout Set<String>) -> String {
        let base = id(for: item, amount: amount).isEmpty ? fallback : id(for: item, amount: amount)
        var candidate = base
        var suffix = 2
        while used.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        used.insert(candidate)
        return candidate
    }

    private enum Template {
        case ingredient, ingredientsMissing, tool, toolsMissing, step

        func question(_ instructions: String) -> JSONValue {
            .object([
                ("type", .string("choice")),
                ("instructions", .string(instructions)),
                ("criteria", .object(criteria.map { ($0.0, .string($0.1)) }))
            ])
        }

        private var criteria: [(String, String)] {
            switch self {
            case .ingredient: [
                ("no_problem", "The ingredient is in the original text, a step uses it, its amount matches the text with its unit, and its item names only the ingredient"),
                ("not_in_text", "The ingredient does not appear in the original text"),
                ("unused", "No step uses the ingredient"),
                ("amount_wrong", "The amount gives a different quantity from the original text"),
                ("amount_lost_unit", "The amount has the right figure but lost the unit the original text gives"),
                ("item_repeats_amount", "The item carries the amount or the preparation as well as the ingredient")
            ]
            case .ingredientsMissing: [
                ("no_problem", "Everything the steps call for is on the list, in enough quantity"),
                ("main_ingredient_missing", "A step relies on a main ingredient of the dish that is not on the list"),
                ("minor_ingredient_missing", "A step calls for a minor ingredient, such as a seasoning or a garnish, that is not on the list at all"),
                ("quantity_short", "An ingredient is on the list, but the steps use more of it than the list buys")
            ]
            case .tool: [
                ("no_problem", "The tool is in the original text, and a step names it"),
                ("not_in_text", "The tool does not appear in the original text"),
                ("unused", "The method has no use for the tool"),
                ("not_named", "No step names the tool, though the method needs it without saying so")
            ]
            case .toolsMissing: [
                ("no_problem", "Every tool the steps need is on the list"),
                ("main_vessel_missing", "A step needs a pot, pan, or other main cooking vessel that is not on the list"),
                ("minor_tool_missing", "A step needs a smaller tool, such as a utensil or a piece of prep equipment, that is not on the list")
            ]
            case .step: [
                ("no_problem", "The step agrees with itself, the other steps, and the cook's request, its timing works, its points keep everything it says as complete sentences, and its title is a short heading that fits it"),
                ("contradicts", "The step contradicts itself or another step"),
                ("breaks_dish", "The step ruins the dish where it falls, such as cooking something before it is prepared"),
                ("against_request", "The step goes against what the cook asked for"),
                ("repeats_work", "The step redoes work an earlier step already did"),
                ("waits_too_long", "Something this step finishes waits too long before a later step uses it, and suffers for it"),
                ("cooks_too_long", "Something this step adds cooks too long because of the steps after it"),
                ("instruction_dropped", "The points leave out an instruction the step gives"),
                ("not_an_instruction", "A point is a fragment, or is not something a cook can do"),
                ("detail_dropped", "Every instruction is kept, but a detail the step gives is lost"),
                ("title_is_full_step", "The title is the whole step written out rather than a heading"),
                ("title_misstates_step", "The title is short, but names work the step does not do or leaves out its main action"),
                ("punctuation_missing", "A point does not end in punctuation")
            ]
            }
        }
    }

    /// Writes the state and the questions of every structured run into `directory`, two files
    /// a run, and returns how many runs were written.
    static func export(_ runs: [EvalRun], to directory: URL) throws -> Int {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written = 0
        for run in runs {
            guard let recipe = run.recipe else { continue }
            let name = "\(run.modelID)-\(run.caseID)-\(run.language.rawValue.lowercased())-\(run.repetition)"
            try Data(state(for: run, recipe: recipe).json().utf8)
                .write(to: directory.appendingPathComponent("\(name).state.json"), options: .atomic)
            try Data(questions(for: recipe).json().utf8)
                .write(to: directory.appendingPathComponent("\(name).questions.json"), options: .atomic)
            written += 1
        }
        return written
    }
}

/// JSON with its object keys kept in the order they were given.
indirect enum JSONValue {
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])

    func json(indent: Int = 0) -> String {
        let inner = String(repeating: "  ", count: indent + 1)
        let outer = String(repeating: "  ", count: indent)
        switch self {
        case .string(let value):
            return Self.quoted(value)
        case .array(let values):
            if values.isEmpty { return "[]" }
            return "[\n" + values.map { inner + $0.json(indent: indent + 1) }.joined(separator: ",\n") + "\n\(outer)]"
        case .object(let entries):
            if entries.isEmpty { return "{}" }
            return "{\n" + entries.map { inner + Self.quoted($0.0) + ": " + $0.1.json(indent: indent + 1) }
                .joined(separator: ",\n") + "\n\(outer)}"
        }
    }

    private static func quoted(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}
