//
//  PaceCalculatorTests.swift
//  WaterTrackerTests
//

import Foundation
import Testing

struct PaceCalculatorTests {

    // A fixed UTC calendar for deterministic window math.
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, calendar: Calendar) -> Date {
        var dc = DateComponents()
        dc.year = y; dc.month = mo; dc.day = d; dc.hour = h; dc.minute = mi
        return calendar.date(from: dc)!
    }

    // MARK: TrackingWindow

    @Test func windowLengthNormal() {
        let w = TrackingWindow(startMinute: 480, endMinute: 1320) // 08:00-22:00
        #expect(w.crossesMidnight == false)
        #expect(w.lengthMinutes == 840) // 14 h
    }

    @Test func windowLengthCrossMidnight() {
        let w = TrackingWindow(startMinute: 1260, endMinute: 420) // 21:00 -> 07:00
        #expect(w.crossesMidnight == true)
        #expect(w.lengthMinutes == 600) // 10 h
    }

    // MARK: resolveWindowInstance

    @Test func resolveContainsNow() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let now = date(2025, 6, 1, 12, 0, calendar: cal)
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        #expect(inst.start == date(2025, 6, 1, 8, 0, calendar: cal))
        #expect(inst.end == date(2025, 6, 1, 22, 0, calendar: cal))
    }

    @Test func resolveBeforeWindowReturnsTodayUpcoming() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let now = date(2025, 6, 1, 6, 0, calendar: cal) // before 08:00
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        #expect(inst.start == date(2025, 6, 1, 8, 0, calendar: cal))
    }

    @Test func resolveAfterWindowReturnsTomorrow() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let now = date(2025, 6, 1, 23, 0, calendar: cal) // after 22:00
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        #expect(inst.start == date(2025, 6, 2, 8, 0, calendar: cal))
    }

    @Test func resolveCrossMidnightEarlyMorning() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 1260, endMinute: 420) // 21:00 -> 07:00
        let now = date(2025, 6, 2, 3, 0, calendar: cal) // 3am - inside the window that opened yesterday
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        #expect(inst.start == date(2025, 6, 1, 21, 0, calendar: cal))
        #expect(inst.end == date(2025, 6, 2, 7, 0, calendar: cal))
        #expect(inst.start <= now && now < inst.end)
    }

    @Test func resolveCrossMidnightEvening() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 1260, endMinute: 420) // 21:00 -> 07:00
        let now = date(2025, 6, 1, 22, 0, calendar: cal) // 10pm - inside today's window
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        #expect(inst.start == date(2025, 6, 1, 21, 0, calendar: cal))
        #expect(inst.end == date(2025, 6, 2, 7, 0, calendar: cal))
    }

    // MARK: expectedIntake

    @Test func expectedIntakeBoundaries() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let inst = PaceCalculator.resolveWindowInstance(now: date(2025, 6, 1, 12, 0, calendar: cal), window: w, calendar: cal)
        let goal = 2400.0
        #expect(PaceCalculator.expectedIntake(at: date(2025, 6, 1, 7, 0, calendar: cal), goal: goal, windowInstance: inst) == 0)
        #expect(PaceCalculator.expectedIntake(at: inst.start, goal: goal, windowInstance: inst) == 0)
        // Taper end = 22:00 - 90min = 20:30 -> full goal.
        #expect(PaceCalculator.expectedIntake(at: date(2025, 6, 1, 20, 30, calendar: cal), goal: goal, windowInstance: inst) == goal)
        #expect(PaceCalculator.expectedIntake(at: date(2025, 6, 1, 21, 30, calendar: cal), goal: goal, windowInstance: inst) == goal)
    }

    @Test func expectedIntakeLinearMidpoint() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let inst = PaceCalculator.resolveWindowInstance(now: date(2025, 6, 1, 12, 0, calendar: cal), window: w, calendar: cal)
        let goal = 2400.0
        // Ramp runs 08:00 -> 20:30 (750 min). Midpoint at 08:00 + 375min = 14:15.
        let mid = date(2025, 6, 1, 14, 15, calendar: cal)
        #expect(abs(PaceCalculator.expectedIntake(at: mid, goal: goal, windowInstance: inst) - goal / 2) < 0.001)
    }

    // MARK: computeNudgePlan

    @Test func nudgePlanGoalMetGuard() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let now = date(2025, 6, 1, 12, 0, calendar: cal)
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        // Within a threshold of the goal -> never nag.
        let plan = PaceCalculator.computeNudgePlan(now: now, todayIntake: 2200, goal: 2400, windowInstance: inst, lastDrinkAt: nil, threshold: 250)
        #expect(plan.isEmpty)
    }

    @Test func nudgePlanBehindPaceFires() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let now = date(2025, 6, 1, 15, 0, calendar: cal)
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        let plan = PaceCalculator.computeNudgePlan(now: now, todayIntake: 0, goal: 2400, windowInstance: inst, lastDrinkAt: nil, threshold: 250)
        #expect(!plan.isEmpty)
        #expect(plan.count <= PaceCalculator.maxNudgesPerWindow)
        #expect(plan.allSatisfy { $0 > now })          // strictly future
        #expect(plan.allSatisfy { $0 < inst.end })      // inside the window
        for i in 1..<plan.count {                       // >= 60 min apart
            #expect(plan[i].timeIntervalSince(plan[i - 1]) >= 60 * 60 - 0.001)
        }
    }

    @Test func nudgePlanRespectsLastDrink() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let now = date(2025, 6, 1, 15, 0, calendar: cal)
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        let lastDrink = date(2025, 6, 1, 14, 45, calendar: cal) // 15 min ago
        let plan = PaceCalculator.computeNudgePlan(now: now, todayIntake: 0, goal: 2400, windowInstance: inst, lastDrinkAt: lastDrink, threshold: 250)
        // First nudge must be >= 45 min after the last drink (>= 15:30).
        if let first = plan.first {
            #expect(first >= date(2025, 6, 1, 15, 30, calendar: cal))
        }
    }

    @Test func nudgePlanEmptyWhenWindowIsOver() {
        let cal = Self.utc
        let now = date(2025, 6, 1, 23, 0, calendar: cal)
        let endedInst = DateInterval(start: date(2025, 6, 1, 8, 0, calendar: cal),
                                     end: date(2025, 6, 1, 22, 0, calendar: cal))
        let plan = PaceCalculator.computeNudgePlan(now: now, todayIntake: 0, goal: 2400, windowInstance: endedInst, lastDrinkAt: nil, threshold: 250)
        #expect(plan.isEmpty)
    }

    // MARK: DST + units

    @Test func dstSpringForwardKeepsWallClockTimes() {
        // 2025-03-09 America/New_York springs forward (02:00 -> 03:00).
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let w = TrackingWindow(startMinute: 480, endMinute: 1320) // 08:00-22:00
        let inst = PaceCalculator.resolveWindowInstance(now: date(2025, 3, 9, 12, 0, calendar: cal), window: w, calendar: cal)
        // Still opens at wall-clock 08:00 and closes at 22:00 despite DST.
        #expect(cal.dateComponents([.hour, .minute], from: inst.start).hour == 8)
        #expect(cal.dateComponents([.hour, .minute], from: inst.end).hour == 22)
        // The lost hour (02:00) is before the window, so it is a normal 14 h.
        #expect(inst.duration == 14 * 3600)
    }

    @Test func perUnitThresholdOz() {
        let cal = Self.utc
        let w = TrackingWindow(startMinute: 480, endMinute: 1320)
        let now = date(2025, 6, 1, 15, 0, calendar: cal)
        let inst = PaceCalculator.resolveWindowInstance(now: now, window: w, calendar: cal)
        // oz goal 80, 0 intake, 8 oz threshold -> behind, fires.
        #expect(!PaceCalculator.computeNudgePlan(now: now, todayIntake: 0, goal: 80, windowInstance: inst, lastDrinkAt: nil, threshold: 8).isEmpty)
        // oz goal met -> no fire.
        #expect(PaceCalculator.computeNudgePlan(now: now, todayIntake: 75, goal: 80, windowInstance: inst, lastDrinkAt: nil, threshold: 8).isEmpty)
    }
}
