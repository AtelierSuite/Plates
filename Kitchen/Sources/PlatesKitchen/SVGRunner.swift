import Foundation

@MainActor
final class SVGRunner: ObservableObject {
    @Published var selectedModels: Set<String> = ["granite4-1b"]
    @Published var repetitions = 1
    @Published var concurrency = 2
    var assetFilter: Set<String> = []
    @Published var runs: [SVGRun] = [] { didSet { save() } }
    @Published var status = "Ready to evaluate recipe SVGs."
    @Published var isRunning = false

    let recipes: [SVGSampleRecipe]
    var serverPath = "/opt/homebrew/bin/llama-server"
    var modelDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Plates Kitchen/Models")
    private let outputURL: URL
    private var port = 0
    private var process: Process?
    private var task: Task<Void, Never>?
    private let scenePlanner = AppleScenePlanner()

    init(outputURL: URL? = nil) {
        recipes = (try? SVGSampleRecipe.load()) ?? []
        self.outputURL = outputURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Plates Kitchen/svg-session.json")
        if let data = try? Data(contentsOf: self.outputURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            runs = (try? decoder.decode([SVGRun].self, from: data)) ?? []
        }
    }

    var assets: [SVGSampleAsset] { recipes.flatMap(\.assets) }
    var appleSceneAvailable: Bool { scenePlanner.isAvailable }

    func startScenePlan() {
        guard !isRunning else { return }
        guard !recipes.isEmpty else { status = "Could not load the SVG sample recipes."; return }
        guard assetFilter.isEmpty || assets.contains(where: { assetFilter.contains($0.id) }) else {
            status = "No sample assets match the filter."
            return
        }
        guard appleSceneAvailable else { status = "Apple Intelligence is unavailable for scene planning."; return }
        do { try archiveIfNeeded() }
        catch { status = "Could not archive SVG results: \(error.localizedDescription)"; return }
        isRunning = true
        task = Task {
            status = "Apple scene plan: running up to \(min(concurrency, 4)) scenes at once"
            let selectedAssets = assets.filter { assetFilter.isEmpty || assetFilter.contains($0.id) }
            await EvalConcurrency.run(selectedAssets, limit: concurrency) { asset in
                await self.generateScene(asset)
            } onResult: { run in
                self.runs.append(run)
            }
            isRunning = false
            status = Task.isCancelled ? "Stopped. Completed scene plans are saved." : "Finished Apple scene plans. Review subject and action fidelity."
            task = nil
        }
    }

    private func generateScene(_ asset: SVGSampleAsset) async -> SVGRun {
        let start = Date.now
        var raw = ""
        var svg: String?
        var checks: [String] = []
        var errorText: String?
        do {
            let plan = try await scenePlanner.plan(for: asset)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            raw = String(decoding: try encoder.encode(plan), as: UTF8.self)
            let rendered = try SceneSVGRenderer.render(plan, for: asset)
            let svgChecks = SVGChecks.evaluate(rendered, asset: asset)
            checks = svgChecks + SceneChecks.evaluate(plan, for: asset)
            if svgChecks.isEmpty { svg = rendered }
        } catch { errorText = error.localizedDescription }
        return SVGRun(id: UUID(), modelID: "apple-scene", assetID: asset.id, recipeID: asset.recipeID,
                      kind: asset.kind, repetition: 1, startedAt: start,
                      durationSeconds: Date.now.timeIntervalSince(start), rawText: raw,
                      svg: svg, formatWarning: nil, checks: checks, error: errorText,
                      review: SVGReview())
    }

