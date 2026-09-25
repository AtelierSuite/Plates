import Foundation
import SwiftUI

@main
@MainActor
enum PlatesKitchenMain {
    static func main() async {
        if CommandLine.arguments.contains("--headless-scene-eval") {
            await runScene()
            return
        }
        if CommandLine.arguments.contains("--headless-image-eval") {
            await runImages()
            return
        }
        if CommandLine.arguments.contains("--headless-svg-eval") {
            await runSVG()
            return
        }
        guard CommandLine.arguments.contains("--headless-eval") else {
            PlatesKitchenApp.main()
            return
        }

        let arguments = CommandLine.arguments
        let server = value(after: "--server", in: arguments) ?? "/opt/homebrew/bin/llama-server"
        let modelDirectory = URL(fileURLWithPath: value(after: "--models-directory", in: arguments)
            ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support/Plates Kitchen/Models"))
        let output = URL(fileURLWithPath: value(after: "--output", in: arguments)
            ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support/Plates Kitchen/headless-\(Int(Date.now.timeIntervalSince1970)).json"))
        let repetitions = max(1, min(Int(value(after: "--repetitions", in: arguments) ?? "3") ?? 3, 10))

        let runner = EvalRunner(sessionURL: output)
        runner.serverPath = server
        runner.modelPaths = Dictionary(uniqueKeysWithValues: Candidate.all.map {
            ($0.id, modelDirectory.appendingPathComponent($0.fileName).path)
        })
        if let model = value(after: "--model", in: arguments) {
            guard Candidate.all.contains(where: { $0.id == model }) else {
                print("Unknown model ID: \(model)")
                exit(1)
            }
            runner.selectedModels = [model]
        }
        runner.repetitions = repetitions
        runner.concurrency = concurrency(in: arguments)
        runner.start()
        guard runner.isRunning else {
            print("Could not start: \(runner.status)")
            exit(1)
        }

        print("Saving results to \(output.path)")
        var previousStatus = ""
        while runner.isRunning {
            if runner.status != previousStatus {
                print(runner.status)
                fflush(stdout)
                previousStatus = runner.status
            }
            try? await Task.sleep(for: .seconds(1))
        }
        print(runner.status)
        let failures = runner.runs.filter { $0.error != nil || $0.structuringError != nil }
        print("Completed \(runner.runs.count) runs; \(runner.runs.filter { $0.recipe != nil }.count) structured; \(failures.count) generation or structuring errors.")
        exit(failures.isEmpty ? 0 : 2)
    }

    private static func runScene() async {
        let arguments = CommandLine.arguments
        let output = URL(fileURLWithPath: value(after: "--output", in: arguments)
            ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support/Plates Kitchen/scene-headless-\(Int(Date.now.timeIntervalSince1970)).json"))
        let runner = SVGRunner(outputURL: output)
        runner.concurrency = concurrency(in: arguments)
        if let assets = value(after: "--assets", in: arguments) {
            runner.assetFilter = Set(assets.split(separator: ",").map(String.init))
        }
        runner.startScenePlan()
        guard runner.isRunning else { print("Could not start: \(runner.status)"); exit(1) }
        print("Saving scene results to \(output.path)")
        var previousStatus = ""
        while runner.isRunning {
            if runner.status != previousStatus {
                print(runner.status)
                fflush(stdout)
                previousStatus = runner.status
            }
            try? await Task.sleep(for: .seconds(1))
        }
        let sceneRuns = runner.runs.filter { $0.modelID == "apple-scene" }
        print("Completed \(sceneRuns.count) scene plans; \(sceneRuns.filter { $0.svg != nil }.count) rendered; \(sceneRuns.filter { !$0.checks.isEmpty }.count) semantic or SVG flags.")
        exit(sceneRuns.contains { $0.error != nil || $0.svg == nil } ? 2 : 0)
    }

    private static func runSVG() async {
        let arguments = CommandLine.arguments
        let output = URL(fileURLWithPath: value(after: "--output", in: arguments)
            ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support/Plates Kitchen/svg-headless-\(Int(Date.now.timeIntervalSince1970)).json"))
        let runner = SVGRunner(outputURL: output)
        runner.serverPath = value(after: "--server", in: arguments) ?? "/opt/homebrew/bin/llama-server"
        if let directory = value(after: "--models-directory", in: arguments) {
            runner.modelDirectory = URL(fileURLWithPath: directory)
        }
        if let model = value(after: "--model", in: arguments) {
            guard Candidate.all.contains(where: { $0.id == model }) else {
                print("Unknown model ID: \(model)")
                exit(1)
            }
            runner.selectedModels = [model]
        }
        runner.repetitions = max(1, min(Int(value(after: "--repetitions", in: arguments) ?? "1") ?? 1, 10))
        runner.concurrency = concurrency(in: arguments)
        if let assets = value(after: "--assets", in: arguments) {
            runner.assetFilter = Set(assets.split(separator: ",").map(String.init))
        }
        runner.start()
        guard runner.isRunning else { print("Could not start: \(runner.status)"); exit(1) }
        print("Saving SVG results to \(output.path)")
        var previousStatus = ""
        while runner.isRunning {
            if runner.status != previousStatus {
                print(runner.status)
                fflush(stdout)
                previousStatus = runner.status
            }
            try? await Task.sleep(for: .seconds(1))
        }
        let failures = runner.runs.filter { $0.error != nil || !$0.checks.isEmpty }
        print("Completed \(runner.runs.count) SVG trials; \(runner.runs.filter { $0.svg != nil }.count) passed static checks; \(failures.count) failed.")
        exit(failures.isEmpty ? 0 : 2)
    }

    private static func runImages() async {
        let arguments = CommandLine.arguments
        let output = URL(fileURLWithPath: value(after: "--output", in: arguments)
            ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support/Plates Kitchen/image-headless-\(Int(Date.now.timeIntervalSince1970)).json"))
        let runner = ImageRunner(outputURL: output)
        if let directory = value(after: "--models-directory", in: arguments) {
            runner.modelDirectory = URL(fileURLWithPath: directory)
        }
        if let model = value(after: "--model", in: arguments) {
            if model == "all" {
                runner.selectedModels = Set(runner.downloadedModels.map(\.id))
            } else {
                let ids = Set(model.split(separator: ",").map(String.init))
                guard ids.allSatisfy({ id in ImageCandidate.all.contains { $0.id == id } }) else {
                    print("Unknown model ID in \(model). Use all, or \(ImageCandidate.all.map(\.id).joined(separator: ", ")).")
                    exit(1)
                }
                runner.selectedModels = ids
            }
        }
        runner.repetitions = max(1, min(Int(value(after: "--repetitions", in: arguments) ?? "1") ?? 1, 10))
        runner.stepCount = max(1, min(Int(value(after: "--steps", in: arguments) ?? "25") ?? 25, 100))
        runner.concurrency = concurrency(in: arguments)
        if let styles = value(after: "--styles", in: arguments) {
            let ids = styles.split(separator: ",").map(String.init)
            let chosen = ImageStyle.all.filter { ids.contains($0.id) }
            guard chosen.count == ids.count else {
                print("Unknown style in \(styles). Use \(ImageStyle.all.map(\.id).joined(separator: ", ")).")
                exit(1)
            }
            runner.styleOverrides = chosen
        }
        if let assets = value(after: "--assets", in: arguments) {
            runner.assetFilter = Set(assets.split(separator: ",").map(String.init))
        }
        if let background = value(after: "--background", in: arguments) {
            guard let parsed = ImageBackground(rawValue: background) else {
                print("Unknown background: \(background). Use white or green.")
                exit(1)
            }
            runner.background = parsed
        }
        if arguments.contains("--recut") {
            runner.recutSavedImages()
        } else {
            runner.start()
        }
        guard runner.isRunning else { print("Could not start: \(runner.status)"); exit(1) }
        print("Saving image results to \(output.path)")
        var previousStatus = ""
        while runner.isRunning {
            if runner.status != previousStatus {
                print(runner.status)
                fflush(stdout)
                previousStatus = runner.status
            }
            try? await Task.sleep(for: .seconds(1))
        }
        let sheet = output.deletingPathExtension().appendingPathExtension("png")
        let cutoutSheet = output.deletingPathExtension().appendingPathExtension("cutout.png")
        do {
            try ImageContactSheet.write(runs: runner.runs, recipes: runner.recipes, imageDirectory: runner.imageDirectory, to: sheet)
            try ImageContactSheet.write(runs: runner.runs, recipes: runner.recipes, imageDirectory: runner.imageDirectory,
                                        to: cutoutSheet, cutouts: true)
            print("Contact sheets: \(sheet.path), \(cutoutSheet.lastPathComponent)")
        } catch { print("Could not write contact sheet: \(error.localizedDescription)") }
        let generated = runner.runs.filter { $0.imageFile != nil }
        let clean = generated.filter { $0.cutoutChecks.isEmpty }.count
        let vision = generated.filter { $0.cutoutMethod == .vision }.count
        let keyed = generated.filter { $0.cutoutMethod == .backgroundKey }.count
        print("Cutouts: \(clean)/\(generated.count) usable without problems; Vision \(vision), background key \(keyed), none \(generated.count - vision - keyed).")
        let failures = runner.runs.filter { $0.error != nil }
        let timed = runner.runs.filter { $0.error == nil }.map(\.durationSeconds).sorted()
        let median = timed.isEmpty ? 0 : timed[timed.count / 2]
        let peak = runner.runs.map(\.peakFootprintMB).max() ?? 0
        print("Completed \(runner.runs.count) images; \(failures.count) failed; median \(median.formatted(.number.precision(.fractionLength(1)))) s; peak footprint \(Int(peak)) MB.")
        exit(failures.isEmpty ? 0 : 2)
    }

    private static func concurrency(in arguments: [String]) -> Int {
        max(1, min(Int(value(after: "--concurrency", in: arguments) ?? "2") ?? 2, 4))
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
