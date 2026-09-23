import Foundation
import FoundationModels

@Generable(description: "A visual scene assembled from existing cookbook symbols")
struct GeneratedScenePlan {
    @Guide(description: "Most important visible food or tool", .anyOf(ScenePlan.symbols))
    var primary: String

    @Guide(description: "Second visible food or tool, or none", .anyOf(ScenePlan.optionalSymbols))
    var secondary: String

    @Guide(description: "Third visible food or tool, or none", .anyOf(ScenePlan.optionalSymbols))
    var accent: String

    @Guide(description: "The cooking vessel or work surface, or none", .anyOf(ScenePlan.settings))
    var setting: String

    @Guide(description: "What the drawing shows happening", .anyOf(ScenePlan.actions))
    var action: String
}

struct ScenePlan: Codable {
    static let symbols = ["Egg", "Rice", "SpringOnion", "Tomato", "Celery", "Beef", "Bread", "Cheese", "Butter", "Onion", "Oil", "Spaghetti", "Pan", "Bowl", "Pot", "Spatula", "Knife", "CuttingBoard"]
    static let optionalSymbols = ["none"] + symbols
    static let settings = ["none", "Pan", "Bowl", "Pot", "CuttingBoard"]
    static let actions = ["chop", "mix", "heat", "assemble", "serve"]

    let primary: String
    let secondary: String
    let accent: String
    let setting: String
    let action: String

    var visibleSymbols: Set<String> { Set([primary, secondary, accent, setting]).subtracting(["none"]) }
}

@MainActor
struct AppleScenePlanner {
    var isAvailable: Bool { SystemLanguageModel.default.availability == .available }

    func plan(for asset: SVGSampleAsset) async throws -> ScenePlan {
        let session = LanguageModelSession(instructions: """
            Select existing cookbook symbols for a small drawing. Choose only objects that should be visible in the requested scene. Use the setting field for a pan, pot, bowl, or cutting board when one is visible. Do not invent or rename symbols. Do not write SVG.
            """)
        let answer = try await session.respond(to: """
            Recipe: \(asset.recipeTitle)
            Drawing: \(asset.subject)
            Context: \(asset.context)
            Choose the visible symbols and the action. The drawing is \(asset.kind == .icon ? "a finished recipe icon" : "one cooking step").
            """, generating: GeneratedScenePlan.self).content
        return ScenePlan(primary: answer.primary, secondary: answer.secondary,
                         accent: answer.accent, setting: answer.setting, action: answer.action)
    }
}

enum SceneChecks {
    static func evaluate(_ plan: ScenePlan, for asset: SVGSampleAsset) -> [String] {
        var issues = asset.expectedSymbols.filter { !plan.visibleSymbols.contains($0) }
            .map { "Missing scene symbol: \($0)" }
        if asset.kind == .step && plan.action != asset.expectedAction {
            issues.append("Expected action \(asset.expectedAction), got \(plan.action)")
        }
        return issues
    }
}

enum SceneSVGRenderer {
    static func render(_ plan: ScenePlan, for asset: SVGSampleAsset) throws -> String {
        let size = asset.size
        var parts = [
            "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(size.width) \(size.height)\">",
            "<rect x=\"0\" y=\"0\" width=\"\(size.width)\" height=\"\(size.height)\" fill=\"#fffaf2\"/>"
        ]
        if asset.kind == .icon {
            parts.append("<ellipse cx=\"64\" cy=\"99\" rx=\"45\" ry=\"13\" fill=\"#e7ddd0\"/>")
            try append(plan.setting, to: &parts, x: 34, y: 52, scale: 1.25)
            try append(plan.primary, to: &parts, x: 13, y: 20, scale: 1.3)
            try append(plan.secondary, to: &parts, x: 66, y: 20, scale: 1.05)
            try append(plan.accent, to: &parts, x: 76, y: 71, scale: 0.7)
        } else {
            parts.append("<line x1=\"10\" y1=\"130\" x2=\"190\" y2=\"130\" stroke=\"#c8b9a6\" stroke-width=\"3\"/>")
            try append(plan.setting, to: &parts, x: 16, y: 54, scale: 1.4)
            try append(plan.primary, to: &parts, x: 76, y: 48, scale: 1.4)
            try append(plan.secondary, to: &parts, x: 129, y: 67, scale: 1.0)
            try append(plan.accent, to: &parts, x: 150, y: 25, scale: 0.75)
            parts.append(actionMark(plan.action))
        }
        parts.append("</svg>")
        return parts.joined(separator: "\n")
    }

    private static func append(_ name: String, to parts: inout [String], x: Int, y: Int, scale: Double) throws {
        guard name != "none" else { return }
        guard ScenePlan.symbols.contains(name),
              let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Samples/Symbols") else {
            throw SceneRenderError.missingSymbol(name)
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        guard let start = source.firstIndex(of: ">"), let end = source.range(of: "</svg>", options: .backwards)?.lowerBound else {
            throw SceneRenderError.missingSymbol(name)
        }
        parts.append("<g transform=\"translate(\(x) \(y)) scale(\(scale))\">\(source[source.index(after: start)..<end])</g>")
    }

    private static func actionMark(_ action: String) -> String {
        switch action {
        case "chop": "<path d=\"M111 22l18 23m-7-30l18 23\" fill=\"none\" stroke=\"#6f747b\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
        case "mix": "<path d=\"M92 116q16 15 38 0\" fill=\"none\" stroke=\"#a97142\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
        case "heat": "<path d=\"M45 55q-7-9 0-19m13 19q-7-9 0-19\" fill=\"none\" stroke=\"#de8060\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
        case "assemble": "<path d=\"M112 19v24m-6-6l6 7 6-7\" fill=\"none\" stroke=\"#a97142\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
        default: "<circle cx=\"176\" cy=\"29\" r=\"4\" fill=\"#f1c21b\"/>"
        }
    }
}

private enum SceneRenderError: LocalizedError {
    case missingSymbol(String)
    var errorDescription: String? {
        switch self { case .missingSymbol(let symbol): "Missing scene symbol: \(symbol)" }
    }
}
