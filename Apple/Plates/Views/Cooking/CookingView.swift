import AudioToolbox
import CulinaryIntelligence
import SwiftUI

/// The recipe as it is cooked: one step to a screen, scrolled through upwards, with a timer that
/// runs on from step to step. The screen is kept awake the whole time, since hands are busy.
struct CookingView: View {
    let recipe: Recipe
    /// Marks the recipe as tried from the last page. Nil when the recipe has nowhere to be saved.
    let markTried: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var timer = CookingTimer()
    /// The step and wait the timer was started from, where its controls take the button's place.
    @State private var timerSource: TimerSource?
    /// The page on screen, so the timer is kept along the bottom of every other page.
    @State private var page: Int?
    @State private var rings = 0
    /// Counts the times the cook tried to move on while the step's timer ran, to shake it each time.
    @State private var shakes = 0
    @State private var hasShaken = false
    @State private var isShowingTroubleshooting = false

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        CookingStepPage(
                            number: index + 1,
                            count: recipe.steps.count,
                            step: step,
                            items: items,
                            timer: timer,
                            runningDuration: timerSource?.step == index ? timerSource?.duration : nil,
                            shakes: timerSource?.step == index ? shakes : 0,
                            startTimer: { duration in
                                timerSource = TimerSource(step: index, duration: duration)
                                timer.start(duration)
                            }
                        )
                        .page(insets: insets, background: .step(step.title))
                        .overlay(alignment: .bottom) {
                            swipeHint(isLast: index == recipe.steps.count - 1)
                                .padding(.bottom, insets.bottom)
                        }
                    }

                    finished
                        .page(insets: insets, background: .step(recipe.title))
                        .id(recipe.steps.count)
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $page)
            .scrollDisabled(isHeld)
            .simultaneousGesture(holdGesture, including: isHeld ? .all : .subviews)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) {
            if timer.isSet, timerSource?.step != page ?? 0 {
                CookingTimerBar(timer: timer)
                    .padding(.horizontal, CookingView.pageMargin)
                    .padding(.bottom, Self.hintHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: timer.isSet)
        .animation(.default, value: page)
        .onChange(of: timer.isSet) {
            if !timer.isSet { timerSource = nil }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingTroubleshooting) {
            TroubleshootingView(entries: recipe.troubleshooting)
        }
        // Goes off once when a running timer reaches zero, wherever the cook has scrolled to.
        .task(id: timer.endDate) {
            guard let end = timer.endDate else { return }
            try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            rings += 1
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
        .sensoryFeedback(.warning, trigger: rings)
        .sensoryFeedback(.error, trigger: shakes)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var currentPage: Int { page ?? 0 }

    /// Whether the step on screen is held until its timer is done. A paused or finished timer
    /// lets the cook move on; the ring when it finishes draws the page again to let go.
    private var isHeld: Bool {
        timerSource?.step == currentPage && timer.isRunning && !timer.isFinished()
    }

    /// While a step is held, a swipe up shakes its timer instead of moving on, and a swipe
    /// down still goes back a step.
    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard !hasShaken, value.translation.height < -24 else { return }
                hasShaken = true
                shakes += 1
            }
            .onEnded { value in
                hasShaken = false
                if value.translation.height > 60, currentPage > 0 {
                    withAnimation { page = currentPage - 1 }
                }
            }
    }

    /// The space either side of a page's content, which the floating timer keeps to as well.
    fileprivate static let pageMargin: CGFloat = 24

    /// The room the swipe hint takes along the bottom of a step, which the timer sits above.
    fileprivate static let hintHeight: CGFloat = 44

    /// A nudge along the very bottom of a step that there is more above the thumb.
    private func swipeHint(isLast: Bool) -> some View {
        VStack(spacing: 4) {
            Text(isLast ? "Recipe.Cook.Swipe.Finish" : "Recipe.Cook.Swipe.Next")
                .font(.footnote.weight(.semibold))
            Image(systemName: "chevron.compact.down")
                .font(.title2)
        }
        // Lifts, drops back with a bounce, then rests a moment before the next lift.
        .keyframeAnimator(initialValue: 0.0, repeating: true) { content, lift in
            content.offset(y: lift)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-8, duration: 0.3)
                SpringKeyframe(0, duration: 0.6, spring: .bouncy(duration: 0.45, extraBounce: 0.3))
                LinearKeyframe(0, duration: 1.4)
            }
        }
        .foregroundStyle(.white.opacity(0.75))
        .frame(height: Self.hintHeight)
        .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Label {
                    Text("Recipe.Cook.Close")
                } icon: {
                    topBarIcon("xmark", font: .title3)
                }
            }

            Spacer()

            if !recipe.troubleshooting.isEmpty {
                Button {
                    isShowingTroubleshooting = true
                } label: {
                    Label {
                        Text("Recipe.Detail.Troubleshooting")
                    } icon: {
                        topBarIcon("questionmark")
                    }
                }
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding(.horizontal, 16)
    }

    /// A glyph drawn over a hidden xmark at the usual size, so both circles in the top bar are
    /// the same size whatever glyph or font is drawn in them.
    private func topBarIcon(_ systemName: String, font: Font? = nil) -> some View {
        Image(systemName: "xmark")
            .hidden()
            .overlay {
                Image(systemName: systemName)
                    .font(font)
            }
    }

    /// The page after the last step: the dish, and the way back out.
    private var finished: some View {
        VStack(spacing: 28) {
            Spacer()
            DishIcon(recipe: recipe, size: 200)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            Text("Recipe.Cook.Finished")
                .font(.largeTitle.weight(.heavy))
            Text(verbatim: recipe.title)
                .font(.title3.weight(.medium))
                .opacity(0.8)
            Spacer()
            if let markTried, recipe.tried != true {
                Button {
                    markTried()
                    dismiss()
                } label: {
                    Text("Recipe.Cook.MarkTried")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            Button {
                dismiss()
            } label: {
                Text("Shared.Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// Every ingredient and tool the recipe lists, so a step's icon can be named and measured.
    private var items: [TileInfo] {
        RecipeList.allCases.flatMap { recipe.items(in: $0) }
    }
}

/// Where a timer was started from: which step, and which of the waits it names.
private struct TimerSource: Equatable {
    let step: Int
    let duration: Duration
}

private extension View {
    /// Fills one screen of the pager in a colour that runs to the edges, with the content kept
    /// clear of the top buttons, the timer, and the device's own edges.
    func page(insets: EdgeInsets, background: Color) -> some View {
        padding(.horizontal, CookingView.pageMargin)
            .padding(.top, insets.top + 64)
            .padding(.bottom, insets.bottom + CookingView.hintHeight + 92)
            .containerRelativeFrame([.horizontal, .vertical])
            .background(background)
    }
}
