//
//  PaceCalculator.swift
//  WaterTracker
//
//  Created by Claude Fable 5 on 7/8/26.
//

import Foundation

/*
 * A daily tracking window, e.g. 08:00-22:00. Minutes are measured from
 * midnight (0...1439). If endMinute <= startMinute the window crosses midnight
 * (a night-shift window, e.g. 21:00 -> 07:00). The engine works in whatever
 * volume unit the caller passes (ml or oz) and never converts.
 */
struct TrackingWindow: Equatable {
    var startMinute: Int
    var endMinute: Int

    static let defaultStartMinute = 480   // 08:00
    static let defaultEndMinute = 1320    // 22:00

    // The taper denominator needs at least this much room, so the setter must
    // never store a window shorter than this.
    static let minimumLengthMinutes = 120 // 2 h

    init(startMinute: Int = defaultStartMinute, endMinute: Int = defaultEndMinute) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    var crossesMidnight: Bool {
        endMinute <= startMinute
    }

    // Length in real minutes, accounting for a midnight crossing.
    var lengthMinutes: Int {
        crossesMidnight ? (1440 - startMinute) + endMinute : endMinute - startMinute
    }
}

enum PaceCalculator {
    // The expected-intake curve reaches the full goal this long before the
    // window ends, so a user who keeps pace is done a bit early rather than at
    // the last second.
    static let taperMinutes: Double = 90

    // How finely computeNudgePlan walks the window looking for fire times.
    private static let stepMinutes: Double = 15
    // A nudge must be at least this long after the last drink...
    private static let minMinutesSinceLastDrink: Double = 45
    // ...and this far from the previous nudge.
    private static let minMinutesBetweenNudges: Double = 60
    // At most this many nudges per window.
    static let maxNudgesPerWindow = 5

    /*
     * Concrete start/end Dates of the window instance that contains `now`, or
     * the next upcoming instance if `now` falls between windows. Wall-clock
     * times are set with date(bySettingHour:) anchored on each day's midnight,
     * so 08:00 stays 08:00 across DST transitions (using date(byAdding:.minute)
     * here would drift by an hour on the spring-forward / fall-back day).
     */
    static func resolveWindowInstance(now: Date, window: TrackingWindow, calendar: Calendar) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)

        func setTime(_ minuteOfDay: Int, on dayStart: Date) -> Date {
            calendar.date(bySettingHour: minuteOfDay / 60,
                          minute: minuteOfDay % 60,
                          second: 0,
                          of: dayStart) ?? dayStart
        }

        func instance(dayOffset: Int) -> DateInterval {
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)!
            let start = setTime(window.startMinute, on: dayStart)
            // For a midnight-crossing window the end is on the following day.
            let endDayStart = window.crossesMidnight
                ? calendar.date(byAdding: .day, value: 1, to: dayStart)!
                : dayStart
            let end = setTime(window.endMinute, on: endDayStart)
            return DateInterval(start: start, end: end)
        }

        // Yesterday's instance can still be active in the early hours of a
        // night-shift window.
        for offset in [-1, 0, 1] {
            let candidate = instance(dayOffset: offset)
            if candidate.start <= now && now < candidate.end {
                return candidate
            }
        }
        // Between windows: return the next one to start.
        for offset in [0, 1] {
            let candidate = instance(dayOffset: offset)
            if candidate.start > now {
                return candidate
            }
        }
        return instance(dayOffset: 1)
    }

    /*
     * Cumulative intake a perfectly-paced user would have reached by `at`:
     * 0 before the window opens, the full goal from (end - taper) onward, and a
     * straight line in between.
     */
    static func expectedIntake(at: Date, goal: Double, windowInstance: DateInterval) -> Double {
        if at <= windowInstance.start { return 0 }
        let taperEnd = windowInstance.end.addingTimeInterval(-taperMinutes * 60)
        if at >= taperEnd { return goal }
        let denominator = taperEnd.timeIntervalSince(windowInstance.start)
        guard denominator > 0 else { return goal }  // window shorter than the taper; treat as met
        let elapsed = at.timeIntervalSince(windowInstance.start)
        return goal * (elapsed / denominator)
    }

    /*
     * Fire times for the rest of the current window, assuming no further intake.
     * Every returned Date is strictly in the future. Empty when the goal is
     * essentially met, when the window is over, or when nothing is due yet.
     *
     * threshold, todayIntake and goal are all in the caller's display unit
     * (250 ml / 8 oz thresholds; the app never converts units).
     */
    static func computeNudgePlan(now: Date,
                                 todayIntake: Double,
                                 goal: Double,
                                 windowInstance: DateInterval,
                                 lastDrinkAt: Date?,
                                 threshold: Double) -> [Date] {
        // Goal met (or within a threshold of it): never nag.
        if goal - todayIntake <= threshold { return [] }

        var nudges: [Date] = []
        var lastNudge: Date? = nil

        // Start no earlier than now, the window opening, or 45 min after the
        // last drink - whichever is latest.
        var cursor = max(now, windowInstance.start)
        if let last = lastDrinkAt {
            cursor = max(cursor, last.addingTimeInterval(minMinutesSinceLastDrink * 60))
        }

        while cursor < windowInstance.end && nudges.count < maxNudgesPerWindow {
            let expected = expectedIntake(at: cursor, goal: goal, windowInstance: windowInstance)
            let deficit = expected - todayIntake  // assumes zero future intake

            let farEnoughFromLastNudge = lastNudge.map { cursor.timeIntervalSince($0) >= minMinutesBetweenNudges * 60 } ?? true

            if deficit >= threshold && cursor > now && farEnoughFromLastNudge {
                nudges.append(cursor)
                lastNudge = cursor
            }
            cursor = cursor.addingTimeInterval(stepMinutes * 60)
        }

        return nudges
    }
}
