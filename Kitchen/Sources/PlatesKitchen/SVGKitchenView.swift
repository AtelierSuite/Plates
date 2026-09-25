import SwiftUI
import AppKit

struct SVGKitchenView: View {
    @ObservedObject var runner: SVGRunner
    @State private var selectedAssetID: String?
    @State private var selectedRunID: UUID?
    @State private var galleryModelID = "granite4-1b"

    private var selectedRunIndex: Int? { runner.runs.firstIndex { $0.id == selectedRunID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button("Run model SVGs") { runner.start() }.disabled(runner.isRunning)
                    .buttonStyle(.borderedProminent)
                Button("Run Apple scene plan") { runner.startScenePlan() }
                    .disabled(runner.isRunning || !runner.appleSceneAvailable)
                Button("Stop") { runner.stop() }.disabled(!runner.isRunning)
                Menu("Settings") {
                    ForEach(Candidate.all) { candidate in
                        Toggle(candidate.name, isOn: Binding(
                            get: { runner.selectedModels.contains(candidate.id) },
                            set: { selected in
                                if selected { runner.selectedModels.insert(candidate.id) }
                                else { runner.selectedModels.remove(candidate.id) }
                            }
                        ))
                    }
                    Picker("Runs per graphic", selection: $runner.repetitions) {
                        ForEach(1...10, id: \.self) { count in Text("\(count)").tag(count) }
                    }
                    Picker("Concurrent trials", selection: $runner.concurrency) {
                        ForEach(1...4, id: \.self) { count in Text("\(count)").tag(count) }
                    }
                }
                Menu("Results") {
                    Button("Import JSON") { importResults() }.disabled(runner.isRunning)
                    Button("Export JSON") { export() }.disabled(runner.runs.isEmpty)
                }
                Spacer()
                Text(runner.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(8)
            Divider()
            HSplitView {
                List(selection: $selectedAssetID) {
                    Label("Gallery", systemImage: "square.grid.2x2").tag("gallery")
                    ForEach(runner.recipes) { recipe in
                        Section(recipe.title) {
                            ForEach(recipe.assets) { asset in
                                HStack {
                                    Image(systemName: asset.kind == .icon ? "fork.knife.circle" : "square.on.square")
                                    Text(asset.kind == .icon ? "Recipe icon" : recipe.steps[asset.stepIndex!].title)
                                    Spacer()
                                    Text(resultCount(for: asset))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .tag(asset.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 280)
                Group {
                    if let asset = runner.assets.first(where: { $0.id == selectedAssetID }) {
                        assetDetail(asset)
                    } else {
                        gallery
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func resultCount(for asset: SVGSampleAsset) -> String {
        let trials = runner.runs.filter { $0.assetID == asset.id }
        return "\(trials.filter { $0.svg != nil }.count)/\(trials.count)"
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Graphics gallery").font(.title2.bold())
                Picker("Model", selection: $galleryModelID) {
                    ForEach(Candidate.all) { candidate in Text(candidate.name).tag(candidate.id) }
                    Text("Apple scene plan").tag("apple-scene")
                }
                .frame(maxWidth: 280)
                ForEach(runner.recipes) { recipe in
                    Text(recipe.title).font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                        ForEach(recipe.assets) { asset in
                            VStack(alignment: .leading, spacing: 5) {
                                if let run = runner.runs.first(where: { $0.assetID == asset.id && $0.modelID == galleryModelID }),
                                   let svg = run.svg {
                                    SVGPreview(svg: svg).frame(height: 130)
                                } else {
                                    Label("No valid SVG", systemImage: "xmark.square")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .frame(height: 130)
                                }
                                Text(asset.kind == .icon ? "Recipe icon" : recipe.steps[asset.stepIndex!].title)
                                    .font(.caption).lineLimit(2)
                            }
                            .padding(6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func assetDetail(_ asset: SVGSampleAsset) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(asset.kind == .icon ? "Recipe icon" : "Step \((asset.stepIndex ?? 0) + 1)")
                    .font(.title2.bold())
                Text(asset.subject).font(.subheadline)
                if asset.kind == .step, let index = asset.stepIndex,
                   let recipe = runner.recipes.first(where: { $0.id == asset.recipeID }) {
                    Text(recipe.steps[index].action).font(.caption).foregroundStyle(.secondary)
                }
                Picker("Trial", selection: $selectedRunID) {
                    Text("Choose a trial").tag(nil as UUID?)
                    ForEach(runner.runs.filter { $0.assetID == asset.id }) { run in
                        Text("\(run.modelID == "apple-scene" ? "Apple scene plan" : Candidate.all.first { $0.id == run.modelID }?.name ?? run.modelID), run \(run.repetition)")
                            .tag(run.id as UUID?)
                    }
                }
                if let index = selectedRunIndex, runner.runs[index].assetID == asset.id {
                    let run = runner.runs[index]
                    Text("\(run.durationSeconds.formatted(.number.precision(.fractionLength(1)))) seconds")
                        .font(.caption).foregroundStyle(.secondary)
                    if let svg = run.svg {
                        SVGPreview(svg: svg)
                            .frame(height: asset.kind == .icon ? 240 : 260)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("Save SVG") { saveSVG(svg, name: asset.id) }
                    }
                    if let error = run.error { Label(error, systemImage: "xmark.circle").foregroundStyle(.red) }
                    if let warning = run.formatWarning { Label(warning, systemImage: "text.badge.checkmark") }
                    ForEach(run.checks, id: \.self) { check in
                        Label(check, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                    DisclosureGroup("Raw model output") {
                        Text(run.rawText).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                    Divider()
                    Text("Human review").font(.headline)
                    Toggle("Subject matches", isOn: $runner.runs[index].review.subjectMatches)
                    Toggle("Action matches", isOn: $runner.runs[index].review.actionMatches)
                    Toggle("Readable at small size", isOn: $runner.runs[index].review.readableAtSmallSize)
                    Toggle("Style is consistent", isOn: $runner.runs[index].review.consistentStyle)
                    TextField("Review notes", text: $runner.runs[index].review.notes, axis: .vertical)
                        .lineLimit(3...6)
                    Button(run.review.reviewed ? "Reviewed" : "Mark reviewed") {
                        runner.runs[index].review.reviewed = true
                    }
                    .disabled(run.review.reviewed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "plates-kitchen-svg-results.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try runner.export(to: url) }
            catch { runner.status = "Export failed: \(error.localizedDescription)" }
        }
    }

    private func importResults() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK {
            do { try runner.importResults(from: panel.urls) }
            catch { runner.status = "Import failed: \(error.localizedDescription)" }
        }
    }

    private func saveSVG(_ svg: String, name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(name).svg"
        if panel.runModal() == .OK, let url = panel.url {
            do { try Data(svg.utf8).write(to: url, options: .atomic) }
            catch { runner.status = "Could not save SVG: \(error.localizedDescription)" }
        }
    }
}

private struct SVGPreview: View {
    let svg: String

    var body: some View {
        if let image = NSImage(data: Data(svg.utf8)) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white)
        }
    }
}
