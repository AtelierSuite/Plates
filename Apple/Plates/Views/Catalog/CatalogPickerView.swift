import CulinaryIntelligence
import SwiftUI

/// A two column grid of catalog cards to tick off, grouped into native list sections, so a cook can pick
/// what they have instead of typing it. Icon names come back from the catalog already in the
/// reader's language, so they are shown as they are handed over.
struct CatalogPickerView: View {
    /// One collapsible group of icons.
    struct IconGroup: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let icons: [String]
    }

    var title: LocalizedStringResource
    let searchPrompt: LocalizedStringResource
    /// What the picked bar says while nothing is picked.
    let emptyLabel: LocalizedStringResource
    /// The groups a search turns up. An empty search returns everything.
    let groups: (String) -> [IconGroup]
    /// Where an asset name sits in the schema, so the tile can draw it.
    let path: (String) -> String

    @Binding var selection: [String]

    @State private var query = ""
    @State private var collapsed: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        List {
            ForEach(matches) { group in
                Section {
                    if isExpanded(group.id) {
                        grid(group.icons)
                    }
                } header: {
                    header(group)
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) { pickedBar }
        .animation(.default, value: selection)
        .searchable(text: $query, prompt: Text(searchPrompt))
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var matches: [IconGroup] { groups(query) }

    /// What is picked so far, floating over the catalog rather than taking a section from it.
    /// A tap in here drops the pick, so nothing in the bar is highlighted. The bar stays put
    /// when nothing is picked, so the catalog never shifts under a finger.
    private var pickedBar: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(selection.isEmpty ? emptyLabel : "Generate.Picker.Selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: selection.isEmpty ? .center : .leading)
                if !selection.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(selection, id: \.self) { asset in
                                Button {
                                    toggle(asset)
                                } label: {
                                    VStack(spacing: 2) {
                                        RecipeIcon(path: path(asset), size: 36)
                                        Text(verbatim: IconCatalog.displayName(for: asset))
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(width: 72)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                }
            }
            .padding(.vertical, 10)
            .frame(height: 92, alignment: selection.isEmpty ? .center : .top)
            .glassEffect(.regular, in: .rect(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// A group closes on a tap of its header. A search leaves every group it matched open,
    /// so nothing found is hidden behind a closed header. The inset grouped style draws no
    /// disclosure of its own, so the header carries the chevron.
    private func isExpanded(_ id: String) -> Bool {
        !query.isEmpty || !collapsed.contains(id)
    }

    private func header(_ group: IconGroup) -> some View {
        HStack {
            Text(group.title)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.semibold))
                .rotationEffect(.degrees(isExpanded(group.id) ? 0 : -90))
        }
        .contentShape(.rect)
        .onTapGesture {
            withAnimation {
                if collapsed.contains(group.id) {
                    collapsed.remove(group.id)
                } else {
                    collapsed.insert(group.id)
                }
            }
        }
    }

    /// The cards carry their own background, so the row under them is cleared and the cards
    /// sit on the grouped background like cells of their own.
    private func grid(_ icons: [String]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(icons, id: \.self) { cell($0) }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func toggle(_ asset: String) {
        if let index = selection.firstIndex(of: asset) {
            selection.remove(at: index)
        } else {
            selection.append(asset)
        }
    }

    private func cell(_ asset: String) -> some View {
        let isPicked = selection.contains(asset)
        let shape = RoundedRectangle(cornerRadius: .listRowCornerRadius, style: .continuous)
        return Button {
            toggle(asset)
        } label: {
            HStack(spacing: 10) {
                RecipeIcon(path: path(asset), size: 40)
                // A hidden two line blank holds every card to the same height, so a name
                // that fits on one line sits in the middle of the card instead of the top.
                ZStack(alignment: .leading) {
                    Text(verbatim: " \n ")
                        .hidden()
                    Text(verbatim: IconCatalog.displayName(for: asset))
                        .fontWeight(isPicked ? .semibold : .regular)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(isPicked ? Color.accentColor : .primary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                isPicked ? AnyShapeStyle(Color.accentColor.opacity(0.3))
                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                in: shape
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

extension CatalogPickerView {
    /// The fresh half of the ingredient catalog, in the groups a shop is laid out in.
    static func ingredients(selection: Binding<[String]>) -> CatalogPickerView {
        catalog(
            on: .fresh,
            title: "Generate.Ingredients.Title",
            searchPrompt: "Generate.Ingredients.Search",
            emptyLabel: "Generate.Ingredients.Empty",
            selection: selection
        )
    }

    /// The half of the catalog that keeps: seasonings, sauces, baking, and what is tinned or
    /// dried.
    static func pantry(selection: Binding<[String]>) -> CatalogPickerView {
        catalog(
            on: .pantry,
            title: "Generate.Pantry.Title",
            searchPrompt: "Generate.Pantry.Search",
            emptyLabel: "Generate.Pantry.Empty",
            selection: selection
        )
    }

    private static func catalog(
        on shelf: IngredientShelf,
        title: LocalizedStringResource,
        searchPrompt: LocalizedStringResource,
        emptyLabel: LocalizedStringResource,
        selection: Binding<[String]>
    ) -> CatalogPickerView {
        CatalogPickerView(
            title: title,
            searchPrompt: searchPrompt,
            emptyLabel: emptyLabel,
            groups: { query in
                IconCatalog.categories(matching: query, on: shelf).map {
                    IconGroup(id: $0.category.rawValue, title: $0.category.title, icons: $0.icons)
                }
            },
            path: IconCatalog.ingredientPath,
            selection: selection
        )
    }

    /// The whole ingredient catalog in one picker, both shelves together, for editing the list
    /// a recipe carries. The title says which of a recipe's lists is being picked into.
    static func recipeIngredients(
        title: LocalizedStringResource,
        selection: Binding<[String]>
    ) -> CatalogPickerView {
        CatalogPickerView(
            title: title,
            searchPrompt: "Generate.Ingredients.Search",
            emptyLabel: "Generate.Ingredients.Empty",
            groups: { query in
                IconCatalog.allCategories(matching: query).map {
                    IconGroup(id: $0.category.rawValue, title: $0.category.title, icons: $0.icons)
                }
            },
            path: IconCatalog.ingredientPath,
            selection: selection
        )
    }

    /// The tool catalog under a title of the caller's choosing, for the same reason.
    static func recipeTools(
        title: LocalizedStringResource,
        selection: Binding<[String]>
    ) -> CatalogPickerView {
        var picker = tools(selection: selection)
        picker.title = title
        return picker
    }

    /// The tool catalog, in the groups a kitchen is laid out in.
    static func tools(selection: Binding<[String]>) -> CatalogPickerView {
        CatalogPickerView(
            title: "Generate.Tools.Title",
            searchPrompt: "Generate.Tools.Search",
            emptyLabel: "Generate.Tools.Empty",
            groups: { query in
                IconCatalog.toolCategories(matching: query).map {
                    IconGroup(id: $0.category.rawValue, title: $0.category.title, icons: $0.icons)
                }
            },
            path: IconCatalog.toolPath,
            selection: selection
        )
    }
}

extension IngredientCategory {
    /// How the group is headed in a picker.
    var title: LocalizedStringResource {
        switch self {
        case .vegetables: "Ingredient.Category.Vegetables"
        case .fruits: "Ingredient.Category.Fruits"
        case .meat: "Ingredient.Category.Meat"
        case .seafood: "Ingredient.Category.Seafood"
        case .dairy: "Ingredient.Category.Dairy"
        case .grains: "Ingredient.Category.Grains"
        case .seasonings: "Ingredient.Category.Seasonings"
        case .sauces: "Ingredient.Category.Sauces"
        case .baking: "Ingredient.Category.Baking"
        case .preserved: "Ingredient.Category.Preserved"
        }
    }
}

extension ToolCategory {
    /// How the group is headed in a picker.
    var title: LocalizedStringResource {
        switch self {
        case .utensils: "Tool.Category.Utensils"
        case .stovetop: "Tool.Category.Stovetop"
        case .other: "Tool.Category.Other"
        }
    }
}
