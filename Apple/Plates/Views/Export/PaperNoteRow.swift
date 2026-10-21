import CulinaryIntelligence
import SwiftUI
import UIKit

struct PaperNoteRow: View {
    let note: Troubleshooting

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: note.problem)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.paperInk)
            Text(verbatim: note.solution)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.paperSoft)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paperTint, in: .rect(cornerRadius: 10))
    }
}
