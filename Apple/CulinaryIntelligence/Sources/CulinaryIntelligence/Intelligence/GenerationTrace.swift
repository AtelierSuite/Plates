import Foundation

/// What one run of `RecipeGenerator.generate` did on its way to a recipe, kept for the
/// generation eval. The generator writes to one only when it is handed one, so a run in the app
/// records nothing.
final class GenerationTrace {
    /// The request as Gemma was given it, when the cook's words had to be put into English.
    var translation = ""
    /// Gemma's text as it arrived, kept piece by piece so a run that fails part way still has it.
    var draft = ""
    /// What the reading cut Gemma's text into.
    var written: WrittenRecipe?
    /// The same, after the picks the method never uses were dropped in code.
    var kept: WrittenRecipe?
    /// Set when `WrittenRecipe` could not split a section and it was sorted from the whole text.
    var sortedWholeShopping = false
    var sortedWholeMethod = false
    /// Set when code listed the oven because the method bakes in one Gemma did not list.
    var addedOven = false
    /// The recipe the run handed over, or nil when it failed.
    var recipe: Recipe?
    /// What stopped the run, when something did.
    var error: (any Error)?

    /// Whether Gemma stopped at the token limit. Nil means the run cannot tell. Set it where
    /// the Worker's finish reason reaches the app (PR #19, which ends a cut-off answer in
    /// `CloudError.cutOff`).
    var cutOff: Bool?

    /// What the draft consistency checks found wrong with Gemma's text, empty when it passed.
    /// Nil until those checks exist (issue #4); the generator sets it where they run.
    var draftCheckFailures: [String]?

    init() {}
}
