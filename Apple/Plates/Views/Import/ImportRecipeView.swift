import CulinaryIntelligence
import SwiftUI

/// The sheet a recipe shared from a web page opens in. The page has written the recipe, so
/// Apple Intelligence only sorts it, the way it sorts what Gemma writes, and the cook reads it
/// and can ask for changes before it is saved. When it cannot be sorted, the recipe is shown
/// as the share extension read it.
struct ImportRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    let store: RecipeStore
    let shared: SharedImport

    @State private var generator = RecipeGenerator(observer: GenerationActivity.generation)
    @State private var draft: Recipe?
    /// Why the recipe is shown as the page wrote it, when it is.
    @State private var asReadReason: LocalizedStringResource?
    @State private var editor = RecipeAskEditor(observer: GenerationActivity.edit)
    @State private var revision = ""
    @State private var revisionError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isRevising {
                    RevisionProgressView(progress: editor.progress)
                } else if let draft {
                    RecipeConfirmationView(recipe: ConfirmationRecipe(draft)) {
                        DishIcon(recipe: draft, size: 168)
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView {
                        GenerationProgressView(progress: generator.progress)
                            .padding(.listRowInset)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        store.finish(shared, saving: nil)
                        dismiss()
                    }
                    .disabled(isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let draft {
                        Button("Shared.Save") {
                            if store.finish(shared, saving: draft) { dismiss() }
                        }
                        .disabled(isBusy)
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                if draft != nil {
                    VStack(spacing: 8) {
                        if let asReadReason {
                            Text(asReadReason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        RecipeRevisionBar(
                            text: $revision,
                            isEnabled: editor.isAvailable && !isBusy,
                            canSend: canRevise,
                            send: revise
                        )
                    }
                }
            }
        }
        .alert(
            "Edit.Ask.Title",
            isPresented: Binding(
                get: { revisionError != nil },
                set: { if !$0 { revisionError = nil } }
            )
        ) {
            Button("Shared.Done", role: .cancel) {}
        } message: {
            Text(verbatim: revisionError ?? "")
        }
        .interactiveDismissDisabled(isBusy || draft != nil)
        // Sorting runs a pass for every line, so the screen is held awake while it does.
        .onChange(of: isBusy) { UIApplication.shared.isIdleTimerDisabled = isBusy }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task { await sort() }
    }

    /// The page's title until the recipe is sorted, then the recipe's own.
    private var title: Text {
        if let draft {
            Text(verbatim: draft.title)
        } else if let page = shared.page, !page.title.isEmpty {
            Text(verbatim: page.title)
        } else {
            Text("Import.Title")
        }
    }

    private var isRevising: Bool { editor.state == .working }

    private var isBusy: Bool { generator.state == .generating || isRevising }

    private var canRevise: Bool {
        editor.isAvailable && !isBusy && !revision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sort() async {
        guard draft == nil else { return }
        if let page = shared.page, generator.canSortPages, let sorted = await generator.sortPage(page) {
            draft = sorted
            return
        }
        var recipe = store.asRead(shared.recipe)
        recipe.dish = Dish.planned(for: recipe)
        asReadReason = generator.pageUnavailableReason ?? "Import.AsRead"
        draft = recipe
    }

    /// The same changes a generated recipe takes before it is saved. A failed change leaves
    /// the draft as it was.
    private func revise() {
        guard let draft, canRevise else { return }
        let ask = revision.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if let revised = await editor.revise(draft, request: ask) {
                self.draft = revised
                revision = ""
            } else if case let .failed(message) = editor.state {
                revisionError = message
            }
        }
    }
}
