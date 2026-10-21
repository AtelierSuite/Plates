import CulinaryIntelligence
import SwiftUI

struct StepCard: View {
    let number: Int
    let step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "Recipe.Detail.Step.Title"), number, step.title))
                .font(.headline)

            if let icons = step.icons, !icons.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            RecipeIcon(path: icon, size: 32)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            ForEach(step.points, id: \.self) { point in
                Text(verbatim: point)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground()
    }
}
