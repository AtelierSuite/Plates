import Foundation
import Testing
@testable import CulinaryIntelligence

/// The generation eval: every request in `EvalRequests` in the reader's language, through
/// `RecipeGenerator.generate`, with Gemma writing on the Worker and Apple Intelligence sorting
/// on the device. It sends real requests to both models, so it only runs when asked to.
///
/// Run it once per language in Simulator, against `npm run dev` in `Cloud/`:
///
/// ```sh
/// TEST_RUNNER_PLATES_EVAL=1 \
/// TEST_RUNNER_PLATES_EVAL_RUNS=3 \
/// TEST_RUNNER_PLATES_EVAL_OUTPUT=/tmp/generation-eval-en.json \
/// TEST_RUNNER_PLATES_CLOUD_URL=http://localhost:8788 \
/// xcodebuild test -scheme CulinaryIntelligence \
///     -destination 'platform=iOS Simulator,id=<device>' \
///     -testLanguage en -testRegion US \
///     -only-testing:CulinaryIntelligenceTests/GenerationEvalTests
/// ```
///
/// `-testLanguage ja -testRegion JP` runs the Japanese requests. `PLATES_EVAL_IDS` takes a
/// comma separated list of request IDs to run only those.
@Suite(.serialized)
struct GenerationEvalTests {
    private static let environment = ProcessInfo.processInfo.environment

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PLATES_EVAL"] == "1"), .timeLimit(.minutes(600)))
    func generateEveryRequest() async throws {
        let language: EvalRequest.Language = Measures.readsJapanese ? .japanese : .english
        let only = Self.environment["PLATES_EVAL_IDS"].map { Set($0.split(separator: ",").map(String.init)) }
        let requests = EvalRequests.all.filter { $0.language == language && (only?.contains($0.id) ?? true) }
        let repetitions = Self.environment["PLATES_EVAL_RUNS"].flatMap(Int.init) ?? 1
        let output = URL(filePath: Self.environment["PLATES_EVAL_OUTPUT"]
            ?? NSTemporaryDirectory() + "generation-eval-\(language.rawValue).json")
        #expect(!requests.isEmpty)

        Plates.shared.isAllowed = true
        let generator = RecipeGenerator()
        try #require(generator.isAvailable, "Apple Intelligence or the Worker is not available")

        let startedAt = Date.now
        var runs: [EvalRun] = []
        for run in 1...repetitions {
            for request in requests {
                let trace = GenerationTrace()
                generator.trace = trace
                let clock = ContinuousClock.now
                _ = await generator.generate(request.request)
                let elapsed = ContinuousClock.now - clock
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                runs.append(EvalRun(request: request, run: run, seconds: seconds, trace: trace))
                // Saved after every run, so a run stopped part way keeps what it has.
                try Self.save(EvalReport(language: language, startedAt: startedAt, summary: EvalSummary(runs), runs: runs), to: output)
                print("[generation-eval] \(request.id) run \(run): \(trace.recipe == nil ? "failed" : "done") in \(Int(seconds))s")
            }
        }
        print("[generation-eval] wrote \(output.path(percentEncoded: false))")
    }

    private static func save(_ report: EvalReport, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: url, options: .atomic)
    }
}
