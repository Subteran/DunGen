import SwiftUI

struct InventoryManagementView: View {
    let currentInventory: [ItemDefinition]
    let newItems: [ItemDefinition]
    let maxSlots: Int
    let onConfirm: ([ItemDefinition]) -> Void

    @State private var selectedItems: Set<String> = Set()
    @Environment(\.dismiss) private var dismiss

    init(currentInventory: [ItemDefinition], newItems: [ItemDefinition], maxSlots: Int, onConfirm: @escaping ([ItemDefinition]) -> Void) {
        self.currentInventory = currentInventory
        self.newItems = newItems
        self.maxSlots = maxSlots
        self.onConfirm = onConfirm

        // Pre-select all current inventory items
        _selectedItems = State(initialValue: Set(currentInventory.map { $0.id }))
    }

    var allItems: [ItemDefinition] {
        currentInventory + newItems
    }

    var selectedCount: Int {
        selectedItems.count
    }

    var canConfirm: Bool {
        selectedCount <= maxSlots && selectedCount > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with slot info
                VStack(spacing: 8) {
                    Text("Inventory Management")
                        .font(.headline)

                    HStack {
                        Text("\(selectedCount) / \(maxSlots) slots")
                            .font(.subheadline)
                            .foregroundStyle(selectedCount > maxSlots ? .red : .secondary)

                        if selectedCount > maxSlots {
                            Text("• Too many items selected!")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if !newItems.isEmpty {
                        Text("Select up to \(maxSlots) items to keep")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))

                Divider()

                // Item list
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Current inventory section
                        if !currentInventory.isEmpty {
                            sectionHeader("Current Inventory")

                            ForEach(currentInventory) { item in
                                itemRow(item: item, isNew: false)
                                Divider()
                            }
                        }

                        // New items section
                        if !newItems.isEmpty {
                            sectionHeader("New Items")

                            ForEach(newItems) { item in
                                itemRow(item: item, isNew: true)
                                Divider()
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        let finalItems = allItems.filter { selectedItems.contains($0.id) }
                        onConfirm(finalItems)
                        dismiss()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
    }

    private func itemRow(item: ItemDefinition, isNew: Bool) -> some View {
        let isSelected = selectedItems.contains(item.id)

        return Button {
            if isSelected {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)

                // Item info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.displayName)
                            .font(.body)
                            .fontWeight(isNew ? .semibold : .regular)

                        if isNew {
                            Text("NEW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    HStack {
                        Text(item.rarity.capitalized)
                            .font(.caption)
                            .foregroundStyle(rarityColor(item.rarity))

                        if !item.effect.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.effect)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .secondary
        }
    }
}
