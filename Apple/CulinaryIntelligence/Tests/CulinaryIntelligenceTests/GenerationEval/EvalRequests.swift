@testable import CulinaryIntelligence

/// One request in the generation eval, as a cook would type it into Plates.
struct EvalRequest: Sendable {
    enum Language: String, Codable, Sendable {
        case english = "en-US"
        case japanese = "ja"
    }

    let id: String
    let language: Language
    let description: String
    let ingredients: [String]
    let tools: [String]

    var hasPicks: Bool { !ingredients.isEmpty || !tools.isEmpty }

    var request: GenerationRequest {
        GenerationRequest(description: description, ingredients: ingredients, tools: tools)
    }
}

/// The fixed set the generation eval runs. Every request is one a cook would type: a dish named
/// the way it is on a menu or a recipe site, or what they have on the shelf. None is written to
/// trip the pipeline up. Change the set only alongside a new baseline, since every number is
/// measured against these.
enum EvalRequests {
    static let all: [EvalRequest] = english + japanese

    static let english: [EvalRequest] = [
        EvalRequest(id: "en-chicken-fried-rice", language: .english, description: "chicken fried rice", ingredients: [], tools: []),
        EvalRequest(id: "en-carbonara", language: .english, description: "spaghetti carbonara", ingredients: [], tools: []),
        EvalRequest(id: "en-beef-stew", language: .english, description: "beef stew", ingredients: [], tools: []),
        EvalRequest(id: "en-banana-bread", language: .english, description: "banana bread", ingredients: [], tools: []),
        EvalRequest(id: "en-chickpea-curry", language: .english, description: "chickpea curry", ingredients: [], tools: []),
        EvalRequest(id: "en-lemon-salmon", language: .english, description: "baked salmon with lemon and dill", ingredients: [], tools: []),
        EvalRequest(id: "en-pad-thai", language: .english, description: "shrimp pad thai", ingredients: [], tools: []),
        EvalRequest(id: "en-pancakes", language: .english, description: "fluffy pancakes", ingredients: [], tools: []),
        EvalRequest(
            id: "en-picks-chicken-dinner",
            language: .english,
            description: "quick weeknight dinner with chicken",
            ingredients: ["chicken", "rice", "broccoli", "garlic", "soy-sauce", "honey"],
            tools: ["pan", "pot"]
        ),
        EvalRequest(
            id: "en-picks-tomato-pasta",
            language: .english,
            description: "pasta",
            ingredients: ["spaghetti", "canned-tomatoes", "garlic", "onion", "olive-oil", "parmesan", "basil"],
            tools: ["pot", "pan"]
        ),
        EvalRequest(
            id: "en-picks-pork-stir-fry",
            language: .english,
            description: "stir fry",
            ingredients: ["pork", "cabbage", "carrot", "ginger", "soy-sauce", "rice", "sesame-oil"],
            tools: ["wok", "rice-cooker"]
        ),
        EvalRequest(
            id: "en-picks-only-eggs",
            language: .english,
            description: "",
            ingredients: ["egg", "spinach", "cheddar", "onion", "butter", "milk"],
            tools: ["pan"]
        ),
    ]

    static let japanese: [EvalRequest] = [
        EvalRequest(id: "ja-oyakodon", language: .japanese, description: "親子丼", ingredients: [], tools: []),
        EvalRequest(id: "ja-nikujaga", language: .japanese, description: "肉じゃが", ingredients: [], tools: []),
        EvalRequest(id: "ja-shogayaki", language: .japanese, description: "豚の生姜焼き", ingredients: [], tools: []),
        EvalRequest(id: "ja-mapo-tofu", language: .japanese, description: "麻婆豆腐", ingredients: [], tools: []),
        EvalRequest(id: "ja-salmon-meuniere", language: .japanese, description: "鮭のムニエル", ingredients: [], tools: []),
        EvalRequest(id: "ja-curry-rice", language: .japanese, description: "カレーライス", ingredients: [], tools: []),
        EvalRequest(id: "ja-dashimaki", language: .japanese, description: "だし巻き卵", ingredients: [], tools: []),
        EvalRequest(id: "ja-hamburg", language: .japanese, description: "煮込みハンバーグ", ingredients: [], tools: []),
        EvalRequest(
            id: "ja-picks-chicken-dinner",
            language: .japanese,
            description: "簡単な晩ごはん",
            ingredients: ["chicken-thigh", "onion", "egg", "rice", "soy-sauce", "mirin"],
            tools: ["pan"]
        ),
        EvalRequest(
            id: "ja-picks-miso-soup",
            language: .japanese,
            description: "味噌汁",
            ingredients: ["tofu", "wakame", "spring-onion", "miso", "dashi", "daikon"],
            tools: ["pot"]
        ),
        EvalRequest(
            id: "ja-picks-mushroom-pasta",
            language: .japanese,
            description: "和風パスタ",
            ingredients: ["spaghetti", "shimeji", "bacon", "butter", "soy-sauce", "garlic"],
            tools: ["pot", "pan"]
        ),
        EvalRequest(
            id: "ja-picks-only-yakisoba",
            language: .japanese,
            description: "",
            ingredients: ["noodles", "pork", "cabbage", "carrot", "bean-sprouts", "yakisoba-sauce"],
            tools: ["pan"]
        ),
    ]
}
