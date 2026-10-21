import SwiftUI

extension CGFloat {
    /// The corner radius an inset grouped list row uses on iOS 26, measured against a real
    /// `List` so cards drawn by hand sit flush with native ones.
    static let listRowCornerRadius: CGFloat = 26

    /// The horizontal inset an inset grouped list uses.
    static let listRowInset: CGFloat = 20
}

extension View {
    /// Draws the receiver as a list row sized card.
    func cardBackground() -> some View {
        background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: .rect(cornerRadius: .listRowCornerRadius, style: .continuous)
        )
    }
}
