import Foundation
import XCTest
@testable import NookClone

final class CalendarTests: XCTestCase {
    func testSelectedDayWindowUsesCalendarBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let selected = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 15))
        )

        let window = CalendarDateWindow.day(containing: selected, calendar: calendar)

        XCTAssertEqual(calendar.component(.hour, from: window.start), 0)
        XCTAssertEqual(calendar.component(.day, from: window.start), 8)
        XCTAssertEqual(calendar.component(.day, from: window.end), 9)
        XCTAssertEqual(window.duration, 23 * 60 * 60, accuracy: 0.1)
    }

    func testMealPeriodBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))

        func date(hour: Int, minute: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: hour, minute: minute)))
        }

        XCTAssertEqual(SchoolMealPeriod.current(at: try date(hour: 0, minute: 0), calendar: calendar), .breakfast)
        XCTAssertEqual(SchoolMealPeriod.current(at: try date(hour: 7, minute: 59), calendar: calendar), .breakfast)
        XCTAssertEqual(SchoolMealPeriod.current(at: try date(hour: 8, minute: 0), calendar: calendar), .lunch)
        XCTAssertEqual(SchoolMealPeriod.current(at: try date(hour: 13, minute: 59), calendar: calendar), .lunch)
        XCTAssertEqual(SchoolMealPeriod.current(at: try date(hour: 14, minute: 0), calendar: calendar), .dinner)
        XCTAssertEqual(SchoolMealPeriod.current(at: try date(hour: 23, minute: 59), calendar: calendar), .dinner)
    }

    func testMealPairUsesTomorrowBreakfastAtNight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 20)))
        let pair = SchoolMealPeriod.upcomingPair(at: evening, calendar: calendar)
        XCTAssertEqual(pair.map(\.period), [.dinner, .breakfast])
        XCTAssertTrue(calendar.isDate(pair[1].date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: evening)!))
    }

    func testReminderDateWindowAndSorting() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12)))
        let window = ReminderDateLogic.displayWindow(now: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: window.end), 13)

        let today = ReminderItem(id: "today", title: "Today", dueDate: now, listTitle: "Tasks", isOverdue: false)
        let old = ReminderItem(id: "old", title: "Old", dueDate: now.addingTimeInterval(-86_400), listTitle: "Tasks", isOverdue: true)
        let older = ReminderItem(id: "older", title: "Older", dueDate: now.addingTimeInterval(-172_800), listTitle: "Tasks", isOverdue: true)
        XCTAssertEqual(ReminderDateLogic.sort([today, old, older]).map(\.id), ["older", "old", "today"])
    }
}
