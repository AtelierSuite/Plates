import SwiftUI

extension CGFloat {
    /// The circle every checklist marker is drawn in, so the ring, the dotted circle, and the
    /// checkmark are all the same size.
    static let markerSize: CGFloat = 20
    /// How thick the ring is drawn. The ring is inset by half of it so its outer edge lands on
    /// the circle the symbols fill.
    static let markerLineWidth: CGFloat = 2
}
