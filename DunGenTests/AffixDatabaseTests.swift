import Testing
import Foundation
@testable import DunGen

@MainActor
struct AffixDatabaseTests {

    @Test("Monster prefix database has 50 entries")
    func testMonsterPrefixCount() {
        #expect(AffixDatabase.monsterPrefixes.count == 50)
    }

    @Test("Monster suffix database has 50 entries")
    func testMonsterSuffixCount() {
        #expect(AffixDatabase.monsterSuffixes.count == 50)
    }

    @Test("Item prefix database has 50 entries")
    func testItemPrefixCount() {
        #expect(AffixDatabase.itemPrefixes.count == 50)
    }

    @Test("Item suffix database has 50 entries")
    func testItemSuffixCount() {
        #expect(AffixDatabase.itemSuffixes.count == 50)
    }

    @Test("All monster prefixes have required fields")
    func testMonsterPrefixStructure() {
        for prefix in AffixDatabase.monsterPrefixes {
            #expect(!prefix.name.isEmpty)
            #expect(prefix.type == "prefix")
            #expect(!prefix.effect.isEmpty)
            #expect(prefix.hpMultiplier >= 1.0)
        }
    }

    @Test("All monster suffixes have required fields")
    func testMonsterSuffixStructure() {
        for suffix in AffixDatabase.monsterSuffixes {
            #expect(!suffix.name.isEmpty)
            #expect(suffix.type == "suffix")
            #expect(!suffix.effect.isEmpty)
        }
    }

    @Test("All item prefixes have required fields")
    func testItemPrefixStructure() {
        for prefix in AffixDatabase.itemPrefixes {
            #expect(!prefix.name.isEmpty)
            #expect(prefix.type == "prefix")
            #expect(!prefix.effect.isEmpty)
        }
    }

    @Test("All item suffixes have required fields")
    func testItemSuffixStructure() {
        for suffix in AffixDatabase.itemSuffixes {
            #expect(!suffix.name.isEmpty)
            #expect(suffix.type == "suffix")
            #expect(!suffix.effect.isEmpty)
        }
    }

    @Test("Random monster prefix returns valid entry")
    func testRandomMonsterPrefix() {
        let prefix = AffixDatabase.randomMonsterPrefix()
        #expect(prefix != nil)
        #expect(!prefix!.name.isEmpty)
    }

    @Test("Random monster suffix returns valid entry")
    func testRandomMonsterSuffix() {
        let suffix = AffixDatabase.randomMonsterSuffix()
        #expect(suffix != nil)
        #expect(!suffix!.name.isEmpty)
    }

    @Test("Random item prefix returns valid entry")
    func testRandomItemPrefix() {
        let prefix = AffixDatabase.randomItemPrefix()
        #expect(prefix != nil)
        #expect(!prefix!.name.isEmpty)
    }

    @Test("Random item suffix returns valid entry")
    func testRandomItemSuffix() {
        let suffix = AffixDatabase.randomItemSuffix()
        #expect(suffix != nil)
        #expect(!suffix!.name.isEmpty)
    }

    @Test("Get monster prefix by name returns correct entry")
    func testGetMonsterPrefixByName() {
        let ancient = AffixDatabase.getMonsterPrefix(name: "Ancient")
        #expect(ancient != nil)
        #expect(ancient?.name == "Ancient")
        #expect(ancient?.type == "prefix")
    }

    @Test("Get monster suffix by name returns correct entry")
    func testGetMonsterSuffixByName() {
        let ofRage = AffixDatabase.getMonsterSuffix(name: "of Rage")
        #expect(ofRage != nil)
        #expect(ofRage?.name == "of Rage")
        #expect(ofRage?.type == "suffix")
    }

    @Test("Get item prefix by name returns correct entry")
    func testGetItemPrefixByName() {
        let sharp = AffixDatabase.getItemPrefix(name: "Sharp")
        #expect(sharp != nil)
        #expect(sharp?.name == "Sharp")
        #expect(sharp?.type == "prefix")
    }

    @Test("Get item suffix by name returns correct entry")
    func testGetItemSuffixByName() {
        let ofPower = AffixDatabase.getItemSuffix(name: "of Power")
        #expect(ofPower != nil)
        #expect(ofPower?.name == "of Power")
        #expect(ofPower?.type == "suffix")
    }

    @Test("Get non-existent affix returns nil")
    func testGetNonExistentAffix() {
        let result = AffixDatabase.getMonsterPrefix(name: "NonExistent")
        #expect(result == nil)
    }

    @Test("Monster affixes have varied HP multipliers")
    func testMonsterAffixHPVariety() {
        let multipliers = Set(AffixDatabase.monsterPrefixes.map { $0.hpMultiplier } +
                             AffixDatabase.monsterSuffixes.map { $0.hpMultiplier })
        #expect(multipliers.count > 5)
    }

    @Test("Item affixes have damage bonuses")
    func testItemAffixDamageVariety() {
        let damageAffixes = AffixDatabase.itemPrefixes.filter { $0.damageBonus != nil }
        #expect(damageAffixes.count > 20)
    }

    @Test("Item affixes have defense bonuses")
    func testItemAffixDefenseVariety() {
        let defenseAffixes = AffixDatabase.itemPrefixes.filter { $0.defenseBonus != nil }
        #expect(defenseAffixes.count > 10)
    }

    @Test("Monster affixes provide meaningful stat changes")
    func testMonsterAffixStats() {
        for prefix in AffixDatabase.monsterPrefixes {
            let hasStats = prefix.hpMultiplier != 1.0 || prefix.damageBonus != 0 || prefix.defenseBonus != 0
            #expect(hasStats, "Prefix '\(prefix.name)' should have at least one stat modifier")
        }
    }

    @Test("Item affixes provide meaningful stat changes")
    func testItemAffixStats() {
        for prefix in AffixDatabase.itemPrefixes {
            let hasStats = prefix.damageBonus != nil || prefix.defenseBonus != nil
            #expect(hasStats, "Prefix '\(prefix.name)' should have at least one stat bonus")
        }
    }
}
