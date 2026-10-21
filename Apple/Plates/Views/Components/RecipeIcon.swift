import CulinaryIntelligence
import SwiftUI

/// One of the shared 48 pt SVG icons, drawn at 44 pt the way the site does. An outline colour
/// draws a border that follows the drawing's own edge, for showing an icon as picked.
struct RecipeIcon: View {
    let path: String
    var size: CGFloat = 44
    var outline: Color?

    /// The eight directions the silhouette is stamped in to make an edge.
    private static let directions: [CGSize] = [
        CGSize(width: 1, height: 0), CGSize(width: -1, height: 0),
        CGSize(width: 0, height: 1), CGSize(width: 0, height: -1),
        CGSize(width: 0.7, height: 0.7), CGSize(width: -0.7, height: 0.7),
        CGSize(width: 0.7, height: -0.7), CGSize(width: -0.7, height: -0.7),
    ]

    private let thickness: CGFloat = 2

    var body: some View {
        Group {
            if let name = IconCatalog.assetName(for: path), UIImage(named: name) != nil {
                icon(name)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    /// The icon over its own silhouette, stamped around in the outline colour.
    private func icon(_ name: String) -> some View {
        ZStack {
            if let outline {
                ForEach(Array(Self.directions.enumerated()), id: \.offset) { _, direction in
                    Image(name)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(outline)
                        .offset(x: direction.width * thickness, y: direction.height * thickness)
                }
            }
            Image(name)
                .resizable()
                .scaledToFit()
        }
    }
}
