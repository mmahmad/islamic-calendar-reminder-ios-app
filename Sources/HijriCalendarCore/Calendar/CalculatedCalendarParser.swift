import Foundation

struct CalculatedCalendarParser {
    private struct MonthStart: Hashable {
        let hijriYear: Int
        let hijriMonth: Int
        let gregorianStartDate: Date
    }

    private let calendar: Calendar
    private let textExtractor: TextExtracting

    init(calendar: Calendar = Calendar(identifier: .gregorian), textExtractor: TextExtracting = HTMLTextExtractor()) {
        var calendar = calendar
        // Treat parsed Gregorian dates as local calendar dates to avoid day shifts.
        calendar.timeZone = TimeZone.autoupdatingCurrent
        self.calendar = calendar
        self.textExtractor = textExtractor
    }

    func parseMonthDefinitions(from data: Data) throws -> [HijriMonthDefinition] {
        let text = textExtractor.extractText(from: data)
        let starts = try parseMonthStarts(from: text)
        return try buildDefinitions(from: starts)
    }

    private func parseMonthStarts(from text: String) throws -> [MonthStart] {
        let normalizedText = normalize(text)
        var starts: [MonthStart] = []
        starts.append(contentsOf: parseMonthStartsFromLines(normalizedText))
        starts.append(contentsOf: parseMonthStartsFromRegex(normalizedText))

        let unique = dedupe(starts)
        guard unique.count >= 2 else {
            throw CalendarProviderError.parsingFailed
        }

        return unique
    }

