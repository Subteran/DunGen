import Foundation
import SwiftData

@Model
final class DeceasedCharacter {
    var name: String
    var race: String
    var className: String
    var finalLevel: Int
    var finalXP: Int
    var finalGold: Int
    var adventuresCompleted: Int
    var monstersDefeated: Int
    var itemsCollected: Int
    var causeOfDeath: String
    var deathDate: Date
    var playTime: TimeInterval

    init(
        name: String,
        race: String,
        className: String,
        finalLevel: Int,
        finalXP: Int,
        finalGold: Int,
        adventuresCompleted: Int,
        monstersDefeated: Int,
        itemsCollected: Int,
        causeOfDeath: String,
        deathDate: Date = Date(),
        playTime: TimeInterval
    ) {
        self.name = name
        self.race = race
        self.className = className
        self.finalLevel = finalLevel
        self.finalXP = finalXP
        self.finalGold = finalGold
        self.adventuresCompleted = adventuresCompleted
        self.monstersDefeated = monstersDefeated
        self.itemsCollected = itemsCollected
        self.causeOfDeath = causeOfDeath
        self.deathDate = deathDate
        self.playTime = playTime
    }
}

struct CharacterDeathReport {
    let character: CharacterProfile
    let finalLevel: Int
    let adventuresCompleted: Int
    let monstersDefeated: Int
    let itemsCollected: Int
    let causeOfDeath: String
    let playTime: TimeInterval

    var formattedPlayTime: String {
        let hours = Int(playTime) / 3600
        let minutes = (Int(playTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func toDeceasedCharacter(levelingService: LevelingServiceProtocol) -> DeceasedCharacter {
        DeceasedCharacter(
            name: character.name,
            race: character.race,
            className: character.className,
            finalLevel: finalLevel,
            finalXP: character.xp,
            finalGold: character.gold,
            adventuresCompleted: adventuresCompleted,
            monstersDefeated: monstersDefeated,
            itemsCollected: itemsCollected,
            causeOfDeath: causeOfDeath,
            playTime: playTime
        )
    }
}
