//
//  Units.swift
//  WaterTracker
//
//  Created by Yu Liang on 10/30/24.
//

import Foundation

enum WaterUnits: Codable, Hashable {
    
    case oz
    case ml
    
    var cupDefaultCapacity: Double {
        // FIXME:: Changing cup size?
        switch self {
        case .oz:
            return 20.0
        case .ml:
            return 600.0
        }
    }
    
    var cupMinimumNum: Double {
        switch self {
        case .oz:
            return 0.1
        case .ml:
            return 10
        }
    }

    var unitStep: Double {
        switch self {
        case .oz:
            return 0.1
        case .ml:
            return 5
        }
    }
    
    var unitStr: String {
        switch self {
        case .oz:
            return "oz"
        case .ml:
            return "ml"
        }
    }
    
    static let mlPerLiter: Double = 1000.0
    static let literUnitStr: String = "L" // Unlocalized unit symbol by convention, same as unitStr above.

    /*
     * Display pair (number string, unit string) for a volume in this unit.
     * ml auto-scales to liters at >= 1000 for display only; stored values stay raw ml.
     * isPadded keeps CupView's fixed-width "%.3d" style for sub-liter ml values;
     * the liter branch renders unpadded (unreachable while cup capacity caps at 600ml).
     * Returning a pair keeps every localization key's existing "%@%@" shape.
     */
    func volumeStrPair(_ value: Double, isPadded: Bool = false) -> (numStr: String, unitStr: String) {
        switch self {
        case .oz:
            return (String(format: "%.1f", value), self.unitStr)
        case .ml:
            if value >= WaterUnits.mlPerLiter {
                let liters = value / WaterUnits.mlPerLiter
                return (liters.formatted(.number.precision(.fractionLength(0...2))), WaterUnits.literUnitStr)
            }
            return (String(format: isPadded ? "%.3d" : "%d", Int(value)), self.unitStr)
        }
    }
    
    var defaultDailyGoal: Double {
        // As suggested by the citation. 
        switch self {
        case .oz:
            return 80.0
        case .ml:
            return 2400.0
        }
    }
    
    var dailyGoalRange: [Double] {
        switch self {
        case .oz:
            return Array(stride(from: 50.0, to: 160, by: 5.0))
        case .ml:
            return Array(stride(from: 1500.0, to: 3700.0, by: 100.0))
        }
    }
}
