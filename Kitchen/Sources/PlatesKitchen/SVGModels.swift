import Foundation
import AppKit

struct SVGSampleRecipe: Codable, Identifiable {
    struct Step: Codable {
        let title: String
        let action: String
        let visual: String
        let expectedSymbols: [String]
        let actionType: String
    }

    let id: String
    let title: String
    let ingredients: [String]
    let tools: [String]
    let iconSubject: String
    let iconExpectedSymbols: [String]
    let iconAction: String
    let steps: [Step]

    static func load() throws -> [Self] {
        let url = Bundle.module.url(forResource: "svg-recipes", withExtension: "json", subdirectory: "Samples")!
        return try JSONDecoder().decode([Self].self, from: Data(contentsOf: url))
    }

    var assets: [SVGSampleAsset] {
        [.init(id: "\(id)-icon", recipeID: id, recipeTitle: title, kind: .icon,
               stepIndex: nil, subject: iconSubject, context: ingredients.joined(separator: ", "),
               expectedSymbols: iconExpectedSymbols, expectedAction: iconAction)]
        + steps.enumerated().map { index, step in
            .init(id: "\(id)-step-\(index + 1)", recipeID: id, recipeTitle: title,
                  kind: .step, stepIndex: index, subject: step.visual,
                  context: "Step \(index + 1) of \(steps.count): \(step.title). \(step.action). Ingredients: \(ingredients.joined(separator: ", ")). Tools: \(tools.joined(separator: ", ")).",
                  expectedSymbols: step.expectedSymbols, expectedAction: step.actionType)
        }
    }
}

struct SVGSampleAsset: Identifiable {
    enum Kind: String, Codable { case icon, step }
    let id: String
    let recipeID: String
    let recipeTitle: String
    let kind: Kind
    let stepIndex: Int?
    let subject: String
    let context: String
    let expectedSymbols: [String]
    let expectedAction: String

    var size: (width: Int, height: Int) { kind == .icon ? (128, 128) : (200, 150) }
}

struct SVGReview: Codable {
    var reviewed = false
    var subjectMatches = false
    var actionMatches = false
    var readableAtSmallSize = false
    var consistentStyle = false
    var notes = ""

    var passes: Bool { reviewed && subjectMatches && actionMatches && readableAtSmallSize && consistentStyle }
}

struct SVGRun: Identifiable, Codable {
    let id: UUID
    let modelID: String
    let assetID: String
    let recipeID: String
    let kind: SVGSampleAsset.Kind
    let repetition: Int
    let startedAt: Date
    let durationSeconds: Double
    let rawText: String
    let svg: String?
    let formatWarning: String?
    let checks: [String]
    let error: String?
    var review: SVGReview
}

enum SVGChecks {
    static func extract(_ raw: String) -> (svg: String, warning: String?) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```"), text.hasSuffix("```") else { return (text, nil) }
        guard let newline = text.firstIndex(of: "\n") else { return (text, nil) }
        let language = text[text.index(text.startIndex, offsetBy: 3)..<newline]
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["", "svg", "xml"].contains(language) else { return (text, nil) }
        let body = text[text.index(after: newline)..<text.index(text.endIndex, offsetBy: -3)]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, "Markdown code fence removed")
    }

    static func evaluate(_ text: String, asset: SVGSampleAsset) -> [String] {
        var checks: [String] = []
        let data = Data(text.utf8)
        if data.count > 24_000 { checks.append("SVG exceeds 24 KB") }
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<svg") else {
            return checks + ["Output does not begin with an SVG element"]
        }
        if text.localizedCaseInsensitiveContains("<!doctype") || text.localizedCaseInsensitiveContains("<!entity") {
            checks.append("DTD or entity declaration is forbidden")
        }
        let checker = SVGParser(expected: asset.size)
        let parser = XMLParser(data: data)
        parser.delegate = checker
        parser.shouldResolveExternalEntities = false
        if !parser.parse() { checks.append("SVG is not well formed XML") }
        checks += checker.issues
        if checker.elementCount > 120 { checks.append("SVG has more than 120 elements") }
        if checker.shapeCount == 0 { checks.append("SVG has no visible shapes") }
        if !checker.sawRoot { checks.append("Missing SVG root") }
        if checks.isEmpty && NSImage(data: data)?.tiffRepresentation == nil {
            checks.append("SVG could not be rendered")
        }
        return Array(Set(checks)).sorted()
    }
}

private final class SVGParser: NSObject, XMLParserDelegate {
    private static let elements: Set<String> = ["svg", "g", "rect", "circle", "ellipse", "path", "line", "polyline", "polygon"]
    private static let attributes: Set<String> = [
        "xmlns", "viewBox", "width", "height", "fill", "stroke", "stroke-width",
        "stroke-linecap", "stroke-linejoin", "opacity", "fill-opacity", "stroke-opacity",
        "cx", "cy", "r", "rx", "ry", "x", "y", "x1", "y1", "x2", "y2",
        "d", "points", "transform", "role", "aria-label"
    ]
    private let expected: (width: Int, height: Int)
    var issues: [String] = []
    var elementCount = 0
    var shapeCount = 0
    var sawRoot = false

    init(expected: (width: Int, height: Int)) { self.expected = expected }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        elementCount += 1
        if elementCount == 1 {
            sawRoot = name == "svg"
            if attributes["xmlns"] != "http://www.w3.org/2000/svg" { issues.append("Missing SVG namespace") }
            if attributes["viewBox"] != "0 0 \(expected.width) \(expected.height)" { issues.append("Unexpected viewBox") }
        }
        if !Self.elements.contains(name) { issues.append("Forbidden element: \(name)") }
        if Self.elements.contains(name) && name != "svg" && name != "g" { shapeCount += 1 }
        for (key, value) in attributes {
            if !Self.attributes.contains(key) { issues.append("Forbidden attribute: \(key)") }
            if (key == "fill" || key == "stroke") && !Self.isLiteralColor(value) {
                issues.append("Invalid literal color")
            }
            let lower = value.lowercased()
            if lower.contains("url(") || lower.contains("javascript:") || lower.contains("data:") || lower.contains("http:") || lower.contains("https:") {
                if !(key == "xmlns" && value == "http://www.w3.org/2000/svg") {
                    issues.append("External or embedded reference")
                }
            }
        }
    }

    private static func isLiteralColor(_ value: String) -> Bool {
        if value == "none" { return true }
        guard value.first == "#", value.count == 4 || value.count == 7 else { return false }
        return value.dropFirst().allSatisfy(\.isHexDigit)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Text content is forbidden") }
    }
}
