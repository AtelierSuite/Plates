import CulinaryIntelligence
import SwiftUI

/// An ingredient or a tool as the detail view shows it. The name, amount, and note come from
/// recipe data, so they are shown as written rather than looked up in the string catalog.
nonisolated struct TileInfo: Identifiable, Hashable {
    let id: String
    let icon: String
    let name: String
    let detail: String?
    let note: String?

    init(_ ingredient: Ingredient) {
        id = "ingredient-" + ingredient.id
        icon = ingredient.icon
        name = ingredient.item
        detail = ingredient.amount
        note = ingredient.note
    }

    init(_ tool: Tool) {
        id = "tool-" + tool.id
        icon = tool.icon
        name = tool.name
        detail = nil
        note = tool.note
    }

    /// What the card has no room for, shown in an alert when the card is tapped. The card cuts
    /// a long name and a long amount short, so the alert is where both are read in full.
    var message: String {
        [detail, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
