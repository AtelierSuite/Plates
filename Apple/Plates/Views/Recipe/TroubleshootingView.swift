import CulinaryIntelligence
import SwiftUI

/// The troubleshooting entries, kept off the recipe page and opened from the bottom bar.
struct TroubleshootingView: View {
    @Environment(\.dismiss) private var dismiss

    let entries: [Troubleshooting]

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: entry.problem)
                        .font(.headline)
                    Text(verbatim: entry.solution)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Recipe.Detail.Troubleshooting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Shared.Done") { dismiss() }
                }
            }
        }
    }
}
