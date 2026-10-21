import CulinaryIntelligence
import SwiftUI

/// The recipe as it stands, read under the checklist while the model works on it. Writing one
/// and rewriting one both show it, so a cook watching either screen reads the same thing.
struct RecipePreview: View {
    /// Everything here is written by the model, so it is shown as written rather than looked up.
    let title: String
    let time: String
    let serves: String
    /// The ingredients and tools, each a name with its amount or note, shown only once there
    /// are some.
    var ingredients: [GenerationProgress.Line] = []
    var tools: [GenerationProgress.Line] = []
    /// The step titles, in order.
    let steps: [String]
    /// The problems, without their fixes.
    var problems: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if !time.isEmpty, !serves.isEmpty {
                    Text(String(
                        format: String(localized: "Recipe.Row.Subtitle"),
                        Recipe.formatTime(time),
                        serves
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            lines("Recipe.Detail.Ingredients", ingredients)
            lines("Recipe.Detail.Tools", tools)

            if !steps.isEmpty, !(ingredients.isEmpty && tools.isEmpty && problems.isEmpty) {
                heading("Recipe.Detail.Steps")
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(index + 1, format: .number)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(verbatim: step)
                        .font(.subheadline)
                    Spacer(minLength: 0)
                }
            }

            if !problems.isEmpty {
                heading("Recipe.Detail.Troubleshooting")
                ForEach(Array(problems.enumerated()), id: \.offset) { _, problem in
                    Text(verbatim: problem)
                        .font(.subheadline)
                }
            }
        }
    }

    private func heading(_ key: LocalizedStringResource) -> some View {
        Text(key)
            .font(.headline)
            .padding(.top, 4)
    }

    /// A list of names with what goes with each on the trailing side.
    @ViewBuilder private func lines(
        _ key: LocalizedStringResource,
        _ lines: [GenerationProgress.Line]
    ) -> some View {
        if !lines.isEmpty {
            heading(key)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: line.name)
                    Spacer(minLength: 0)
                    Text(verbatim: line.detail)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }
}
