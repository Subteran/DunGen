import Testing
import Foundation
@testable import DunGen

@MainActor
struct AffixRegistryTests {

    @Test("Register item prefix and retrieve recent prefixes")
    func testRegisterItemPrefix() {
        let registry = AffixRegistry()
        let prefix = ItemAffix(name: "Flaming", type: "prefix", effect: "Deals fire damage")

        registry.registerItemAffix(prefix)
        let recent = registry.getRecentItemPrefixes(limit: 10)

        #expect(recent.contains("Flaming"))
        #expect(recent.count == 1)
    }

    @Test("Register item suffix and retrieve recent suffixes")
    func testRegisterItemSuffix() {
        let registry = AffixRegistry()
        let suffix = ItemAffix(name: "of Power", type: "suffix", effect: "Increased damage")

        registry.registerItemAffix(suffix)
        let recent = registry.getRecentItemSuffixes(limit: 10)

        #expect(recent.contains("of Power"))
        #expect(recent.count == 1)
    }

    @Test("Separate tracking of item prefixes and suffixes")
    func testSeparateItemPrefixSuffixTracking() {
        let registry = AffixRegistry()
        let prefix = ItemAffix(name: "Sharp", type: "prefix", effect: "Increased damage")
        let suffix = ItemAffix(name: "of Slaying", type: "suffix", effect: "Bonus damage")

        registry.registerItemAffix(prefix)
        registry.registerItemAffix(suffix)

        let prefixes = registry.getRecentItemPrefixes(limit: 10)
        let suffixes = registry.getRecentItemSuffixes(limit: 10)

        #expect(prefixes.contains("Sharp"))
        #expect(!prefixes.contains("of Slaying"))
        #expect(suffixes.contains("of Slaying"))
        #expect(!suffixes.contains("Sharp"))
    }

    @Test("Register monster prefix and retrieve recent prefixes")
    func testRegisterMonsterPrefix() {
        let registry = AffixRegistry()
        let prefix = MonsterAffix(name: "Enraged", type: "prefix", effect: "Increased HP and attack power")

        registry.registerMonsterAffix(prefix)
        let recent = registry.getRecentMonsterPrefixes(limit: 10)

        #expect(recent.contains("Enraged"))
        #expect(recent.count == 1)
    }

    @Test("Register monster suffix and retrieve recent suffixes")
    func testRegisterMonsterSuffix() {
        let registry = AffixRegistry()
        let suffix = MonsterAffix(name: "of Rage", type: "suffix", effect: "Increased damage")

        registry.registerMonsterAffix(suffix)
        let recent = registry.getRecentMonsterSuffixes(limit: 10)

        #expect(recent.contains("of Rage"))
        #expect(recent.count == 1)
    }

    @Test("Separate tracking of monster prefixes and suffixes")
    func testSeparateMonsterPrefixSuffixTracking() {
        let registry = AffixRegistry()
        let prefix = MonsterAffix(name: "Giant", type: "prefix", effect: "Massive size")
        let suffix = MonsterAffix(name: "of Power", type: "suffix", effect: "Increased strength")

        registry.registerMonsterAffix(prefix)
        registry.registerMonsterAffix(suffix)

        let prefixes = registry.getRecentMonsterPrefixes(limit: 10)
        let suffixes = registry.getRecentMonsterSuffixes(limit: 10)

        #expect(prefixes.contains("Giant"))
        #expect(!prefixes.contains("of Power"))
        #expect(suffixes.contains("of Power"))
        #expect(!suffixes.contains("Giant"))
    }

    @Test("Get recent item affixes with limit")
    func testGetRecentItemAffixes() {
        let registry = AffixRegistry()
        registry.registerItemAffix(ItemAffix(name: "Affix1", type: "prefix", effect: "Effect1"))
        registry.registerItemAffix(ItemAffix(name: "Affix2", type: "prefix", effect: "Effect2"))
        registry.registerItemAffix(ItemAffix(name: "Affix3", type: "suffix", effect: "Effect3"))
        registry.registerItemAffix(ItemAffix(name: "Affix4", type: "suffix", effect: "Effect4"))

        let recent = registry.getRecentItemAffixes(limit: 2)

        #expect(recent.count == 2)
    }

    @Test("Get recent monster affixes with limit")
    func testGetRecentMonsterAffixes() {
        let registry = AffixRegistry()
        registry.registerMonsterAffix(MonsterAffix(name: "Affix1", type: "prefix", effect: "Effect1"))
        registry.registerMonsterAffix(MonsterAffix(name: "Affix2", type: "prefix", effect: "Effect2"))
        registry.registerMonsterAffix(MonsterAffix(name: "Affix3", type: "suffix", effect: "Effect3"))

        let recent = registry.getRecentMonsterAffixes(limit: 2)

        #expect(recent.count == 2)
    }

    @Test("Reset clears all item affixes")
    func testResetClearsItemAffixes() {
        let registry = AffixRegistry()
        registry.registerItemAffix(ItemAffix(name: "Test", type: "prefix", effect: "Test"))

        #expect(registry.getRecentItemPrefixes(limit: 10).count == 1)

        registry.reset()

        #expect(registry.getRecentItemPrefixes(limit: 10).count == 0)
    }

    @Test("Reset clears all monster affixes")
    func testResetClearsMonsterAffixes() {
        let registry = AffixRegistry()
        registry.registerMonsterAffix(MonsterAffix(name: "Test", type: "prefix", effect: "Test effect"))

        #expect(registry.getRecentMonsterPrefixes(limit: 10).count == 1)

        registry.reset()

        #expect(registry.getRecentMonsterPrefixes(limit: 10).count == 0)
    }

    @Test("Registry maintains last 10 prefixes only")
    func testRegistryMaintainsLast10Prefixes() {
        let registry = AffixRegistry()

        for i in 1...15 {
            registry.registerItemAffix(ItemAffix(name: "Prefix\(i)", type: "prefix", effect: "Effect"))
        }

        let recent = registry.getRecentItemPrefixes(limit: 20)
        #expect(recent.count == 10)
        #expect(recent.contains("Prefix15"))
        #expect(!recent.contains("Prefix1"))
    }

    @Test("Recent affixes limit larger than count returns all")
    func testRecentAffixesLimitLargerThanCount() {
        let registry = AffixRegistry()
        registry.registerItemAffix(ItemAffix(name: "Affix1", type: "prefix", effect: "Effect1"))
        registry.registerItemAffix(ItemAffix(name: "Affix2", type: "prefix", effect: "Effect2"))

        let recent = registry.getRecentItemAffixes(limit: 10)

        #expect(recent.count == 2)
    }

    @Test("Recent affixes with zero limit returns empty")
    func testRecentAffixesZeroLimit() {
        let registry = AffixRegistry()
        registry.registerItemAffix(ItemAffix(name: "Affix1", type: "prefix", effect: "Effect1"))

        let recent = registry.getRecentItemAffixes(limit: 0)

        #expect(recent.count == 0)
    }
}
