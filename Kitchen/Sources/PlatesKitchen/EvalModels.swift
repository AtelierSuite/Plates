import Foundation

struct Candidate: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let repository: String
    let fileName: String
    let approximateSizeMB: Int
    let notes: String

    static let all: [Candidate] = [
        .init(id: "gemma3-1b", name: "Gemma 3 1B", repository: "google/gemma-3-1b-it-qat-q4_0-gguf", fileName: "gemma-3-1b-it-q4_0.gguf", approximateSizeMB: 1000, notes: "Google license acceptance required"),
        .init(id: "granite4-1b", name: "Granite 4.0 1B", repository: "ibm-granite/granite-4.0-1b-GGUF", fileName: "granite-4.0-1b-Q4_K_M.gguf", approximateSizeMB: 1020, notes: "Apache 2.0"),
        .init(id: "qwen3-17b", name: "Qwen3 1.7B", repository: "ggml-org/Qwen3-1.7B-GGUF", fileName: "Qwen3-1.7B-Q4_K_M.gguf", approximateSizeMB: 1283, notes: "Q4_K_M; Apache 2.0"),
        .init(id: "bonsai-17b", name: "Bonsai 1.7B", repository: "prism-ml/Bonsai-1.7B-gguf", fileName: "Bonsai-1.7B-Q1_0.gguf", approximateSizeMB: 249, notes: "1-bit Qwen3 derivative; Apache 2.0"),
        .init(id: "lfm25-12b", name: "LFM2.5 1.2B Instruct", repository: "LiquidAI/LFM2.5-1.2B-Instruct-GGUF", fileName: "LFM2.5-1.2B-Instruct-Q4_K_M.gguf", approximateSizeMB: 730, notes: "Review LFM license before distribution"),
        .init(id: "lfm25-jp", name: "LFM2.5 1.2B JP", repository: "LiquidAI/LFM2.5-1.2B-JP-GGUF", fileName: "LFM2.5-1.2B-JP-Q4_K_M.gguf", approximateSizeMB: 731, notes: "Japanese specialist; review LFM license")
    ]

    var modelPage: URL { URL(string: "https://huggingface.co/\(repository)/tree/main")! }
    var prefersNonThinkingMode: Bool { id == "qwen3-17b" }
}

enum EvalLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "English"
    case japanese = "Japanese"
    var id: String { rawValue }
}

struct EvalCase: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let englishRequest: String
    let japaneseRequest: String

    static let all: [EvalCase] = [
        .init(id: "egg-fried-rice", title: "Egg fried rice", englishRequest: "Make egg fried rice using one frying pan, without a wok.", japaneseRequest: "中華鍋を使わず、フライパン1つで作る卵チャーハンのレシピを作ってください。"),
        .init(id: "tomato-meat-sauce", title: "Spaghetti with tomato meat sauce", englishRequest: "Make spaghetti with tomato meat sauce. Include celery for texture.", japaneseRequest: "食感を残すためにセロリを入れた、トマトミートソースのスパゲッティのレシピを作ってください。"),
        .init(id: "grilled-cheese", title: "Simple grilled cheese", englishRequest: "Make a simple grilled cheese sandwich.", japaneseRequest: "シンプルなグリルドチーズサンドイッチのレシピを作ってください。")
    ]

    func request(in language: EvalLanguage) -> String {
        language == .english ? englishRequest : japaneseRequest
    }
}

struct EvalRecipe: Codable, Sendable {
    struct Ingredient: Codable, Sendable { let item: String; let amount: String }
    struct Step: Codable, Sendable { let title: String; let points: [String] }
    struct Trouble: Codable, Sendable { let problem: String; let solution: String }
    let title: String
    let time: String
    let serves: String
    let ingredients: [Ingredient]
    let tools: [String]
    let steps: [Step]
    let troubleshooting: [Trouble]
}

struct Review: Codable, Sendable {
    var reviewed = false
    var feasible = false
    var constraintsMet = false
    var ingredientUse = false
    var clearSteps = false
    var languageQuality = false
    var criticalFailure = false
    var notes = ""

    var passes: Bool {
        reviewed && feasible && constraintsMet && ingredientUse && clearSteps && languageQuality && !criticalFailure
    }
}

struct EvalRun: Identifiable, Codable, Sendable {
    let id: UUID
    let modelID: String
    let modelFile: String
    let caseID: String
    let language: EvalLanguage
    let repetition: Int
    let startedAt: Date
    let durationSeconds: Double
    let rawText: String
    let recipe: EvalRecipe?
    let checks: [String]
    let error: String?
    let structuringError: String?
    let structureDurationSeconds: Double?
    let structuredByApple: Bool?
    var review: Review
}

enum RecipeChecks {
    static func evaluate(_ recipe: EvalRecipe, caseID: String) -> [String] {
        var issues: [String] = []
        if recipe.title.isEmpty || recipe.ingredients.isEmpty || recipe.steps.isEmpty { issues.append("Missing title, ingredients, or steps") }
        if recipe.ingredients.contains(where: { $0.item.isEmpty || $0.amount.isEmpty }) { issues.append("Ingredient missing name or amount") }
        if recipe.steps.contains(where: { $0.title.isEmpty || $0.points.isEmpty }) { issues.append("Step missing title or points") }
        let titles = recipe.steps.map { $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        if Set(titles).count != titles.count { issues.append("Repeated step title") }
        let ingredients = recipe.ingredients.map(\.item).joined(separator: " ").lowercased()
        let method = recipe.steps.flatMap(\.points).joined(separator: " ").lowercased()
        let tools = recipe.tools.joined(separator: " ").lowercased()
        if caseID == "egg-fried-rice" {
            if !ingredients.contains("egg") && !ingredients.contains("卵") { issues.append("Egg absent from ingredients") }
            if !ingredients.contains("rice") && !ingredients.contains("ご飯") && !ingredients.contains("米") { issues.append("Rice absent from ingredients") }
            if !method.contains("egg") && !method.contains("卵") { issues.append("Egg absent from method") }
            if !method.contains("rice") && !method.contains("ご飯") && !method.contains("米") { issues.append("Rice absent from method") }
            if tools.contains("wok") || tools.contains("中華鍋") || method.contains("wok") || method.contains("中華鍋") { issues.append("Wok mentioned") }
        }
        if caseID == "tomato-meat-sauce" {
            if !ingredients.contains("celery") && !ingredients.contains("セロリ") { issues.append("Celery absent from ingredients") }
            if !method.contains("celery") && !method.contains("セロリ") { issues.append("Celery absent from method") }
        }
        if caseID == "grilled-cheese" {
            if !ingredients.contains("bread") && !ingredients.contains("パン") { issues.append("Bread absent from ingredients") }
            if !ingredients.contains("cheese") && !ingredients.contains("チーズ") { issues.append("Cheese absent from ingredients") }
            if recipe.steps.count < 2 { issues.append("Method has fewer than two steps") }
            if recipe.ingredients.count > 6 { issues.append("More than six ingredients for simple grilled cheese") }
        }
        return issues
    }
}
