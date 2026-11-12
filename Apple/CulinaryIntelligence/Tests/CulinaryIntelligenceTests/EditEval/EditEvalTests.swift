import Foundation
import Testing
@testable import CulinaryIntelligence

/// The edit eval: every request in `EditEvalRequests` in the reader's language, through the
/// real `RecipeAskEditor` on its sample recipe, with Apple Intelligence on the device. It sends
/// real requests to the model, so it only runs when asked to. The editor never reaches the
/// Worker, so nothing else needs to be running.
///
/// Run it once per language in Simulator, on a Mac with Apple Intelligence turned on:
///
/// ```sh
/// TEST_RUNNER_PLATES_EVAL=1 \
/// TEST_RUNNER_PLATES_EVAL_RUNS=3 \
/// TEST_RUNNER_PLATES_EVAL_OUTPUT=/tmp/edit-eval-en.json \
/// xcodebuild test -scheme CulinaryIntelligence \
///     -destination 'platform=iOS Simulator,id=<device>' \
///     -testLanguage en -testRegion US \
///     -only-testing:CulinaryIntelligenceTests/EditEvalTests
/// ```
///
/// `-testLanguage ja -testRegion JP` runs the Japanese requests on the `ja.lproj` samples.
/// `PLATES_EVAL_IDS` takes a comma separated list of request IDs to run only those.
@Suite(.serialized)
struct EditEvalTests {
    private static let environment = ProcessInfo.processInfo.environment

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PLATES_EVAL"] == "1"), .timeLimit(.minutes(600)))
    func editEveryRequest() async throws {
        let language: EditEvalRequest.Language = Measures.readsJapanese ? .japanese : .english
        let only = Self.environment["PLATES_EVAL_IDS"].map { Set($0.split(separator: ",").map(String.init)) }
        let requests = EditEvalRequests.all.filter { $0.language == language && (only?.contains($0.id) ?? true) }
        let repetitions = Self.environment["PLATES_EVAL_RUNS"].flatMap(Int.init) ?? 1
        let output = URL(filePath: Self.environment["PLATES_EVAL_OUTPUT"]
            ?? NSTemporaryDirectory() + "edit-eval-\(language.rawValue).json")
        #expect(!requests.isEmpty)

        let editor = RecipeAskEditor()
        try #require(editor.isAvailable, "Apple Intelligence is not available")

        let startedAt = Date.now
        var runs: [EditEvalRun] = []
        for run in 1...repetitions {
            for request in requests {
                let original = try EditEvalSamples.recipe(request.recipe, in: language)
                let clock = ContinuousClock.now
                // The two halves of `revise`, so the plan can be kept as well as the result.
                await editor.prepare(original, request: request.request)
                let plan = editor.proposedEdits
                let edited = await editor.applyApprovedPlan()
                let elapsed = ContinuousClock.now - clock
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                var error: String?
                if case let .failed(message) = editor.state { error = message }
                if case .awaitingApproval = editor.state { editor.discardPlan() }
                let result = EditEvalRun(
                    request: request,
                    run: run,
                    seconds: seconds,
                    plan: plan,
                    original: original,
                    edited: edited,
                    error: error
                )
                runs.append(result)
                // Saved after every run, so a run stopped part way keeps what it has.
                try Self.save(
                    EditEvalReport(language: language, startedAt: startedAt, summary: EditEvalSummary(runs), runs: runs),
                    to: output
                )
                let outcome = result.score.map { score in
                    "\(score.met ? "met" : "missed"), \(score.collateral.count) collateral"
                } ?? "failed"
                print("[edit-eval] \(request.id) run \(run): \(outcome) in \(Int(seconds))s")
            }
        }
        print("[edit-eval] wrote \(output.path(percentEncoded: false))")
    }

    private static func save(_ report: EditEvalReport, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: url, options: .atomic)
    }
}
