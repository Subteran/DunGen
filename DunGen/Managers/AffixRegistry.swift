import Foundation

@MainActor
@Observable
final class AffixRegistry {
    private var knownItemPrefixes: [String] = []
    private var knownItemSuffixes: [String] = []
    private var knownMonsterPrefixes: [String] = []
    private var knownMonsterSuffixes: [String] = []

    func registerItemAffix(_ affix: ItemAffix) {
        if affix.type.lowercased() == "prefix" {
            knownItemPrefixes.append(affix.name)
            if knownItemPrefixes.count > 10 {
                knownItemPrefixes.removeFirst()
            }
        } else if affix.type.lowercased() == "suffix" {
            knownItemSuffixes.append(affix.name)
            if knownItemSuffixes.count > 10 {
                knownItemSuffixes.removeFirst()
            }
        }
    }

    func registerMonsterAffix(_ affix: MonsterAffix) {
        if affix.type.lowercased() == "prefix" {
            knownMonsterPrefixes.append(affix.name)
            if knownMonsterPrefixes.count > 10 {
                knownMonsterPrefixes.removeFirst()
            }
        } else if affix.type.lowercased() == "suffix" {
            knownMonsterSuffixes.append(affix.name)
            if knownMonsterSuffixes.count > 10 {
                knownMonsterSuffixes.removeFirst()
            }
        }
    }

    func getRecentItemPrefixes(limit: Int) -> [String] {
        Array(knownItemPrefixes.suffix(limit))
    }

    func getRecentItemSuffixes(limit: Int) -> [String] {
        Array(knownItemSuffixes.suffix(limit))
    }

    func getRecentMonsterPrefixes(limit: Int) -> [String] {
        Array(knownMonsterPrefixes.suffix(limit))
    }

    func getRecentMonsterSuffixes(limit: Int) -> [String] {
        Array(knownMonsterSuffixes.suffix(limit))
    }

    func getRecentItemAffixes(limit: Int) -> [String] {
        Array((knownItemPrefixes + knownItemSuffixes).suffix(limit))
    }

    func getRecentMonsterAffixes(limit: Int) -> [String] {
        Array((knownMonsterPrefixes + knownMonsterSuffixes).suffix(limit))
    }

    func reset() {
        knownItemPrefixes.removeAll()
        knownItemSuffixes.removeAll()
        knownMonsterPrefixes.removeAll()
        knownMonsterSuffixes.removeAll()
    }
}
