import Foundation

/// What the lock screen is told about a run: the pass that is running, what is being cooked,
/// and how far along it is. Writing a recipe and rewriting one each work this out their own
/// way, and the app shows either.
public struct ActivityProgress: Equatable, Sendable {
    /// The pass that is running, already in the cook's language.
    public var stage: String
    /// The dish, once there is one to name.
    public var dish: String?
    public var fraction: Double

    public init(stage: String, dish: String?, fraction: Double) {
        self.stage = stage
        self.dish = dish
        self.fraction = fraction
    }
}

/// Where a run reports how far along it is. The app hands one in to drive its Live Activity,
/// so the package never reaches for ActivityKit itself.
public protocol RunObserver: AnyObject {
    func runStarted(_ progress: ActivityProgress)
    func runUpdated(_ progress: ActivityProgress)
    func runEnded(_ progress: ActivityProgress, succeeded: Bool)
}
