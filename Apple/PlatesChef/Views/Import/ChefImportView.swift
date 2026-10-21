import SwiftUI

struct ChefImportView: View {
    let items: [NSExtensionItem]
    let complete: () -> Void
    let cancel: () -> Void

    @State private var recipe: ChefRecipe?
    @State private var isLoading = true
    @State private var failure: Failure?
    @State private var saveFailed = false

    private enum Failure {
        case noURL, unsupportedURL, downloadFailed, noRecipe
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Chef.Loading")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let recipe {
                    RecipeConfirmationView(recipe: ConfirmationRecipe(recipe))
                } else {
                    errorView
                }
            }
            .navigationTitle(recipe?.title ?? String(localized: "Chef.Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if recipe != nil {
                        Button("Chef.Add", action: save)
                            .disabled(recipe?.canSave != true)
                    }
                }
            }
            // The app sorts a page's recipe when it next opens, so the cook is told to go there.
            .safeAreaBar(edge: .bottom) {
                if recipe?.page != nil {
                    Text("Chef.OpenPlates")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        .task { await load() }
        .alert("Chef.Error.Save", isPresented: $saveFailed) {
            Button("Chef.OK", role: .cancel) {}
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Chef.Error.Title", systemImage: "doc.text.magnifyingglass")
        } description: {
            switch failure {
            case .noURL: Text("Chef.Error.NoURL")
            case .unsupportedURL: Text("Chef.Error.UnsupportedURL")
            case .downloadFailed: Text("Chef.Error.Download")
            case .noRecipe, .none: Text("Chef.Error.NoRecipe")
            }
        } actions: {
            Button("Chef.Retry") { Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        do {
            recipe = try await RecipePageLoader.load(from: items)
            failure = nil
        } catch let error as RecipePageLoader.LoadError {
            switch error {
            case .noURL: failure = .noURL
            case .unsupportedURL: failure = .unsupportedURL
            case .downloadFailed: failure = .downloadFailed
            case .noRecipe: failure = .noRecipe
            }
        } catch {
            failure = .downloadFailed
        }
        isLoading = false
    }

    private func save() {
        guard var recipe else { return }
        recipe.tidy()
        guard recipe.canSave,
              let group = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.Plates"
              ) else {
            saveFailed = true
            return
        }
        do {
            let directory = group.appending(path: "PendingRecipes", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appending(path: "\(UUID().uuidString).json")
            try JSONEncoder().encode(recipe).write(to: destination, options: .atomic)
            complete()
        } catch {
            saveFailed = true
        }
    }
}
