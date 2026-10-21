import CulinaryIntelligence
import SwiftUI
import UIKit

struct PaperItemRow: View {
    let item: TileInfo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RecipeIcon(path: item.icon, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.paperInk)
                if let detail = item.detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.paperAccent)
                }
                if let note = item.note, !note.isEmpty {
                    Text(verbatim: note)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.paperSoft)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Two items side by side, so a list takes half the height it would in one column. The odd one
/// out at the end of a list sits on the left.
struct PaperItemPair: View {
    let items: [TileInfo]

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach(items) { PaperItemRow(item: $0) }
            if items.count == 1 {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A list cut into pairs, in order.
    static func pairs(_ items: [TileInfo]) -> [[TileInfo]] {
        stride(from: 0, to: items.count, by: 2).map { Array(items[$0 ..< min($0 + 2, items.count)]) }
    }
}
