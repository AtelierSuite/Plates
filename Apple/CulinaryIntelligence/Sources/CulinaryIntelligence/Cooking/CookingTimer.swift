import Foundation
import Observation

/// The one timer kept while a recipe is cooked. It runs on while the cook moves between steps,
/// and keeps the time it ends at rather than counting down, so it stays right while the app is
/// in the background.
@Observable
public final class CookingTimer {
    /// How long the timer was set for, or nil when no timer is set.
    public private(set) var length: Duration?
    /// When a running timer reaches zero. Nil while it is paused or not set.
    public private(set) var endDate: Date?
    /// What was left when the timer was paused.
    private var pausedRemaining: Duration = .zero

    public init() {}

    public var isSet: Bool { length != nil }

    public var isRunning: Bool { endDate != nil }

    /// The time left at a moment, never below zero.
    public func remaining(at date: Date = .now) -> Duration {
        guard let endDate else { return pausedRemaining }
        return .seconds(max(0, endDate.timeIntervalSince(date).rounded(.up)))
    }

    public func isFinished(at date: Date = .now) -> Bool {
        isSet && remaining(at: date) == .zero
    }

    /// Sets the timer and starts it at once.
    public func start(_ duration: Duration) {
        length = duration
        endDate = Date.now.addingTimeInterval(duration.seconds)
    }

    public func pause() {
        guard isRunning else { return }
        pausedRemaining = remaining()
        endDate = nil
    }

    public func resume() {
        guard isSet, !isRunning, pausedRemaining > .zero else { return }
        endDate = Date.now.addingTimeInterval(pausedRemaining.seconds)
    }

    /// A minute more, for food that is not done when the timer goes off.
    public func addMinute() {
        guard isSet else { return }
        if let endDate {
            self.endDate = max(endDate, .now).addingTimeInterval(60)
        } else {
            pausedRemaining += .seconds(60)
        }
    }

    public func stop() {
        length = nil
        endDate = nil
        pausedRemaining = .zero
    }
}

private extension Duration {
    var seconds: TimeInterval {
        TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}
