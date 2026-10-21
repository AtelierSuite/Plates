import SwiftUI
import AppKit

struct ImageKitchenView: View {
    @ObservedObject var runner: ImageRunner
    @State private var selectedAssetID: String?
    @State private var selectedRunID: UUID?
    @State private var galleryModelID = "bk-sdm-v2-tiny"
    @State private var showCutouts = true
    /// Nil shows the most recent run of each asset regardless of style.
    @State private var galleryStyleID: String?

    private var selectedRunIndex: Int? { runner.runs.firstIndex { $0.id == selectedRunID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button("Run image models") { runner.start() }.disabled(runner.isRunning)
                    .buttonStyle(.borderedProminent)
                Button("Stop") { runner.stop() }.disabled(!runner.isRunning)
                Menu("Settings") {
                    ForEach(ImageCandidate.all) { candidate in
                        Toggle(candidate.name, isOn: Binding(
                            get: { runner.selectedModels.contains(candidate.id) },
                            set: { selected in
                                if selected { runner.selectedModels.insert(candidate.id) }
                                else { runner.selectedModels.remove(candidate.id) }
                            }
                        ))
                    }
                    Button("Select all downloaded models") {
                        runner.selectedModels = Set(runner.downloadedModels.map(\.id))
                    }
                    Divider()
                    Picker("Style", selection: Binding(
                        get: { runner.styleOverrides.first?.id ?? "" },
                        set: { id in runner.styleOverrides = ImageStyle.all.filter { $0.id == id } }
                    )) {
                        Text("Each model's default").tag("")
                        ForEach(ImageStyle.all) { style in Text(style.name).tag(style.id) }
                    }
                    Picker("Runs per image", selection: $runner.repetitions) {
                        ForEach(1...10, id: \.self) { count in Text("\(count)").tag(count) }
                    }
                    Picker("Concurrent image workers", selection: $runner.concurrency) {
                        ForEach(1...4, id: \.self) { count in Text("\(count)").tag(count) }
                    }
                    .help("Each worker loads its own Core ML pipeline and uses more memory.")
                    Picker("Background", selection: $runner.background) {
                        ForEach(ImageBackground.allCases) { background in Text(background.rawValue.capitalized).tag(background) }
                    }
                    Picker("Denoising steps", selection: $runner.stepCount) {
                        ForEach([10, 15, 20, 25, 30, 40], id: \.self) { count in Text("\(count)").tag(count) }
                    }
                    Divider()
                    ForEach(ImageCandidate.all.filter { $0.archiveURL != nil }) { candidate in
                        Button(runner.resourceURL(for: candidate) == nil
                               ? "Download \(candidate.name) (\(candidate.approximateSizeMB) MB)"
                               : "\(candidate.name) downloaded") { runner.download(candidate) }
                            .disabled(runner.downloadingModelID != nil || runner.resourceURL(for: candidate) != nil)
                    }
                }
                Menu("Results") {
                    Button("Export JSON") { export() }.disabled(runner.runs.isEmpty)
                    Button("Redo background removal") { runner.recutSavedImages() }
                        .disabled(runner.isRunning || !runner.runs.contains { $0.imageFile != nil })
                    Button("Show images in Finder") { NSWorkspace.shared.open(runner.imageDirectory) }
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
        return "\(trials.filter { $0.imageFile != nil }.count)/\(trials.count)"
    }

    private func galleryMatches(_ run: ImageRun) -> Bool {
        run.modelID == galleryModelID && (galleryStyleID == nil || (run.styleID ?? ImageStyle.cookbook.id) == galleryStyleID)
    }

    private func styleName(_ id: String?) -> String {
        ImageStyle.all.first { $0.id == (id ?? ImageStyle.cookbook.id) }?.name ?? (id ?? "")
    }

    private func modelName(_ id: String) -> String {
        ImageCandidate.all.first { $0.id == id }?.name ?? id
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Image gallery").font(.title2.bold())
                Picker("Model", selection: $galleryModelID) {
                    ForEach(ImageCandidate.all) { candidate in Text(candidate.name).tag(candidate.id) }
                }
                .frame(maxWidth: 320)
                Picker("Style", selection: $galleryStyleID) {
                    Text("Any").tag(nil as String?)
                    ForEach(ImageStyle.all) { style in Text(style.name).tag(style.id as String?) }
                }
                .frame(maxWidth: 320)
                Toggle("Show background removed", isOn: $showCutouts)
                let generated = runner.runs.filter { galleryMatches($0) && $0.imageFile != nil }
                if !generated.isEmpty {
                    Text("\(generated.filter { $0.cutoutChecks.isEmpty }.count) of \(generated.count) cutouts are usable without problems.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                let timed = generated.map(\.durationSeconds).sorted()
                if !timed.isEmpty {
                    Text("\(timed.count) images. Median \(timed[timed.count / 2].formatted(.number.precision(.fractionLength(1)))) seconds on this Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(runner.recipes) { recipe in
                    Text(recipe.title).font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 12) {
                        ForEach(recipe.assets) { asset in
                            VStack(alignment: .leading, spacing: 5) {
                                if let run = runner.runs.first(where: { $0.assetID == asset.id && galleryMatches($0) }),
                                   let url = showCutouts ? runner.cutoutURL(for: run) : runner.imageURL(for: run) {
                                    GeneratedImage(url: url, checkerboard: showCutouts).frame(height: 160)
                                        .overlay(alignment: .topTrailing) {
                                            if showCutouts && !run.cutoutChecks.isEmpty {
                                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).padding(4)
                                                    .help(run.cutoutChecks.joined(separator: "\n"))
                                            }
                                        }
                                } else {
                                    Label("No image", systemImage: "xmark.square")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .frame(height: 160)
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
                Picker("Trial", selection: $selectedRunID) {
                    Text("Choose a trial").tag(nil as UUID?)
                    ForEach(runner.runs.filter { $0.assetID == asset.id }) { run in
                        Text("\(modelName(run.modelID)), \(styleName(run.styleID)), run \(run.repetition)").tag(run.id as UUID?)
                    }
                }
                if let index = selectedRunIndex, runner.runs[index].assetID == asset.id {
                    let run = runner.runs[index]
                    Text("\(run.durationSeconds.formatted(.number.precision(.fractionLength(1)))) seconds, \(run.stepCount) steps, seed \(run.seed)")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 12) {
                        if let url = runner.imageURL(for: run) {
                            GeneratedImage(url: url)
                                .frame(maxWidth: 360, maxHeight: 360)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if let url = runner.cutoutURL(for: run) {
                            GeneratedImage(url: url, checkerboard: true)
                                .frame(maxWidth: 360, maxHeight: 360)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if let method = run.cutoutMethod {
                        Text("Background removed with \(method == .vision ? "Vision subject lifting" : "the border color key"). Subject covers \(Int((run.subjectCoverage ?? 0) * 100))% of the image, \(Int((run.subjectCenterOffset ?? 0) * 100))% off center.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(run.cutoutNotes, id: \.self) { note in
                        Label(note, systemImage: "wand.and.stars").foregroundStyle(.secondary)
                    }
                    ForEach(run.cutoutChecks, id: \.self) { check in
                        Label(check, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                    if let error = run.error { Label(error, systemImage: "xmark.circle").foregroundStyle(.red) }
                    DisclosureGroup("Prompt") {
                        Text(run.prompt).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
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
        panel.nameFieldStringValue = "plates-kitchen-image-results.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try runner.export(to: url) }
            catch { runner.status = "Export failed: \(error.localizedDescription)" }
        }
    }
}

private struct GeneratedImage: View {
    let url: URL
    var checkerboard = false

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .background { if checkerboard { Checkerboard() } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 10
            for row in 0..<Int(size.height / square) + 1 {
                for column in 0..<Int(size.width / square) + 1 where (row + column) % 2 == 1 {
                    context.fill(Path(CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square, width: square, height: square)),
                                 with: .color(.gray.opacity(0.25)))
                }
            }
        }
        .background(.white)
    }
}
