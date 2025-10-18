import SwiftUI

struct PaperDollView: View {
    let character: CharacterProfile
    let detailedInventory: [ItemDefinition]
    let size: CGFloat

    init(character: CharacterProfile, detailedInventory: [ItemDefinition] = [], size: CGFloat = 200) {
        self.character = character
        self.detailedInventory = detailedInventory
        self.size = size
    }

    var body: some View {
        ZStack {
            baseBody
            armorLayer
            helmetLayer
            bootsLayer
            mainHandLayer
            offHandLayer
        }
        .frame(width: size, height: size)
    }

    private var baseBody: some View {
        Circle()
            .fill(bodyColor)
            .frame(width: size * 0.8, height: size * 0.8)
            .overlay(
                VStack(spacing: size * 0.05) {
                    Circle()
                        .fill(skinColor)
                        .frame(width: size * 0.25, height: size * 0.25)
                        .overlay(
                            Text(character.name.prefix(1))
                                .font(.system(size: size * 0.15, weight: .bold))
                                .foregroundColor(.white)
                        )

                    RoundedRectangle(cornerRadius: size * 0.05)
                        .fill(bodyColor.opacity(0.8))
                        .frame(width: size * 0.4, height: size * 0.5)
                }
            )
    }

    private var armorLayer: some View {
        Group {
            if hasArmor {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(armorColor.opacity(0.3))
                        .frame(width: size * 0.45, height: size * 0.52)
                        .overlay(
                            RoundedRectangle(cornerRadius: size * 0.08)
                                .stroke(armorColor, lineWidth: 3)
                        )
                }
                .offset(y: size * 0.12)
            }
        }
    }

    private var helmetLayer: some View {
        Group {
            if hasHelmet {
                Circle()
                    .fill(armorColor.opacity(0.4))
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle()
                            .stroke(armorColor, lineWidth: 2)
                    )
                    .offset(y: size * -0.27)
            }
        }
    }

    private var bootsLayer: some View {
        Group {
            if hasBoots {
                HStack(spacing: size * 0.05) {
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(armorColor.opacity(0.5))
                        .frame(width: size * 0.12, height: size * 0.15)
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(armorColor.opacity(0.5))
                        .frame(width: size * 0.12, height: size * 0.15)
                }
                .offset(y: size * 0.42)
            }
        }
    }

    private var mainHandLayer: some View {
        Group {
            if let weapon = mainHandWeapon {
                weaponIcon(for: weapon)
                    .offset(x: size * -0.45, y: size * 0.1)
            }
        }
    }

    private var offHandLayer: some View {
        Group {
            if let offhand = offHandItem {
                shieldOrWeaponIcon(for: offhand)
                    .offset(x: size * 0.45, y: size * 0.1)
            }
        }
    }

    private func weaponIcon(for weapon: ItemDefinition) -> some View {
        Group {
            if weapon.baseName.lowercased().contains("sword") || weapon.baseName.lowercased().contains("blade") {
                swordShape
            } else if weapon.baseName.lowercased().contains("axe") {
                axeShape
            } else if weapon.baseName.lowercased().contains("staff") || weapon.baseName.lowercased().contains("wand") {
                staffShape
            } else if weapon.baseName.lowercased().contains("bow") {
                bowShape
            } else if weapon.baseName.lowercased().contains("dagger") {
                daggerShape
            } else {
                swordShape
            }
        }
    }

    private func shieldOrWeaponIcon(for item: ItemDefinition) -> some View {
        Group {
            if item.baseName.lowercased().contains("shield") {
                shieldShape
            } else {
                weaponIcon(for: item)
            }
        }
    }

    private var swordShape: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(weaponColor)
                .frame(width: size * 0.05, height: size * 0.3)
            Rectangle()
                .fill(weaponColor.opacity(0.7))
                .frame(width: size * 0.15, height: size * 0.05)
            Rectangle()
                .fill(Color.brown)
                .frame(width: size * 0.06, height: size * 0.1)
        }
    }

    private var axeShape: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(weaponColor)
                .frame(width: size * 0.12, height: size * 0.12)
            Rectangle()
                .fill(Color.brown)
                .frame(width: size * 0.05, height: size * 0.25)
        }
    }

    private var staffShape: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.purple.opacity(0.6))
                .frame(width: size * 0.08, height: size * 0.08)
            Rectangle()
                .fill(Color.brown)
                .frame(width: size * 0.04, height: size * 0.35)
        }
    }

    private var bowShape: some View {
        ZStack {
            Arc(startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                .stroke(Color.brown, lineWidth: 3)
                .frame(width: size * 0.08, height: size * 0.25)
            Path { path in
                path.move(to: CGPoint(x: 0, y: -size * 0.125))
                path.addLine(to: CGPoint(x: 0, y: size * 0.125))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
    }

    private var daggerShape: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(weaponColor)
                .frame(width: size * 0.04, height: size * 0.15)
            Rectangle()
                .fill(Color.brown)
                .frame(width: size * 0.05, height: size * 0.06)
        }
    }

    private var shieldShape: some View {
        RoundedRectangle(cornerRadius: size * 0.03)
            .fill(armorColor.opacity(0.4))
            .frame(width: size * 0.15, height: size * 0.2)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.03)
                    .stroke(armorColor, lineWidth: 3)
            )
    }

    private var skinColor: Color {
        switch character.race.lowercased() {
        case let race where race.contains("orc"):
            return Color.green.opacity(0.8)
        case let race where race.contains("elf"):
            return Color.yellow.opacity(0.3)
        case let race where race.contains("dwarf"):
            return Color.orange.opacity(0.5)
        default:
            return Color.brown.opacity(0.6)
        }
    }

    private var bodyColor: Color {
        switch character.className.lowercased() {
        case let c where c.contains("warrior") || c.contains("paladin"):
            return Color.blue
        case let c where c.contains("rogue"):
            return Color.gray
        case let c where c.contains("mage") || c.contains("necromancer"):
            return Color.purple
        case let c where c.contains("healer") || c.contains("druid"):
            return Color.green
        case let c where c.contains("ranger"):
            return Color.brown
        case let c where c.contains("monk"):
            return Color.orange
        case let c where c.contains("bard"):
            return Color.pink
        case let c where c.contains("barbarian"):
            return Color.red
        default:
            return Color.blue
        }
    }

    private var armorColor: Color {
        if hasPlateArmor {
            return Color.gray
        } else if hasChainmail {
            return Color.gray.opacity(0.7)
        } else if hasLeatherArmor {
            return Color.brown
        }
        return Color.gray.opacity(0.5)
    }

    private var weaponColor: Color {
        Color.gray
    }

    private var hasArmor: Bool {
        character.inventory.contains { item in
            item.lowercased().contains("armor") ||
            item.lowercased().contains("chainmail") ||
            item.lowercased().contains("plate") ||
            item.lowercased().contains("leather")
        }
    }

    private var hasHelmet: Bool {
        character.inventory.contains { item in
            item.lowercased().contains("helmet") ||
            item.lowercased().contains("helm") ||
            item.lowercased().contains("cap")
        }
    }

    private var hasBoots: Bool {
        character.inventory.contains { item in
            item.lowercased().contains("boots") ||
            item.lowercased().contains("shoes") ||
            item.lowercased().contains("greaves")
        }
    }

    private var hasPlateArmor: Bool {
        character.inventory.contains { $0.lowercased().contains("plate") }
    }

    private var hasChainmail: Bool {
        character.inventory.contains { $0.lowercased().contains("chainmail") || $0.lowercased().contains("mail") }
    }

    private var hasLeatherArmor: Bool {
        character.inventory.contains { $0.lowercased().contains("leather") }
    }

    private var mainHandWeapon: ItemDefinition? {
        detailedInventory.first { item in
            item.itemType.lowercased() == "weapon" &&
            (item.baseName.lowercased().contains("sword") ||
             item.baseName.lowercased().contains("axe") ||
             item.baseName.lowercased().contains("staff") ||
             item.baseName.lowercased().contains("bow") ||
             item.baseName.lowercased().contains("dagger") ||
             item.baseName.lowercased().contains("mace") ||
             item.baseName.lowercased().contains("wand"))
        }
    }

    private var offHandItem: ItemDefinition? {
        detailedInventory.first { item in
            item.baseName.lowercased().contains("shield")
        }
    }
}

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(center: center, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        return path
    }
}

#Preview {
    Text("Paper Doll Preview")
}
