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

    // The liter number renders via FormatStyle, which honors the run locale's
    // decimal separator (e.g. "1,25" on a de_DE machine) - derive it so the
    // expectations below hold on any Latin-digit test host.
    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    @Test func volumeStrPairMlSubLiterIsUnchanged() {
        // Sub-liter ml must stay byte-identical to the v1.8 "%d" rendering:
        // integer truncation, no padding, "ml" suffix.
        #expect(WaterUnits.ml.volumeStrPair(0) == ("0", "ml"))
        #expect(WaterUnits.ml.volumeStrPair(50) == ("50", "ml"))
        #expect(WaterUnits.ml.volumeStrPair(999) == ("999", "ml"))
        #expect(WaterUnits.ml.volumeStrPair(999.9) == ("999", "ml"))
        // Truncation, not rounding - matches Int(value) at every existing ml surface.
        #expect(WaterUnits.ml.volumeStrPair(250.7) == ("250", "ml"))
        // Float boundary: 999.99 stays ml; the liter flip is >= 1000.0 exact.
        #expect(WaterUnits.ml.volumeStrPair(999.99).unitStr == "ml")
    }

    @Test func volumeStrPairMlAutoScalesToLiters() {
        let sep = decimalSeparator
        #expect(WaterUnits.ml.volumeStrPair(1000) == ("1", "L"))
        #expect(WaterUnits.ml.volumeStrPair(1050) == ("1\(sep)05", "L"))
        // 2 x 20 oz logged in oz mode, read back in ml mode.
        #expect(WaterUnits.ml.volumeStrPair(1182.94) == ("1\(sep)18", "L"))
        #expect(WaterUnits.ml.volumeStrPair(1250) == ("1\(sep)25", "L"))
        // Trailing zeros are trimmed: the default goal reads "2.4L", not "2.40L".
        #expect(WaterUnits.ml.volumeStrPair(2400) == ("2\(sep)4", "L"))
        #expect(WaterUnits.ml.volumeStrPair(3600) == ("3\(sep)6", "L"))
    }

    @Test func volumeStrPairKeepsCupViewZeroPadding() {
        // CupView renders the pending amount fixed-width ("%.3d").
        #expect(WaterUnits.ml.volumeStrPair(50, isPadded: true) == ("050", "ml"))
        #expect(WaterUnits.ml.volumeStrPair(600, isPadded: true) == ("600", "ml"))
        // Padding only applies to the sub-liter integer style; liters render plain
        // (unreachable from CupView while cup capacity caps at 600ml).
        #expect(WaterUnits.ml.volumeStrPair(1050, isPadded: true) == ("1\(decimalSeparator)05", "L"))
        // oz ignores the flag entirely.
        #expect(WaterUnits.oz.volumeStrPair(20, isPadded: true) == ("20.0", "oz"))
    }

    @Test func volumeStrPairOzIsPassthrough() {
        // oz output must stay byte-identical to the v1.8 "%.1f" rendering
        // everywhere - oz never auto-scales.
        #expect(WaterUnits.oz.volumeStrPair(20) == ("20.0", "oz"))
        #expect(WaterUnits.oz.volumeStrPair(80) == ("80.0", "oz"))
        #expect(WaterUnits.oz.volumeStrPair(8.64) == ("8.6", "oz"))
        #expect(WaterUnits.oz.volumeStrPair(1182.94) == ("1182.9", "oz"))
    }

    @Test func volumeStrPairGoalRangeRendersUniformly() {
        // Every ml goal choice is >= 1000, so the settings wheel reads all-liters;
        // a future sub-1000 range entry would silently mix units in the picker.
        for goal in WaterUnits.ml.dailyGoalRange {
            #expect(WaterUnits.ml.volumeStrPair(goal).unitStr == WaterUnits.literUnitStr)
        }
        // oz rows keep their "%.1f" look for the whole range.
        for goal in WaterUnits.oz.dailyGoalRange {
            #expect(WaterUnits.oz.volumeStrPair(goal).unitStr == "oz")
        }
    }
}
