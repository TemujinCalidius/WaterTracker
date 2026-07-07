//
//  DrinkCatalog.swift
//  WaterTracker
//
//  Created by Claude Fable 5 on 7/7/26.
//

import SwiftUI

/*
 * Catalog version. Bump whenever any hydration factor changes.
 * Every logged HealthKit sample snapshots its own factor in metadata,
 * so a version bump never rewrites history: old samples keep the factor
 * they were logged under, new samples use the current one.
 */
let drinkCatalogVersion: Int = 1

/*
 * Custom HKMetadata keys carried on every dietaryWater sample this app writes.
 * The prefix matches the notification-id convention (NotificationHandler.swift).
 * The sample QUANTITY stores the effective (capped) hydration volume so every
 * existing statistics-sum consumer keeps working untouched; the raw volume and
 * both factors ride here so the in-app breakdown stays fully reconstructable.
 */
enum DrinkLogMetadata {
    static let drinkType = "YuLiang.SimpleWaterTracker.drinkType"                 // String rawValue
    static let rawVolumeML = "YuLiang.SimpleWaterTracker.rawVolumeML"             // Double, canonical ml
    static let factorAtLog = "YuLiang.SimpleWaterTracker.factorAtLog"             // Double, the applied (capped) factor
    static let strictFactorAtLog = "YuLiang.SimpleWaterTracker.strictFactorAtLog" // Double, signed factor snapshot
    static let catalogVersion = "YuLiang.SimpleWaterTracker.catalogVersion"       // Int
}

/*
 * Last-selected drink type, per-device UI state.
 * Deliberately stored in the shared app-group UserDefaults and NOT in the
 * CloudKit-synced configuration @Model: the selection changes with almost
 * every log, and a device still running an older app version would drop
 * unknown config fields through the delete-all-then-reinsert setters.
 * Logged samples carry their own metadata, so history never depends on this.
 */
enum LastDrinkTypeStore {
    static let storageKey = "YuLiang.SimpleWaterTracker.lastDrinkType"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.YuLiang.WaterTracker") ?? UserDefaults.standard
    }

    static func get() -> DrinkType {
        guard let rawValue = defaults.string(forKey: storageKey) else {
            return .water
        }
        return DrinkType(rawValue: rawValue) ?? .water
    }

    static func set(_ drinkType: DrinkType) {
        defaults.set(drinkType.rawValue, forKey: storageKey)
    }
}

/*
 * Sections group drinks in the picker. Alcohol is intentionally absent for now
 * (keeps the App Store rating at 4+); adding an `alcohol` case here plus the
 * alcohol drink cases below is a purely additive change.
 */
enum DrinkSection: String, Codable, Hashable, CaseIterable, Identifiable {
    case water, hot, dairy, cold
    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .water: return "Water"
        case .hot: return "Hot Drinks"
        case .dairy: return "Dairy"
        case .cold: return "Cold Drinks"
        }
    }
}

/*
 * The drink catalog. Mirrors the WaterUnits idiom (Units.swift): one Codable
 * enum with computed vars per case, no JSON resource, no new persistence.
 * rawValues are STABLE — they are written verbatim into HealthKit sample
 * metadata, so renaming one silently orphans logged history. Add cases freely;
 * never repurpose an existing rawValue.
 */
enum DrinkType: String, Codable, Hashable, CaseIterable, Identifiable {
    case water = "water_still"
    case sparklingWater = "water_sparkling"
    case coffee
    case espresso
    case teaBlackGreen = "tea_black_green"
    case teaHerbal = "tea_herbal"
    case milkWhole = "milk_whole"
    case milkSkim = "milk_skim"
    case plantMilk = "plant_milk"
    case juiceFruit = "juice_fruit"
    case smoothie
    case sodaRegular = "soda_regular"
    case sodaDiet = "soda_diet"
    case sportsDrink = "sports_drink"
    case energyDrink = "energy_drink"
    case ors
    case coconutWater = "coconut_water"
    case kombucha
    case brothSoup = "broth_soup"
    case proteinShake = "protein_shake"
    case hotChocolate = "hot_chocolate"

    var id: String { rawValue }

    /*
     * Hydration retention factor (Beverage Hydration Index anchors, Maughan et
     * al. 2016). Can exceed 1.0 (skim milk retains more than its own volume),
     * but the HealthKit WRITE is capped at writeFactor so we never record more
     * water than was actually poured; the > 1.0 bonus surfaces only in the
     * in-app breakdown.
     */
    var factor: Double {
        switch self {
        case .water, .sparklingWater, .teaBlackGreen, .teaHerbal: return 1.00
        case .coffee, .sodaDiet, .kombucha, .hotChocolate: return 0.95
        case .espresso, .juiceFruit, .energyDrink: return 0.90
        case .smoothie, .sodaRegular: return 0.85
        case .plantMilk: return 1.05
        case .milkWhole: return 1.20
        case .milkSkim: return 1.25
        case .sportsDrink, .coconutWater, .brothSoup, .proteinShake: return 1.10
        case .ors: return 1.50
        }
    }

    /*
     * Signed factor for a future "strict" mode. Identical to factor for every
     * non-alcohol drink; alcohol cases will return a lower (possibly negative)
     * value from the Polhuis model. Snapshotted now so that when alcohol/strict
     * ships, samples logged today remain retroactively computable.
     */
    var strictFactor: Double { factor }

    /*
     * The factor actually applied to the HealthKit write: never more than 1.0,
     * so a factored sample is always <= the beverage volume.
     */
    var writeFactor: Double { min(factor, 1.0) }

