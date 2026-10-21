import CulinaryIntelligence
import SwiftUI

/// One card being edited: which list it is in and where in that list it sits.
struct CardEdit: Identifiable {
    let list: RecipeList
    let index: Int

    var id: String { "\(list.rawValue)-\(index)" }
}
