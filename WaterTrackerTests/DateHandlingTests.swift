//
//  DateHandlingTests.swift
//  WaterTrackerTests
//

import Foundation
import Testing

struct DateHandlingTests {

    @Test func startOfDateHonorsItsArgument() {
        // Regression test: getStartOfDate used to ignore its parameter and
        // always return the start of *today*.
        let calendar = Calendar(identifier: .gregorian)
        let pastNoon = calendar.date(byAdding: .day, value: -3, to: Date())!
        let expected = calendar.startOfDay(for: pastNoon)
        #expect(getStartOfDate(date: pastNoon) == expected)
    }

    @Test func startOfTodayMatchesCalendar() {
        let now = Date()
        let expected = Calendar(identifier: .gregorian).startOfDay(for: now)
        #expect(getStartOfDate(date: now) == expected)
    }

    @Test func resultHasNoTimeComponents() {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.hour, .minute, .second], from: getStartOfDate(date: Date()))
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }
}
