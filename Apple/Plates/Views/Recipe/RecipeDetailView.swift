import CulinaryIntelligence
import SwiftUI

struct RecipeDetailView: View {
    /// Where edits are written. A recipe being looked over before it is saved has no store, so
    /// it is shown without the way into the editor.
    private let store: RecipeStore?

    @State private var recipe: Recipe
    @State private var isEditing = false
    @State private var isShowingTroubleshooting = false
    /// The list whose missing lines are being asked about.
    @State private var checking: RecipeList?
    /// What the inventory held when it was last read, so a list can say it is missing lines.
    @State private var inventoryIngredients = Pantry.ingredients
    @State private var inventoryTools = Pantry.tools
    @State private var isCooking = false
    @State private var tapped: TileInfo?
    @State private var field: Field?
    @State private var fieldText = ""
    @State private var editingCard: CardEdit?
    @State private var editingStep: ListEdit?
    @State private var editingNote: ListEdit?
    @State private var shared: SharedFile?
    @State private var shareFailed = false
    /// Changes the cook asks for in their own words while editing.
    @State private var editor = RecipeAskEditor(observer: GenerationActivity.edit)
    @State private var revision = ""
    @State private var revisionError: String?
    /// Asking for changes is left out when the cook writes their recipes by hand.
    @AppStorage(PlatesCloud.allowedKey) private var isGenerationAllowed = false

    /// The three things about a recipe that are edited in an alert rather than a sheet.
    private enum Field {
        case name
        case time
        case serves
    }

    /// A recipe started by hand opens already being edited.
    init(recipe: Recipe, store: RecipeStore? = nil, isEditing: Bool = false) {
        _recipe = State(initialValue: recipe)
        _isEditing = State(initialValue: isEditing)
        self.store = store
    }

    var body: some View {
        Group {
            if isRevising {
                RevisionProgressView(progress: editor.progress)
            } else {
                page
            }
        }
        .safeAreaBar(edge: .bottom) {
            if isEditing, isGenerationAllowed {
                RecipeRevisionBar(
                    text: $revision,
                    isEnabled: editor.isAvailable && !isRevising,
                    canSend: canRevise,
                    send: revise
                )
            }
        }
        .navigationDestination(for: RecipeList.self) { list in
            picker(for: list)
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .animation(.default, value: isEditing)
        .toolbar {
            if store != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(
                            isEditing ? "Shared.Done" : "Recipe.Edit.Start",
                            systemImage: isEditing ? "checkmark" : "pencil"
                        )
                    }
                    .disabled(isRevising)
                }
            }

            if !isEditing {
                ToolbarItem(placement: .bottomBar) {
                    shareMenu
                }
            }

