import SwiftUI

/// The finished recipe layout used to confirm a generated or shared recipe.
struct RecipeConfirmationView<Header: View>: View {
    let recipe: ConfirmationRecipe
    let header: Header
    @State private var selectedItem: ConfirmationRecipe.Item?

    init(recipe: ConfirmationRecipe, @ViewBuilder header: () -> Header) {
        self.recipe = recipe
        self.header = header()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                summary
                    .padding(.horizontal, .listRowInset)

                ForEach(Array(recipe.sections.enumerated()), id: \.offset) { _, section in
                    if !section.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.headline)
                                .padding(.horizontal, .listRowInset)

                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 12) {
                                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                        Button { selectedItem = item } label: { itemCard(item) }
                                            .buttonStyle(.plain)
                                            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 12)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .scrollIndicators(.hidden)
                            .contentMargins(.horizontal, .listRowInset, for: .scrollContent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recipe.Detail.Steps")
                        .font(.headline)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: String(localized: "Recipe.Detail.Step.Title"), index + 1, step.title))
                                .font(.headline)
                            ForEach(Array(step.points.enumerated()), id: \.offset) { _, point in
                                Text(verbatim: point)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .cardBackground()
                    }
                }
                .padding(.horizontal, .listRowInset)

                if !recipe.problems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recipe.Detail.Troubleshooting")
                            .font(.headline)
                        ForEach(Array(recipe.problems.enumerated()), id: \.offset) { _, problem in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: problem.question)
                                    .font(.headline)
                                Text(verbatim: problem.answer)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .cardBackground()
                        }
                    }
                    .padding(.horizontal, .listRowInset)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .alert(
            Text(verbatim: selectedItem?.name ?? ""),
            isPresented: Binding(get: { selectedItem != nil }, set: { if !$0 { selectedItem = nil } })
        ) {
            Button("Shared.Done", role: .cancel) {}
        } message: {
            Text(verbatim: selectedItem?.message ?? "")
        }
    }

    private var summary: some View {
        Grid(horizontalSpacing: 12) {
            GridRow {
                summaryCell("Recipe.Detail.Time", value: recipe.time)
                summaryCell("Recipe.Detail.Serves", value: recipe.serves)
                summaryCell("Recipe.Detail.Tried", value: recipe.tried ? "✓" : "×")
            }
        }
    }

    private func summaryCell(_ label: LocalizedStringResource, value: String) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: value)
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

    private func itemCard(_ item: ConfirmationRecipe.Item) -> some View {
        HStack(spacing: 10) {
            Group {
                if let assetName = item.assetName, UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: item.name)
                    .font(.subheadline)
                    .lineLimit(2)
                if !item.detail.isEmpty {
                    Text(verbatim: item.detail)
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

extension RecipeConfirmationView where Header == EmptyView {
    init(recipe: ConfirmationRecipe) {
        self.init(recipe: recipe) { EmptyView() }
    }
}