    func start() {
        guard !isRunning else { return }
        guard !recipes.isEmpty else { status = "Could not load the SVG sample recipes."; return }
        guard assetFilter.isEmpty || assets.contains(where: { assetFilter.contains($0.id) }) else {
            status = "No sample assets match the filter."
            return
        }
        guard FileManager.default.isExecutableFile(atPath: serverPath) else {
            status = "Choose an executable llama-server binary."
            return
        }
        let candidates = Candidate.all.filter { selectedModels.contains($0.id) }
        guard !candidates.isEmpty else { status = "Select at least one model."; return }
        guard candidates.allSatisfy({ FileManager.default.fileExists(atPath: modelDirectory.appendingPathComponent($0.fileName).path) }) else {
            status = "Download or select GGUF files for the selected models."
            return
        }
        do { try archiveIfNeeded() }
        catch { status = "Could not archive SVG results: \(error.localizedDescription)"; return }
        runs = []
        isRunning = true
        task = Task {
            for candidate in candidates {
                if Task.isCancelled { break }
                do {
                    try await launch(candidate)
                    let selectedAssets = assets.filter { assetFilter.isEmpty || assetFilter.contains($0.id) }
                    let jobs = selectedAssets.flatMap { asset in
                        (1...max(1, min(repetitions, 10))).map { SVGJob(asset: asset, repetition: $0) }
                    }
                    status = "\(candidate.name): running up to \(min(concurrency, 4)) SVGs at once"
                    await EvalConcurrency.run(jobs, limit: concurrency) { job in
                        await self.generate(candidate, asset: job.asset, repetition: job.repetition)
                    } onResult: { run in
                        self.runs.append(run)
                    }
                } catch {
                    status = "\(candidate.name): \(error.localizedDescription)"
                    runs.append(SVGRun(id: UUID(), modelID: candidate.id, assetID: "startup", recipeID: "", kind: .icon,
                                       repetition: 0, startedAt: .now, durationSeconds: 0, rawText: "", svg: nil,
                                       formatWarning: nil, checks: [], error: error.localizedDescription, review: SVGReview()))
                }
                stopServer()
            }
            isRunning = false
            status = Task.isCancelled ? "Stopped. Completed SVG results are saved." : "Finished \(runs.count) SVG trials. Review the drawings."
            task = nil
        }
    }

    func stop() { task?.cancel(); stopServer() }

    private func launch(_ candidate: Candidate) async throws {
        stopServer()
        port = try LocalServerPort.available()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: serverPath)
        process.arguments = ["-m", modelDirectory.appendingPathComponent(candidate.fileName).path,
                             "--host", "127.0.0.1", "--port", String(port),
                             "-c", String(4096 * max(1, min(concurrency, 4))),
                             "--parallel", String(max(1, min(concurrency, 4))), "-ngl", "99"]
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("plates-kitchen-svg-llama-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        self.process = process
        status = "Loading \(candidate.name)..."
        let health = URL(string: "http://127.0.0.1:\(port)/health")!
        for _ in 0..<120 {
            try Task.checkCancellation()
            if !process.isRunning { throw SVGRunnerError.serverStopped(log.path) }
            if let (_, response) = try? await URLSession.shared.data(from: health),
               (response as? HTTPURLResponse)?.statusCode == 200 { return }
            try await Task.sleep(for: .seconds(1))
        }
        throw SVGRunnerError.startupTimeout(log.path)
    }

    private func stopServer() {
        if let process, process.isRunning { process.terminate(); process.waitUntilExit() }
        process = nil
    }

