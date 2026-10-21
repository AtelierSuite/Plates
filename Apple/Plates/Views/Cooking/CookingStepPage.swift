import CulinaryIntelligence
import SwiftUI

/// One step filling the screen: its title in heavy type, what it works with as icons, its
/// points, and a timer for each wait it names.
struct CookingStepPage: View {
    let number: Int
    let count: Int
    let step: Step
    /// The recipe's ingredients and tools, for the amount under an icon and the name a tap shows.
    let items: [TileInfo]
    let timer: CookingTimer
    /// The wait the timer was started from on this step, whose button gives way to the controls.
    let runningDuration: Duration?
    /// Goes up each time the cook tries to move on while this step's timer runs.
    let shakes: Int
    let startTimer: (Duration) -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 46
    @State private var tapped: TileInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(String(format: String(localized: "Recipe.Cook.Step"), number, count))
                .font(.headline)
                .opacity(0.8)

            Text(verbatim: step.title)
                .font(.system(size: titleSize, weight: .heavy))
                .lineLimit(4)
                .minimumScaleFactor(0.5)

            if let icons = step.icons, !icons.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(icons, id: \.self) { icon in
                        iconTile(icon)
                    }
                }
            }

            // Long steps come down a size or two rather than running off the page.
            ViewThatFits(in: .vertical) {
                points(.title2)
                points(.title3)
                points(.body)
            }

            Spacer(minLength: 0)

            if !step.durations.isEmpty {
                timers
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(
            Text(verbatim: tapped?.name ?? ""),
            isPresented: Binding(get: { tapped != nil }, set: { if !$0 { tapped = nil } }),
            presenting: tapped
        ) { _ in
            Button("Shared.Done", role: .cancel) {}
        } message: { info in
            if !info.message.isEmpty {
                Text(verbatim: info.message)
            }
        }
    }

    private func iconTile(_ icon: String) -> some View {
        let item = items.first { $0.icon == icon }
        return Button {
            tapped = item
        } label: {
            VStack(spacing: 6) {
                RecipeIcon(path: icon, size: 48)
                    .padding(10)
                    .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 18, style: .continuous))
                if let amount = item?.detail, !amount.isEmpty {
                    Text(verbatim: amount)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(item == nil)
        .accessibilityLabel(Text(verbatim: [item?.name, item?.detail].compactMap { $0 }.joined(separator: ", ")))
    }

    private func points(_ font: Font) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(step.points, id: \.self) { point in
                Text(verbatim: point)
                    .font(font.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var timers: some View {
        VStack(spacing: 10) {
            ForEach(step.durations.prefix(3), id: \.self) { duration in
                if duration == runningDuration, timer.isSet {
                    CookingTimerBar(timer: timer)
                        .shaking(shakes)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    timerButton(duration)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .animation(.default, value: runningDuration)
        .animation(.default, value: timer.isSet)
    }

    private func timerButton(_ duration: Duration) -> some View {
        let text = duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
        return Button {
            startTimer(duration)
        } label: {
            Label {
                Text(verbatim: text)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "timer")
            }
            .font(.title.weight(.bold))
            // Drawn the way the bar is drawn, so the bar takes its place without a change in size.
            .frame(maxWidth: .infinity)
            .frame(height: CookingTimerBar.height)
            .contentShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(format: String(localized: "Recipe.Cook.Timer.Start"), text)))
    }
}

private extension View {
    /// A quick shake from side to side, the way a field turns down a wrong password.
    func shaking(_ trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-14, duration: 0.06)
                LinearKeyframe(14, duration: 0.08)
                LinearKeyframe(-10, duration: 0.08)
                LinearKeyframe(8, duration: 0.07)
                CubicKeyframe(0, duration: 0.12)
            }
        }
    }
}
