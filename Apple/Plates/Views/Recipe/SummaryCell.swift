import CulinaryIntelligence
import SwiftUI

/// Time, servings, or whether the recipe has been cooked.
struct SummaryCell<Content: View>: View {
    let label: LocalizedStringResource
    @ViewBuilder let value: Content

    var body: some View {
        VStack(spacing: 4) {
            value
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }
}
