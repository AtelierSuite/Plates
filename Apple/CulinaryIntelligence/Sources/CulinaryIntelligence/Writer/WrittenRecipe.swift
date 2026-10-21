import Foundation

/// A recipe as Gemma wrote it, cut into its sections by reading the text, before any model
/// sorts it. Gemma writes in a regular cookbook shape, headed sections of bulleted or numbered
/// lines, so the lines can be counted here. The sorting passes are then asked for exactly that
/// many ingredients, steps, and fixes, which keeps them from dropping a line or making one up.
nonisolated struct WrittenRecipe: Equatable {
    var title = ""
    var time = ""
    var serves = ""
    var ingredients: [String] = []
    var tools: [String] = []
    var steps: [String] = []
    /// Each problem with its fix, as one entry.
    var problems: [String] = []

    private enum Section {
        case none, ingredients, tools, method, problems

        /// The section the prompt asks for after this one.
        var next: Section? {
            switch self {
            case .none: .ingredients
            case .ingredients: .tools
            case .tools: .method
            case .method: .problems
            case .problems: nil
            }
        }
    }

    /// A line of the problems, kept until the end, when it is known whether they were written
    /// as blocks.
    private struct ProblemLine {
        var text: String
        var startsItem: Bool
        var startsBlock: Bool
    }

    init(parsing text: String) {
        var section = Section.none
        // Gemma leaves a heading out now and then, or writes no headings at all. A section with
        // no heading is worked out from where it falls: the prompt asks for the sections in
        // order, each its own block, so a new block after one is the section after it.
        var isInferred = false
        var startsBlock = true
        var problemLines: [ProblemLine] = []
        let lines = text.components(separatedBy: .newlines)
        for (index, raw) in lines.enumerated() {
            let line = Self.plain(raw)
            guard !line.isEmpty else {
                startsBlock = true
                continue
            }
            defer { startsBlock = false }
            let endsBlock = index + 1 == lines.count || Self.plain(lines[index + 1]).isEmpty

            if let (heading, rest) = Self.heading(in: line) {
                switch heading {
                case .title:
                    if title.isEmpty { title = rest }
                    continue
                case let .time(isTotal):
                    // A prep time and a cooking time can both be given. The total is the one
                    // the recipe carries.
                    if time.isEmpty || isTotal { time = rest }
                    continue
                case .serves:
                    if serves.isEmpty { serves = rest }
                    continue
                case let .section(next):
                    section = next
                    isInferred = false
                    if section == .problems, !rest.isEmpty {
                        problemLines.append(ProblemLine(text: rest, startsItem: true, startsBlock: startsBlock))
                    } else if section == .tools {
                        // "Tools: 1 small bowl, 1 wok" lists them on the heading's line. A tool
                        // line has no prep to set off with a comma, as an ingredient's has.
                        for tool in rest.split(separator: ",") {
                            let name = tool.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty { append(name, to: section, startsItem: true) }
                        }
                    } else if !rest.isEmpty {
                        append(rest, to: section, startsItem: true)
                    }
                    continue
                }
            }

            // "Makes 4 servings" and "Serves 4" say how many it feeds without a colon, and
            // "45 minutes" how long it takes. They come before the lists, so a line inside one
            // is never read this way. "12 cookies" says it too, when it stands on its own
            // rather than opening the ingredients.
            if section == .none, serves.isEmpty,
               Self.isServingLine(line) || (startsBlock && endsBlock && Self.isYieldLine(line)) {
                serves = line
                continue
            }
            if section == .none, time.isEmpty, Self.isTimeLine(line) {
                time = line
                continue
            }

            let indented = raw.first?.isWhitespace ?? false
            let (text, marked) = Self.item(in: line)
            var item = text
            // A step numbered "1 Crack the eggs", with no stop after the figure. Only in the
            // method, where a line never opens with an amount.
            let bareNumber = item.firstMatch(of: #/^\d+\s+(?=\p{Lu})/#)
            // A heading of its own inside a section, such as "For the sauce:", groups lines
            // rather than being one.
            let isGroup = !marked && item.hasSuffix(":")
            if section == .none {
                if title.isEmpty {
                    title = item
                    continue
                }
                // A sentence about the dish before the lists is not one of them.
                guard item.split(separator: " ").count <= 12 else { continue }
                section = .ingredients
                isInferred = true
            } else if isInferred, startsBlock, !isGroup, let next = section.next,
                      !(section == .method && (marked || bareNumber != nil)) {
                section = next
            } else if startsBlock, line.firstMatch(of: #/^\d+[.)]\s/#) != nil,
                      (section == .ingredients && !ingredients.isEmpty) || (section == .tools && !tools.isEmpty) {
                // Numbered steps after the lists are the method, heading or not.
                section = .method
                isInferred = true
            }
            if isGroup { continue }
            if section == .method, !marked, let bareNumber {
                item.removeSubrange(bareNumber.range)
            }
            if section == .problems {
                let lowered = item.lowercased()
                let isFix = lowered.hasPrefix("fix") || lowered.hasPrefix("solution")
                let isProblem = lowered.hasPrefix("problem") || lowered.hasPrefix("issue")
                problemLines.append(ProblemLine(
                    text: item,
                    startsItem: !isFix && (isProblem || marked || !indented),
                    startsBlock: startsBlock && !isFix
                ))
            } else {
                append(item, to: section, startsItem: marked || !indented)
            }
        }
        problems = Self.grouped(problemLines)
    }

    /// The problems as entries, each a problem with its fix. When they are written as blocks,
    /// a problem on one line and its fix on the next, a block is one entry. Otherwise each line
    /// that opens an entry is one.
    private static func grouped(_ lines: [ProblemLine]) -> [String] {
        let inBlocks = lines.dropFirst().contains(where: \.startsBlock)
        var entries: [String] = []
        for line in lines {
            let starts = inBlocks ? line.startsBlock : line.startsItem
            if starts || entries.isEmpty {
                entries.append(line.text)
            } else {
                entries[entries.count - 1] += " " + line.text
            }
        }
        return entries
    }

    private mutating func append(_ text: String, to section: Section, startsItem: Bool) {
        func add(_ list: inout [String]) {
            if startsItem || list.isEmpty {
                list.append(text)
            } else {
                list[list.count - 1] += " " + text
            }
        }
        switch section {
        case .ingredients: add(&ingredients)
        case .tools:
            // "1 large pot, 1 cutting board, 1 chef knife" is a list on one line when each
            // piece is counted.
            let pieces = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if startsItem, pieces.count > 1, pieces.allSatisfy({ $0.first?.isNumber == true }) {
                tools += pieces
            } else {
                add(&tools)
            }
        case .method: add(&steps)
        case .problems: add(&problems)
        case .none: break
        }
    }

    // MARK: - Reading a line

    private enum Heading {
        case title, serves
        case time(isTotal: Bool)
        case section(Section)
    }

    /// The line with Markdown emphasis and heading marks taken off.
    private static func plain(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        while text.hasPrefix("#") { text.removeFirst() }
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// A line such as "Ingredients:" or "Total Time: 20 minutes", with whatever follows the
    /// colon. Only a short label counts, so a sentence with a colon in it is left alone.
    private static func heading(in line: String) -> (Heading, String)? {
        guard let colon = line.firstIndex(of: ":") else { return bareHeading(in: line) }
        let label = line[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
        let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, label.split(separator: " ").count <= 5,
              !label.first!.isNumber, !"-*•".contains(label.first!)
        else { return nil }
        let heading: Heading
        if label == "title" || label == "recipe" {
            heading = .title
        } else if label.contains("time") {
            heading = .time(isTotal: label.contains("total"))
        } else if label.hasPrefix("serv") || label.hasPrefix("yield") {
            heading = .serves
        } else if label.contains("ingredient") {
            heading = .section(.ingredients)
        } else if label.contains("tool") || label.contains("equipment") || label.contains("utensil") {
            heading = .section(.tools)
        } else if ["method", "instruction", "direction", "step", "preparation"].contains(where: label.contains) {
            heading = .section(.method)
        } else if ["problem", "troubleshoot", "fixes", "mistake"].contains(where: label.contains) {
            heading = .section(.problems)
        } else {
            return nil
        }
        return (heading, rest)
    }

    /// A section heading written without a colon, such as "Tools" or "Common Problems". Only a
    /// line of a few words, with no figures, that has a section's word in it counts, so no
    /// ingredient or tool is taken for one.
    private static func bareHeading(in line: String) -> (Heading, String)? {
        let words = line.lowercased().split(separator: " ")
        guard (1...4).contains(words.count), !line.contains(where: \.isNumber) else { return nil }
        let sections: [(Section, [String])] = [
            (.ingredients, ["ingredient"]),
            (.tools, ["tool", "equipment", "utensil"]),
            (.method, ["method", "instruction", "direction", "step"]),
            (.problems, ["problem", "troubleshoot", "fixes", "mistake"]),
        ]
        for (section, stems) in sections where words.contains(where: { word in stems.contains { word.hasPrefix($0) } }) {
            return (.section(section), "")
        }
        return nil
    }

    /// A short line that says how long the recipe takes, such as "45 minutes".
    private static func isTimeLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered.split(separator: " ").count <= 6
            && lowered.contains(where: \.isNumber)
            && (lowered.contains("min") || lowered.contains("hour"))
    }

    /// A figure and what it makes, such as "12 cookies" or "1 loaf".
    private static func isYieldLine(_ line: String) -> Bool {
        let words = line.split(separator: " ")
        return words.count <= 3 && words.first?.allSatisfy(\.isNumber) == true && !isTimeLine(line)
    }

    /// A short line that says how many the recipe feeds.
    private static func isServingLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered.split(separator: " ").count <= 6
            && lowered.contains(where: \.isNumber)
            && (lowered.hasPrefix("serves") || lowered.hasPrefix("makes") || lowered.contains("serving"))
    }

    /// A line with its bullet or number taken off, and whether it had one. A marked line opens
    /// an entry of its own, and so does a plain line that is not indented under the one before.
    private static func item(in line: String) -> (String, Bool) {
        var text = line
        var marked = false
        if let first = text.first, "-*•".contains(first) {
            text.removeFirst()
            marked = true
        } else if let match = text.firstMatch(of: #/^\d+[.)]\s+/#) {
            text.removeSubrange(match.range)
            marked = true
        }
        return (text.trimmingCharacters(in: .whitespaces), marked)
    }
}
