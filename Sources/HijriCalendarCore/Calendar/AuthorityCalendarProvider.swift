import Foundation

public struct AuthorityCalendarProvider {
    public struct AuthorityInfo: Codable {
        public let slug: String
        public let name: String
        public let updatedAt: Int?
    }

    public struct AuthorityMonthStart: Codable {
        public let hijriYear: Int
        public let hijriMonth: Int
        public let gregorianStartDate: String
        public let updatedAt: Int?
    }

    public struct AuthorityFeed: Codable {
        public let authority: AuthorityInfo
        public let months: [AuthorityMonthStart]
    }

    public struct MonthStartOverride {
        public let hijriYear: Int
        public let hijriMonth: Int
        public let gregorianStartDate: Date
    }

    public let feedURL: URL
    public let session: URLSession

    public init(feedURL: URL, session: URLSession = .shared) {
        self.feedURL = feedURL
        self.session = session
    }

    public func fetchFeed() async throws -> AuthorityFeed {
        let (data, response) = try await session.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarProviderError.invalidResponse
        }
        let decoder = JSONDecoder()
        return try decoder.decode(AuthorityFeed.self, from: data)
    }

    public func fetchAuthorityOverrides() async throws -> (AuthorityInfo, [MonthStartOverride]) {
        let feed = try await fetchFeed()
        return (feed.authority, monthStarts(from: feed))
    }

    public func fetchMonthStarts() async throws -> [MonthStartOverride] {
        let feed = try await fetchFeed()
        return monthStarts(from: feed)
    }

    private func monthStarts(from feed: AuthorityFeed) -> [MonthStartOverride] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"

        return feed.months.compactMap { month in
            guard let date = formatter.date(from: month.gregorianStartDate) else { return nil }
            return MonthStartOverride(
                hijriYear: month.hijriYear,
                hijriMonth: month.hijriMonth,
                gregorianStartDate: date
            )
        }
    }
}
