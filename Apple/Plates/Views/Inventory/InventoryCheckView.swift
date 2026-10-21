import CulinaryIntelligence
import SwiftUI

/// Asks whether the cook has what one of a recipe's lists needs and the inventory does not
/// hold. A tap on a line puts it in the inventory, and a second tap takes it out again. The
/// lines are worked out when the popover opens, so a line that is ticked off stays on screen.
struct InventoryCheckView: View {
    private let list: ShoppingList

    @State private var ingredients = Pantry.ingredients
    @State private var tools = Pantry.tools

    init(list: ShoppingList) {
        self.list = list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(list.ingredients) { ingredient in
                        row(TileInfo(ingredient), catalog: IconCatalog.ingredients, inventory: $ingredients)
                    }
                    ForEach(list.tools) { tool in
                        row(TileInfo(tool), catalog: IconCatalog.tools, inventory: $tools)
                    }
                }

                Text("Inventory.Check.Footer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(idealWidth: 300, maxHeight: 420)
        .presentationCompactAdaptation(.popover)
        .onChange(of: ingredients) { Pantry.ingredients = ingredients }
        .onChange(of: tools) { Pantry.tools = tools }
    }

    private var title: LocalizedStringResource {
        list.ingredients.isEmpty ? "Inventory.Check.Title.Tools" : "Inventory.Check.Title.Ingredients"
    }

    /// One line the inventory does not hold. A line drawn with an icon the catalog does not
    /// carry cannot go in the inventory, so it has no mark to tick.
    @ViewBuilder
    private func row(_ item: TileInfo, catalog: [String], inventory: Binding<[String]>) -> some View {
        let name = IconCatalog.iconName(for: item.icon).flatMap { catalog.contains($0) ? $0 : nil }
        let isHad = name.map(inventory.wrappedValue.contains) ?? false
        Button {
            guard let name else { return }
            if isHad {
                inventory.wrappedValue.removeAll { $0 == name }
            } else {
                inventory.wrappedValue.append(name)
            }
        } label: {
            HStack(spacing: 10) {
                RecipeIcon(path: item.icon, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: item.name)
                        .font(.subheadline)
                    if let detail = item.detail, !detail.isEmpty {
                        Text(verbatim: detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if name != nil {
                    Image(systemName: isHad ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isHad ? Color.accentColor : .secondary)
                        .font(.title3)
                        .padding(.trailing, 2)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(name == nil)
        .accessibilityAddTraits(isHad ? .isSelected : [])
    }
}
