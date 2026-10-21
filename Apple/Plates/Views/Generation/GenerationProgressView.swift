import CulinaryIntelligence
import SwiftUI

/// The recipe filling in, stage by stage, while the model writes it. The checklist is on top
/// and the recipe reads under it, so the cook watches the work and the writing in one place.
struct GenerationProgressView: View {
    let progress: GenerationProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // A recipe off a web page was written by the page, and has no fixes to sort.
                row(
                    progress.readsPage ? "Import.Progress.Row.Read" : "Generate.Progress.Row.Write",
                    count: 0,
                    stage: .write
                )
                row("Generate.Progress.Row.Ingredients", count: progress.ingredientCount, stage: .shopping)
                row("Generate.Progress.Row.Tools", count: progress.toolCount, stage: .shopping)
                row("Generate.Progress.Row.Steps", count: progress.stepCount, stage: .method)
                if !progress.readsPage {
                    row(
                        "Generate.Progress.Row.Troubleshooting",
                        count: progress.troubleshootingCount,
                        stage: .method
                    )
                }
            }
            .animation(.default, value: progress)

            preview
                .animation(.default, value: progress.stage)
                .animation(.default, value: progress.title)
                .animation(.default, value: progress.outline)
                .animation(.default, value: progress.ingredients)
                .animation(.default, value: progress.tools)
                .animation(.default, value: progress.problems)
        }
    }

    /// The recipe as it stands, under the checklist. While Gemma writes, that is its text as
    /// it comes; once Apple Intelligence starts sorting it, it is the recipe the sorting has made.
    @ViewBuilder private var preview: some View {
        if progress.stage == .write {
            if !progress.draft.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(verbatim: paragraph)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        } else if let heading = progress.title, !heading.isEmpty {
            RecipePreview(
                title: heading,
                time: progress.time ?? "",
                serves: progress.serves ?? "",
                ingredients: progress.ingredients,
                tools: progress.tools,
                steps: progress.outline,
                problems: progress.problems
            )
        }
    }

    /// Gemma's text split at its blank lines, so a finished paragraph is not laid out again.
    private var paragraphs: [String] {
        progress.draft
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Where a line has got to: spinning while its pass is the one running, ticked once that
    /// pass is behind it.
    private func marker(for stage: GenerationProgress.Stage) -> ProgressMarkerState {
        if progress.isFinished { return .done }
        if progress.stage == stage { return .working }
        return progress.stage.rawValue > stage.rawValue ? .done : .waiting
    }

    /// One line of the checklist, spinning while its pass is the one running.
    private func row(
        _ label: LocalizedStringResource,
        count: Int,
        stage: GenerationProgress.Stage
    ) -> some View {
        HStack(spacing: 8) {
            ProgressMarker(state: marker(for: stage))
            Text(label)
            Spacer(minLength: 0)
            if count > 0 {
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }
}
