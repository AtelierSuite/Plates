import Foundation

@MainActor
final class EvalRunner: ObservableObject {
    @Published var serverPath = UserDefaults.standard.string(forKey: "serverPath") ?? ""
    @Published var modelPaths = UserDefaults.standard.dictionary(forKey: "modelPaths") as? [String: String] ?? [:]
    @Published var selectedModels: Set<String> = ["gemma3-1b", "granite4-1b", "lfm25-12b", "lfm25-jp"]
    @Published var huggingFaceToken = ""
    @Published var downloadingModelID: String?
    @Published var repetitions = 3
    @Published var runs: [EvalRun] = [] {
        didSet { saveSession() }
    }
    @Published var status = "Choose llama-server and the GGUF files to begin."
    @Published var isRunning = false

    private var process: Process?
    private var task: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private let port = 12783
    private let structurer = AppleRecipeStructurer()
    private let sessionURL: URL

    var appleIntelligenceAvailable: Bool { structurer.isAvailable }

    init(sessionURL: URL? = nil) {
        self.sessionURL = sessionURL ?? Self.defaultSessionURL
        if let data = try? Data(contentsOf: self.sessionURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            runs = (try? decoder.decode([EvalRun].self, from: data)) ?? []
            if !runs.isEmpty { status = "Restored \(runs.count) saved runs." }
        }
        for candidate in Candidate.all {
            let path = Self.modelsDirectory.appendingPathComponent(candidate.fileName).path
            if FileManager.default.fileExists(atPath: path) && modelPaths[candidate.id] == nil {
                modelPaths[candidate.id] = path
            }
        }
    }

