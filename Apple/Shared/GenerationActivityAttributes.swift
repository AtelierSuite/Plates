import ActivityKit
import Foundation

/// What the Live Activity shows while a recipe is being written. The app localizes every
/// string before it goes in here, so the widget never looks a key up for itself. It is handed
/// to ActivityKit off the main actor, so it stays out of any actor of its own.
nonisolated struct GenerationActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// The pass that is running, in the cook's language.
        var stage: String
        /// The dish, once the model has named it.
        var dish: String?
        /// How far along the recipe is, from 0 to 1.
        var fraction: Double
        /// What to say when there is no more work: the recipe landed, or it did not.
        var outcome: String?
    }

    /// When the cook asked for the recipe.
    var startedAt: Date
}
