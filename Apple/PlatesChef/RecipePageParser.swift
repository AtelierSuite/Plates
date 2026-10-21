import Foundation

nonisolated enum RecipePageParser {
    static func onePanRecipe(_ data: Data) -> ChefRecipe? {
        try? JSONDecoder().decode(ChefRecipe.self, from: data)
    }

    static func structuredRecipe(in html: String) -> ChefRecipe? {
        let pattern = #"<script\b[^>]*type\s*=\s*["']application/ld\+json[^"']*["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        let scripts = regex.matches(in: html, range: range).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[range])
        }
        return structuredRecipe(in: scripts)
    }

    static func structuredRecipe(in scripts: [String]) -> ChefRecipe? {
        for script in scripts {
            guard let root = jsonObject(script) else { continue }
            for object in recipeObjects(in: root) {
                if let recipe = makeRecipe(from: object) { return recipe }
            }
        }
        return nil
    }

    // Some pages break lines inside their JSON-LD strings, which JSON does not allow,
    // so a script that does not parse is read again with its control characters as spaces.
    private static func jsonObject(_ script: String) -> Any? {
        if let data = script.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: data) {
            return root
        }
        let cleaned = String(String.UnicodeScalarView(script.unicodeScalars.map {
            $0.value < 0x20 ? " " : $0
        }))
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func recipeObjects(in value: Any) -> [[String: Any]] {
        if let array = value as? [Any] {
            return array.flatMap(recipeObjects)
        }
        guard let object = value as? [String: Any] else { return [] }
        let types = [object["@type"]].compactMap { $0 }.flatMap { value -> [String] in
            if let text = value as? String { return [text] }
            return value as? [String] ?? []
        }
        if types.contains(where: { $0.split(separator: "/").last?.lowercased() == "recipe" }) {
            return [object]
        }
        return [object["@graph"], object["mainEntity"]]
            .compactMap { $0 }
            .flatMap(recipeObjects)
    }

    private static func makeRecipe(from object: [String: Any]) -> ChefRecipe? {
        guard let title = object["name"] as? String, !title.isEmpty else { return nil }
        let lines = (object["recipeIngredient"] as? [String] ?? [])
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let ingredients = lines.map(ingredient)
        let instructions = instructionLines(object["recipeInstructions"])
        guard !ingredients.isEmpty, !instructions.isEmpty else { return nil }
        var titles = Set<String>()
        let steps = instructions.enumerated().map { index, line in
            var title = line.name.isEmpty ? String(line.text.prefix(80)) : line.name
            if !titles.insert(title.lowercased()).inserted {
                title += " (\(index + 1))"
                titles.insert(title.lowercased())
            }
            return ChefRecipe.Step(title: title, points: [line.text])
        }
        let time: String
        if let total = durationMinutes(object["totalTime"] as? String) {
            time = "\(total) min"
        } else {
            let prep = durationMinutes(object["prepTime"] as? String)
            let cook = durationMinutes(object["cookTime"] as? String)
            time = prep == nil && cook == nil ? "" : "\((prep ?? 0) + (cook ?? 0)) min"
        }
        let serves = yieldText(object["recipeYield"])
        return ChefRecipe(
            id: ChefRecipe.makeID(from: title),
            title: title,
            time: time,
            serves: serves,
            tried: nil,
            ingredients: .init(supermarket: ingredients),
            tools: [],
            steps: steps,
            troubleshooting: [],
            page: .init(
                title: title,
                time: time,
                serves: serves,
                ingredients: lines,
                steps: instructions.map(pageStep)
            )
        )
    }

    /// A step as the app is handed it: the page's name for it in front of its text, when the
    /// name says something the text does not.
    private static func pageStep(_ line: (name: String, text: String)) -> String {
        let name = line.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !line.text.hasPrefix(name.trimmingCharacters(in: .punctuationCharacters)) else {
            return line.text
        }
        return "\(name): \(line.text)"
    }

    private static func instructionLines(_ value: Any?) -> [(name: String, text: String)] {
        guard let value else { return [] }
        if let text = value as? String { return [("", text)] }
        if let array = value as? [Any] { return array.flatMap(instructionLines) }
        guard let object = value as? [String: Any] else { return [] }
        if let children = object["itemListElement"] { return instructionLines(children) }
        guard let text = object["text"] as? String, !text.isEmpty else { return [] }
        return [(object["name"] as? String ?? "", text)]
    }

    private static func yieldText(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        if let array = value as? [String] { return array.first ?? "" }
        return ""
    }

    private static func ingredient(_ line: String) -> ChefRecipe.Ingredient {
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first, first.first?.isNumber == true ||
                "¼½¾⅓⅔⅛".contains(first.first ?? " ") else {
            return .init(item: line, icon: "", amount: "")
        }
        var end = 1
        if words.count > end, words[end].first?.isNumber == true { end += 1 }
        if words.count > end, ["to", "-", "–"].contains(words[end].lowercased()),
           words.count > end + 1, words[end + 1].first?.isNumber == true {
            end += 2
        }
        let units: Set<String> = [
            "cup", "cups", "tsp", "teaspoon", "teaspoons", "tbsp", "tablespoon", "tablespoons",
            "g", "kg", "ml", "l", "oz", "lb", "lbs", "pound", "pounds", "clove", "cloves",
            "slice", "slices", "pinch", "pinches", "can", "cans",
        ]
        if words.count > end, units.contains(words[end].lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            end += 1
        }
        guard words.count > end else { return .init(item: line, icon: "", amount: "") }
        return .init(
            item: words[end...].joined(separator: " "),
            icon: "",
            amount: words[..<end].joined(separator: " ")
        )
    }

    private static func durationMinutes(_ value: String?) -> Int? {
        let number = #"(\d+(?:[.,]\d+)?)"#
        guard let value = value?.trimmingCharacters(in: .whitespaces),
              let regex = try? NSRegularExpression(
                pattern: "^P(?:\(number)D)?(?:T(?:\(number)H)?(?:\(number)M)?(?:\(number)S)?)?$",
                options: [.caseInsensitive]
              ),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value))
        else { return nil }
        func count(_ index: Int) -> Double {
            guard let range = Range(match.range(at: index), in: value) else { return 0 }
            return Double(value[range].replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        let minutes = Int((count(1) * 1440 + count(2) * 60 + count(3) + count(4) / 60).rounded(.up))
        return minutes > 0 ? minutes : nil
    }
}
