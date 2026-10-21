import SwiftUI

/// A ring with a gap in it, turning while the model works on that line. It sits where the
/// line's checkmark goes, so nothing shifts when the work finishes.
struct DonutSpinner: View {
    @State private var isTurning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(.secondary, style: StrokeStyle(lineWidth: .markerLineWidth, lineCap: .round))
            .padding(.markerLineWidth / 2)
            .rotationEffect(.degrees(isTurning ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isTurning)
            .frame(width: .markerSize, height: .markerSize)
            .onAppear { isTurning = true }
    }
}
