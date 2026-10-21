import CulinaryIntelligence
import SwiftUI

/// The timer while it is set. It takes the place of the button it was started from, and is
/// kept along the bottom of every other step so it can be read and paused from anywhere.
struct CookingTimerBar: View {
    /// The height of the bar, which the button it replaces matches so nothing moves.
    static let height: CGFloat = 72

    let timer: CookingTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let isFinished = timer.isFinished(at: context.date)
            HStack(spacing: 12) {
                Image(systemName: isFinished ? "bell.fill" : "timer")
                    .font(.title2)
                    .symbolEffect(.wiggle, options: .repeat(.continuous), isActive: isFinished)

                Group {
                    if isFinished {
                        Text("Recipe.Cook.Timer.Finished")
                    } else {
                        Text(verbatim: Self.clock(timer.remaining(at: context.date)))
                            .monospacedDigit()
                    }
                }
                .font(.title.weight(.bold))
                .contentTransition(.numericText(countsDown: true))
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Recipe.Cook.Timer.AddMinute", systemImage: "goforward.60") {
                    timer.addMinute()
                }

                if !isFinished {
                    if timer.isRunning {
                        Button("Recipe.Cook.Timer.Pause", systemImage: "pause.fill") {
                            timer.pause()
                        }
                    } else {
                        Button("Recipe.Cook.Timer.Resume", systemImage: "play.fill") {
                            timer.resume()
                        }
                    }
                }

                Button("Recipe.Cook.Timer.Stop", systemImage: "xmark") {
                    timer.stop()
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .frame(height: Self.height)
            .glassEffect(isFinished ? .regular.tint(.red) : .regular, in: .capsule)
        }
    }

    /// The time left as a kitchen timer shows it: "4:05", or "1:20:00" past the hour.
    private static func clock(_ remaining: Duration) -> String {
        remaining.formatted(
            remaining >= .seconds(3600)
                ? .time(pattern: .hourMinuteSecond)
                : .time(pattern: .minuteSecond)
        )
    }
}
