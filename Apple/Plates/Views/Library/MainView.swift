import CulinaryIntelligence
import SwiftUI

/// The app's one screen: the recipes, what is sorted and searched out of them, and the menus
/// that act on the store.
struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase

    enum SortOrder: String, CaseIterable, Identifiable {
        case alphabetical
        case quickest

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .alphabetical: "Sort.Alphabetical"
            case .quickest: "Sort.Quickest"
            }
        }
    }

    @State private var store = RecipeStore()
    @State private var sortOrder: SortOrder = .alphabetical
    @State private var showTriedOnly = false
    @State private var search = ""
    @State private var generation: Generation?
    /// The shared web page being sorted, one at a time.
    @State private var sharedImport: SharedImport?
    @State private var isShowingLimits = false
    @State private var isShowingInventory = false
    @AppStorage("Onboarding.Completed") private var onboardingCompleted = false
    @State private var isOnboarding = false
    /// Set by plates://onboardme, so onboarding opens once the sheets in its way are gone.
    @State private var isOnboardingRequested = false
    /// The dish named at the end of onboarding, written in once the recipe sheet opens.
    @State private var firstDish = ""
    /// Whether recipes are generated, or only written by hand, as the cook chose in onboarding
    /// or later in the menu.
    @AppStorage(PlatesCloud.allowedKey) private var isGenerationAllowed = false
    @State private var isShowingAIProcessing = false
    @State private var path = NavigationPath()
    /// The title a recipe written by hand starts with, once the recipe sheet is gone.
    @State private var byHandTitle: String?

    var body: some View {
        NavigationStack(path: $path) {
            RecipesGridView(recipes: visibleRecipes, delete: store.delete)
                .navigationTitle("Recipe.List.Title")
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0, store: store) }
                .navigationDestination(for: ByHand.self) {
                    RecipeDetailView(recipe: $0.recipe, store: store, isEditing: true)
                }
                .searchable(text: $search, prompt: Text("Recipe.List.Search.Prompt"))
                .overlay {
                    if store.recipes.isEmpty {
                        emptyState
                    } else if visibleRecipes.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingInventory = true
                        } label: {
                            Label("Menu.Inventory", systemImage: "refrigerator")
                        }
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    ToolbarItem(placement: .topBarTrailing) {
                        menu
                    }
                    ToolbarItem(placement: .bottomBar) {
                        sortFilterMenu
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: newRecipe) {
                            Label(newRecipeTitle, systemImage: "plus")
                        }
                    }
                }
                .sheet(item: $generation, onDismiss: generationDismissed) { generation in
                    GenerateRecipeView(store: store, dish: generation.dish) { title in
                        byHandTitle = title
                        self.generation = nil
                    }
                }
        }
        .sheet(isPresented: $isShowingLimits, onDismiss: openNextImport) {
            LimitsView()
        }
        .sheet(isPresented: $isShowingInventory, onDismiss: openNextImport) {
            InventoryView()
        }
        .sheet(item: $sharedImport, onDismiss: openNextImport) { shared in
            ImportRecipeView(store: store, shared: shared)
        }
        .sheet(isPresented: $isOnboarding, onDismiss: openFirstRecipe) {
            OnboardingView { dish in
                onboardingCompleted = true
                firstDish = dish ?? ""
                isOnboarding = false
            }
        }
        .sheet(isPresented: $isShowingAIProcessing, onDismiss: openNextImport) {
            AIProcessingView()
        }
        .onAppear {
            store.importSharedRecipes()
            if !onboardingCompleted { isOnboarding = true }
            openNextImport()
        }
        .onOpenURL { url in
            guard url.scheme == "plates", url.host() == "onboardme" else { return }
            onboardAgain()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            store.importSharedRecipes()
            openNextImport()
        }
    }

    /// What the recipe sheet opens with. It is handed over whole, since a sheet shown from a
    /// flag can be built before the values set beside the flag reach it.
    struct Generation: Identifiable {
        let id = UUID()
        var dish = ""
    }

    /// A recipe started by hand, opened in the editor rather than read.
    struct ByHand: Hashable {
        let recipe: Recipe
    }

    private var newRecipeTitle: LocalizedStringKey {
        isGenerationAllowed ? "Menu.Generate" : "Menu.New"
    }

    /// The recipe sheet when recipes are generated, and a blank recipe when they are not.
    private func newRecipe() {
        if isGenerationAllowed {
            generation = Generation()
        } else {
            writeByHand(titled: "")
        }
    }

    /// Writes out a blank recipe and opens it in the editor, where every change is saved as it
    /// is made.
    private func writeByHand(titled title: String) {
        let recipe = Recipe(
            id: "",
            title: title.isEmpty ? String(localized: "Recipe.New.Untitled") : title,
            time: "30 min",
            serves: "2",
            ingredients: IngredientSections(),
            tools: [],
            steps: [],
            troubleshooting: []
        )
        guard let created = store.create(recipe) else { return }
        path.append(ByHand(recipe: created))
    }

    private func generationDismissed() {
        if let byHandTitle { writeByHand(titled: byHandTitle) }
        byHandTitle = nil
        openNextImport()
    }

    /// The recipe sheet waits for onboarding to be gone, since one sheet cannot open over
    /// another that is closing.
    private func openFirstRecipe() {
        if !firstDish.isEmpty {
            if isGenerationAllowed {
                generation = Generation(dish: firstDish)
            } else {
                writeByHand(titled: firstDish)
            }
        }
        firstDish = ""
        openNextImport()
    }

    /// Closes whatever sheet is open and brings onboarding back, which opens from
    /// `openNextImport` once the sheet is gone.
    private func onboardAgain() {
        guard !isOnboarding else { return }
        isOnboardingRequested = true
        generation = nil
        sharedImport = nil
        isShowingLimits = false
        isShowingInventory = false
        isShowingAIProcessing = false
        openNextImport()
    }

    /// Opens the next shared web page once nothing else is on screen, so a page shared while
    /// the cook was busy waits its turn rather than covering what they were doing. Onboarding
    /// asked for by URL goes first.
    private func openNextImport() {
        guard sharedImport == nil, generation == nil, !isOnboarding, !isShowingLimits,
              !isShowingInventory, !isShowingAIProcessing else { return }
        if isOnboardingRequested {
            isOnboardingRequested = false
            isOnboarding = true
            return
        }
        sharedImport = store.sharedPages.first
    }

    private var menu: some View {
        Menu {
            Section("Menu.Storage.Title") {
                Picker(
                    "Menu.Storage.Title",
                    selection: Binding(get: { store.location }, set: { store.location = $0 })
                ) {
                    ForEach(StorageLocation.allCases) { location in
                        Label {
                            Text(location.title)
                        } icon: {
                            Image(systemName: location.symbol)
                        }
                        .tag(location)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                if store.recipes.isEmpty {
                    Button {
                        store.addSampleRecipes()
                    } label: {
                        Label("Menu.AddSamples", systemImage: "tray.and.arrow.down")
                    }
                }
                Button {
                    store.load()
                } label: {
                    Label("Menu.Refresh", systemImage: "arrow.clockwise")
                }
            }

            Section {
                Button {
                    isShowingAIProcessing = true
                } label: {
                    Label("Menu.AIProcessing", systemImage: "apple.intelligence")
                }

                if PlatesCloud.shared.isConfigured, isGenerationAllowed {
                    Button {
                        isShowingLimits = true
                    } label: {
                        Label("Menu.Limits", systemImage: "gauge.with.dots.needle.33percent")
                    }
                }
            }

            Section {
                Link(destination: URL(string: "https://github.com/AtelierSuite/Plates")!) {
                    Label {
                        Text("Menu.SourceCode")
                        Text(verbatim: "AtelierSuite/Plates")
                    } icon: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
        } label: {
            Label("Menu.Label", systemImage: "ellipsis")
        }
    }

    private var sortFilterMenu: some View {
        Menu {
            Picker("Menu.Sort.Title", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
            .pickerStyle(.inline)
            Toggle("Menu.Sort.TriedOnly", isOn: $showTriedOnly)
        } label: {
            Label("Menu.Sort.Title", systemImage: "line.3.horizontal.decrease")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Recipe.List.Empty.Title", systemImage: "frying.pan")
        } description: {
            if let loadError = store.loadError {
                Text(verbatim: loadError)
            } else if isGenerationAllowed {
                Text("Recipe.List.Empty.Description")
            } else {
                Text("Recipe.List.Empty.Description.ByHand")
            }
        } actions: {
            Button(newRecipeTitle, action: newRecipe)
                .buttonStyle(.borderedProminent)
            Button("Menu.AddSamples") { store.addSampleRecipes() }
        }
    }

    /// Sorted and filtered on every render, so the order files come back in never matters.
    private var visibleRecipes: [Recipe] {
        var list = store.recipes
        if showTriedOnly {
            list = list.filter { $0.tried == true }
        }
        if !search.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(search) }
        }
        switch sortOrder {
        case .alphabetical:
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .quickest:
            list.sort {
                $0.minutes == $1.minutes
                    ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    : $0.minutes < $1.minutes
            }
        }
        return list
    }
}

#Preview {
    MainView()
}
