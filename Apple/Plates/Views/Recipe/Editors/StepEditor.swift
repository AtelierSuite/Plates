import CulinaryIntelligence
import SwiftUI

/// The sheet behind a step: what it is called, what it reaches for, and what to do. The icons
/// are ticked off the recipe's own lists, so a step never shows something the recipe does not
/// carry.
struct StepEditor: View {
    /// One icon a step can be marked with, drawn from the recipe's ingredients and tools.
    struct Choice: Identifiable, Hashable {
        let path: String
        let name: String

        var id: String { path }
    }

    let choices: [Choice]
    let save: (Step) -> Void
    let remove: () -> Void

    @State private var draft: Step
    @State private var points: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    init(
        step: Step,
        choices: [Choice],
        save: @escaping (Step) -> Void,
        remove: @escaping () -> Void
    ) {
        self.choices = choices
        self.save = save
        self.remove = remove
        _draft = State(initialValue: step)
        _points = State(initialValue: step.points.joined(separator: "\n"))
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Step.Title", remove: remove) {
            var step = draft
            step.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            step.points = points
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            step.icons = (step.icons?.isEmpty ?? true) ? nil : step.icons
            save(step)
        } content: {
            Section {
                TextField("Recipe.Edit.Step.Name", text: $draft.title, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section {
                TextField("Recipe.Edit.Step.Points", text: $points, axis: .vertical)
                    .lineLimit(4...12)
            } footer: {
                Text("Recipe.Edit.Step.Points.Footer")
            }

            if !choices.isEmpty {
                Section("Recipe.Edit.Step.Icons") {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(choices) { choice in
                            cell(choice)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                }
            }
        }
    }

    private func cell(_ choice: StepEditor.Choice) -> some View {
        let isPicked = draft.icons?.contains(choice.path) ?? false
        return Button {
            var icons = draft.icons ?? []
            if let index = icons.firstIndex(of: choice.path) {
                icons.remove(at: index)
            } else {
                icons.append(choice.path)
            }
            draft.icons = icons
        } label: {
            VStack(spacing: 4) {
                RecipeIcon(path: choice.path, size: 44, outline: isPicked ? .accentColor : nil)
                Text(verbatim: choice.name)
                    .font(.caption)
                    .fontWeight(isPicked ? .semibold : .regular)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isPicked ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
