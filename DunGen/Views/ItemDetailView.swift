import SwiftUI

struct ItemDetailView: View {
    let item: ItemDefinition
    let onUse: ((String) -> Bool)?
    @Environment(\.dismiss) private var dismiss

    init(item: ItemDefinition, onUse: ((String) -> Bool)? = nil) {
        self.item = item
        self.onUse = onUse
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(rarityColor)

            HStack {
                Text(item.itemType.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(item.rarity.capitalized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(rarityColor)
            }

            Divider()

            Text(item.description)
                .font(.body)

            if item.prefix != nil || item.suffix != nil {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Enchantments")
                        .font(.headline)

                    if let prefix = item.prefix {
                        HStack(alignment: .top) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prefix.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(prefix.effect)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let suffix = item.suffix {
                        HStack(alignment: .top) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suffix.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(suffix.effect)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if isConsumable {
                Divider()

                Button {
                    let success = onUse?(item.fullName) ?? false
                    if success {
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                        Text("Use Item")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isConsumable: Bool {
        item.itemType.lowercased() == "consumable" ||
        item.fullName.lowercased().contains("potion") ||
        item.fullName.lowercased().contains("elixir") ||
        item.fullName.lowercased().contains("scroll")
    }

    private var rarityColor: Color {
        switch item.rarity.lowercased() {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .primary
        }
    }
}

#Preview {
    ItemDetailView(item: ItemDefinition(
        baseName: "Sword",
        prefix: ItemAffix(name: "Flaming", type: "prefix", effect: "+10 fire damage"),
        suffix: ItemAffix(name: "of the Bear", type: "suffix", effect: "+5 strength"),
        itemType: "weapon",
        description: "A finely crafted blade wreathed in magical flames, imbued with the strength of a mighty bear.",
        rarity: "rare"
    ))
}
