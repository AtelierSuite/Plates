import Testing
@testable import CulinaryIntelligence

struct AmountsTests {
    @Test(arguments: [
        ("300 g", Amounts.Kind.weight(300)),
        ("300g", .weight(300)),
        ("1 kg", .weight(1000)),
        ("1 lb", .weight(454)),
        ("1 can (400 g)", .weight(400)),
        ("2 tbsp", .volume(30)),
        ("1 1/2 tsp", .volume(7.5)),
        ("2 to 3 tbsp", .volume(45)),
        ("1/2 cup", .volume(120)),
        ("200 ml", .volume(200)),
        ("1 L", .volume(1000)),
        ("大さじ2", .volume(30)),
        ("小さじ1/2", .volume(2.5)),
        ("大さじ1から2", .volume(30)),
        ("カップ1", .volume(200)),
        ("200cc", .volume(200)),
        ("1.5リットル", .volume(1500)),
        ("2", .count),
        ("1 large", .count),
        ("3 cloves", .count),
        ("2 blocks", .count),
        ("a thumb", .count),
        ("2個", .count),
        ("4枚", .count),
        ("1丁", .count),
        ("1から2本", .count),
        ("2かけ", .count),
        ("大1個", .count),
        ("a pinch", .loose),
        ("to taste", .loose),
        ("少々", .loose),
        ("適量", .loose),
        ("ひとつまみ", .loose),
    ])
    func readsKind(_ amount: String, _ kind: Amounts.Kind) {
        #expect(Amounts.kind(of: amount) == kind)
    }

    @Test func readsFullWidthFigures() {
        #expect(Amounts.kind(of: "３００ｇ") == .weight(300))
    }

    @Test func leavesUnreadableAmounts() {
        #expect(Amounts.kind(of: "") == nil)
        #expect(Amounts.kind(of: "some") == nil)
    }

    @Test(arguments: [
        ("300 g", "350 g"),
        ("300 g", "200 g"),
        ("300g", "1丁"),
        ("300 g", "1 block"),
        ("200 g", "2"),
        ("1 lb", "400 g"),
        ("2 tbsp", "1 tbsp"),
        ("大さじ2", "大さじ1"),
        ("大さじ1", "小さじ2"),
        ("200 ml", "1 cup"),
        ("1 tbsp", "to taste"),
        ("小さじ1", "少々"),
        ("5 g", "a pinch"),
        ("2 cloves", "1 tsp"),
        ("1個", "100g"),
        ("a pinch", "1 tsp"),
        ("to taste", "2 tbsp"),
        ("some", "2 tbsp"),
        ("300 g", "about two handfuls"),
    ])
    func fits(_ old: String, _ new: String) {
        #expect(Amounts.fits(new, replacing: old))
    }

    @Test(arguments: [
        ("300 g", "2 tbsp"),
        ("300g", "大さじ2"),
        ("300 g", "50 g"),
        ("300 g", "1 kg"),
        ("100 g", "to taste"),
        ("200 ml", "200 g"),
        ("大さじ2", "2個"),
        ("1 cup", "a pinch"),
        ("200 ml", "2"),
        ("300 g", ""),
    ])
    func doesNotFit(_ old: String, _ new: String) {
        #expect(!Amounts.fits(new, replacing: old))
    }
}