    private func parseMonthStartsFromLines(_ text: String) -> [MonthStart] {
        var starts: [MonthStart] = []
        let lines = text.split(whereSeparator: \.isNewline)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let start = extractMonthStart(from: trimmed) {
                starts.append(start)
            }
        }
        return starts
    }

    private func parseMonthStartsFromRegex(_ text: String) -> [MonthStart] {
        let pattern = #"([A-Za-z'\-]+(?:[-\s][A-Za-z'\-]+)*)\s+1(?:st)?\s+(\d{4})(?:\s*AH)?\s*=\s*([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        var starts: [MonthStart] = []
        starts.reserveCapacity(matches.count)

        for match in matches {
            guard match.numberOfRanges == 6 else { continue }
            guard let monthRange = Range(match.range(at: 1), in: text),
                  let hijriYearRange = Range(match.range(at: 2), in: text),
                  let gregorianMonthRange = Range(match.range(at: 3), in: text),
                  let gregorianDayRange = Range(match.range(at: 4), in: text),
                  let gregorianYearRange = Range(match.range(at: 5), in: text) else {
                continue
            }

            let monthName = String(text[monthRange])
            let hijriYearString = String(text[hijriYearRange])
            let gregorianMonthName = String(text[gregorianMonthRange])
            let gregorianDayString = String(text[gregorianDayRange])
            let gregorianYearString = String(text[gregorianYearRange])

            guard let hijriYear = Int(hijriYearString),
                  let hijriMonth = hijriMonthNumber(from: monthName),
                  let gregorianDay = Int(gregorianDayString),
                  let gregorianYear = Int(gregorianYearString) else {
                continue
            }

            guard let gregorianDate = parseGregorianDate(
                monthName: gregorianMonthName,
                day: gregorianDay,
                year: gregorianYear
            ) else {
                continue
            }

            starts.append(MonthStart(
                hijriYear: hijriYear,
                hijriMonth: hijriMonth,
                gregorianStartDate: gregorianDate
            ))
        }

        return starts
    }

    private func extractMonthStart(from line: String) -> MonthStart? {
        guard let hijriMatch = extractHijriMonth(from: line) else { return nil }
        guard let hijriMonth = hijriMonthNumber(from: hijriMatch.monthName) else { return nil }

        let gregorianSection: String
        if let equalsRange = line.range(of: "=") {
            gregorianSection = String(line[equalsRange.upperBound...])
        } else {
            gregorianSection = line
        }

        guard let gregorianMatch = extractGregorianDate(from: gregorianSection) else { return nil }
        guard let gregorianDate = parseGregorianDate(
            monthName: gregorianMatch.monthName,
            day: gregorianMatch.day,
            year: gregorianMatch.year
        ) else { return nil }

        return MonthStart(
            hijriYear: hijriMatch.year,
            hijriMonth: hijriMonth,
            gregorianStartDate: gregorianDate
        )
    }

    private func extractHijriMonth(from line: String) -> (monthName: String, year: Int)? {
        let patterns = [
            #"([A-Za-z'\-]+(?:[-\s][A-Za-z'\-]+)*)\s+1(?:st)?\s+(\d{4})(?:\s*AH)?"#,
            #"1(?:st)?\s+([A-Za-z'\-]+(?:[-\s][A-Za-z'\-]+)*)\s+(\d{4})(?:\s*AH)?"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges == 3 else {
                continue
            }
            guard let monthRange = Range(match.range(at: 1), in: line),
                  let yearRange = Range(match.range(at: 2), in: line) else {
                continue
            }
            let monthName = String(line[monthRange])
            let yearString = String(line[yearRange])
            if let year = Int(yearString) {
                return (monthName, year)
            }
        }
        return nil
    }

    private func extractGregorianDate(from line: String) -> (monthName: String, day: Int, year: Int)? {
        let patterns = [
            #"([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?(?:,\s*|\s+)(\d{4})"#,
            #"(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges == 4 else {
                continue
            }

            if pattern.hasPrefix("([A-Za-z]+)") {
                guard let monthRange = Range(match.range(at: 1), in: line),
                      let dayRange = Range(match.range(at: 2), in: line),
                      let yearRange = Range(match.range(at: 3), in: line) else {
                    continue
                }
                let monthName = String(line[monthRange])
                let dayString = String(line[dayRange])
                let yearString = String(line[yearRange])
                if let day = Int(dayString), let year = Int(yearString) {
                    return (monthName, day, year)
                }
            } else {
                guard let dayRange = Range(match.range(at: 1), in: line),
                      let monthRange = Range(match.range(at: 2), in: line),
                      let yearRange = Range(match.range(at: 3), in: line) else {
                    continue
                }
                let dayString = String(line[dayRange])
                let monthName = String(line[monthRange])
                let yearString = String(line[yearRange])
                if let day = Int(dayString), let year = Int(yearString) {
                    return (monthName, day, year)
                }
            }
        }

        return nil
    }

    private func buildDefinitions(from starts: [MonthStart]) throws -> [HijriMonthDefinition] {
        let sorted = starts.sorted {
            if $0.hijriYear == $1.hijriYear {
                return $0.hijriMonth < $1.hijriMonth
            }
            return $0.hijriYear < $1.hijriYear
        }

        var definitions: [HijriMonthDefinition] = []
        definitions.reserveCapacity(max(sorted.count - 1, 0))

        for index in 0..<(sorted.count - 1) {
            let current = sorted[index]
            let next = sorted[index + 1]
            let length = calendar.dateComponents([
                .day,
            ], from: calendar.startOfDay(for: current.gregorianStartDate), to: calendar.startOfDay(for: next.gregorianStartDate)).day ?? 0

            guard (29...30).contains(length) else {
                continue
            }

            definitions.append(
                HijriMonthDefinition(
                    hijriYear: current.hijriYear,
                    hijriMonth: current.hijriMonth,
                    gregorianStartDate: current.gregorianStartDate,
                    length: length,
                    source: .calculated
                )
            )
        }

        guard !definitions.isEmpty else {
            throw CalendarProviderError.parsingFailed
        }

        return definitions
    }

    private func dedupe(_ starts: [MonthStart]) -> [MonthStart] {
        struct Key: Hashable {
            let year: Int
            let month: Int
        }

        var map: [Key: MonthStart] = [:]
        for start in starts {
            let key = Key(year: start.hijriYear, month: start.hijriMonth)
            if let existing = map[key] {
                if existing.gregorianStartDate != start.gregorianStartDate {
                    continue
                }
                continue
            }
            map[key] = start
        }

        return Array(map.values)
    }

    private func parseGregorianDate(monthName: String, day: Int, year: Int) -> Date? {
        let normalizedMonth = monthName.trimmingCharacters(in: .punctuationCharacters)
        let dateString = "\(normalizedMonth) \(day), \(year)"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone

        formatter.dateFormat = "MMMM d, yyyy"
        if let date = formatter.date(from: dateString) {
            return date
        }

        formatter.dateFormat = "MMM d, yyyy"
        if let date = formatter.date(from: dateString) {
            return date
        }

        formatter.dateFormat = "MMMM d yyyy"
        if let date = formatter.date(from: dateString.replacingOccurrences(of: ",", with: "")) {
            return date
        }

        formatter.dateFormat = "MMM d yyyy"
        return formatter.date(from: dateString.replacingOccurrences(of: ",", with: ""))
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
            "rabi-al-ula": 3,
            "rabi-al-thani": 4,
            "rabi-al-akhir": 4,
            "rabi-al-ukhra": 4,
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
            "dhu-al-qidah": 11,
            "dhu-al-qadah": 11,
            "zul-qidah": 11,
            "zul-qadah": 11,
            "dhul-hijjah": 12,
            "dhul-hijja": 12,
            "dhu-al-hijjah": 12,
            "dhu-al-hijja": 12,
            "zul-hijjah": 12,
            "zul-hijja": 12,
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
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        return normalized
    }

    private func normalizeMonthName(_ name: String) -> String {
        var key = name
        key = key.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        key = key.lowercased()
        key = key.replacingOccurrences(of: "\u{2019}", with: "")
        key = key.replacingOccurrences(of: "\u{2018}", with: "")
        key = key.replacingOccurrences(of: "\u{02BC}", with: "")
        key = key.replacingOccurrences(of: "'", with: "")
        key = key.replacingOccurrences(of: "\u{2010}", with: "-")
        key = key.replacingOccurrences(of: "\u{2013}", with: "-")
        key = key.replacingOccurrences(of: "\u{2014}", with: "-")
        key = key.replacingOccurrences(of: ".", with: "")
        key = key.replacingOccurrences(of: "_", with: " ")
        key = key.replacingOccurrences(of: "-", with: " ")
        key = key.replacingOccurrences(of: "  ", with: " ")
        let tokens = key.split(whereSeparator: { !$0.isLetter })
        let normalized = tokens.joined(separator: "-")
        return normalized
    }
}
