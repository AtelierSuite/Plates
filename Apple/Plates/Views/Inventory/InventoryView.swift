import CulinaryIntelligence
import SwiftUI

/// What the cook has in the kitchen, kept apart from any one recipe. Every new recipe starts
/// from what is picked here.
struct InventoryView: View {
    private enum PickerRoute: Hashable {
        case freshIngredients
        case pantryIngredients
        case tools
    }

    @Environment(\.dismiss) private var dismiss

    @State private var ingredients = Pantry.ingredients
    @State private var tools = Pantry.tools

    var body: some View {
        NavigationStack {
            Form {
                picks(
                    "Generate.Ingredients.Title",
                    link: "Generate.Choose.Ingredients",
                    assets: shelf(.fresh),
                    path: IconCatalog.ingredientPath,
                    route: .freshIngredients
                )

                picks(
                    "Generate.Pantry.Title",
                    link: "Generate.Choose.Pantry",
                    assets: shelf(.pantry),
                    path: IconCatalog.ingredientPath,
                    route: .pantryIngredients
                )

                picks(
                    "Generate.Tools.Title",
                    link: "Generate.Choose.Tools",
                    assets: $tools,
                    path: IconCatalog.toolPath,
                    route: .tools
                )
            }
            .navigationDestination(for: PickerRoute.self) { route in
                switch route {
                case .freshIngredients:
                    CatalogPickerView.ingredients(selection: shelf(.fresh))
                case .pantryIngredients:
                    CatalogPickerView.pantry(selection: shelf(.pantry))
                case .tools:
                    CatalogPickerView.tools(selection: $tools)
                }
            }
            .navigationTitle("Inventory.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .onChange(of: ingredients) { Pantry.ingredients = ingredients }
        .onChange(of: tools) { Pantry.tools = tools }
    }

    /// One shelf of the ingredients, so each picker shows and edits its own half while they are
    /// still kept as a single list. Writing back keeps the other shelf as it was.
    private func shelf(_ shelf: IngredientShelf) -> Binding<[String]> {
        Binding(
            get: { ingredients.filter { IconCatalog.shelf(of: $0) == shelf } },
            set: { picks in
                ingredients = ingredients.filter { IconCatalog.shelf(of: $0) != shelf } + picks
            }
        )
    }

    /// What the cook has already picked, with the way back into the catalog under it.
    private func picks(
        _ header: LocalizedStringResource,
        link: LocalizedStringResource,
        assets: Binding<[String]>,
        path: @escaping (String) -> String,
        route: PickerRoute
    ) -> some View {
        Section {
            if !assets.wrappedValue.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(assets.wrappedValue, id: \.self) { asset in
                            Button {
                                assets.wrappedValue.removeAll { $0 == asset }
                            } label: {
                                VStack(spacing: 2) {
                                    RecipeIcon(path: path(asset), size: 30)
                                    Text(verbatim: IconCatalog.displayName(for: asset))
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 66)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .listRowInsets(EdgeInsets())
            }

            NavigationLink(value: route) {
                Text(link)
            }
        } header: {
            Text(header)
        }
    }
}
