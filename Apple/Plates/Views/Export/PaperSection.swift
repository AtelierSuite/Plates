import CulinaryIntelligence
import SwiftUI
import UIKit

/// A heading in the accent colour with a rule running out to the margin, over what it heads.
struct PaperSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.paperAccent)
                    .fixedSize()
                Rectangle()
                    .fill(Color.paperRule)
                    .frame(height: 1)
            }
            content
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
