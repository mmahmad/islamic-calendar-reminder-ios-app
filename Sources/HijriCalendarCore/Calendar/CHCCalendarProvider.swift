import Foundation

public struct CHCCalendarProvider: CalendarProvider {
    public let source: CalendarSource = .moonsighting
    public let siteURL: URL
    public let session: URLSession
    private let parser: CHCCalendarParser
    private let announcementParser: CHCAnnouncementParser

    public init(
        siteURL: URL = URL(string: "https://hilalcommittee.org/")!,
        session: URLSession = .shared
    ) {
        self.siteURL = siteURL
        self.session = session
        self.parser = CHCCalendarParser()
        self.announcementParser = CHCAnnouncementParser()
    }

    init(
        siteURL: URL,
        session: URLSession,
        parser: CHCCalendarParser,
        announcementParser: CHCAnnouncementParser = CHCAnnouncementParser()
    ) {
        self.siteURL = siteURL
        self.session = session
        self.parser = parser
        self.announcementParser = announcementParser
    }

    public func fetchMonthDefinitions() async throws -> [HijriMonthDefinition] {
        if let announcementDefinitions = try? await fetchAnnouncementDefinitions(),
           !announcementDefinitions.isEmpty {
            return announcementDefinitions
        }

        let (htmlData, htmlResponse) = try await session.data(from: siteURL)
        guard let http = htmlResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarProviderError.invalidResponse
        }

        guard let pdfURL = extractLatestPDFURL(from: htmlData, baseURL: siteURL) else {
            throw CalendarProviderError.parsingFailed
        }

        let (pdfData, pdfResponse) = try await session.data(from: pdfURL)
        guard let pdfHttp = pdfResponse as? HTTPURLResponse, (200..<300).contains(pdfHttp.statusCode) else {
            throw CalendarProviderError.invalidResponse
        }

        return try parser.parseMonthDefinitions(from: pdfData)
    }

    private func fetchAnnouncementDefinitions() async throws -> [HijriMonthDefinition] {
        let newsURL = siteURL.appendingPathComponent("news")
        let (newsData, newsResponse) = try await session.data(from: newsURL)
        guard let http = newsResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarProviderError.invalidResponse
        }

        let links = extractNewsLinks(from: newsData, baseURL: newsURL)
        guard !links.isEmpty else {
            throw CalendarProviderError.parsingFailed
        }

        var starts: [CHCAnnouncementParser.MonthStart] = []
        for link in links.prefix(12) {
            do {
                let (postData, postResponse) = try await session.data(from: link)
                guard let postHttp = postResponse as? HTTPURLResponse, (200..<300).contains(postHttp.statusCode) else {
                    continue
                }
                if let start = announcementParser.parseMonthStart(from: postData) {
                    starts.append(start)
                }
            } catch {
                continue
            }
        }

        let unique = Array(Set(starts))
        guard !unique.isEmpty else {
            throw CalendarProviderError.parsingFailed
        }

        return try announcementParser.buildDefinitions(from: unique)
    }

    func extractLatestPDFURL(from data: Data, baseURL: URL) -> URL? {
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"href=[\"']([^\"']+\.pdf)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        let links: [String] = matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else {
                return nil
            }
            return String(html[range])
        }

        guard !links.isEmpty else { return nil }

        let preferred = links.first { $0.localizedCaseInsensitiveContains("calendar") } ?? links[0]
        let resolved = resolveURLString(preferred, baseURL: baseURL)
        return resolved
    }

    private func extractNewsLinks(from data: Data, baseURL: URL) -> [URL] {
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"href=[\"']([^\"']+/news/[^\"']+)[\"']"#
        let relativePattern = #"href=[\"'](/news/[^\"']+)[\"']"#
        let links = extractLinks(matching: pattern, in: html) + extractLinks(matching: relativePattern, in: html)

        var urls: [URL] = []
        for link in links {
            guard let resolved = resolveURLString(link, baseURL: baseURL) else { continue }
            let path = resolved.path.lowercased()
            guard path.contains("/news/") else { continue }
            guard !path.contains("alert") else { continue }
            guard path != "/news" else { continue }
            urls.append(resolved)
        }

        var seen: Set<URL> = []
        return urls.filter { url in
            if seen.contains(url) { return false }
            seen.insert(url)
            return true
        }
    }

    private func extractLinks(matching pattern: String, in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else {
                return nil
            }
            return String(html[range])
        }
    }

    private func resolveURLString(_ string: String, baseURL: URL) -> URL? {
        if let absolute = URL(string: string), absolute.scheme != nil {
            return absolute
        }

        var trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("//") {
            trimmed = "https:" + trimmed
        }

        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }

        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
    }
}
