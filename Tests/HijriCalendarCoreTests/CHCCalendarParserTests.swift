import Foundation
import Testing
@testable import HijriCalendarCore

@Test func chcParserBuildsDefinitionsFromText() throws {
    let sampleText = """
    Tuesday, January 20, 2026, the 1st day of Sha'ban 1447 AH.
    Wednesday, February 18, 2026, the 1st day of Ramadan 1447 AH.
    """

    let parser = CHCCalendarParser(textExtractor: StubTextExtractor(text: sampleText))
    let definitions = try parser.parseMonthDefinitions(from: Data())

    #expect(definitions.count == 1)
    let first = try #require(definitions.first)
    #expect(first.hijriYear == 1447)
    #expect(first.hijriMonth == 8)
    #expect(first.length == 29)
}

private struct StubTextExtractor: TextExtracting {
    let text: String

    func extractText(from data: Data) -> String {
        text
    }
}
