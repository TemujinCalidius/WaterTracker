//
//  UnitsTests.swift
//  WaterTrackerTests
//

import Foundation
import Testing

struct UnitsTests {

    @Test func unitStrings() {
        #expect(WaterUnits.ml.unitStr == "ml")
        #expect(WaterUnits.oz.unitStr == "oz")
    }

    @Test func defaultsAreConsistent() {
        for unit in [WaterUnits.ml, WaterUnits.oz] {
            #expect(unit.cupMinimumNum > 0)
            #expect(unit.unitStep > 0)
            #expect(unit.cupMinimumNum < unit.cupDefaultCapacity)
            #expect(unit.defaultDailyGoal > unit.cupDefaultCapacity)
        }
    }

    @Test func dailyGoalRangeContainsDefault() {
        // The settings picker offers dailyGoalRange; the default goal must be
        // selectable, or a fresh install shows a goal the picker can't represent.
        for unit in [WaterUnits.ml, WaterUnits.oz] {
            #expect(unit.dailyGoalRange.contains(unit.defaultDailyGoal))
        }
    }

    @Test func dailyGoalRangeIsAscendingAndNonEmpty() {
        for unit in [WaterUnits.ml, WaterUnits.oz] {
            let range = unit.dailyGoalRange
            #expect(!range.isEmpty)
            #expect(range == range.sorted())
        }
    }

    @Test func codableRoundTrip() throws {
        // WaterUnits is Codable-persisted inside WaterTrackerConfiguration
        // (SwiftData + CloudKit) - encoding stability matters across versions.
        for unit in [WaterUnits.ml, WaterUnits.oz] {
            let data = try JSONEncoder().encode(unit)
            let decoded = try JSONDecoder().decode(WaterUnits.self, from: data)
            #expect(decoded == unit)
        }
    }
}
