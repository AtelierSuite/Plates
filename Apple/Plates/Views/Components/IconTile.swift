import CulinaryIntelligence
import SwiftUI

/// A card in one of the carousels: the icon, the name, and the amount when there is one.
struct IconTile: View {
    let item: TileInfo

    var body: some View {
        HStack(spacing: 10) {
            RecipeIcon(path: item.icon, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: item.name)
                    .font(.subheadline)
                    .lineLimit(2)
                if let detail = item.detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68, alignment: .leading)
        .cardBackground()
    }
}
