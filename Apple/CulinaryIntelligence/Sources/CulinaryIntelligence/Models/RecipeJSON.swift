import Foundation

/// A recipe written out as JSON by hand. `JSONEncoder` hands its keys back in whatever order
/// its own storage holds them, which loses the key order the schema is read and written in, so
/// a recipe is written here instead: key by key, in the order the properties are declared, and
/// in the shape the site's own files are kept in.
public nonisolated enum JSONValue {
    case string(String)
    case number(Int)
    case bool(Bool)
    case object([(key: String, value: JSONValue)])
    case array([JSONValue])

    /// The value written out, indented two spaces a level the way the recipe files are.
    public func text(indent level: Int = 0) -> String {
        let pad = String(repeating: "  ", count: level)
        let inner = String(repeating: "  ", count: level + 1)
        switch self {
        case let .string(value):
            return "\"\(JSONValue.escaped(value))\""
        case let .number(value):
            return String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case let .object(entries):
            guard !entries.isEmpty else { return "{}" }
            let lines = entries.map { "\(inner)\"\(JSONValue.escaped($0.key))\": \($0.value.text(indent: level + 1))" }
            return "{\n" + lines.joined(separator: ",\n") + "\n\(pad)}"
        case let .array(values):
            guard !values.isEmpty else { return "[]" }
            let lines = values.map { inner + $0.text(indent: level + 1) }
            return "[\n" + lines.joined(separator: ",\n") + "\n\(pad)]"
        }
    }

    /// A string as JSON writes it. Slashes and everything above ASCII are left as they are, so
    /// an icon path reads as a path and Japanese reads as Japanese.
    private static func escaped(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for character in string.unicodeScalars {
            switch character {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
            case let scalar where scalar.value < 0x20:
                result += String(format: "\\u%04x", scalar.value)
            case let scalar: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// An entry written only when it is there, for the keys the schema leaves out rather than
    /// writing empty.
    public static func entry(_ key: String, _ value: String?) -> [(key: String, value: JSONValue)] {
        value.map { [(key, JSONValue.string($0))] } ?? []
    }
}

extension Recipe {
    /// The recipe as a file: the same keys, in the same order, with a newline at the end the
    /// way the site's own files are written.
    public func fileContents() -> Data {
        Data((json.text() + "\n").utf8)
    }

    public var json: JSONValue {
        .object(
            [
                ("id", .string(id)),
                ("title", .string(title)),
                ("time", .string(time)),
                ("serves", .string(serves)),
            ]
                // Written only when the recipe has been cooked, always as `true`.
                + (tried == true ? [(key: "tried", value: JSONValue.bool(true))] : [])
                + (dish.map { [(key: "dish", value: $0.json)] } ?? [])
                + [
                    ("ingredients", ingredients.json),
                    ("tools", .array(tools.map(\.json))),
                    ("steps", .array(steps.map(\.json))),
                    ("troubleshooting", .array(troubleshooting.map(\.json))),
                ]
        )
    }
}

extension IngredientSections {
    /// A section is written only when it holds entries.
    public var json: JSONValue {
        .object(
            [
                ("supermarket", supermarket),
                ("general", general),
                ("optional", optional),
            ].compactMap { key, list in
                guard let list, !list.isEmpty else { return nil }
                return (key, .array(list.map(\.json)))
            }
        )
    }
}

extension Ingredient {
    public var json: JSONValue {
        .object([
            ("item", .string(item)),
            ("icon", .string(icon)),
            ("amount", .string(amount)),
        ] + JSONValue.entry("note", note))
    }
}

extension Tool {
    public var json: JSONValue {
        .object([
            ("name", .string(name)),
            ("icon", .string(icon)),
            ("required", .bool(required)),
        ] + JSONValue.entry("note", note))
    }
}

extension Step {
    public var json: JSONValue {
        .object(
            [("title", JSONValue.string(title))]
                + ((icons?.isEmpty ?? true)
                    ? []
                    : [(key: "icons", value: JSONValue.array((icons ?? []).map(JSONValue.string)))])
                + [("points", .array(points.map(JSONValue.string)))]
        )
    }
}

extension Troubleshooting {
    public var json: JSONValue {
        .object([
            ("problem", .string(problem)),
            ("solution", .string(solution)),
        ])
    }
}
