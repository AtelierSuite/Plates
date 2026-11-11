import Testing
@testable import CulinaryIntelligence

struct VolumeTests {
    @Test(arguments: [
        "Bring 2 litres of water to a rolling boil and add the salt.",
        "Bring it to a boil, skim the foam off, then simmer for 15 minutes.",
        "Boil the water",
        "Take it to a proper golden brown, not just soft.",
        "Sear the seafood",
        "Render the guanciale",
        "Fry for 4 minutes over medium heat.",
        "Stir-fry the vegetables for 2 minutes.",
        "Sauté the onion until soft.",
        "Don't crowd the pan, fry it in two lots.",
        "脂が出てふちが色づくまで4分ほど炒めます。",
        "チップを揚げる",
        "2リットルの水をしっかり沸かし、塩を入れます。",
        "沸いたらあくを取り、ふたをずらして15分煮ます。",
    ])
    func flagsVolumeWork(_ line: String) {
        #expect(Step.dependsOnVolume(line))
    }

    @Test(arguments: [
        "Do not let it brown.",
        "The grains should end up glossy and separate, not browned.",
        "Keep it below a boil.",
        "Add the brown sugar and stir.",
        "Sit the fried egg on top and break it at the table.",
        "Grate the pecorino as fine as you can.",
        "煮立てません。",
        "油揚げを細切りにします。",
        "チャーハンを茶碗に詰めます。",
        "ペコリーノをできるだけ細かくおろします。",
    ])
    func leavesOtherWork(_ line: String) {
        #expect(!Step.dependsOnVolume(line))
    }

    @Test func flagsPansAndPots() {
        #expect(Tool(name: "Pot", icon: "img/tools/pot.svg", required: true).holdsTheFood)
        #expect(Tool(name: "中華鍋", icon: "img/tools/wok.svg", required: true).holdsTheFood)
        #expect(!Tool(name: "Lid", icon: "img/tools/lid.svg", required: true).holdsTheFood)
        #expect(!Tool(name: "Knife", icon: "img/tools/knife.svg", required: true).holdsTheFood)
    }

    @Test func outgrowsPansFromOneAndAHalfTimes() {
        #expect(Recipe.outgrowsPans(scaledBy: 2))
        #expect(Recipe.outgrowsPans(scaledBy: 1.5))
        #expect(Recipe.outgrowsPans(scaledBy: 2.0 / 3.0))
        #expect(Recipe.outgrowsPans(scaledBy: 0.5))
        #expect(!Recipe.outgrowsPans(scaledBy: 1.25))
        #expect(!Recipe.outgrowsPans(scaledBy: 0.75))
    }
}
