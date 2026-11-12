import Testing
@testable import CulinaryIntelligence

struct ServesTests {
    @Test(arguments: [
        ("4", "4"),
        ("Serves 4", "4"),
        ("4 to 6", "4 to 6"),
        ("4-6", "4 to 6"),
        ("2 or 3", "2 to 3"),
        ("2〜3人分", "2 to 3"),
        ("2, with about 1 1/2 cups of kaya left over", "2"),
        ("4 (makes 12 dumplings)", "4"),
        ("", ""),
    ])
    func readsTheServingCount(_ written: String, _ expected: String) {
        #expect(RecipeGenerator.serves(from: written) == expected)
    }
}
