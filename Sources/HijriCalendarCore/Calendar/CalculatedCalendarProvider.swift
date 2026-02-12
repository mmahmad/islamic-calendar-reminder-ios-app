import Foundation

public struct CalculatedCalendarProvider: CalendarProvider {
    public let source: CalendarSource = .calculated
    public let url: URL
    public let session: URLSession
    private let parser: CalculatedCalendarParser

    public init(
        url: URL = URL(string: "https://fiqhcouncil.org/calendar/")!,
        session: URLSession = .shared
    ) {
        self.url = url
        self.session = session
        self.parser = CalculatedCalendarParser()
    }

    init(
        url: URL,
        session: URLSession,
        parser: CalculatedCalendarParser
    ) {
        self.url = url
        self.session = session
        self.parser = parser
    }

    public func fetchMonthDefinitions() async throws -> [HijriMonthDefinition] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalendarProviderError.invalidResponse
        }
        do {
            return try parser.parseMonthDefinitions(from: data)
        } catch {
            guard let providerError = error as? CalendarProviderError,
                  providerError == .parsingFailed,
                  let pdfURL = extractPDFURL(from: data, baseURL: url) else {
                throw error
            }

            let (pdfData, pdfResponse) = try await session.data(from: pdfURL)
            guard let pdfHttp = pdfResponse as? HTTPURLResponse, (200..<300).contains(pdfHttp.statusCode) else {
                throw CalendarProviderError.invalidResponse
            }

            let pdfParser = CalculatedCalendarParser(textExtractor: PDFTextExtractor())
            return try pdfParser.parseMonthDefinitions(from: pdfData)
        }
    }

    func parseMonthDefinitions(from data: Data) throws -> [HijriMonthDefinition] {
        try parser.parseMonthDefinitions(from: data)
    }

    private func extractPDFURL(from data: Data, baseURL: URL) -> URL? {
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
        return resolveURLString(preferred, baseURL: baseURL)
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
