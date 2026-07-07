//
//  Units.swift
//  WaterTracker
//
//  Created by Yu Liang on 10/30/24.
//

enum WaterUnits: Codable, Hashable {
    
    case oz
    case ml
    
    var cupDefaultCapacity: Double {
        // The on-screen vessel is a 1 L bottle, so the fill reads accurately:
        // 500ml is half full, 1L is full.
        switch self {
        case .oz:
            return 34.0
        case .ml:
            return 1000.0
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
