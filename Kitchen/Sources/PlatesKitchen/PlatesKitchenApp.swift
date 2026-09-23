import SwiftUI
import AppKit

@main
struct PlatesKitchenApp: App {
    @StateObject private var runner = EvalRunner()

    var body: some Scene {
        WindowGroup("Plates Kitchen") {
            KitchenView()
                .environmentObject(runner)
                .frame(minWidth: 1050, minHeight: 700)
        }
    }
}

private struct KitchenView: View {
    @EnvironmentObject private var runner: EvalRunner
    @State private var selectedRunID: UUID?
    @State private var selectedCaseID = "egg-fried-rice"
    @State private var selectedLanguage: EvalLanguage = .english

    private var selectedRunIndex: Int? { runner.runs.firstIndex { $0.id == selectedRunID } }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Models").font(.headline)
                ForEach(Candidate.all) { candidate in
                    modelRow(candidate)
                }
                SecureField("Hugging Face token for Gemma", text: $runner.huggingFaceToken)
                    .textFieldStyle(.roundedBorder)
                Text("Accept Gemma access on its Source page first. The token stays in this app session.")
                    .font(.caption2).foregroundStyle(.secondary)
                Divider()
                Text("Runtime").font(.headline)
                HStack {
                    Text(runner.serverPath.isEmpty ? "No llama-server selected" : URL(fileURLWithPath: runner.serverPath).lastPathComponent)
                        .lineLimit(1)
                    Spacer()
                    Button("Choose") { chooseServer() }
                }
                Text("Use a current llama.cpp build with GGUF support. The server binds to 127.0.0.1.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Stepper("Runs per case: \(runner.repetitions)", value: $runner.repetitions, in: 1...10)
                Text("Three dishes in English and Japanese. The same prompt and settings are used for every model.")
                    .font(.caption).foregroundStyle(.secondary)
                Text(runner.appleIntelligenceAvailable ? "Apple Intelligence is ready to structure recipes." : "Apple Intelligence is unavailable on this Mac.")
                    .font(.caption).foregroundStyle(runner.appleIntelligenceAvailable ? .green : .orange)
                HStack {
                    Button("Run eval") { runner.start() }.disabled(runner.isRunning || !runner.appleIntelligenceAvailable)
                        .buttonStyle(.borderedProminent)
                    Button("Stop") { runner.stop() }.disabled(!runner.isRunning)
                    Button("Export JSON") { export() }.disabled(runner.runs.isEmpty)
                }
                Button("Structure saved outputs") { runner.structureSavedOutputs() }
                    .disabled(runner.isRunning || !runner.appleIntelligenceAvailable || !runner.runs.contains { !$0.rawText.isEmpty })
                Text(runner.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .frame(minWidth: 320)
        } content: {
            VStack(spacing: 0) {
                DisclosureGroup("Results summary") {
                    ForEach(Candidate.all.filter { candidate in runner.runs.contains { $0.modelID == candidate.id } }) { candidate in
                        let modelRuns = runner.runs.filter { $0.modelID == candidate.id && $0.caseID != "startup" }
                        let reviewed = modelRuns.filter { $0.review.reviewed }
                        Text("\(candidate.name): \(modelRuns.filter { $0.structuredByApple == true }.count)/\(modelRuns.count) structured, \(reviewed.filter { $0.review.passes }.count)/\(reviewed.count) passed review")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                HStack {
                    Picker("Dish", selection: $selectedCaseID) {
                        ForEach(EvalCase.all) { item in Text(item.title).tag(item.id) }
                    }
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(EvalLanguage.allCases) { language in Text(language.rawValue).tag(language) }
                    }
                }
                .padding()
                List(selection: $selectedRunID) {
                    ForEach(runner.runs.filter { $0.caseID == selectedCaseID && $0.language == selectedLanguage }) { run in
                        HStack {
                            Text(Candidate.all.first { $0.id == run.modelID }?.name ?? run.modelID)
                            Spacer()
                            Text("#\(run.repetition)")
                            Image(systemName: run.error != nil || run.structuringError != nil || run.recipe == nil ? "xmark.circle.fill" : run.checks.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(run.error != nil || run.structuringError != nil || run.recipe == nil ? .red : run.checks.isEmpty ? .green : .orange)
                        }
                        .tag(run.id)
                    }
                }
                Text("Automated checks flag candidates for review. They do not establish cooking safety.")
                    .font(.caption).foregroundStyle(.secondary).padding(8)
            }
            .frame(minWidth: 320)
        } detail: {
            if let index = selectedRunIndex {
                runDetail(index)
            } else {
                ContentUnavailableView("Select a result", systemImage: "fork.knife", description: Text("Run the eval, then inspect each recipe and record your review."))
            }
        }
    }

    private func modelRow(_ candidate: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(candidate.name, isOn: Binding(
                get: { runner.selectedModels.contains(candidate.id) },
                set: { selected in
                    if selected { runner.selectedModels.insert(candidate.id) }
                    else { runner.selectedModels.remove(candidate.id) }
                }
            ))
            HStack {
                Text(runner.modelPaths[candidate.id].map { URL(fileURLWithPath: $0).lastPathComponent } ?? "No GGUF selected")
                    .lineLimit(1).truncationMode(.middle)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Choose") { chooseModel(candidate) }.font(.caption)
                Button(runner.downloadingModelID == candidate.id ? "Downloading" : "Download") {
                    runner.download(candidate)
                }
                .disabled(runner.downloadingModelID != nil)
                .font(.caption)
                Link("Source", destination: candidate.modelPage).font(.caption)
            }
            Text("About \(candidate.approximateSizeMB) MB. \(candidate.notes)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func runDetail(_ index: Int) -> some View {
        let run = runner.runs[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(Candidate.all.first { $0.id == run.modelID }?.name ?? run.modelID) · Run \(run.repetition)")
                    .font(.title2.bold())
                Text("\(run.durationSeconds.formatted(.number.precision(.fractionLength(1)))) seconds · \(run.modelFile)")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                if let seconds = run.structureDurationSeconds {
                    Text("Apple structuring: \(seconds.formatted(.number.precision(.fractionLength(1)))) seconds")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = run.error { Label(error, systemImage: "xmark.circle").foregroundStyle(.red) }
                if let error = run.structuringError { Label("Apple structuring failed: \(error)", systemImage: "xmark.circle").foregroundStyle(.red) }
                if !run.checks.isEmpty {
                    GroupBox("Automated flags") {
                        ForEach(run.checks, id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }
                if let recipe = run.recipe {
                    if run.structuredByApple == true {
                        Text("Apple Intelligence extracted this structure. Compare it with the original before scoring.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(recipe.title).font(.title3.bold())
                    Text("\(recipe.time) · Serves \(recipe.serves)")
                    Text("Ingredients").font(.headline)
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                        Text("\(ingredient.amount) \(ingredient.item)")
                    }
                    Text("Tools: \(recipe.tools.joined(separator: ", "))")
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { number, step in
                        Text("\(number + 1). \(step.title)").font(.headline)
                        ForEach(step.points, id: \.self) { Text($0) }
                    }
                    if !recipe.troubleshooting.isEmpty {
                        Text("Troubleshooting").font(.headline)
                        ForEach(Array(recipe.troubleshooting.enumerated()), id: \.offset) { _, item in
                            Text("\(item.problem): \(item.solution)")
                        }
                    }
                }
                DisclosureGroup("Original model recipe") {
                    Text(run.rawText).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
                Divider()
                Text("Human review").font(.headline)
                Toggle("Cookable as written", isOn: $runner.runs[index].review.feasible)
                Toggle("Request constraints met", isOn: $runner.runs[index].review.constraintsMet)
                Toggle("Ingredients used consistently", isOn: $runner.runs[index].review.ingredientUse)
                Toggle("Steps are clear and ordered", isOn: $runner.runs[index].review.clearSteps)
                Toggle("Language reads naturally", isOn: $runner.runs[index].review.languageQuality)
                Toggle("Critical failure", isOn: $runner.runs[index].review.criticalFailure)
                TextField("Review notes", text: $runner.runs[index].review.notes, axis: .vertical)
                    .lineLimit(3...8)
                Button(run.review.reviewed ? "Reviewed" : "Mark reviewed") {
                    runner.runs[index].review.reviewed = true
                }
                .disabled(run.review.reviewed)
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func chooseServer() {
        let panel = NSOpenPanel()
        panel.message = "Choose the llama-server executable"
        if panel.runModal() == .OK, let url = panel.url { runner.setServer(url) }
    }

    private func chooseModel(_ candidate: Candidate) {
        let panel = NSOpenPanel()
        panel.message = "Choose \(candidate.fileName) from \(candidate.repository)"
        panel.allowedContentTypes = [.data]
        if panel.runModal() == .OK, let url = panel.url {
            if url.lastPathComponent == candidate.fileName { runner.setModel(url, for: candidate) }
            else { runner.status = "Expected \(candidate.fileName). Choose the listed quantization." }
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "plates-kitchen-results.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try runner.export(to: url) }
            catch { runner.status = "Export failed: \(error.localizedDescription)" }
        }
    }
}
