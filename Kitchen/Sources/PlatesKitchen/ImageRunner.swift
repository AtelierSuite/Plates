import Foundation
import CoreML
import ImageIO
import UniformTypeIdentifiers
import StableDiffusion

@MainActor
final class ImageRunner: ObservableObject {
    @Published var selectedModels: Set<String> = ["sd21-base"]
    @Published var repetitions = 1
    @Published var concurrency = 2
    @Published var stepCount = 25
    @Published var background: ImageBackground = .white
    /// Overrides each model's default style for every selected model. Several styles run in one model load.
    @Published var styleOverrides: [ImageStyle] = []
    /// Limits a run to these asset IDs, for quick trials.
    var assetFilter: Set<String> = []
    @Published var runs: [ImageRun] = [] { didSet { save() } }
    @Published var status = "Ready to evaluate recipe images."
    @Published var isRunning = false
    @Published var downloadingModelID: String?

    let recipes: [SVGSampleRecipe]
    var modelDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Plates Kitchen/ImageModels")
    let imageDirectory: URL
    private let outputURL: URL
    private var task: Task<Void, Never>?
    private var generators: [ImageGenerator] = []
    private var readyRuns: [Int: ImageRun] = [:]
    private var nextRunIndex = 0

    init(outputURL: URL? = nil) {
        recipes = (try? SVGSampleRecipe.load()) ?? []
        self.outputURL = outputURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Plates Kitchen/image-session.json")
        imageDirectory = self.outputURL.deletingLastPathComponent().appendingPathComponent("Images")
        if let data = try? Data(contentsOf: self.outputURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            runs = (try? decoder.decode([ImageRun].self, from: data)) ?? []
        }
    }

    var assets: [SVGSampleAsset] { recipes.flatMap(\.assets) }

    func resourceURL(for candidate: ImageCandidate) -> URL? {
        let root = modelDirectory.appendingPathComponent(candidate.id)
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == "VAEDecoder.mlmodelc" {
            return url.deletingLastPathComponent()
        }
        return nil
    }

    var downloadedModels: [ImageCandidate] { ImageCandidate.all.filter { resourceURL(for: $0) != nil } }

    func imageURL(for run: ImageRun) -> URL? {
        run.imageFile.map { imageDirectory.appendingPathComponent($0) }
    }

    func cutoutURL(for run: ImageRun) -> URL? {
        run.cutoutFile.map { imageDirectory.appendingPathComponent($0) }
    }

    func download(_ candidate: ImageCandidate) {
        guard downloadingModelID == nil, let archiveURL = candidate.archiveURL else { return }
        downloadingModelID = candidate.id
        status = "Downloading \(candidate.name), about \(candidate.approximateSizeMB) MB."
        Task {
            do {
                let (temporary, response) = try await URLSession.shared.download(from: archiveURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ImageRunnerError.download }
                let destination = modelDirectory.appendingPathComponent(candidate.id)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unzip.arguments = ["-x", "-k", temporary.path, destination.path]
                try unzip.run()
                unzip.waitUntilExit()
                try? FileManager.default.removeItem(at: temporary)
                guard unzip.terminationStatus == 0 else { throw ImageRunnerError.unzip }
                status = "\(candidate.name) is ready."
            } catch {
                status = "\(candidate.name) download failed: \(error.localizedDescription)"
            }
            downloadingModelID = nil
        }
    }

    func start() {
        guard !isRunning else { return }
        guard !recipes.isEmpty else { status = "Could not load the sample recipes."; return }
        let candidates = ImageCandidate.all.filter { selectedModels.contains($0.id) }
        guard !candidates.isEmpty else { status = "Select at least one model."; return }
        let resources = candidates.compactMap { candidate in resourceURL(for: candidate).map { (candidate, $0) } }
        guard resources.count == candidates.count else {
            status = "Download the Core ML resources for the selected models."
            return
        }
        let selectedAssets = assets.filter { assetFilter.isEmpty || assetFilter.contains($0.id) }
        guard !selectedAssets.isEmpty else { status = "No sample assets match the filter."; return }
        do {
            try archiveIfNeeded()
            try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        } catch { status = "Could not prepare image results: \(error.localizedDescription)"; return }
        runs = []
        isRunning = true
        let steps = stepCount
        let background = background
        let selectedStyles = styleOverrides
        let repeatCount = max(1, min(repetitions, 10))
        let workerLimit = max(1, min(concurrency, 4))
        task = Task {
            for (candidate, url) in resources {
                if Task.isCancelled { break }
                let styles = selectedStyles.isEmpty ? [candidate.defaultStyle] : selectedStyles
                var jobs: [ImageJob] = []
                for style in styles {
                    for asset in selectedAssets {
                        for repetition in 1...repeatCount {
                            jobs.append(ImageJob(index: jobs.count, asset: asset, style: style,
                                                 repetition: repetition))
                        }
                    }
                }
                let workerCount = min(workerLimit, jobs.count)
                status = "\(candidate.name): loading \(workerCount) Core ML worker\(workerCount == 1 ? "" : "s")"
                generators = []
                var loadTimes: [Double] = []
                var loadError: Error?
                for _ in 0..<workerCount {
                    if Task.isCancelled { break }
                    let generator = ImageGenerator()
                    do {
                        loadTimes.append(try await generator.load(candidate, resourcesAt: url))
                        generators.append(generator)
                    } catch {
                        loadError = error
                        break
                    }
                }
                if let loadError {
                    runs.append(failedRun(candidate, error: loadError))
                    for generator in generators { await generator.unload() }
                    generators = []
                    continue
                }
                if !Task.isCancelled {
                    readyRuns = [:]
                    nextRunIndex = 0
                    let queue = ImageJobQueue(jobs)
                    status = "\(candidate.name): generating up to \(workerCount) image\(workerCount == 1 ? "" : "s") at once"
                    await withTaskGroup(of: Void.self) { group in
                        for (workerIndex, generator) in generators.enumerated() {
                            let loadSeconds = loadTimes[workerIndex]
                            group.addTask {
                                var first = true
                                while !Task.isCancelled, let job = await queue.next() {
                                    let run = await self.generate(candidate, asset: job.asset,
                                                                  repetition: job.repetition, stepCount: steps,
                                                                  background: background, style: job.style,
                                                                  generator: generator,
                                                                  loadSeconds: first ? loadSeconds : nil)
                                    first = false
                                    await self.record(run, at: job.index)
                                }
                            }
                        }
                    }
                }
                for generator in generators { await generator.unload() }
                generators = []
                readyRuns = [:]
            }
            isRunning = false
            status = Task.isCancelled ? "Stopped. Completed images are saved." : "Finished \(runs.count) images. Review the drawings."
            task = nil
        }
    }

