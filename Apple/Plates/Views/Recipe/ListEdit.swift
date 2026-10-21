import CulinaryIntelligence
import SwiftUI

/// Where in a list something being edited sits. An index past the end of the list is
/// something new, which is added when it is saved.
struct ListEdit: Identifiable {
    let index: Int

    var id: Int { index }
}
