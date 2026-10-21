import CulinaryIntelligence
import SwiftUI
import UIKit

/// One sheet of a printed recipe, filled from the top, with a band of the accent colour across
/// the head and the title and page number at the foot.
struct PaperPage: View {
    let title: String
    let blocks: [AnyView]
    let height: CGFloat
    let number: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(RecipeExport.margin)
        // The page grows rather than squeezing what is on it, so a block measured a hair short
        // of how it draws is never cut off at the foot of the page.
        .frame(width: RecipeExport.pageWidth, alignment: .topLeading)
        .frame(minHeight: height, alignment: .topLeading)
        .overlay(alignment: .top) {
            Color.paperAccent.frame(height: 6)
        }
        .overlay(alignment: .bottom) {
            footer
        }
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    private var footer: some View {
        HStack {
            // The first page is headed with the title already.
            if number > 1 {
                Text(verbatim: title)
                    .lineLimit(1)
            }
            Spacer()
            if count > 1 {
                Text(String(format: String(localized: "Recipe.Share.Page"), number, count))
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(Color.paperSoft)
        .padding(.horizontal, RecipeExport.margin)
        .padding(.bottom, 22)
    }
}