    private func record(_ run: ImageRun, at index: Int) {
        readyRuns[index] = run
        while let ordered = readyRuns.removeValue(forKey: nextRunIndex) {
            runs.append(ordered)
            nextRunIndex += 1
            status = "\(ordered.modelID): completed \(nextRunIndex) image\(nextRunIndex == 1 ? "" : "s")"
        }
    }

    func stop() {
        task?.cancel()
        for generator in generators { generator.cancel() }
    }

    private func generate(_ candidate: ImageCandidate, asset: SVGSampleAsset, repetition: Int,
                          stepCount: Int, background: ImageBackground, style: ImageStyle, generator: ImageGenerator,
                          loadSeconds: Double?) async -> ImageRun {
        let id = UUID()
        let seed = UInt32(1000 + repetition)
        let prompt = ImagePrompt.prompt(for: asset, background: background, style: style)
        let start = Date.now
        var file: String?
        var errorText: String?
        var png: Data?
        let name = "\(candidate.id)-\(style.id)-\(asset.id)-\(repetition)-\(id.uuidString.prefix(8))"
        do {
            png = try await generator.generate(prompt: prompt, negativePrompt: ImagePrompt.negative(for: style),
                                               seed: seed, stepCount: stepCount)
            try png!.write(to: imageDirectory.appendingPathComponent("\(name).png"), options: .atomic)
            file = "\(name).png"
        } catch { errorText = error.localizedDescription }
        let duration = Date.now.timeIntervalSince(start)
        let memory = ProcessMemory.footprintMB()
        var run = ImageRun(id: id, modelID: candidate.id, assetID: asset.id, recipeID: asset.recipeID, kind: asset.kind,
                           repetition: repetition, seed: seed, stepCount: stepCount, prompt: prompt, startedAt: start,
                           loadSeconds: loadSeconds, durationSeconds: duration,
                           footprintMB: memory.current, peakFootprintMB: memory.peak,
                           imageFile: file, error: errorText, review: SVGReview())
        run.background = background
        run.styleID = style.id
        if let png { await cutOut(png, name: name, into: &run) }
        return run
    }

    /// Removes the background, centers the subject, and records the cutout measurements on the run.
    private func cutOut(_ png: Data, name: String, into run: inout ImageRun) async {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
        let start = Date.now
        run.cutoutFile = nil
        run.cutoutMethod = nil
        if let cutout = try? await SubjectCutout.process(image) {
            do {
                try cutout.png.write(to: imageDirectory.appendingPathComponent("\(name)-cutout.png"), options: .atomic)
                run.cutoutFile = "\(name)-cutout.png"
                run.cutoutMethod = cutout.method
                run.subjectInstances = cutout.instances
                run.droppedInstances = cutout.droppedInstances
                run.subjectCoverage = cutout.coverage
                run.subjectCenterOffset = cutout.centerOffset
                run.subjectTouchesEdge = cutout.touchesEdge
            } catch { status = "Could not save cutout: \(error.localizedDescription)" }
        }
        run.cutoutSeconds = Date.now.timeIntervalSince(start)
    }

