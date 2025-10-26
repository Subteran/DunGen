import Foundation

@MainActor
@Observable
final class InventoryStateManager {
    var detailedInventory: [ItemDefinition] = []

    var pendingLoot: [ItemDefinition] = []

    let maxInventorySlots = 20

    internal var itemsCollected: Int = 0

    func reset() {
        detailedInventory = []
        pendingLoot = []
        itemsCollected = 0
    }

    func hasSpace(for count: Int) -> Bool {
        detailedInventory.count + count <= maxInventorySlots
    }

    func addItem(_ item: ItemDefinition) {
        if item.itemType.lowercased() == "consumable" {
            if let index = detailedInventory.firstIndex(where: {
                $0.baseName == item.baseName &&
                $0.itemType == item.itemType &&
                $0.consumableEffect == item.consumableEffect
            }) {
                detailedInventory[index].quantity += item.quantity
            } else {
                detailedInventory.append(item)
            }
        } else {
            detailedInventory.append(item)
        }
        itemsCollected += 1
    }

    func addItems(_ items: [ItemDefinition]) {
        for item in items {
            addItem(item)
        }
    }

    func removeItem(_ item: ItemDefinition) {
        if let index = detailedInventory.firstIndex(where: { $0.id == item.id }) {
            detailedInventory.remove(at: index)
        }
    }

    func findItem(byName name: String) -> ItemDefinition? {
        detailedInventory.first { $0.fullName.lowercased() == name.lowercased() }
    }

    func hasDuplicateItem(name: String) -> Bool {
        detailedInventory.contains(where: { $0.fullName.lowercased() == name.lowercased() })
    }

    func setPendingLoot(_ items: [ItemDefinition]) {
        pendingLoot = items
    }

    func clearPendingLoot() {
        pendingLoot = []
    }
}
