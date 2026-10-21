import CulinaryIntelligence
import SwiftUI

/// The changes filling in as the model makes them, with the recipe reading under them. The
/// first line is the model deciding what to change, and the lines under it are what it decided,
/// followed by the steps and notes put right for it. The checklist is only as long as the work
/// turned out to be.
struct EditProgressView: View {
    let progress: EditProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                row(state: progress.isPlanning ? .working : .done) {
                    Text("Edit.Progress.Planning")
                }

                // Change titles are written by the model, so they are shown as written.
                ForEach(progress.changes) { change in
                    row(state: state(of: change)) {
                        Text(verbatim: change.title)
                    }
                }
            }

            if !progress.title.isEmpty {
                RecipePreview(
                    title: progress.title,
                    time: progress.time,
                    serves: progress.serves,
                    steps: progress.steps
                )
            }
        }
        .animation(.default, value: progress)
    }

    private func state(of change: EditProgress.Change) -> ProgressMarkerState {
        switch change.state {
        case .waiting: .waiting
        case .working: progress.isFinished ? .done : .working
        case .done: .done
        }
    }

    private func row(
        state: ProgressMarkerState,
        @ViewBuilder label: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ProgressMarker(state: state)
            label()
            Spacer(minLength: 0)
        }
    }
}
