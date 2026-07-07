//
//  ShortCutIntent.swift
//  WaterTracker
//
//  Created by Yu Liang on 12/4/24.
//

import AppIntents
import SwiftUI
import SwiftData
import WidgetKit

/*
 * Siri-facing mirror of DrinkType (same stable rawValues). A separate
 * AppEnum wrapper keeps the AppIntents display machinery out of the
 * widget targets, which compile DrinkCatalog.swift but not this file.
 */
enum DrinkTypeAppEnum: String, AppEnum {
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

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Drink Type"

    static let caseDisplayRepresentations: [DrinkTypeAppEnum: DisplayRepresentation] = [
        .water: "Water",
        .sparklingWater: "Sparkling Water",
        .coffee: "Coffee",
        .espresso: "Espresso",
        .teaBlackGreen: "Tea",
        .teaHerbal: "Herbal Tea",
        .milkWhole: "Whole Milk",
        .milkSkim: "Skim Milk",
        .plantMilk: "Plant Milk",
        .juiceFruit: "Fruit Juice",
        .smoothie: "Smoothie",
        .sodaRegular: "Soda",
        .sodaDiet: "Diet Soda",
        .sportsDrink: "Sports Drink",
        .energyDrink: "Energy Drink",
        .ors: "Rehydration Solution",
        .coconutWater: "Coconut Water",
        .kombucha: "Kombucha",
        .brothSoup: "Broth / Soup",
        .proteinShake: "Protein Shake",
        .hotChocolate: "Hot Chocolate",
    ]

    var drinkType: DrinkType {
        return DrinkType(rawValue: self.rawValue) ?? .water
    }
}

struct ShortCutIntent: AppIntent {

    static let title: LocalizedStringResource = "Log a water drinking event"

    @Parameter(title: "Drink Num")
    var drinkNum: Double

    // Optional so the existing one-breath Siri phrase keeps working:
    // when omitted, the last drink picked in the app is logged.
    @Parameter(title: "Drink Type")
    var drinkType: DrinkTypeAppEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let healthKitManager = HealthKitManager()
        let config = WaterTrackerConfigManager()
        let container = try ModelContainer(for: WaterTrackerConfiguration.self)
        let context = ModelContext(container)
        config.receiveUpdatedWaterTrackerConfig(modelContext: context)

        let selectedDrinkType = self.drinkType?.drinkType ?? LastDrinkTypeStore.get()

        _ = await healthKitManager.saveDrinkWater(drink_num: self.drinkNum, waterUnitInput: config.getUnit(), drinkType: selectedDrinkType)

        // Water keeps the exact v1.8 dialog; other drinks are named.
        let drinkNameStr = selectedDrinkType == .water ? "water drinking" : selectedDrinkType.localizedName

        var res_str:String.LocalizationValue = ""
        if config.getUnit() == .ml {
            let tmp_res_str = String(format:"Logged %.0f\(config.getUnitStr()) \(drinkNameStr). ", drinkNum)
            res_str = String.LocalizationValue(stringLiteral: tmp_res_str)
        } else {
            let tmp_res_str = String(format:"Logged %.1f\(config.getUnitStr()) \(drinkNameStr). ", drinkNum)
            res_str = String.LocalizationValue(stringLiteral: tmp_res_str)
        }

        WidgetCenter.shared.reloadAllTimelines()
        LocalNotificationHandler.registerLocalNotification()
        CrossOsConnectivity.shared.sendNotificationReminder()
        return .result(dialog: IntentDialog(stringLiteral: String(localized:res_str)))
    }

    static let openAppWhenRun: Bool = false
}


// Siri integration
struct WaterTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShortCutIntent(),
            phrases: [
                "Log a \(.applicationName) water drinking",
                "Use \(.applicationName) to log water drinking",
                "Log a \(\.$drinkType) in \(.applicationName)",
                "记录\(.applicationName)喝水",
                "使用\(.applicationName)来记录喝水",
                "用\(.applicationName)记录\(\.$drinkType)"
            ],
            shortTitle: "Log Drinking",
            systemImageName: "AppIcon"
        )
    }
}
