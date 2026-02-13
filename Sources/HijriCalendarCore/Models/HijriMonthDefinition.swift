import Foundation

public enum CalendarSource: String, Codable {
    case calculated
    case moonsighting
    case manual
    case authority
}

public struct HijriMonthDefinition: Hashable, Codable {
    public let hijriYear: Int
    public let hijriMonth: Int
    public let gregorianStartDate: Date
    public let length: Int
    public let source: CalendarSource

    public init(
        hijriYear: Int,
        hijriMonth: Int,
        gregorianStartDate: Date,
        length: Int,
        source: CalendarSource
    ) {
        self.hijriYear = hijriYear
        self.hijriMonth = hijriMonth
        self.gregorianStartDate = gregorianStartDate
        self.length = length
        self.source = source
    }

    public func contains(hijriDay: Int) -> Bool {
        (1...length).contains(hijriDay)
    }

    public func gregorianDate(forHijriDay hijriDay: Int, calendar: Calendar) -> Date? {
        guard contains(hijriDay: hijriDay) else { return nil }
        guard let date = calendar.date(byAdding: .day, value: hijriDay - 1, to: gregorianStartDate) else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }

    public func gregorianEndDate(calendar: Calendar) -> Date? {
        guard length > 0 else { return nil }
        guard let date = calendar.date(byAdding: .day, value: length - 1, to: gregorianStartDate) else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }
}
