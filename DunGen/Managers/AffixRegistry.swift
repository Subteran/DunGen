import Foundation

@MainActor
@Observable
final class AffixRegistry {
    private var knownItemAffixes: [String: ItemAffix] = [:]
    private var knownMonsterAffixes: [String: MonsterAffix] = [:]

    func registerItemAffix(_ affix: ItemAffix) {
        knownItemAffixes[affix.name] = affix
    }

    func getItemAffix(named name: String) -> ItemAffix? {
        knownItemAffixes[name]
    }

    func registerMonsterAffix(_ affix: MonsterAffix) {
        knownMonsterAffixes[affix.name] = affix
    }

    func getMonsterAffix(named name: String) -> MonsterAffix? {
        knownMonsterAffixes[name]
    }

    func reset() {
        knownItemAffixes.removeAll()
        knownMonsterAffixes.removeAll()
    }
}
