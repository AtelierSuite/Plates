import CulinaryIntelligence
import SwiftUI
import UIKit

/// Time, servings, and whether the recipe has been cooked, the way the detail view sums them up.
struct PaperFacts: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 8) {
            fact("Recipe.Detail.Time", value: recipe.formattedTime, symbol: "clock")
            fact("Recipe.Detail.Serves", value: recipe.serves, symbol: "person.2")
            if recipe.tried == true {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.paperAccent)
                    Text("Recipe.Detail.Tried")
                        .foregroundStyle(Color.paperInk)
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.paperTint, in: .capsule)
            }
        }
    }

    private func fact(_ label: LocalizedStringResource, value: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .foregroundStyle(Color.paperAccent)
            Text(label)
                .foregroundStyle(Color.paperSoft)
            Text(verbatim: value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.paperInk)
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.paperTint, in: .capsule)
    }
}
