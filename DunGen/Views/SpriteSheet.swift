import SwiftUI

struct SpriteView: View {
    let imageName: String
    let row: Int
    let column: Int
    let totalColumns: Int
    let totalRows: Int
    let displaySize: CGSize

    var body: some View {
        GeometryReader { geometry in
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: displaySize.width * CGFloat(totalColumns),
                    height: displaySize.height * CGFloat(totalRows)
                )
                .offset(
                    x: -displaySize.width * CGFloat(column),
                    y: -displaySize.height * CGFloat(row)
                )
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .clipped()
    }
}

struct RaceClassSprite {
    static func spriteView(race: String, className: String, size: CGFloat) -> some View {
        let normalizedRace = race.lowercased()
        let sheetName = "\(normalizedRace)_sheet"

        let characterClass = CharacterClass.allCases.first { $0.rawValue.lowercased() == className.lowercased() } ?? .warrior
        let pos = characterClass.gridPosition
        let aspectRatio: CGFloat = 256.0 / 384.0
        let displaySize = CGSize(width: size * aspectRatio, height: size)

        return SpriteView(
            imageName: sheetName,
            row: pos.row,
            column: pos.column,
            totalColumns: 4,
            totalRows: 4,
            displaySize: displaySize
        )
    }
}

struct MonsterSprite {
    static func spriteView(monsterName: String, size: CGFloat) -> some View {
        let (sheetName, gridPosition) = getSpriteInfo(for: monsterName)
        let aspectRatio: CGFloat = 256.0 / 384.0
        let displaySize = CGSize(width: size * aspectRatio, height: size)

        return SpriteView(
            imageName: sheetName,
            row: gridPosition.row,
            column: gridPosition.column,
            totalColumns: 4,
            totalRows: 4,
            displaySize: displaySize
        )
    }

    private static func getSpriteInfo(for monsterName: String) -> (sheetName: String, gridPosition: (row: Int, column: Int)) {
        let monsters = MonsterDatabase.allMonsters
        guard let index = monsters.firstIndex(where: { $0.name == monsterName }) else {
            return ("monsters_one", (row: 0, column: 0))
        }

        let groupNumber = (index / 16) + 1
        let positionInGroup = index % 16
        let row = positionInGroup / 4
        let column = positionInGroup % 4

        let sheetName: String
        switch groupNumber {
        case 1: sheetName = "monsters_one"
        case 2: sheetName = "monsters_two"
        case 3: sheetName = "monsters_three"
        case 4: sheetName = "monsters_four"
        case 5: sheetName = "monsters_five"
        case 6: sheetName = "monsters_six"
        case 7: sheetName = "monsters_seven"
        default: sheetName = "monsters_one"
        }

        return (sheetName, (row: row, column: column))
    }
}

#Preview("Race Class Sprites (4×4)") {
    VStack(spacing: 10) {
        Text("Dwarf Class Sprite Sheet (4×4 Grid)")
            .font(.headline)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
            ForEach(CharacterClass.allCases, id: \.rawValue) { charClass in
                VStack {
                    RaceClassSprite.spriteView(race: "Dwarf", className: charClass.rawValue, size: 100)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)

                    Text(charClass.rawValue)
                        .font(.caption2)
                        .fontWeight(.bold)

                    let pos = charClass.gridPosition
                    Text("[\(pos.row), \(pos.column)]")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview("Monster Sprites (First 16)") {
    VStack(spacing: 10) {
        Text("Monster Sprite Sheet (Group 1: 4×4)")
            .font(.headline)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(0..<16, id: \.self) { index in
                let monster = MonsterDatabase.allMonsters[index]
                VStack(spacing: 4) {
                    MonsterSprite.spriteView(monsterName: monster.name, size: 80)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(6)
                    Text(monster.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding()
    }
}
