import CulinaryIntelligence
import SwiftUI
import UIKit

/// A step under its number, in the colour cooking mode gives the same step.
struct PaperStepRow: View {
    let number: Int
    let step: Step

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: "\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.step(step.title), in: .circle)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: step.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.paperInk)
                if let icons = step.icons, !icons.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(icons, id: \.self) { RecipeIcon(path: $0, size: 20) }
                    }
                }
                ForEach(step.points, id: \.self) { point in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(Color.paperRule)
                            .frame(width: 4, height: 4)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
                        Text(verbatim: point)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.paperSoft)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