    private func generate(_ candidate: Candidate, asset: SVGSampleAsset, repetition: Int) async -> SVGRun {
        let start = Date.now
        var raw = ""
        var errorText: String?
        do {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 180
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": candidate.name, "temperature": 0, "seed": 1000 + repetition,
                "max_tokens": 2000,
                "messages": [
                    ["role": "system", "content": SVGPrompt.system + (candidate.prefersNonThinkingMode ? "\n/no_think" : "")],
                    ["role": "user", "content": SVGPrompt.user(for: asset)]
                ]
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw SVGRunnerError.http(String(data: data, encoding: .utf8) ?? "Unknown response")
            }
            raw = try JSONDecoder().decode(SVGCompletion.self, from: data).choices.first?.message.content ?? ""
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw SVGRunnerError.empty }
        } catch { errorText = error.localizedDescription }
        let extracted = SVGChecks.extract(raw)
        let checks = errorText == nil ? SVGChecks.evaluate(extracted.svg, asset: asset) : []
        return SVGRun(id: UUID(), modelID: candidate.id, assetID: asset.id, recipeID: asset.recipeID,
                      kind: asset.kind, repetition: repetition, startedAt: start,
                      durationSeconds: Date.now.timeIntervalSince(start), rawText: raw,
                      svg: checks.isEmpty && errorText == nil ? extracted.svg : nil,
                      formatWarning: extracted.warning, checks: checks, error: errorText,
                      review: SVGReview())
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(runs).write(to: outputURL, options: .atomic)
        } catch { status = "Could not save SVG results: \(error.localizedDescription)" }
    }

    private func archiveIfNeeded() throws {
        guard !runs.isEmpty else { return }
        let archive = outputURL.deletingLastPathComponent()
            .appendingPathComponent("svg-before-\(Int(Date.now.timeIntervalSince1970))-\(UUID().uuidString).json")
        try Data(contentsOf: outputURL).write(to: archive, options: .atomic)
    }

    func export(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(runs).write(to: url, options: .atomic)
    }

    func importResults(from urls: [URL]) throws {
        try archiveIfNeeded()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var imported = runs
        var knownIDs = Set(imported.map(\.id))
        for url in urls {
            for run in try decoder.decode([SVGRun].self, from: Data(contentsOf: url)) where knownIDs.insert(run.id).inserted {
                imported.append(run)
            }
        }
        runs = imported
        status = "Imported \(runs.count) SVG trials."
    }
}

private struct SVGJob: Sendable {
    let asset: SVGSampleAsset
    let repetition: Int
}

enum SVGPrompt {
    static let system = """
        Compose one recognizable cookbook scene from the supplied SVG symbol shapes. Each symbol uses a 48 by 48 coordinate box. Copy its elements and colors into a separate <g transform="translate(x y) scale(s)">. Scale the main symbol to 2 or more so it fills most of the canvas; use smaller groups for food details. Use different positions for each group and overlap them naturally: food inside a pan or bowl, sauce on noodles, cheese between bread. Never paste unscaled 48-pixel symbols in a corner. Do not redraw symbols as rectangles, invent shapes, or repeat them in a grid. A plain light background is optional.
        Return only one complete SVG, no Markdown or text. Use only svg, g, rect, circle, ellipse, path, line, polyline, polygon. Use literal #RGB or #RRGGBB colors. No CSS, defs, images, external references, scripts, or animation. Close every tag.
        """

    static func user(for asset: SVGSampleAsset) -> String {
        let size = asset.size
        let objects = asset.expectedSymbols.map { symbol in
            symbol.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).lowercased()
        }.joined(separator: ", ")
        let references = asset.expectedSymbols.compactMap { symbol -> String? in
            guard let url = Bundle.module.url(forResource: symbol, withExtension: "svg", subdirectory: "Samples/Symbols"),
                  let svg = try? String(contentsOf: url, encoding: .utf8),
                  let start = svg.firstIndex(of: ">"),
                  let end = svg.range(of: "</svg>", options: .backwards)?.lowerBound else { return nil }
            return "\(symbol): \(svg[svg.index(after: start)..<end].trimmingCharacters(in: .whitespacesAndNewlines))"
        }.joined(separator: "\n")
        return """
            Scene: \(asset.subject).
            Required visible objects: \(objects).
            \(asset.kind == .icon ? "Show one finished dish." : "Show one cooking step.")
            Symbol shapes to use (copy the elements inside each named symbol):
            \(references)
            Start exactly with <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(size.width) \(size.height)"> and end with </svg>.
            Include every required object, arranged as one scene. Do not add other foods, tools, letters, or captions.
            """
    }
}

private struct SVGCompletion: Decodable {
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String? }
    let choices: [Choice]
}

private enum SVGRunnerError: LocalizedError {
    case serverStopped(String), startupTimeout(String), http(String), empty
    var errorDescription: String? {
        switch self {
        case .serverStopped(let log): "llama-server stopped. See \(log)"
        case .startupTimeout(let log): "Model did not load within two minutes. See \(log)"
        case .http(let response): "SVG request failed: \(response)"
        case .empty: "The model returned an empty SVG"
        }
    }
}