    /// Reruns background removal on saved images without generating them again.
    func recutSavedImages() {
        guard !isRunning else { return }
        isRunning = true
        task = Task {
            let jobs = runs.enumerated().compactMap { index, run -> RecutJob? in
                run.imageFile == nil ? nil : RecutJob(index: index, run: run)
            }
            status = "Removing backgrounds, two images at once"
            await EvalConcurrency.run(jobs, limit: 2) { job in
                var run = job.run
                if let file = run.imageFile,
                   let png = try? Data(contentsOf: self.imageDirectory.appendingPathComponent(file)) {
                    await self.cutOut(png, name: String(file.dropLast(4)), into: &run)
                }
                return RecutJob(index: job.index, run: run)
            } onResult: { result in
                self.runs[result.index] = result.run
            }
            isRunning = false
            status = "Redid background removal for \(runs.filter { $0.imageFile != nil }.count) images."
            task = nil
        }
    }

    private func failedRun(_ candidate: ImageCandidate, error: Error) -> ImageRun {
        let memory = ProcessMemory.footprintMB()
        return ImageRun(id: UUID(), modelID: candidate.id, assetID: "startup", recipeID: "", kind: .icon, repetition: 0,
                        seed: 0, stepCount: 0, prompt: "", startedAt: .now, loadSeconds: nil, durationSeconds: 0,
                        footprintMB: memory.current, peakFootprintMB: memory.peak, imageFile: nil,
                        error: error.localizedDescription, review: SVGReview())
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(runs).write(to: outputURL, options: .atomic)
        } catch { status = "Could not save image results: \(error.localizedDescription)" }
    }

    private func archiveIfNeeded() throws {
        guard !runs.isEmpty else { return }
        let archive = outputURL.deletingLastPathComponent()
            .appendingPathComponent("image-before-\(Int(Date.now.timeIntervalSince1970))-\(UUID().uuidString).json")
        try Data(contentsOf: outputURL).write(to: archive, options: .atomic)
    }

    func export(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(runs).write(to: url, options: .atomic)
    }
}

private struct RecutJob: Sendable {
    let index: Int
    let run: ImageRun
}

private struct ImageJob: Sendable {
    let index: Int
    let asset: SVGSampleAsset
    let style: ImageStyle
    let repetition: Int
}

private actor ImageJobQueue {
    private let jobs: [ImageJob]
    private var index = 0

    init(_ jobs: [ImageJob]) { self.jobs = jobs }

    func next() -> ImageJob? {
        guard index < jobs.count else { return nil }
        defer { index += 1 }
        return jobs[index]
    }
}

enum ImageRunnerError: LocalizedError {
    case download, unzip, notLoaded, noImage, encoding

    var errorDescription: String? {
        switch self {
        case .download: "The model archive could not be downloaded."
        case .unzip: "The model archive could not be extracted."
        case .notLoaded: "The pipeline is not loaded."
        case .noImage: "The pipeline returned no image."
        case .encoding: "The image could not be encoded as PNG."
        }
    }
}

/// Owns one Core ML pipeline. Each worker calls its own instance sequentially.
final class ImageGenerator: @unchecked Sendable {
    private var pipeline: (any StableDiffusionPipelineProtocol)?
    private var candidate: ImageCandidate?
    private let lock = NSLock()
    private var cancelled = false

    func cancel() { lock.withLock { cancelled = true } }
    private var isCancelled: Bool { lock.withLock { cancelled } }

    func load(_ candidate: ImageCandidate, resourcesAt url: URL) async throws -> Double {
        try await Task.detached(priority: .userInitiated) { [self] in
            let start = Date.now
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndNeuralEngine
            let pipeline: any StableDiffusionPipelineProtocol = candidate.isXL
                ? try StableDiffusionXLPipeline(resourcesAt: url, configuration: configuration, reduceMemory: true)
                : try StableDiffusionPipeline(resourcesAt: url, controlNet: [], configuration: configuration,
                                              disableSafety: true, reduceMemory: true)
            try pipeline.loadResources()
            self.pipeline = pipeline
            self.candidate = candidate
            return Date.now.timeIntervalSince(start)
        }.value
    }

    func generate(prompt: String, negativePrompt: String, seed: UInt32, stepCount: Int) async throws -> Data {
        try await Task.detached(priority: .userInitiated) { [self] in
            guard let pipeline, let candidate else { throw ImageRunnerError.notLoaded }
            var configuration = StableDiffusionPipeline.Configuration(prompt: prompt)
            configuration.negativePrompt = negativePrompt
            configuration.stepCount = stepCount
            configuration.seed = seed
            configuration.guidanceScale = 7.5
            configuration.disableSafety = true
            configuration.schedulerType = .dpmSolverMultistepScheduler
            if candidate.isXL {
                configuration.encoderScaleFactor = 0.13025
                configuration.decoderScaleFactor = 0.13025
                configuration.schedulerTimestepSpacing = .karras
                configuration.originalSize = Float32(candidate.resolution)
                configuration.targetSize = Float32(candidate.resolution)
            }
            let images = try pipeline.generateImages(configuration: configuration) { _ in !self.isCancelled }
            guard let image = images.first ?? nil else { throw ImageRunnerError.noImage }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
                throw ImageRunnerError.encoding
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw ImageRunnerError.encoding }
            return data as Data
        }.value
    }

    func unload() async {
        await Task.detached { [self] in
            pipeline?.unloadResources()
            pipeline = nil
        }.value
    }
}
