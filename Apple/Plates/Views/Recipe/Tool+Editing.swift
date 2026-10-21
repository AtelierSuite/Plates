import CulinaryIntelligence
import SwiftUI

extension Tool {
    var tidied: Tool {
        var entry = self
        entry.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.note?.isEmpty ?? true { entry.note = nil }
        return entry
    }
}
