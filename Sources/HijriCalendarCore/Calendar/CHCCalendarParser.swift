import Foundation

struct CHCCalendarParser {
    private struct MonthStart: Hashable {
        let hijriYear: Int
        let hijriMonth: Int
        let gregorianStartDate: Date
    }

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }

    private let calendar: Calendar
    private let textExtractor: TextExtracting

    init(calendar: Calendar = Calendar(identifier: .gregorian), textExtractor: TextExtracting = PDFTextExtractor()) {
        var calendar = calendar
        // Treat parsed Gregorian dates as local calendar dates to avoid day shifts.
        calendar.timeZone = TimeZone.autoupdatingCurrent
        self.calendar = calendar
        self.textExtractor = textExtractor
    }

    func parseMonthDefinitions(from data: Data) throws -> [HijriMonthDefinition] {
        let text = textExtractor.extractText(from: data)
        let normalized = normalize(text)
        let starts = parseMonthStarts(from: normalized)
        let explicitLengths = parseExplicitLengths(from: normalized)

        guard !starts.isEmpty else {
            throw CalendarProviderError.parsingFailed
        }

        return try buildDefinitions(from: starts, explicitLengths: explicitLengths)
    }

    private func buildDefinitions(
        from starts: [MonthStart],
        explicitLengths: [MonthKey: Int]
    ) throws -> [HijriMonthDefinition] {
        let sorted = starts.sorted {
            if $0.hijriYear == $1.hijriYear {
                return $0.hijriMonth < $1.hijriMonth
            }
            return $0.hijriYear < $1.hijriYear
        }

        var definitions: [HijriMonthDefinition] = []
        definitions.reserveCapacity(sorted.count)

        for index in 0..<sorted.count {
            let current = sorted[index]
            let key = MonthKey(year: current.hijriYear, month: current.hijriMonth)

            let length: Int? = {
                if let explicit = explicitLengths[key] { return explicit }
                if index + 1 < sorted.count {
                    let next = sorted[index + 1]
                    let diff = calendar.dateComponents([.day],
                        from: calendar.startOfDay(for: current.gregorianStartDate),
                        to: calendar.startOfDay(for: next.gregorianStartDate)
                    ).day ?? 0
                    return diff
                }
                return nil
            }()

            guard let length, (29...30).contains(length) else {
                continue
            }

            definitions.append(
                HijriMonthDefinition(
                    hijriYear: current.hijriYear,
                    hijriMonth: current.hijriMonth,
                    gregorianStartDate: current.gregorianStartDate,
                    length: length,
                    source: .moonsighting
                )
            )
        }

        guard !definitions.isEmpty else {
            throw CalendarProviderError.parsingFailed
        }

        return definitions
    }

    private func parseMonthStarts(from text: String) -> [MonthStart] {
        let matches = parseMonthStartMatches(in: text)
        let unique = dedupe(matches)
        return unique
    }

    private func parseMonthStartMatches(in text: String) -> [MonthStart] {
        var starts: [MonthStart] = []

        let patterns = [
            #"([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4}).{0,80}?([A-Za-z'\-]+)\s+(\d{4})\s*AH"#,
            #"([A-Za-z'\-]+)\s+(\d{4})\s*AH.{0,80}?([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in matches {
                guard match.numberOfRanges == 6 else { continue }

                if pattern.hasPrefix("([A-Za-z]+)") {
                    guard let gregorianMonthRange = Range(match.range(at: 1), in: text),
                          let gregorianDayRange = Range(match.range(at: 2), in: text),
                          let gregorianYearRange = Range(match.range(at: 3), in: text),
                          let hijriMonthRange = Range(match.range(at: 4), in: text),
                          let hijriYearRange = Range(match.range(at: 5), in: text) else {
                        continue
                    }

                    let gregorianMonth = String(text[gregorianMonthRange])
                    let gregorianDay = String(text[gregorianDayRange])
                    let gregorianYear = String(text[gregorianYearRange])
                    let hijriMonthName = String(text[hijriMonthRange])
                    let hijriYear = String(text[hijriYearRange])

                    guard let start = makeStart(
                        hijriMonthName: hijriMonthName,
                        hijriYear: hijriYear,
                        gregorianMonthName: gregorianMonth,
                        gregorianDay: gregorianDay,
                        gregorianYear: gregorianYear
                    ) else {
                        continue
                    }
                    starts.append(start)
                } else {
                    guard let hijriMonthRange = Range(match.range(at: 1), in: text),
                          let hijriYearRange = Range(match.range(at: 2), in: text),
                          let gregorianMonthRange = Range(match.range(at: 3), in: text),
                          let gregorianDayRange = Range(match.range(at: 4), in: text),
                          let gregorianYearRange = Range(match.range(at: 5), in: text) else {
                        continue
                    }

                    let hijriMonthName = String(text[hijriMonthRange])
                    let hijriYear = String(text[hijriYearRange])
                    let gregorianMonth = String(text[gregorianMonthRange])
                    let gregorianDay = String(text[gregorianDayRange])
                    let gregorianYear = String(text[gregorianYearRange])

                    guard let start = makeStart(
                        hijriMonthName: hijriMonthName,
                        hijriYear: hijriYear,
                        gregorianMonthName: gregorianMonth,
                        gregorianDay: gregorianDay,
                        gregorianYear: gregorianYear
                    ) else {
                        continue
                    }
                    starts.append(start)
                }
            }
        }

        return starts
    }

    private func makeStart(
        hijriMonthName: String,
        hijriYear: String,
        gregorianMonthName: String,
        gregorianDay: String,
        gregorianYear: String
    ) -> MonthStart? {
        guard let hijriYearValue = Int(hijriYear),
              let hijriMonthValue = hijriMonthNumber(from: hijriMonthName),
              let gregorianDayValue = Int(gregorianDay),
              let gregorianYearValue = Int(gregorianYear) else {
            return nil
        }

        guard let gregorianDate = parseGregorianDate(
            monthName: gregorianMonthName,
            day: gregorianDayValue,
            year: gregorianYearValue
        ) else {
            return nil
        }

        return MonthStart(
            hijriYear: hijriYearValue,
            hijriMonth: hijriMonthValue,
            gregorianStartDate: gregorianDate
        )
    }

    private func parseExplicitLengths(from text: String) -> [MonthKey: Int] {
        let pattern = #"([A-Za-z'\-]+)\s+(\d{4})\s*AH.{0,40}?(29|30)\s+days"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [:]
        }

        var result: [MonthKey: Int] = [:]
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard match.numberOfRanges == 4 else { continue }
            guard let monthRange = Range(match.range(at: 1), in: text),
                  let yearRange = Range(match.range(at: 2), in: text),
                  let lengthRange = Range(match.range(at: 3), in: text) else {
                continue
            }

            let monthName = String(text[monthRange])
            let yearString = String(text[yearRange])
            let lengthString = String(text[lengthRange])

            guard let month = hijriMonthNumber(from: monthName),
                  let year = Int(yearString),
                  let length = Int(lengthString) else {
                continue
            }

            result[MonthKey(year: year, month: month)] = length
        }

        return result
    }

    private func dedupe(_ starts: [MonthStart]) -> [MonthStart] {
        struct Key: Hashable {
            let year: Int
            let month: Int
        }

        var map: [Key: MonthStart] = [:]
        for start in starts {
            let key = Key(year: start.hijriYear, month: start.hijriMonth)
            if let existing = map[key], existing.gregorianStartDate != start.gregorianStartDate {
                continue
            }
            map[key] = start
        }
        return Array(map.values)
    }

    private func parseGregorianDate(monthName: String, day: Int, year: Int) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.date(from: "\(monthName) \(day), \(year)")
    }

    private func hijriMonthNumber(from name: String) -> Int? {
        let key = normalizeMonthName(name)
        return hijriMonthMap[key]
    }

    private var hijriMonthMap: [String: Int] {
        [
            "muharram": 1,
            "safar": 2,
            "rabi-al-awwal": 3,
            "rabi-al-awal": 3,
            "rabi-al-thani": 4,
            "rabi-al-akhir": 4,
            "jumada-al-ula": 5,
            "jumada-al-awwal": 5,
            "jumada-al-ukhra": 6,
            "jumada-al-akhira": 6,
            "rajab": 7,
            "shaban": 8,
            "ramadan": 9,
            "shawwal": 10,
            "dhul-qidah": 11,
            "dhul-qadah": 11,
            "dhul-hijjah": 12,
            "dhul-hijja": 12,
        ]
    }

    private func normalize(_ text: String) -> String {
        var normalized = text
        normalized = normalized.replacingOccurrences(of: "\u{00A0}", with: " ")
        normalized = normalized.replacingOccurrences(of: "\u{2019}", with: "'")
        normalized = normalized.replacingOccurrences(of: "\u{2018}", with: "'")
        normalized = normalized.replacingOccurrences(of: "\u{02BC}", with: "'")
        normalized = normalized.replacingOccurrences(of: "\u{2010}", with: "-")
        normalized = normalized.replacingOccurrences(of: "\u{2013}", with: "-")
        normalized = normalized.replacingOccurrences(of: "\u{2014}", with: "-")
        return normalized
    }

    private func normalizeMonthName(_ name: String) -> String {
        var key = name.lowercased()
        key = key.replacingOccurrences(of: "\u{2019}", with: "")
        key = key.replacingOccurrences(of: "\u{2018}", with: "")
        key = key.replacingOccurrences(of: "\u{02BC}", with: "")
        key = key.replacingOccurrences(of: "'", with: "")
        key = key.replacingOccurrences(of: "\u{2010}", with: "-")
        key = key.replacingOccurrences(of: "\u{2013}", with: "-")
        key = key.replacingOccurrences(of: "\u{2014}", with: "-")
        key = key.replacingOccurrences(of: ".", with: "")
        return key
    }
}
