import Foundation
import Testing
@testable import HijriCalendarCore

@Test func gregorianDateMapping() throws {
    let calendar = makeCalendar()
    let startDate = makeDate(2026, 1, 20, calendar)
    let definition = HijriMonthDefinition(
        hijriYear: 1447,
        hijriMonth: 8,
        gregorianStartDate: startDate,
        length: 30,
        source: .calculated
    )
    let engine = CalendarEngine(definitions: [definition], calendar: calendar)

    let hijriDate = HijriDate(year: 1447, month: 8, day: 10)
    let mapped = engine.gregorianDate(for: hijriDate)

    #expect(mapped == makeDate(2026, 1, 29, calendar))
}

@Test func annualOccurrencesWithinInterval() throws {
    let calendar = makeCalendar()
    let def1 = HijriMonthDefinition(
        hijriYear: 1447,
        hijriMonth: 8,
        gregorianStartDate: makeDate(2026, 1, 20, calendar),
        length: 30,
        source: .calculated
    )
    let def2 = HijriMonthDefinition(
        hijriYear: 1448,
        hijriMonth: 8,
        gregorianStartDate: makeDate(2027, 1, 9, calendar),
        length: 29,
        source: .calculated
    )

    let engine = CalendarEngine(definitions: [def1, def2], calendar: calendar)
    let reminder = HijriReminder(
        title: "Annual Test",
        hijriDate: HijriDate(month: 8, day: 1),
        recurrence: .annual,
        time: ReminderTime(hour: 9, minute: 0),
        durationDays: 1
    )
    let interval = DateInterval(
        start: makeDate(2026, 1, 1, calendar),
        end: makeDate(2028, 1, 1, calendar)
    )

    let dates = engine.occurrenceDates(for: reminder, within: interval)
    let expected = [
        makeDate(2026, 1, 20, calendar).withTime(hour: 9, minute: 0, calendar: calendar),
        makeDate(2027, 1, 9, calendar).withTime(hour: 9, minute: 0, calendar: calendar),
    ]

    #expect(dates == expected)
}

@Test func multiDayOccurrencesExpand() throws {
    let calendar = makeCalendar()
    let def = HijriMonthDefinition(
        hijriYear: 1447,
        hijriMonth: 9,
        gregorianStartDate: makeDate(2026, 2, 18, calendar),
        length: 30,
        source: .calculated
    )
    let engine = CalendarEngine(definitions: [def], calendar: calendar)
    let reminder = HijriReminder(
        title: "Multi-Day",
        hijriDate: HijriDate(year: 1447, month: 9, day: 1),
        recurrence: .oneTime,
        time: ReminderTime(hour: 6, minute: 30),
        durationDays: 3
    )

    let interval = DateInterval(
        start: makeDate(2026, 2, 1, calendar),
        end: makeDate(2026, 3, 1, calendar)
    )

    let dates = engine.occurrenceDates(for: reminder, within: interval)
    let expected = [
        makeDate(2026, 2, 18, calendar).withTime(hour: 6, minute: 30, calendar: calendar),
        makeDate(2026, 2, 19, calendar).withTime(hour: 6, minute: 30, calendar: calendar),
        makeDate(2026, 2, 20, calendar).withTime(hour: 6, minute: 30, calendar: calendar),
    ]

    #expect(dates == expected)
}

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
}

private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
    let components = DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day)
    return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

private extension Date {
    func withTime(hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }
}
