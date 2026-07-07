//
//  DrinkCatalogTests.swift
//  WaterTrackerTests
//

import Foundation
import Testing

struct DrinkCatalogTests {

    // The exact rawValues shipped in v1 (no alcohol). rawValues are written into
    // write-once HealthKit metadata, so a rename here silently orphans logged
    // history - this golden set makes any accidental rename fail loudly.
    static let expectedRawValues: Set<String> = [
        "water_still", "water_sparkling", "coffee", "espresso",
        "tea_black_green", "tea_herbal", "milk_whole", "milk_skim", "plant_milk",
        "juice_fruit", "smoothie", "soda_regular", "soda_diet", "sports_drink",
        "energy_drink", "ors", "coconut_water", "kombucha", "broth_soup",
        "protein_shake", "hot_chocolate",
    ]

    @Test func catalogHasExactlyTheShippedDrinks() {
        #expect(DrinkType.allCases.count == 21)
        #expect(Set(DrinkType.allCases.map(\.rawValue)) == Self.expectedRawValues)
    }

    @Test func noAlcoholShipped() {
        // v1 intentionally excludes alcohol to keep the App Store rating at 4+.
        for banned in ["beer", "wine", "spirits_neat", "cocktail"] {
            #expect(DrinkType(rawValue: banned) == nil)
        }
    }

    @Test func waterIsTheUnitReference() {
        #expect(DrinkType.water.factor == 1.0)
        #expect(DrinkType.water.strictFactor == 1.0)
        #expect(DrinkType.water.writeFactor == 1.0)
    }

    @Test func factorsAreInSaneRange() {
        for drink in DrinkType.allCases {
            #expect(drink.factor > 0.0)
            #expect(drink.factor <= 1.5)
        }
    }

    @Test func writeFactorNeverExceedsOne() {
        // The HealthKit write is capped at min(factor, 1.0): never record more
        // water than was poured. Retention bonuses (>1.0) live only in-app.
        for drink in DrinkType.allCases {
            #expect(drink.writeFactor == min(drink.factor, 1.0))
            #expect(drink.writeFactor <= 1.0)
        }
        // Sanity: the high-retention drinks do carry a >1.0 factor but a capped write.
        #expect(DrinkType.milkSkim.factor == 1.25)
        #expect(DrinkType.milkSkim.writeFactor == 1.0)
        #expect(DrinkType.ors.factor == 1.5)
        #expect(DrinkType.ors.writeFactor == 1.0)
    }

    @Test func strictEqualsLenientWhileNoAlcohol() {
        // strictFactor only diverges for alcohol; with none shipped it must match
        // factor everywhere, so today's samples stay retroactively correct.
        for drink in DrinkType.allCases {
            #expect(drink.strictFactor == drink.factor)
        }
    }

    @Test func everyDrinkIsFullySpecified() {
        for drink in DrinkType.allCases {
            #expect(drink.id == drink.rawValue)
            #expect(!drink.symbolName.isEmpty)
            #expect(!drink.citation.isEmpty)
            #expect(!drink.defaultServingsML.isEmpty)
            #expect(drink.defaultServingsML.allSatisfy { $0 > 0 })
        }
    }

    @Test func servingsAreAscending() {
        for drink in DrinkType.allCases {
            #expect(drink.defaultServingsML == drink.defaultServingsML.sorted())
        }
    }

    @Test func codableRoundTripByRawValue() throws {
        // Persisted as its rawValue (config field + HK metadata) - encoding must
        // be the stable string, not a case index.
        for drink in DrinkType.allCases {
            let data = try JSONEncoder().encode(drink)
            let decoded = try JSONDecoder().decode(DrinkType.self, from: data)
            #expect(decoded == drink)
            #expect(String(data: data, encoding: .utf8) == "\"\(drink.rawValue)\"")
        }
    }

    @Test func unknownRawValueIsNotForced() {
        // Readers fall back to .water on unknown rawValues; the raw initializer
        // itself must return nil so that fallback is a deliberate choice.
        #expect(DrinkType(rawValue: "unicorn_tears") == nil)
    }

    @Test func catalogVersionIsPinned() {
        #expect(drinkCatalogVersion == 1)
    }

    @Test func sectionsCoverEveryDrink() {
        // Every drink maps to a section, and every section is used (so the
        // picker never renders an empty group).
        let used = Set(DrinkType.allCases.map(\.section))
        #expect(used == Set(DrinkSection.allCases))
    }

    @Test func effectiveWriteVolumeExamples() {
        // What saveDrinkWater records: raw volume x writeFactor.
        #expect(250.0 * DrinkType.water.writeFactor == 250.0)
        #expect(250.0 * DrinkType.coffee.writeFactor == 237.5)
        #expect(330.0 * DrinkType.sodaRegular.writeFactor == 280.5)
        // High-retention drinks write at face value, never more.
        #expect(250.0 * DrinkType.milkSkim.writeFactor == 250.0)
        #expect(250.0 * DrinkType.ors.writeFactor == 250.0)
    }

    @Test func lastDrinkTypeStoreRoundTrip() {
        let original = LastDrinkTypeStore.defaults.string(forKey: LastDrinkTypeStore.storageKey)
        defer {
            // Restore whatever was there so tests never leak state.
            if let original {
                LastDrinkTypeStore.defaults.set(original, forKey: LastDrinkTypeStore.storageKey)
            } else {
                LastDrinkTypeStore.defaults.removeObject(forKey: LastDrinkTypeStore.storageKey)
            }
        }

        LastDrinkTypeStore.set(.coffee)
        #expect(LastDrinkTypeStore.get() == .coffee)

        // Unknown persisted value (e.g. a drink from a newer catalog) falls
        // back to water instead of crashing or sticking.
        LastDrinkTypeStore.defaults.set("drink_from_the_future", forKey: LastDrinkTypeStore.storageKey)
        #expect(LastDrinkTypeStore.get() == .water)

        LastDrinkTypeStore.defaults.removeObject(forKey: LastDrinkTypeStore.storageKey)
        #expect(LastDrinkTypeStore.get() == .water)
    }
}
