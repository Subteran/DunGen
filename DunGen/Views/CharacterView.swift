import SwiftUI

struct CharacterView: View {
    let character: CharacterProfile?
    let detailedInventory: [ItemDefinition]
    let levelingService: LevelingServiceProtocol
    let onUseItem: ((String) -> Bool)?
    @State private var selectedItem: ItemDefinition?
    @State private var selectedAbility: String?
    @State private var selectedSpell: String?

    init(character: CharacterProfile?, detailedInventory: [ItemDefinition] = [], levelingService: LevelingServiceProtocol = DefaultLevelingService(), onUseItem: ((String) -> Bool)? = nil) {
        self.character = character
        self.detailedInventory = detailedInventory
        self.levelingService = levelingService
        self.onUseItem = onUseItem
    }

    var body: some View {
        Group {
            if let character = character {
                characterSheet(for: character)
            } else {
                emptyState
            }
        }
        .navigationTitle(L10n.tabCharacterTitle)
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item, onUse: { itemName in
                let success = onUseItem?(itemName) ?? false
                if success {
                    selectedItem = nil
                }
                return success
            })
            .presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(
            get: { selectedAbility.map { AbilityDetail(name: $0, type: .ability) } },
            set: { selectedAbility = $0?.name }
        )) { detail in
            AbilityDetailView(ability: detail)
                .presentationDetents([.medium])
        }
        .sheet(item: Binding(
            get: { selectedSpell.map { AbilityDetail(name: $0, type: .spell) } },
            set: { selectedSpell = $0?.name }
        )) { detail in
            AbilityDetailView(ability: detail)
                .presentationDetents([.medium])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(L10n.characterNoCharacter)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func characterSheet(for character: CharacterProfile) -> some View {
        List {
            Section {
                HStack {
                    Spacer()
                    PaperDollView(
                        character: character,
                        detailedInventory: detailedInventory,
                        size: 270
                    )
                    .padding(.vertical, 8)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            characterInfoSection(for: character)
            statsSection(for: character)
            attributesSection(for: character)
            abilitiesSection(for: character)
            if !character.spells.isEmpty {
                spellsSection(for: character)
            }
            inventorySection(for: character)
        }
    }

    private func characterInfoSection(for character: CharacterProfile) -> some View {
        Section(L10n.characterSectionInfo) {
            LabeledContent(L10n.characterLabelName, value: character.name)
            LabeledContent(L10n.characterLabelRace, value: character.race)
            LabeledContent(L10n.characterLabelClass, value: character.className)
            LabeledContent(L10n.characterLabelLevel, value: "\(levelingService.level(forXP: character.xp))")
        }
    }

    private func statsSection(for character: CharacterProfile) -> some View {
        Section(L10n.characterSectionStats) {
            LabeledContent(L10n.characterLabelHp, value: "\(character.hp) / \(character.maxHP)")
            LabeledContent(L10n.characterLabelXp, value: "\(character.xp) / \(levelingService.xpNeededForNextLevel(currentXP: character.xp))")
            LabeledContent(L10n.characterLabelGold, value: "\(character.gold)")
        }
    }

    private func attributesSection(for character: CharacterProfile) -> some View {
        Section(L10n.characterSectionAttributes) {
            AttributeRow(label: L10n.characterLabelStrength, value: character.attributes.strength)
            AttributeRow(label: L10n.characterLabelDexterity, value: character.attributes.dexterity)
            AttributeRow(label: L10n.characterLabelConstitution, value: character.attributes.constitution)
            AttributeRow(label: L10n.characterLabelIntelligence, value: character.attributes.intelligence)
            AttributeRow(label: L10n.characterLabelWisdom, value: character.attributes.wisdom)
            AttributeRow(label: L10n.characterLabelCharisma, value: character.attributes.charisma)
        }
    }

    private func abilitiesSection(for character: CharacterProfile) -> some View {
        Section(L10n.characterSectionAbilities) {
            if character.abilities.isEmpty {
                Text(L10n.characterEmptyAbilities)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(character.abilities, id: \.self) { ability in
                    Button {
                        selectedAbility = ability
                    } label: {
                        HStack {
                            Label(ability, systemImage: "star.fill")
                            Spacer()
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func spellsSection(for character: CharacterProfile) -> some View {
        Section(L10n.characterSectionSpells) {
            if character.spells.isEmpty {
                Text(L10n.characterEmptySpells)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(character.spells, id: \.self) { spell in
                    Button {
                        selectedSpell = spell
                    } label: {
                        HStack {
                            Label(spell, systemImage: "sparkles")
                            Spacer()
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func inventorySection(for character: CharacterProfile) -> some View {
        Section(L10n.characterSectionInventory) {
            if detailedInventory.isEmpty && character.inventory.isEmpty {
                Text(L10n.characterEmptyInventory)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(detailedInventory) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        HStack {
                            Image(systemName: itemIcon(for: item.itemType))
                                .foregroundStyle(rarityColor(for: item.rarity))
                            Text(item.fullName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(Array(character.inventory.enumerated()), id: \.offset) { index, item in
                    Button {
                        // For simple items that are consumable, use them directly
                        if isConsumable(item) {
                            let _ = onUseItem?(item)
                        }
                    } label: {
                        HStack {
                            Image(systemName: itemIconForSimple(item))
                                .foregroundStyle(isConsumable(item) ? .green : .gray)
                            Text(item)
                                .foregroundStyle(.primary)
                            if isConsumable(item) {
                                Spacer()
                                Text("Use")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
    }

    private func itemIcon(for type: String) -> String {
        switch type.lowercased() {
        case "weapon": return "sword.fill"
        case "armor": return "shield.fill"
        case "accessory": return "sparkles"
        case "consumable": return "flask.fill"
        default: return "bag.fill"
        }
    }

    private func rarityColor(for rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .primary
        }
    }

    private func isConsumable(_ itemName: String) -> Bool {
        let lowerName = itemName.lowercased()
        return lowerName.contains("potion") || lowerName.contains("elixir") || lowerName.contains("scroll")
    }

    private func itemIconForSimple(_ itemName: String) -> String {
        if isConsumable(itemName) {
            return "flask.fill"
        }
        return "bag.fill"
    }
}

struct AttributeRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundStyle(value > 20 ? .orange : .primary)
            Text("(\(modifier))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modifier: String {
        let mod = (value - 10) / 2
        return mod >= 0 ? "+\(mod)" : "\(mod)"
    }
}

struct AbilityDetail: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let type: AbilityType

    enum AbilityType {
        case ability
        case spell
    }
}

struct AbilityDetailView: View {
    let ability: AbilityDetail

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ability.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(ability.type == .ability ? "Class Ability" : "Spell/Prayer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(generateDescription(for: ability.name, type: ability.type))
                    .font(.body)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func generateDescription(for name: String, type: AbilityDetail.AbilityType) -> String {
        let lowercased = name.lowercased()

        switch type {
        case .ability:
            if lowercased.contains("track") {
                return "Allows you to follow trails and find hidden paths in the wilderness."
            } else if lowercased.contains("sneak") || lowercased.contains("stealth") {
                return "Move silently and avoid detection by enemies."
            } else if lowercased.contains("strike") || lowercased.contains("attack") {
                return "A powerful offensive technique that deals extra damage."
            } else if lowercased.contains("shield") || lowercased.contains("block") {
                return "Defensive maneuver that reduces incoming damage."
            } else if lowercased.contains("rage") || lowercased.contains("fury") {
                return "Channel your anger into devastating combat prowess."
            } else if lowercased.contains("dodge") || lowercased.contains("evade") {
                return "Quickly avoid incoming attacks with agility."
            } else {
                return "A special combat ability unique to your class."
            }

        case .spell:
            if lowercased.contains("fire") || lowercased.contains("flame") {
                return "Harness the power of flame to burn your enemies."
            } else if lowercased.contains("heal") || lowercased.contains("cure") {
                return "Restore health and mend wounds through divine or natural magic."
            } else if lowercased.contains("light") || lowercased.contains("bolt") {
                return "Strike your foes with crackling lightning energy."
            } else if lowercased.contains("ice") || lowercased.contains("frost") {
                return "Freeze enemies with chilling cold magic."
            } else if lowercased.contains("bless") || lowercased.contains("divine") {
                return "Channel divine power to aid yourself or allies."
            } else if lowercased.contains("summon") || lowercased.contains("animate") {
                return "Call forth creatures or raise the dead to fight for you."
            } else if lowercased.contains("shield") || lowercased.contains("protect") {
                return "Magical barrier that defends against attacks."
            } else {
                return "A mystical power granted by your training or divine favor."
            }
        }
    }
}

#Preview {
    NavigationStack {
        CharacterView(
            character: CharacterProfile(
                name: "Aragorn",
                race: "Human",
                className: "Ranger",
                backstory: "A skilled tracker and warrior.",
                attributes: .init(
                    strength: 16,
                    dexterity: 14,
                    constitution: 15,
                    intelligence: 12,
                    wisdom: 13,
                    charisma: 14
                ),
                hp: 15,
                maxHP: 15,
                xp: 250,
                gold: 50,
                inventory: ["Longsword", "Leather Armor", "Backpack", "Rope"],
                abilities: ["Track", "Favored Enemy: Orcs", "Natural Explorer"],
                spells: []
            )
        )
    }
}

#Preview("Empty State") {
    NavigationStack {
        CharacterView(character: nil)
    }
}