    private static var defaultSessionURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Plates Kitchen/session.json")
    }

    private static var modelsDirectory: URL {
        defaultSessionURL.deletingLastPathComponent().appendingPathComponent("Models")
    }

    func download(_ candidate: Candidate) {
        guard downloadingModelID == nil else { return }
        if candidate.id == "gemma3-1b" && huggingFaceToken.isEmpty {
            status = "Gemma requires accepted model access and a Hugging Face token. Open Source first."
            return
        }
        downloadingModelID = candidate.id
        status = "Downloading \(candidate.name) from Hugging Face..."
        downloadTask = Task {
            do {
                let directory = Self.modelsDirectory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let destination = directory.appendingPathComponent(candidate.fileName)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    let url = URL(string: "https://huggingface.co/\(candidate.repository)/resolve/main/\(candidate.fileName)")!
                    var request = URLRequest(url: url)
                    if !huggingFaceToken.isEmpty {
                        request.setValue("Bearer \(huggingFaceToken)", forHTTPHeaderField: "Authorization")
                    }
                    let (temporary, response) = try await URLSession.shared.download(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw DownloadError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
                    }
                    try Task.checkCancellation()
                    try FileManager.default.moveItem(at: temporary, to: destination)
                }
                setModel(destination, for: candidate)
                status = "\(candidate.name) is ready."
            } catch {
                status = "Download failed for \(candidate.name): \(error.localizedDescription)"
            }
            downloadingModelID = nil
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    private func saveSession() {
        let file = sessionURL
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(runs).write(to: file, options: .atomic)
        } catch {
            status = "Could not save results: \(error.localizedDescription)"
        }
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
        guard structurer.isAvailable else {
            status = "Apple Intelligence is unavailable. Enable it and wait for its model to finish downloading."
            return
        }
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
        do { try archiveSessionIfNeeded() }
        catch {
            status = "Could not archive the current results: \(error.localizedDescription)"
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
                    runs.append(EvalRun(id: UUID(), modelID: candidate.id, modelFile: modelPaths[candidate.id] ?? "", caseID: "startup", language: .english, repetition: 0, startedAt: .now, durationSeconds: 0, rawText: "", recipe: nil, checks: [], error: error.localizedDescription, structuringError: nil, structureDurationSeconds: nil, structuredByApple: nil, review: Review()))
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

    func structureSavedOutputs() {
        guard !isRunning else { return }
        guard structurer.isAvailable else {
            status = "Apple Intelligence is unavailable. Enable it and wait for its model to finish downloading."
            return
        }
        do { try archiveSessionIfNeeded() }
        catch {
            status = "Could not archive the current results: \(error.localizedDescription)"
            return
        }
        isRunning = true
        task = Task {
            for index in runs.indices where !runs[index].rawText.isEmpty {
                if Task.isCancelled { break }
                let old = runs[index]
                guard let testCase = EvalCase.all.first(where: { $0.id == old.caseID }) else { continue }
                status = "Structuring saved output \(index + 1) of \(runs.count) with Apple Intelligence..."
                let result = await structure(old.rawText, for: testCase, language: old.language)
                runs[index] = EvalRun(
                    id: old.id, modelID: old.modelID, modelFile: old.modelFile,
                    caseID: old.caseID, language: old.language, repetition: old.repetition,
                    startedAt: old.startedAt, durationSeconds: old.durationSeconds,
                    rawText: old.rawText, recipe: result.recipe, checks: result.checks,
                    error: nil, structuringError: result.error,
                    structureDurationSeconds: result.duration, structuredByApple: result.recipe != nil,
                    review: old.review
                )
            }
            isRunning = false
            status = Task.isCancelled ? "Structuring stopped. Completed results are saved." : "Finished structuring saved outputs. Review source fidelity and cooking quality."
            task = nil
        }
    }

    private func archiveSessionIfNeeded() throws {
        guard !runs.isEmpty else { return }
        let data = try Data(contentsOf: sessionURL)
        let archive = sessionURL.deletingLastPathComponent()
            .appendingPathComponent("session-before-\(Int(Date.now.timeIntervalSince1970))-\(UUID().uuidString).json")
        try data.write(to: archive, options: .atomic)
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
        var errorText: String?
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
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw RunnerError.empty }
        } catch {
            errorText = error.localizedDescription
        }
        let generationDuration = Date.now.timeIntervalSince(start)
        let structured = errorText == nil
            ? await structure(raw, for: testCase, language: language)
            : (recipe: nil as EvalRecipe?, checks: [String](), error: nil as String?, duration: nil as Double?)
        return EvalRun(
            id: UUID(), modelID: candidate.id, modelFile: modelPaths[candidate.id] ?? "",
            caseID: testCase.id, language: language, repetition: repetition, startedAt: start,
            durationSeconds: generationDuration, rawText: raw, recipe: structured.recipe,
            checks: structured.checks, error: errorText, structuringError: structured.error,
            structureDurationSeconds: structured.duration, structuredByApple: structured.recipe != nil,
            review: Review()
        )
    }

    private func structure(_ raw: String, for testCase: EvalCase, language: EvalLanguage) async -> (recipe: EvalRecipe?, checks: [String], error: String?, duration: Double?) {
        let start = Date.now
        do {
            let recipe = try await structurer.structure(raw, for: testCase, language: language)
            return (recipe, RecipeChecks.evaluate(recipe, caseID: testCase.id), nil, Date.now.timeIntervalSince(start))
        } catch {
            return (nil, [], error.localizedDescription, Date.now.timeIntervalSince(start))
        }
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
    case empty

    var errorDescription: String? {
        switch self {
        case .serverStopped(let log): "llama-server stopped. See \(log)"
        case .startupTimeout(let log): "Model did not load within two minutes. See \(log)"
        case .http(let response): "Inference request failed: \(response)"
        case .empty: "The model returned an empty recipe"
        }
    }
}

private enum DownloadError: LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(401), .http(403): "Access denied. Accept the model terms on Hugging Face and check your token."
        case .http(let code): "Hugging Face returned HTTP \(code)."
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
        Write the recipe as plain cookbook text with a title, total time, servings, measured ingredients, tools, and ordered method steps. Add troubleshooting only when useful. Do not write JSON or code.
        Use 2 to 8 steps. Include only tools the cook needs. Do not use an ingredient in a step unless it is in the ingredient list.
        """
    }
}
