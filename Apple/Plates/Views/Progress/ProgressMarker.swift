import SwiftUI

/// The mark at the head of a checklist line. Every state is drawn in the same circle, so
/// nothing shifts when a line finishes.
struct ProgressMarker: View {
    let state: ProgressMarkerState

    var body: some View {
        switch state {
        case .working:
            DonutSpinner()
        case .waiting, .done:
            Image(systemName: state == .done ? "checkmark.circle.fill" : "circle.dotted")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: .markerSize, height: .markerSize)
        }
    }
}
