import CulinaryIntelligence
import SwiftUI

/// While the model works, the recipe goes away and the changes have the screen to themselves.
/// The recipe reads under them and grows as they land, so it scrolls rather than running off
/// the bottom.
struct RevisionProgressView: View {
    let progress: EditProgress

    var body: some View {
        ScrollView {
            EditProgressView(progress: progress)
                .padding(.listRowInset)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
