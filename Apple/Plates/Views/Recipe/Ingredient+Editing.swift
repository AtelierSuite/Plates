import CulinaryIntelligence
import SwiftUI

extension Ingredient {
    /// The entry with its whitespace taken off and an empty note dropped, so nothing blank is
    /// written back to the file.
    var tidied: Ingredient {
        var entry = self
        entry.item = item.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.amount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.note?.isEmpty ?? true { entry.note = nil }
        return entry
    }
}
