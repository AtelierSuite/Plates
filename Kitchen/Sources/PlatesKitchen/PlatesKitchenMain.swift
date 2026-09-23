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
        runner.repetitions = repetitions
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
        if let model = value(after: "--model", in: arguments) { runner.selectedModels = [model] }
        runner.repetitions = max(1, min(Int(value(after: "--repetitions", in: arguments) ?? "1") ?? 1, 10))
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

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
