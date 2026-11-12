import Testing
@testable import CulinaryIntelligence

@MainActor
struct EditRequestTests {
    @Test(arguments: [
        ("6人分にしてください", "6"),
        ("６人分にして", "6"),
        ("4人前で作りたい", "4"),
        ("三人分にしてください", "3"),
        ("6人分の材料と手順に書き直す", "6"),
        ("Make it serve 6", "6"),
        ("Scale it to 8 servings", "8"),
        ("for 4 people, without the pork", "4"),
    ])
    func readsTheCount(_ request: String, _ count: String) {
        #expect(RecipeAskEditor.askedServings(in: request) == count)
    }

    @Test(arguments: [
        "Make it for four",
        "Fry it for 6 minutes",
        "豚肉を鶏肉に替えてください",
        "2cmに切ってください",
    ])
    func leavesTheRestToTheModel(_ request: String) {
        #expect(RecipeAskEditor.askedServings(in: request) == nil)
    }

    @Test(arguments: [
        "6人分にしてください",
        "６人分にして",
        "4人前で作りたい",
        "三人分にしてください",
        "このレシピを6人分に変えてください",
        "Scale it to 8 servings",
        "Make it serve 6, please",
    ])
    func seesARequestForACountAlone(_ request: String) {
        #expect(RecipeAskEditor.asksOnlyForServings(request))
    }

    @Test(arguments: [
        "6人分にして、豚肉を鶏肉に替えてください",
        "6人分にして辛くしてください",
        "for 4 people, without the pork",
        "Make it for four",
        "豚肉を鶏肉に替えてください",
    ])
    func seesARequestForMore(_ request: String) {
        #expect(!RecipeAskEditor.asksOnlyForServings(request))
    }

    @Test func keepsTheRecipesTimeStyle() {
        #expect(RecipeAskEditor.time(25, writtenLike: "20分") == "25分")
        #expect(RecipeAskEditor.time(80, writtenLike: "45分") == "1時間20分")
        #expect(RecipeAskEditor.time(60, writtenLike: "1時間") == "1時間")
        #expect(RecipeAskEditor.time(25, writtenLike: "20 min") == "25 min")
    }
}
