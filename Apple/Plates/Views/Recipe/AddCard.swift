import CulinaryIntelligence
import SwiftUI

/// The card at the end of a row that adds to it.
struct AddCard: View {
    let label: LocalizedStringResource

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
            Text(label)
                .font(.subheadline)
                .lineLimit(1)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 68, maxHeight: 68)
        .frame(maxWidth: .infinity)
        .background(
            .quaternary.opacity(0.4),
            in: .rect(cornerRadius: .listRowCornerRadius, style: .continuous)
        )
    }
}
