import Foundation

struct CHCAnnouncementParser {
    struct MonthStart: Hashable {
        let hijriYear: Int
        let hijriMonth: Int
        let gregorianStartDate: Date
    }

    private let calendar: Calendar
    private let textExtractor: TextExtracting

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        textExtractor: TextExtracting = HTMLTextExtractor()
    ) {
        var calendar = calendar
        // Treat parsed Gregorian dates as local calendar dates to avoid day shifts.
        calendar.timeZone = TimeZone.autoupdatingCurrent
        self.calendar = calendar
        self.textExtractor = textExtractor
    }

    func parseMonthStart(from data: Data) -> MonthStart? {
        let text = textExtractor.extractText(from: data)
        let normalized = normalize(text)
        return extractMonthStart(from: normalized)
    }

    func buildDefinitions(from starts: [MonthStart]) throws -> [HijriMonthDefinition] {
        let sorted = starts.sorted {
            if $0.hijriYear == $1.hijriYear {
                return $0.hijriMonth < $1.hijriMonth
            }
            return $0.hijriYear < $1.hijriYear
        }

        guard !sorted.isEmpty else {
            throw CalendarProviderError.parsingFailed
        }

        var definitions: [HijriMonthDefinition] = []
        definitions.reserveCapacity(sorted.count)

        for index in 0..<sorted.count {
            let current = sorted[index]
            let length: Int = {
                if index + 1 < sorted.count {
                    let next = sorted[index + 1]
                    let diff = calendar.dateComponents([.day],
                        from: calendar.startOfDay(for: current.gregorianStartDate),
                        to: calendar.startOfDay(for: next.gregorianStartDate)
                    ).day ?? 0
                    if (29...30).contains(diff) { return diff }
                }
                return 0
            }()

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

        return definitions
    }

    private func extractMonthStart(from text: String) -> MonthStart? {
        let dayPattern = #"1st\s+day\s+of\s+([A-Za-z'’\- ]+?)\s+(\d{4})\s*AH"#
        guard let dayRegex = try? NSRegularExpression(pattern: dayPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = dayRegex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return nil }

        for match in matches {
            guard match.numberOfRanges == 3,
                  let monthRange = Range(match.range(at: 1), in: text),
                  let yearRange = Range(match.range(at: 2), in: text) else {
                continue
            }

            let hijriMonthName = String(text[monthRange])
            let hijriYearString = String(text[yearRange])
            guard let hijriYear = Int(hijriYearString),
                  let hijriMonth = hijriMonthNumber(from: hijriMonthName) else {
                continue
            }

            if let gregorian = extractGregorianDate(near: match.range, in: text) {
                guard let gregorianDate = parseGregorianDate(
                    monthName: gregorian.monthName,
                    day: gregorian.day,
                    year: gregorian.year
                ) else {
                    continue
                }

                return MonthStart(
                    hijriYear: hijriYear,
                    hijriMonth: hijriMonth,
                    gregorianStartDate: gregorianDate
                )
            }
        }

        return nil
    }

    private func extractGregorianDate(
        near range: NSRange,
        in text: String
    ) -> (monthName: String, day: Int, year: Int)? {
        let window = 180
        let start = max(range.location - window, 0)
        let end = min(range.location + range.length + window, text.utf16.count)
        let windowRange = NSRange(location: start, length: end - start)

        let pattern = #"([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let matches = regex.matches(in: text, range: windowRange)
        guard let match = matches.last,
              match.numberOfRanges == 4,
              let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let yearRange = Range(match.range(at: 3), in: text) else {
            return nil
        }

        let monthName = String(text[monthRange])
        let dayString = String(text[dayRange])
        let yearString = String(text[yearRange])
        guard let day = Int(dayString),
              let year = Int(yearString) else {
            return nil
        }

        return (monthName, day, year)
    }

    private func parseGregorianDate(monthName: String, day: Int, year: Int) -> Date? {
        let normalizedMonth = monthName.trimmingCharacters(in: .punctuationCharacters)
        let dateString = "\(normalizedMonth) \(day), \(year)"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone

        formatter.dateFormat = "MMMM d, yyyy"
        if let date = formatter.date(from: dateString) { return date }

        formatter.dateFormat = "MMM d, yyyy"
        if let date = formatter.date(from: dateString) { return date }

        return nil
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
            "jumada-al-akhirah": 6,
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
        return tokens.joined(separator: "-")
    }
}