            if !recipe.steps.isEmpty, !isEditing {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isCooking = true
                    } label: {
                        Text("Recipe.Cook.Start")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                }
            }

            if !recipe.troubleshooting.isEmpty, !isEditing {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isShowingTroubleshooting = true
                    } label: {
                        Label("Recipe.Detail.Troubleshooting", systemImage: "questionmark.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingTroubleshooting) {
            TroubleshootingView(entries: recipe.troubleshooting)
        }
        .fullScreenCover(isPresented: $isCooking) {
            CookingView(recipe: recipe, markTried: store == nil ? nil : {
                recipe.tried = true
                save()
            })
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
        // A pass can take a while, and the screen is not touched while it runs, so it is held
        // awake rather than locking part way through.
        .onChange(of: isRevising) { UIApplication.shared.isIdleTimerDisabled = isRevising }
        // Covering the page with cooking mode can count as leaving it, and cooking mode keeps
        // the screen awake itself, so it is left alone then.
        // The inventory is changed from the popover and from the main screen, so it is read
        // again whenever either could have changed it.
        .onAppear(perform: readInventory)
        .onChange(of: checking) { if checking == nil { readInventory() } }
        .onDisappear {
            if !isCooking { UIApplication.shared.isIdleTimerDisabled = false }
        }
        .sheet(item: $shared) { file in
            ShareSheet(url: file.url)
        }
        .sheet(item: $editingCard) { card in
            cardEditor(card)
        }
        .sheet(item: $editingStep) { edit in
            stepEditor(edit)
        }
        .sheet(item: $editingNote) { edit in
            noteEditor(edit)
        }
        .alert(
            Text(verbatim: tapped?.name ?? ""),
            isPresented: Binding(get: { tapped != nil }, set: { if !$0 { tapped = nil } }),
            presenting: tapped
        ) { _ in
            Button("Shared.Done", role: .cancel) {}
        } message: { info in
            // A tool with no note has nothing beyond its name, which the alert already titles.
            if !info.message.isEmpty {
                Text(verbatim: info.message)
            }
        }
        .alert("Recipe.Edit.Name", isPresented: editing(.name)) {
            TextField("Recipe.Edit.Name", text: $fieldText)
            Button("Shared.Cancel", role: .cancel) {}
            Button("Shared.Save") { setTitle() }
        }
        .alert("Recipe.Detail.Time", isPresented: editing(.time)) {
            TextField("Recipe.Edit.Time.Prompt", text: $fieldText)
            Button("Shared.Cancel", role: .cancel) {}
            Button("Shared.Save") { setTime() }
        } message: {
            Text("Recipe.Edit.Time.Message")
        }
        .alert("Recipe.Detail.Serves", isPresented: editing(.serves)) {
            TextField("Recipe.Edit.Serves.Prompt", text: $fieldText)
            Button("Shared.Cancel", role: .cancel) {}
            Button("Shared.Save") { setServes(scaling: false) }
            Button("Recipe.Edit.Serves.Scale") { setServes(scaling: true) }
        } message: {
            Text("Recipe.Edit.Serves.Message")
        }
        .alert("Recipe.Share.Error", isPresented: $shareFailed) {
            Button("Shared.Done", role: .cancel) {}
        }
    }

    // MARK: - The page

    /// What the recipe is called, editable while the rest of it is.
    private var nameCard: some View {
        Button {
            open(.name, with: recipe.title)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recipe.Edit.Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: recipe.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .cardBackground()
        }
        .buttonStyle(.plain)
    }

    /// The dish from above. While the recipe is edited, the dish can be worked out again from
    /// the recipe as it now stands, which also lays it out afresh. A dish drawn from its
    /// signature icon has nothing to work out.
    private var dishHeader: some View {
        VStack(spacing: 12) {
            DishIcon(recipe: recipe, size: 168)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            if isEditing, SignatureDish.id(for: recipe) == nil {
                Button("Recipe.Edit.RedrawDish", systemImage: "arrow.clockwise") {
                    Task {
                        recipe.dish = await Dish.asked(for: recipe, seed: UUID().uuidString)
                        save()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Time, servings, and whether it has been cooked, side by side. The cooked mark turns over
    /// on a tap; the other two open an alert while the recipe is being edited.
    private var summary: some View {
        Grid(horizontalSpacing: 12) {
            GridRow {
                Button {
                    guard isEditing else { return }
                    open(.time, with: recipe.time)
                } label: {
                    SummaryCell(label: "Recipe.Detail.Time") {
                        Text(verbatim: recipe.formattedTime)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isEditing)

                Button {
                    guard isEditing else { return }
                    open(.serves, with: recipe.serves)
                } label: {
                    SummaryCell(label: "Recipe.Detail.Serves") {
                        Text(verbatim: recipe.serves)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isEditing)

                Button {
                    recipe.tried = recipe.tried == true ? nil : true
                    save()
                } label: {
                    SummaryCell(label: "Recipe.Detail.Tried") {
                        // Drawn as text so the mark sits on the same line as the other two cells.
                        Text(Image(systemName: recipe.tried == true ? "checkmark" : "xmark"))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A row that scrolls sideways, cut so the third card is half on screen and the cook can
    /// see there is more to come. While the recipe is being edited the row always shows, with
    /// the way into the catalog at the end of it.
    @ViewBuilder
    private func carousel(_ list: RecipeList) -> some View {
        let items = recipe.items(in: list)
        if !items.isEmpty || isEditing {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(list.title)
                        .font(.headline)
                    if !isEditing {
                        inventoryCheck(list)
                    }
                }
                .padding(.horizontal, .listRowInset)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            Button {
                                if isEditing {
                                    editingCard = CardEdit(list: list, index: index)
                                } else {
                                    tapped = item
                                }
                            } label: {
                                IconTile(item: item)
                            }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 12)
                        }

                        if isEditing {
                            NavigationLink(value: list) {
                                AddCard(label: "Recipe.Edit.Add")
                            }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 12)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, .listRowInset, for: .scrollContent)
            }
        }
    }

    /// A mark beside a list's title when the inventory is missing some of its lines. A tap asks
    /// whether the cook has them.
    @ViewBuilder
    private func inventoryCheck(_ list: RecipeList) -> some View {
        let missing = ShoppingList(
            recipe: recipe,
            in: list,
            inventoryIngredients: inventoryIngredients,
            inventoryTools: inventoryTools
        )
        if !missing.isEmpty {
            Button {
                checking = list
            } label: {
                Image(systemName: "exclamationmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Inventory.Check.Label"))
            .popover(isPresented: Binding(
                get: { checking == list },
                set: { if !$0 { checking = nil } }
            )) {
                InventoryCheckView(list: missing)
            }
        }
    }

    private func readInventory() {
        inventoryIngredients = Pantry.ingredients
        inventoryTools = Pantry.tools
    }

    /// The method. While the recipe is being edited a step opens on a tap and moves on a drag,
    /// and a new one is added at the end.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe.Detail.Steps")
                .font(.headline)

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                if isEditing {
                    Button {
                        editingStep = ListEdit(index: index)
                    } label: {
                        StepCard(number: index + 1, step: step)
                    }
                    .buttonStyle(.plain)
                    .draggable(String(index)) {
                        StepCard(number: index + 1, step: step)
                            .frame(width: 280)
                    }
                    .dropDestination(for: String.self) { payload, _ in
                        guard let from = payload.first.flatMap({ Int($0) }) else { return false }
                        move(from: from, to: index)
                        return true
                    }
                } else {
                    StepCard(number: index + 1, step: step)
                }
            }

            if isEditing {
                Button {
                    editingStep = ListEdit(index: recipe.steps.count)
                } label: {
                    AddCard(label: "Recipe.Edit.Step.Add")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The notes kept with the recipe, which are read from the bottom bar and written here.
    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe.Detail.Troubleshooting")
                .font(.headline)

            ForEach(Array(recipe.troubleshooting.enumerated()), id: \.offset) { index, note in
                Button {
                    editingNote = ListEdit(index: index)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: note.problem)
                            .font(.headline)
                        Text(verbatim: note.solution)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardBackground()
                }
                .buttonStyle(.plain)
            }

            Button {
                editingNote = ListEdit(index: recipe.troubleshooting.count)
            } label: {
                AddCard(label: "Recipe.Edit.Note.Add")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var shareMenu: some View {
        Menu {
            ForEach(ShareFormat.allCases) { format in
                Button {
                    share(format)
                } label: {
                    Label(format.title, systemImage: format.symbol)
                }
            }
        } label: {
            Label("Recipe.Share.Title", systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - The editors

    /// The catalog, picking into one of the recipe's own lists.
    @ViewBuilder
    private func picker(for list: RecipeList) -> some View {
        if list.isIngredients {
            CatalogPickerView.recipeIngredients(title: list.title, selection: assets(in: list))
        } else {
            CatalogPickerView.recipeTools(title: list.title, selection: assets(in: list))
        }
    }

    @ViewBuilder
    private func cardEditor(_ card: CardEdit) -> some View {
        if card.list.isIngredients {
            let list = recipe.ingredientList(in: card.list)
            if list.indices.contains(card.index) {
                IngredientEditor(ingredient: list[card.index]) { edited in
                    var list = list
                    list[card.index] = edited
                    recipe.setIngredients(list, in: card.list)
                    save()
                } remove: {
                    var list = list
                    list.remove(at: card.index)
                    recipe.setIngredients(list, in: card.list)
                    save()
                }
            }
        } else {
            let list = recipe.toolList(in: card.list)
            if list.indices.contains(card.index) {
                ToolEditor(tool: list[card.index]) { edited in
                    var list = list
                    list[card.index] = edited
                    recipe.setTools(list, in: card.list)
                    save()
                } remove: {
                    var list = list
                    list.remove(at: card.index)
                    recipe.setTools(list, in: card.list)
                    save()
                }
            }
        }
    }

    private func stepEditor(_ edit: ListEdit) -> some View {
        let isNew = !recipe.steps.indices.contains(edit.index)
        return StepEditor(
            step: isNew ? Step(title: "", icons: nil, points: []) : recipe.steps[edit.index],
            choices: stepChoices
        ) { edited in
            if isNew {
                recipe.steps.append(edited)
            } else {
                recipe.steps[edit.index] = edited
            }
            save()
        } remove: {
            guard !isNew else { return }
            recipe.steps.remove(at: edit.index)
            save()
        }
    }

    private func noteEditor(_ edit: ListEdit) -> some View {
        let isNew = !recipe.troubleshooting.indices.contains(edit.index)
        return NoteEditor(
            note: isNew
                ? Troubleshooting(problem: "", solution: "")
                : recipe.troubleshooting[edit.index]
        ) { edited in
            if isNew {
                recipe.troubleshooting.append(edited)
            } else {
                recipe.troubleshooting[edit.index] = edited
            }
            save()
        } remove: {
            guard !isNew else { return }
            recipe.troubleshooting.remove(at: edit.index)
            save()
        }
    }

    /// The icons a step can be marked with: whatever the recipe itself carries.
    private var stepChoices: [StepEditor.Choice] {
        RecipeList.allCases
            .flatMap { recipe.items(in: $0) }
            .map { StepEditor.Choice(path: $0.icon, name: $0.name) }
            .reduce(into: [StepEditor.Choice]()) { picked, choice in
                if !picked.contains(choice) { picked.append(choice) }
            }
    }

    /// One of the recipe's lists as the catalog picker reads and writes it: asset names in,
    /// entries out. An entry already in the list keeps its amount and its note.
    private func assets(in list: RecipeList) -> Binding<[String]> {
        Binding(
            get: { recipe.items(in: list).compactMap { IconCatalog.iconName(for: $0.icon) } },
            set: { picks in
                if list.isIngredients {
                    let existing = recipe.ingredientList(in: list)
                    recipe.setIngredients(
                        picks.map { asset in
                            existing.first { IconCatalog.iconName(for: $0.icon) == asset }
                                ?? Ingredient(
                                    item: IconCatalog.displayName(for: asset),
                                    icon: IconCatalog.ingredientPath(for: asset),
                                    amount: "",
                                    note: nil
                                )
                        },
                        in: list
                    )
                } else {
                    let existing = recipe.toolList(in: list)
                    recipe.setTools(
                        picks.map { asset in
                            existing.first { IconCatalog.iconName(for: $0.icon) == asset }
                                ?? Tool(
                                    name: IconCatalog.displayName(for: asset),
                                    icon: IconCatalog.toolPath(for: asset),
                                    required: list == .tools,
                                    note: nil
                                )
                        },
                        in: list
                    )
                }
                save()
            }
        )
    }

    // MARK: - Editing

    private func editing(_ value: Field) -> Binding<Bool> {
        Binding(get: { field == value }, set: { if !$0 { field = nil } })
    }

    private func open(_ value: Field, with text: String) {
        fieldText = text
        field = value
    }

    private func setTitle() {
        let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        recipe.title = text
        save()
    }

    private func setTime() {
        let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        recipe.time = text
        save()
    }

    /// A new serving count, on its own or with every amount written up or down to match.
    private func setServes(scaling: Bool) {
        let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if scaling,
           let before = Recipe.servings(in: recipe.serves),
           let after = Recipe.servings(in: text) {
            recipe.scaleAmounts(by: after / before)
        }
        recipe.serves = text
        save()
    }

    private func move(from: Int, to: Int) {
        guard recipe.steps.indices.contains(from), from != to else { return }
        let step = recipe.steps.remove(at: from)
        recipe.steps.insert(step, at: min(to, recipe.steps.count))
        save()
    }

    private func share(_ format: ShareFormat) {
        do {
            shared = SharedFile(url: try RecipeExport.file(format, for: recipe))
        } catch {
            shareFailed = true
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isEditing {
                    nameCard
                        .padding(.horizontal, .listRowInset)
                }

                dishHeader

                summary
                    .padding(.horizontal, .listRowInset)

                ForEach(RecipeList.allCases) { carousel($0) }

                steps
                    .padding(.horizontal, .listRowInset)

                if isEditing {
                    notes
                        .padding(.horizontal, .listRowInset)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var isRevising: Bool { editor.state == .working }

    private var trimmedRevision: String {
        revision.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canRevise: Bool {
        editor.isAvailable && !isRevising && !trimmedRevision.isEmpty
    }

    /// Asks the model for the changes and saves them, as every other edit here is saved. A
    /// failed change leaves the recipe as it was.
    private func revise() {
        guard canRevise else { return }
        let ask = trimmedRevision
        Task {
            if let revised = await editor.revise(recipe, request: ask) {
                recipe = revised
                revision = ""
                save()
            } else if case let .failed(message) = editor.state {
                revisionError = message
            }
        }
    }

    /// Every edit goes straight to the file, so leaving the editor is never the thing that
    /// keeps the work.
    private func save() {
        store?.save(recipe)
    }
}
