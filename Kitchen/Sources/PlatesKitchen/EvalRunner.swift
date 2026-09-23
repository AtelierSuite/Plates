import Foundation

@MainActor
final class EvalRunner: ObservableObject {
    @Published var serverPath = UserDefaults.standard.string(forKey: "serverPath") ?? ""
    @Published var modelPaths = UserDefaults.standard.dictionary(forKey: "modelPaths") as? [String: String] ?? [:]
    @Published var selectedModels: Set<String> = ["gemma3-1b", "granite4-1b", "lfm25-12b", "lfm25-jp"]
    @Published var repetitions = 3
    @Published var runs: [EvalRun] = [] {
        didSet { saveSession() }
    }
    @Published var status = "Choose llama-server and the GGUF files to begin."
    @Published var isRunning = false

    private var process: Process?
    private var task: Task<Void, Never>?
    private let port = 12783

    init() {
        if let data = try? Data(contentsOf: Self.sessionURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            runs = (try? decoder.decode([EvalRun].self, from: data)) ?? []
            if !runs.isEmpty { status = "Restored \(runs.count) saved runs." }
        }
    }

    private static var sessionURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Plates Kitchen/session.json")
    }

    private func saveSession() {
        let file = Self.sessionURL
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(runs) { try? data.write(to: file, options: .atomic) }
    }

    func setServer(_ url: URL) {
        serverPath = url.path
        UserDefaults.standard.set(serverPath, forKey: "serverPath")
    }

    func setModel(_ url: URL, for candidate: Candidate) {
        modelPaths[candidate.id] = url.path
        UserDefaults.standard.set(modelPaths, forKey: "modelPaths")
    }

    func start() {
        guard !isRunning else { return }
        guard FileManager.default.isExecutableFile(atPath: serverPath) else {
            status = "Choose an executable llama-server binary."
            return
        }
        let candidates = Candidate.all.filter { selectedModels.contains($0.id) }
        guard !candidates.isEmpty else { status = "Select at least one model."; return }
        guard candidates.allSatisfy({ FileManager.default.fileExists(atPath: modelPaths[$0.id] ?? "") }) else {
            status = "Choose a GGUF file for each selected model."
            return
        }
        runs = []
        isRunning = true
        task = Task {
            for candidate in candidates {
                if Task.isCancelled { break }
                do {
                    try await launch(candidate)
                    for testCase in EvalCase.all {
                        for language in EvalLanguage.allCases {
                            for repetition in 1...max(1, min(repetitions, 10)) {
                                if Task.isCancelled { break }
                                status = "\(candidate.name): \(testCase.title), \(language.rawValue), run \(repetition)"
                                let run = await generate(candidate, testCase, language, repetition)
                                runs.append(run)
                            }
                            if Task.isCancelled { break }
                        }
                        if Task.isCancelled { break }
                    }
                } catch {
                    status = "\(candidate.name): \(error.localizedDescription)"
                    runs.append(EvalRun(id: UUID(), modelID: candidate.id, modelFile: modelPaths[candidate.id] ?? "", caseID: "startup", language: .english, repetition: 0, startedAt: .now, durationSeconds: 0, rawText: "", recipe: nil, checks: [], error: error.localizedDescription, review: Review()))
                }
                stopServer()
            }
            isRunning = false
            status = Task.isCancelled ? "Stopped. Results so far are available." : "Finished \(runs.count) runs. Review and export the results."
            task = nil
        }
    }

    func stop() {
        task?.cancel()
        stopServer()
    }

    private func launch(_ candidate: Candidate) async throws {
        stopServer()
        let executable = URL(fileURLWithPath: serverPath)
        let weights = modelPaths[candidate.id]!
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-m", weights, "--host", "127.0.0.1", "--port", String(port), "-c", "4096", "-ngl", "99"]
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("plates-kitchen-llama.log")
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
            if !process.isRunning { throw RunnerError.serverStopped(log.path) }
            if let (_, response) = try? await URLSession.shared.data(from: health),
               (response as? HTTPURLResponse)?.statusCode == 200 { return }
            try await Task.sleep(for: .seconds(1))
        }
        throw RunnerError.startupTimeout(log.path)
    }

    private func stopServer() {
        if let process, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        process = nil
    }

    private func generate(_ candidate: Candidate, _ testCase: EvalCase, _ language: EvalLanguage, _ repetition: Int) async -> EvalRun {
        let start = Date.now
        var raw = ""
        var recipe: EvalRecipe?
        var errorText: String?
        var checks: [String] = []
        do {
            let url = URL(string: "http://127.0.0.1:\(port)/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 180
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": candidate.name,
                "temperature": 0.7,
                "seed": 1000 + repetition,
                "max_tokens": 1400,
                "messages": [
                    ["role": "system", "content": Prompt.system(language: language)],
                    ["role": "user", "content": testCase.request(in: language)]
                ]
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw RunnerError.http(String(data: data, encoding: .utf8) ?? "Unknown response")
            }
            let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
            raw = completion.choices.first?.message.content ?? ""
            guard let json = Self.extractJSON(raw).data(using: .utf8) else { throw RunnerError.invalidJSON }
            recipe = try JSONDecoder().decode(EvalRecipe.self, from: json)
            checks = RecipeChecks.evaluate(recipe!, caseID: testCase.id)
        } catch {
            errorText = error.localizedDescription
        }
        return EvalRun(id: UUID(), modelID: candidate.id, modelFile: modelPaths[candidate.id] ?? "", caseID: testCase.id, language: language, repetition: repetition, startedAt: start, durationSeconds: Date.now.timeIntervalSince(start), rawText: raw, recipe: recipe, checks: checks, error: errorText, review: Review())
    }

    private static func extractJSON(_ text: String) -> String {
        guard let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first <= last else { return text }
        return String(text[first...last])
    }

    func export(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(runs).write(to: url, options: .atomic)
    }
}

private struct ChatCompletion: Decodable {
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String? }
    let choices: [Choice]
}

private enum RunnerError: LocalizedError {
    case serverStopped(String)
    case startupTimeout(String)
    case http(String)
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .serverStopped(let log): "llama-server stopped. See \(log)"
        case .startupTimeout(let log): "Model did not load within two minutes. See \(log)"
        case .http(let response): "Inference request failed: \(response)"
        case .invalidJSON: "No JSON object in the model output"
        }
    }
}

private enum Prompt {
    static func system(language: EvalLanguage) -> String {
        let style = language == .japanese
            ? "Write the entire recipe in Japanese using plain です・ます style."
            : "Write the entire recipe in plain US English."
        return """
        You are writing a practical home recipe. Follow the cook's request exactly. Keep tools, ingredients, and method consistent. Give safe, workable heat and cooking instructions. \(style)
        Return only one JSON object, without Markdown, with this shape:
        {"title":"","time":"minutes as a count","serves":"","ingredients":[{"item":"","amount":""}],"tools":[""],"steps":[{"title":"","points":[""]}],"troubleshooting":[{"problem":"","solution":""}]}
        Use 2 to 8 steps. Every ingredient must have an amount. Include only tools the cook needs. Do not add an ingredient to a step unless it is in the ingredient list.
        """
    }
}
