import Foundation
@testable import CulinaryIntelligence

/// A part of a recipe an edit can change. The lists are compared line by line, and the title,
/// time, and serving count as one line each.
enum RecipePart: String, Codable, CaseIterable, Sendable {
    case title
    case time
    case serves
    case ingredients
    case tools
    case steps
    case notes
}

/// One thing a finished edit has to show for the request to count as met. Words are matched
/// without case, anywhere in the lines of the parts named.
enum EditCheck: Sendable, CustomStringConvertible {
    /// At least one of the words is in the parts.
    case has([String], in: Set<RecipePart>)
    /// None of the words is left in the parts.
    case lacks([String], in: Set<RecipePart>)
    /// At least one line in the parts is different.
    case changes(Set<RecipePart>)
    /// The serving count reads as this many.
    case serves(Double)

    var description: String {
        func parts(_ parts: Set<RecipePart>) -> String {
            parts.map(\.rawValue).sorted().joined(separator: ", ")
        }
        return switch self {
        case let .has(words, in: scope): "has \(words.joined(separator: " or ")) in \(parts(scope))"
        case let .lacks(words, in: scope): "lacks \(words.joined(separator: " and ")) in \(parts(scope))"
        case let .changes(scope): "changes \(parts(scope))"
        case let .serves(count): "serves \(count.formatted())"
        }
    }
}

/// One request in the edit eval: a sample recipe and what a cook asked of it.
struct EditEvalRequest: Sendable {
    enum Language: String, Codable, Sendable {
        case english = "en-US"
        case japanese = "ja"
    }

    let id: String
    let language: Language
    /// The sample recipe's file name, without the extension.
    let recipe: String
    let request: String
    /// What a reader checks by eye, beyond what `checks` can tell.
    let expectation: String
    let checks: [EditCheck]
    /// The parts the request may change. A line changed anywhere else is collateral. A method
    /// that changes may change the total time, as the editor checks it whenever it does, so a
    /// request that may change the steps may change the time.
    let mayChange: Set<RecipePart>
    /// Words a changed line has to name, before or after the change, to count as part of the
    /// request. Empty for a request that may change any line in the parts it may change, such
    /// as "less spicy" or a serving count.
    let subjects: [String]

    init(
        _ id: String,
        _ language: Language,
        recipe: String,
        request: String,
        expectation: String,
        checks: [EditCheck],
        mayChange: Set<RecipePart>,
        subjects: [String] = []
    ) {
        self.id = id
        self.language = language
        self.recipe = recipe
        self.request = request
        self.expectation = expectation
        self.checks = checks
        self.mayChange = mayChange.contains(.steps) ? mayChange.union([.time]) : mayChange
        self.subjects = subjects
    }
}

/// The fixed set the edit eval runs, on the sample recipes in each language. Every request is
/// one a cook would type: a swap for what they do not have, something left out, a different
/// serving count, a change to the method alone, or a vague ask such as "less spicy". None is
/// written to trip the editor up. Change the set only alongside a new baseline, since every
/// number is measured against these.
enum EditEvalRequests {
    static let all: [EditEvalRequest] = english + japanese

