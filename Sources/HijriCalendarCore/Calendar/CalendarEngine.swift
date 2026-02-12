import Foundation

public struct CalendarEngine {
    public var definitions: [HijriMonthDefinition]
    public var calendar: Calendar

    public init(definitions: [HijriMonthDefinition], calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.definitions = definitions
        self.calendar = calendar
    }

    public func gregorianDate(for hijriDate: HijriDate, fallbackYear: Int? = nil) -> Date? {
        let resolvedYear = hijriDate.year ?? fallbackYear
        guard let year = resolvedYear else { return nil }
        guard let definition = monthDefinition(forYear: year, month: hijriDate.month) else { return nil }
        return definition.gregorianDate(forHijriDay: hijriDate.day, calendar: calendar)
    }

    public func hijriDate(for gregorianDate: Date) -> HijriDate? {
        guard let definition = monthDefinition(containing: gregorianDate) else { return nil }
        let start = calendar.startOfDay(for: definition.gregorianStartDate)
        let target = calendar.startOfDay(for: gregorianDate)
        let offset = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        let hijriDay = offset + 1
        guard definition.contains(hijriDay: hijriDay) else { return nil }
        return HijriDate(year: definition.hijriYear, month: definition.hijriMonth, day: hijriDay)
    }

    public func monthDefinition(forYear year: Int, month: Int) -> HijriMonthDefinition? {
        definitions.first { $0.hijriYear == year && $0.hijriMonth == month }
    }

    public func monthDefinition(containing gregorianDate: Date) -> HijriMonthDefinition? {
        let target = calendar.startOfDay(for: gregorianDate)
        return definitions.first { definition in
            let start = calendar.startOfDay(for: definition.gregorianStartDate)
            guard let end = definition.gregorianEndDate(calendar: calendar) else { return false }
            return target >= start && target <= end
        }
    }

    public func dates(forHijriMonth hijriMonth: Int, day: Int, within interval: DateInterval) -> [Date] {
        definitions.compactMap { definition in
            guard definition.hijriMonth == hijriMonth else { return nil }
            guard let date = definition.gregorianDate(forHijriDay: day, calendar: calendar) else { return nil }
            return interval.contains(date) ? date : nil
        }.sorted()
    }

    public func occurrenceDates(for reminder: HijriReminder, within interval: DateInterval) -> [Date] {
        let baseDates: [Date]
        if reminder.recurrence == .oneTime, let year = reminder.hijriDate.year {
            baseDates = gregorianDate(for: reminder.hijriDate, fallbackYear: year).map { [$0] } ?? []
        } else {
            baseDates = dates(forHijriMonth: reminder.hijriDate.month, day: reminder.hijriDate.day, within: interval)
        }

        return baseDates.flatMap { baseDate in
            expandMultiDayOccurrences(baseDate: baseDate, time: reminder.time, durationDays: reminder.durationDays, interval: interval)
        }
    }

    private func expandMultiDayOccurrences(
        baseDate: Date,
        time: ReminderTime,
        durationDays: Int,
        interval: DateInterval
    ) -> [Date] {
        guard durationDays > 0 else { return [] }
        let startOfDay = calendar.startOfDay(for: baseDate)

        return (0..<durationDays).compactMap { offset in
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: startOfDay) else {
                return nil
            }
            guard let scheduled = calendar.date(
                bySettingHour: time.hour,
                minute: time.minute,
                second: 0,
                of: dayDate
            ) else {
                return nil
            }
            return interval.contains(scheduled) ? scheduled : nil
        }
    }
}
