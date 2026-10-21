import ActivityKit
import CulinaryIntelligence
import Foundation

/// Runs the Live Activity that shows the model at work, so the cook can leave the app and
/// still watch it fill in on the lock screen. Every string is localized before it gets here,
/// because the widget draws what it is handed.
@MainActor
final class GenerationActivity: RunObserver {
    private var activity: Activity<GenerationActivityAttributes>?

    /// What the activity says when the run lands, and when it does not.
    private let done: LocalizedStringResource
    private let failed: LocalizedStringResource

    /// The fraction last sent. An update is not free, so the bar moves in steps rather than on
    /// every token.
    private var lastFraction = -1.0

    /// How far the bar has to move before another update is worth sending.
    private static let step = 0.05

    /// How long a state stands before the system treats it as out of date.
    private static let staleAfter: TimeInterval = 300

    init(done: LocalizedStringResource, failed: LocalizedStringResource) {
        self.done = done
        self.failed = failed
    }

    /// The activity for writing a new recipe.
    static var generation: GenerationActivity {
        GenerationActivity(done: "Generate.Activity.Done", failed: "Generate.Activity.Failed")
    }

    /// The activity for rewriting one the cook already has.
    static var edit: GenerationActivity {
        GenerationActivity(done: "Edit.Activity.Done", failed: "Edit.Activity.Failed")
    }

    func runStarted(_ progress: ActivityProgress) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(
            attributes: GenerationActivityAttributes(startedAt: .now),
            content: Self.content(for: progress)
        )
        lastFraction = progress.fraction
    }

    /// Sent whenever the pass changes, and otherwise only once the bar has moved far enough to
    /// be worth showing.
    func runUpdated(_ progress: ActivityProgress) {
        guard let activity else { return }
        let state = Self.state(progress)
        guard state.stage != activity.content.state.stage
            || state.dish != activity.content.state.dish
            || abs(state.fraction - lastFraction) >= Self.step
        else { return }
        lastFraction = state.fraction
        Task { await activity.update(Self.content(for: progress)) }
    }

    /// Ends the activity on how it turned out, leaving it up long enough to be read.
    func runEnded(_ progress: ActivityProgress, succeeded: Bool) {
        guard let activity else { return }
        self.activity = nil
        lastFraction = -1
        var state = Self.state(progress)
        state.outcome = String(localized: succeeded ? done : failed)
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(.now.addingTimeInterval(5))
            )
        }
    }

    private static func content(
        for progress: ActivityProgress
    ) -> ActivityContent<GenerationActivityAttributes.ContentState> {
        ActivityContent(
            state: state(progress),
            staleDate: .now.addingTimeInterval(staleAfter)
        )
    }

    private static func state(
        _ progress: ActivityProgress
    ) -> GenerationActivityAttributes.ContentState {
        GenerationActivityAttributes.ContentState(
            stage: progress.stage,
            dish: progress.dish,
            fraction: progress.fraction,
            outcome: nil
        )
    }
}