    static let english: [EditEvalRequest] = [
        // Swaps.
        EditEvalRequest(
            "en-carbonara-bacon", .english,
            recipe: "spaghetti-carbonara",
            request: "I can't find guanciale anywhere, can I use bacon instead?",
            expectation: "Bacon replaces the guanciale on the list and in every step that cut, rendered, or scattered it.",
            checks: [.has(["bacon"], in: [.ingredients]), .lacks(["guanciale"], in: [.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["guanciale", "bacon", "pancetta"]
        ),
        EditEvalRequest(
            "en-carbonara-parmesan", .english,
            recipe: "spaghetti-carbonara",
            request: "use parmesan instead of pecorino",
            expectation: "Parmesan is the only cheese, grated and whisked in where the pecorino was.",
            checks: [.has(["parmesan"], in: [.steps]), .lacks(["pecorino"], in: [.ingredients, .steps])],
            mayChange: [.ingredients, .steps, .notes],
            subjects: ["pecorino", "parmesan", "cheese"]
        ),
        EditEvalRequest(
            "en-egg-fried-rice-no-wok", .english,
            recipe: "egg-fried-rice",
            request: "I don't have a wok, just a normal frying pan",
            expectation: "A frying pan replaces the wok, and the steps that heat and toss in it say pan.",
            checks: [.changes([.tools]), .has(["pan"], in: [.steps]), .lacks(["wok"], in: [.steps])],
            mayChange: [.tools, .steps, .notes],
            subjects: ["wok", "pan"]
        ),
        EditEvalRequest(
            "en-curry-chicken", .english,
            recipe: "seafood-curry",
            request: "can I do this with chicken thighs instead of the seafood?",
            expectation: "Chicken thighs replace the seafood mix, cut and browned rather than thawed, and simmered long enough to cook through.",
            checks: [
                .has(["chicken"], in: [.ingredients]),
                .has(["chicken"], in: [.steps]),
                .lacks(["seafood", "squid", "prawn"], in: [.ingredients, .steps]),
            ],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["seafood", "chicken", "squid", "prawn", "thaw"]
        ),
        EditEvalRequest(
            "en-french-toast-dairy-free", .english,
            recipe: "french-toast",
            request: "my partner can't have dairy, can you make it dairy free?",
            expectation: "The milk, butter, and cream are replaced with plant milk and oil or a dairy free spread, in the list and the method.",
            checks: [.has(["oat", "almond", "soy", "coconut", "plant", "dairy-free", "dairy free", "vegan", "oil"], in: [.ingredients])],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["milk", "butter", "cream", "dairy", "oil", "spread"]
        ),

        // Taking something out.
        EditEvalRequest(
            "en-garlic-rice-no-butter", .english,
            recipe: "garlic-fried-rice",
            request: "leave out the butter",
            expectation: "No butter on the list or in the method. The rest of the seasoning step stays.",
            checks: [.lacks(["butter"], in: [.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["butter"]
        ),
        EditEvalRequest(
            "en-kimchi-no-egg", .english,
            recipe: "kimchi-fried-rice",
            request: "skip the fried egg on top",
            expectation: "The egg and the step that fries it are gone, and plating no longer sits an egg on top.",
            checks: [.lacks(["egg"], in: [.ingredients, .steps])],
            mayChange: [.ingredients, .tools, .steps, .notes],
            subjects: ["egg", "yolk", "second pan"]
        ),
        EditEvalRequest(
            "en-kimchi-vegetarian", .english,
            recipe: "kimchi-fried-rice",
            request: "make it vegetarian",
            expectation: "The pork is gone or swapped for tofu or mushrooms, and the kimchi is fried in oil rather than pork fat.",
            checks: [.lacks(["pork"], in: [.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["pork", "tofu", "mushroom", "fat", "oil", "vegetarian"]
        ),

        // Adding something.
        EditEvalRequest(
            "en-egg-fried-rice-chicken", .english,
            recipe: "egg-fried-rice",
            request: "add some leftover roast chicken",
            expectation: "Chicken is on the list and goes in with the rice.",
            checks: [.has(["chicken"], in: [.ingredients]), .has(["chicken"], in: [.steps])],
            mayChange: [.title, .ingredients, .steps],
            subjects: ["chicken"]
        ),
        EditEvalRequest(
            "en-carbonara-peas", .english,
            recipe: "spaghetti-carbonara",
            request: "throw in some frozen peas",
            expectation: "Frozen peas are on the list and are cooked, most likely with the pasta for its last minutes.",
            checks: [.has(["pea"], in: [.ingredients]), .has(["pea"], in: [.steps])],
            mayChange: [.title, .ingredients, .steps],
            subjects: ["pea"]
        ),

        // Serving counts.
        EditEvalRequest(
            "en-carbonara-for-four", .english,
            recipe: "spaghetti-carbonara",
            request: "make this for 4 people",
            expectation: "Serves 4, with every amount doubled and nothing else changed.",
            checks: [.serves(4), .has(["400"], in: [.ingredients])],
            mayChange: [.serves, .ingredients]
        ),
        EditEvalRequest(
            "en-curry-just-me", .english,
            recipe: "seafood-curry",
            request: "halve it, it's just me tonight",
            expectation: "Serves 1, with every amount halved and nothing else changed.",
            checks: [.serves(1), .changes([.ingredients])],
            mayChange: [.serves, .ingredients]
        ),

        // The method alone.
        EditEvalRequest(
            "en-french-toast-quick-soak", .english,
            recipe: "french-toast",
            request: "I don't have time to soak the bread for half an hour",
            expectation: "The soak is a few minutes a side, and the time comes down with it. The list is unchanged.",
            checks: [.changes([.steps]), .lacks(["15 minutes"], in: [.steps])],
            mayChange: [.steps, .notes]
        ),
        EditEvalRequest(
            "en-garlic-rice-leftover-rice", .english,
            recipe: "garlic-fried-rice",
            request: "I want to use yesterday's leftover rice",
            expectation: "The rice is cold leftover rice, warmed or broken up before it goes in, and the cook the rice step no longer starts a pot.",
            checks: [.changes([.steps])],
            mayChange: [.ingredients, .steps, .notes],
            subjects: ["rice"]
        ),
        EditEvalRequest(
            "en-carbonara-faster", .english,
            recipe: "spaghetti-carbonara",
            request: "how can I get this on the table faster on a weeknight?",
            expectation: "Steps run side by side or are cut short, and the time comes down. The ingredients stay.",
            checks: [.changes([.steps, .time])],
            mayChange: [.steps, .notes]
        ),
        EditEvalRequest(
            "en-curry-no-frying-pan", .english,
            recipe: "seafood-curry",
            request: "I only have one pot, no frying pan",
            expectation: "The seafood is cooked in the pot, not seared in a pan, and the pan is off the tools.",
            checks: [.lacks(["pan"], in: [.tools]), .lacks(["frying pan"], in: [.steps])],
            mayChange: [.tools, .steps, .notes],
            subjects: ["pan", "pot", "sear", "seafood", "butter"]
        ),

        // Vague requests.
        EditEvalRequest(
            "en-kimchi-less-spicy", .english,
            recipe: "kimchi-fried-rice",
            request: "my kids are eating this too, can you make it less spicy?",
            expectation: "Less gochujang or none, perhaps a milder kimchi or more sugar or butter. Nothing else.",
            checks: [.changes([.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes]
        ),
        EditEvalRequest(
            "en-egg-fried-rice-lighter", .english,
            recipe: "egg-fried-rice",
            request: "make it a bit lighter",
            expectation: "Less oil, salt, or ham, or more vegetables. The method stays the same shape.",
            checks: [.changes([.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes]
        ),
        EditEvalRequest(
            "en-french-toast-less-sweet", .english,
            recipe: "french-toast",
            request: "less sweet please",
            expectation: "Less sugar in the custard, perhaps less syrup. Nothing else.",
            checks: [.changes([.ingredients])],
            mayChange: [.ingredients, .steps, .notes],
            subjects: ["sugar", "syrup", "sweet", "vanilla", "cinnamon", "custard"]
        ),
        EditEvalRequest(
            "en-butter-toast-sugar", .english,
            recipe: "butter-toast",
            request: "I want to make it sugar toast",
            expectation: "Sugar goes on over a thin layer of butter before toasting, as the sugar line's note says.",
            checks: [.has(["sugar"], in: [.steps])],
            mayChange: [.title, .ingredients, .steps, .notes]
        ),

        // The details.
        EditEvalRequest(
            "en-butter-toast-rename", .english,
            recipe: "butter-toast",
            request: "call it Crackle Toast",
            expectation: "Only the title changes.",
            checks: [.has(["crackle"], in: [.title])],
            mayChange: [.title]
        ),
    ]

    static let japanese: [EditEvalRequest] = [
        // Swaps.
        EditEvalRequest(
            "ja-carbonara-bacon", .japanese,
            recipe: "spaghetti-carbonara",
            request: "グアンチャーレが売っていないので、ベーコンで作りたいです",
            expectation: "Bacon replaces the guanciale on the list and in every step that cut, rendered, or scattered it.",
            checks: [.has(["ベーコン"], in: [.ingredients]), .lacks(["グアンチャーレ"], in: [.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["グアンチャーレ", "ベーコン", "パンチェッタ"]
        ),
        EditEvalRequest(
            "ja-egg-fried-rice-no-wok", .japanese,
            recipe: "egg-fried-rice",
            request: "中華鍋がないので、フライパンで作りたい",
            expectation: "A frying pan replaces the wok, and the steps that heat and toss in it say フライパン.",
            checks: [.changes([.tools]), .has(["フライパン"], in: [.steps])],
            mayChange: [.tools, .steps, .notes],
            subjects: ["中華鍋", "鍋", "フライパン"]
        ),
        EditEvalRequest(
            "ja-curry-chicken", .japanese,
            recipe: "seafood-curry",
            request: "シーフードの代わりに鶏もも肉で作れますか",
            expectation: "Chicken thighs replace the seafood mix, cut and browned rather than thawed, and simmered long enough to cook through.",
            checks: [
                .has(["鶏", "チキン"], in: [.ingredients]),
                .has(["鶏", "チキン"], in: [.steps]),
                .lacks(["シーフード", "えび", "いか"], in: [.ingredients, .steps]),
            ],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["シーフード", "鶏", "チキン", "えび", "いか", "解凍"]
        ),

        // Taking something out.
        EditEvalRequest(
            "ja-garlic-rice-no-butter", .japanese,
            recipe: "garlic-fried-rice",
            request: "バターなしで作りたい",
            expectation: "No butter on the list or in the method. The rest of the seasoning step stays.",
            checks: [.lacks(["バター"], in: [.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes],
            subjects: ["バター"]
        ),
        EditEvalRequest(
            "ja-kimchi-no-egg", .japanese,
            recipe: "kimchi-fried-rice",
            request: "目玉焼きはのせなくていいです",
            expectation: "The egg and the step that fries it are gone, and plating no longer sits an egg on top.",
            checks: [.lacks(["卵"], in: [.ingredients]), .lacks(["目玉焼き"], in: [.steps])],
            mayChange: [.ingredients, .tools, .steps, .notes],
            subjects: ["卵", "目玉焼き", "黄身", "フライパン"]
        ),

        // Adding something.
        EditEvalRequest(
            "ja-egg-fried-rice-chicken", .japanese,
            recipe: "egg-fried-rice",
            request: "残りもののチキンを入れたい",
            expectation: "Chicken is on the list and goes in with the rice.",
            checks: [.has(["鶏", "チキン"], in: [.ingredients]), .has(["鶏", "チキン"], in: [.steps])],
            mayChange: [.title, .ingredients, .steps],
            subjects: ["鶏", "チキン"]
        ),

        // Serving counts.
        EditEvalRequest(
            "ja-carbonara-for-four", .japanese,
            recipe: "spaghetti-carbonara",
            request: "4人分にしてください",
            expectation: "Serves 4, with every amount doubled and nothing else changed.",
            checks: [.serves(4), .has(["400"], in: [.ingredients])],
            mayChange: [.serves, .ingredients]
        ),
        EditEvalRequest(
            "ja-curry-for-one", .japanese,
            recipe: "seafood-curry",
            request: "1人分に減らしたい",
            expectation: "Serves 1, with every amount halved and nothing else changed.",
            checks: [.serves(1), .changes([.ingredients])],
            mayChange: [.serves, .ingredients]
        ),

        // The method alone.
        EditEvalRequest(
            "ja-french-toast-quick-soak", .japanese,
            recipe: "french-toast",
            request: "パンを浸す時間を短くしたい",
            expectation: "The soak is a few minutes a side, and the time comes down with it. The list is unchanged.",
            checks: [.changes([.steps]), .lacks(["15分"], in: [.steps])],
            mayChange: [.steps, .notes]
        ),
        EditEvalRequest(
            "ja-garlic-rice-leftover-rice", .japanese,
            recipe: "garlic-fried-rice",
            request: "冷やごはんで作りたい",
            expectation: "The rice is cold leftover rice, warmed or broken up before it goes in, and the cook the rice step no longer starts a pot.",
            checks: [.changes([.steps])],
            mayChange: [.ingredients, .steps, .notes],
            subjects: ["ごはん", "米"]
        ),

        // Vague requests.
        EditEvalRequest(
            "ja-kimchi-less-spicy", .japanese,
            recipe: "kimchi-fried-rice",
            request: "子どもも食べるので、辛さを控えめにしたい",
            expectation: "Less gochujang or none, perhaps a milder kimchi or more sugar or butter. Nothing else.",
            checks: [.changes([.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes]
        ),
        EditEvalRequest(
            "ja-french-toast-less-sweet", .japanese,
            recipe: "french-toast",
            request: "甘さ控えめにしてください",
            expectation: "Less sugar in the custard, perhaps less syrup. Nothing else.",
            checks: [.changes([.ingredients])],
            mayChange: [.ingredients, .steps, .notes],
            subjects: ["砂糖", "シロップ", "甘", "バニラ", "シナモン", "卵液"]
        ),
        EditEvalRequest(
            "ja-egg-fried-rice-lighter", .japanese,
            recipe: "egg-fried-rice",
            request: "もう少しあっさりさせたい",
            expectation: "Less oil, salt, or ham, or more vegetables. The method stays the same shape.",
            checks: [.changes([.ingredients, .steps])],
            mayChange: [.title, .ingredients, .steps, .notes]
        ),
    ]
}

/// The recipes the requests are made on: the samples the app shipped until the Singaporean
/// ones replaced them, kept as fixtures so the requests and their baseline still hold.
enum EditEvalSamples {
    /// `Tests/Fixtures/SampleRecipes`, found from this file. Simulator reads the Mac's disk, so
    /// the path holds there too.
    static let folder = URL(filePath: #filePath)
        .deletingLastPathComponent() // EditEval
        .deletingLastPathComponent() // CulinaryIntelligenceTests
        .deletingLastPathComponent() // Tests
        .appending(path: "Fixtures/SampleRecipes")

    static func recipe(_ name: String, in language: EditEvalRequest.Language) throws -> Recipe {
        let file = folder.appending(path: "\(language == .japanese ? "ja" : "en-US").lproj/\(name).json")
        return try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: file))
    }
}
