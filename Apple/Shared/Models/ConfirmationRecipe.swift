import SwiftUI

struct ConfirmationRecipe {
    struct Item {
        let name: String
        let detail: String
        let note: String
        let assetName: String?

        var message: String {
            [detail, note].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
    }

    struct Section {
        let title: LocalizedStringResource
        let items: [Item]
    }

    struct Step {
        let title: String
        let points: [String]
    }

    struct Problem {
        let question: String
        let answer: String
    }

    let title: String
    let time: String
    let serves: String
    let tried: Bool
    let sections: [Section]
    let steps: [Step]
    let problems: [Problem]
}