    /* Common serving sizes in ml, offered as quick-fill shortcuts in the picker. */
    var defaultServingsML: [Double] {
        switch self {
        case .water, .sparklingWater: return [250, 330, 500]
        case .coffee: return [125, 250]
        case .espresso: return [30, 60]
        case .teaBlackGreen, .teaHerbal, .smoothie: return [250, 350]
        case .milkWhole, .milkSkim, .plantMilk, .juiceFruit: return [200, 250]
        case .sodaRegular, .sodaDiet: return [330, 500]
        case .sportsDrink: return [500]
        case .energyDrink, .kombucha, .brothSoup, .hotChocolate: return [250]
        case .ors: return [250, 500]
        case .coconutWater: return [250, 330]
        case .proteinShake: return [300]
        }
    }

    /* Short attribution shown in the breakdown footnote. */
    var citation: String {
        switch self {
        case .water, .sparklingWater:
            return "Reference (1.00)"
        case .coffee, .espresso:
            return "Killer et al. 2014"
        case .teaBlackGreen, .teaHerbal, .milkWhole, .milkSkim, .juiceFruit, .sodaRegular, .ors:
            return "Maughan et al. 2016 (BHI)"
        case .sportsDrink:
            return "Baker et al. 2021 (PMC8465972)"
        case .plantMilk, .smoothie, .sodaDiet, .energyDrink, .coconutWater, .kombucha, .brothSoup, .proteinShake, .hotChocolate:
            return "Estimated (no direct study)"
        }
    }

    var section: DrinkSection {
        switch self {
        case .water, .sparklingWater:
            return .water
        case .coffee, .espresso, .teaBlackGreen, .teaHerbal, .brothSoup, .hotChocolate:
            return .hot
        case .milkWhole, .milkSkim, .plantMilk:
            return .dairy
        case .juiceFruit, .smoothie, .sodaRegular, .sodaDiet, .sportsDrink, .energyDrink, .ors, .coconutWater, .kombucha, .proteinShake:
            return .cold
        }
    }

    /* SF Symbol for the picker row and the drink button. */
    var symbolName: String {
        switch self {
        case .water: return "drop.fill"
        case .sparklingWater: return "bubbles.and.sparkles.fill"
        case .coffee, .espresso: return "cup.and.saucer.fill"
        case .teaBlackGreen, .hotChocolate, .brothSoup: return "mug.fill"
        case .teaHerbal, .coconutWater: return "leaf.fill"
        case .milkWhole, .milkSkim, .kombucha: return "waterbottle.fill"
        case .plantMilk: return "leaf.circle.fill"
        case .juiceFruit: return "waterbottle.fill"
        case .smoothie, .sodaRegular, .sodaDiet: return "cup.and.straw.fill"
        case .sportsDrink: return "figure.run"
        case .energyDrink: return "bolt.fill"
        case .ors: return "cross.vial.fill"
        case .proteinShake: return "dumbbell.fill"
        }
    }

    /* Wave tint for the cup contents (Waterllama-style: the liquid is the drink). */
    var waveColor: Color {
        switch self {
        case .water: return .blue
        case .sparklingWater: return .cyan
        case .coffee: return Color(red: 0.40, green: 0.26, blue: 0.13)
        case .espresso: return Color(red: 0.28, green: 0.18, blue: 0.10)
        case .teaBlackGreen: return Color(red: 0.36, green: 0.54, blue: 0.28)
        case .teaHerbal: return Color(red: 0.78, green: 0.55, blue: 0.22)
        case .milkWhole: return Color(red: 0.96, green: 0.94, blue: 0.86)
        case .milkSkim: return Color(red: 0.90, green: 0.92, blue: 0.95)
        case .plantMilk: return Color(red: 0.85, green: 0.78, blue: 0.62)
        case .juiceFruit: return Color(red: 0.98, green: 0.62, blue: 0.11)
        case .smoothie: return Color(red: 0.78, green: 0.24, blue: 0.44)
        case .sodaRegular: return Color(red: 0.44, green: 0.26, blue: 0.13)
        case .sodaDiet: return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .sportsDrink: return Color(red: 0.32, green: 0.78, blue: 0.55)
        case .energyDrink: return Color(red: 0.85, green: 0.16, blue: 0.30)
        case .ors: return Color(red: 0.13, green: 0.66, blue: 0.71)
        case .coconutWater: return Color(red: 0.93, green: 0.91, blue: 0.82)
        case .kombucha: return Color(red: 0.80, green: 0.52, blue: 0.25)
        case .brothSoup: return Color(red: 0.82, green: 0.60, blue: 0.24)
        case .proteinShake: return Color(red: 0.62, green: 0.47, blue: 0.35)
        case .hotChocolate: return Color(red: 0.35, green: 0.20, blue: 0.14)
        }
    }

    /* User-facing name. en + zh-Hans values land in Localizable.xcstrings with the picker UI. */
    var displayName: LocalizedStringKey {
        switch self {
        case .water: return "Water"
        case .sparklingWater: return "Sparkling Water"
        case .coffee: return "Coffee"
        case .espresso: return "Espresso"
        case .teaBlackGreen: return "Tea"
        case .teaHerbal: return "Herbal Tea"
        case .milkWhole: return "Whole Milk"
        case .milkSkim: return "Skim Milk"
        case .plantMilk: return "Plant Milk"
        case .juiceFruit: return "Fruit Juice"
        case .smoothie: return "Smoothie"
        case .sodaRegular: return "Soda"
        case .sodaDiet: return "Diet Soda"
        case .sportsDrink: return "Sports Drink"
        case .energyDrink: return "Energy Drink"
        case .ors: return "Rehydration Solution"
        case .coconutWater: return "Coconut Water"
        case .kombucha: return "Kombucha"
        case .brothSoup: return "Broth / Soup"
        case .proteinShake: return "Protein Shake"
        case .hotChocolate: return "Hot Chocolate"
        }
    }
}
