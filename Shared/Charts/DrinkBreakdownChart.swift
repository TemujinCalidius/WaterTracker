//
//  DrinkBreakdownChart.swift
//  WaterTracker
//
//  Created by Claude Fable 5 on 7/7/26.
//

import SwiftUI
import Charts

struct DrinkBreakdownChart: View {
    /* "Today's Drinks" card: one stacked horizontal bar of today's intake
     * by drink type, with a row per drink showing poured -> counted volume.
     * Volumes arrive in canonical ml and convert to the display unit here.
     * The card hides itself when nothing was logged today. */

    var breakdownData: [DrinkBreakdownMetric]

    @State var config: WaterTrackerConfigManager

    func volumeStr(_ volumeML: Double) -> String {
        // volumeStrPair keeps this card consistent with the summary
        // sentence: ml amounts >= 1000 read as liters ("1.25L").
        if config.waterUnit == .ml {
            let volumePair = WaterUnits.ml.volumeStrPair(volumeML)
            return volumePair.numStr + volumePair.unitStr
        } else {
            let volumePair = WaterUnits.oz.volumeStrPair(volumeML / mlPerUSFluidOunce)
            return volumePair.numStr + volumePair.unitStr
        }
    }

    var body: some View {
        if !breakdownData.isEmpty {
            VStack { // Overall chart card
                HStack {
                    VStack(alignment: .leading) {
                        Text("Today's Drinks")
                            .font(.title3.bold())
                            .foregroundStyle(.blue)

                        Text("What you drank, and what it counts for")
                            .font(.caption)
                    }

                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

                Chart {
                    ForEach(breakdownData) { curDrinkMetric in
                        BarMark(x: .value("Water Drink", curDrinkMetric.effectiveML))
                            .foregroundStyle(by: .value("Drink", curDrinkMetric.type.localizedName))
                    }
                }
                .chartForegroundStyleScale(domain: breakdownData.map { $0.type.localizedName },
                                           range: breakdownData.map { $0.type.waveColor })
                .chartXAxis(.hidden)
                .chartLegend(.hidden)
#if !os(watchOS)
                .frame(height: 60)
#else
                .frame(height: 30)
#endif

                ForEach(breakdownData) { curDrinkMetric in
                    HStack {
                        Image(systemName: curDrinkMetric.type.symbolName)
                            .foregroundStyle(curDrinkMetric.type.waveColor)

                        Text(curDrinkMetric.type.displayName)

                        // Hydration factor badge (Beverage Hydration Index);
                        // the counted volume stays capped at the poured
                        // volume, so the rows always sum to the ring total.
                        if curDrinkMetric.type.factor != 1.0 {
                            Text(String(format: "×%.2f", curDrinkMetric.type.factor))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Show "poured -> counted" only when the hydration
                        // factor actually changed the number.
                        if volumeStr(curDrinkMetric.rawML) == volumeStr(curDrinkMetric.effectiveML) {
                            Text(String("\(volumeStr(curDrinkMetric.effectiveML))"))
                        } else {
                            Text(String("\(volumeStr(curDrinkMetric.rawML)) → \(volumeStr(curDrinkMetric.effectiveML))"))
                        }
                    }
#if !os(watchOS)
                    .font(.subheadline)
#else
                    .font(.caption)
#endif
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        }
    }
}

#Preview {
    @Previewable @State var configManager = WaterTrackerConfigManager()

    // Mixed day for Preview.
    @Previewable @State var mockBreakdownData: [DrinkBreakdownMetric] = [
        DrinkBreakdownMetric(type: .water, rawML: 750.0, effectiveML: 750.0),
        DrinkBreakdownMetric(type: .coffee, rawML: 500.0, effectiveML: 475.0),
        DrinkBreakdownMetric(type: .milkSkim, rawML: 250.0, effectiveML: 250.0),
    ]

    ZStack {
        DrinkBreakdownChart(breakdownData: mockBreakdownData, config: WaterTrackerConfigManager())
            .padding()
    }
}
