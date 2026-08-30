import XCTest
@testable import SchonErledigt

final class ResetRuleTests: XCTestCase {
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))! }
    func testManualNeverResets() { XCTAssertNil(ResetRule.manual.nextReset(after: .now, calendar: calendar)) }
    func testHourReset() { XCTAssertEqual(ResetRule.afterHours(8).nextReset(after: date(2026, 8, 30, 10), calendar: calendar), date(2026, 8, 30, 18)) }
    func testDailyResetLaterSameDay() { XCTAssertEqual(ResetRule.daily(hour: 18, minute: 30).nextReset(after: date(2026, 8, 30, 10), calendar: calendar), date(2026, 8, 30, 18, 30)) }
    func testDailyResetMovesToTomorrow() { XCTAssertEqual(ResetRule.daily(hour: 5, minute: 0).nextReset(after: date(2026, 8, 30, 10), calendar: calendar), date(2026, 8, 31, 5)) }
    func testRoutineExpiresAtBoundary() { let completion = date(2026, 8, 30, 10); let item = RoutineItem(title: "Test", symbol: "checkmark", tintHex: "000000", resetRule: .afterHours(8), completedAt: completion, sortOrder: 0); XCTAssertTrue(item.isCompleted(at: date(2026, 8, 30, 17, 59))); XCTAssertFalse(item.isCompleted(at: date(2026, 8, 30, 18))) }
}
