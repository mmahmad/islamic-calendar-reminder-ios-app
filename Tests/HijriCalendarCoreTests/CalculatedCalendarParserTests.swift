import Foundation
import Testing
@testable import HijriCalendarCore

@Test func calculatedCalendarParserBuildsMonthDefinitions() throws {
    let data = try loadFixture(named: "fiqhcouncil-sample", ext: "html")
    let parser = CalculatedCalendarParser()

    let definitions = try parser.parseMonthDefinitions(from: data)

    #expect(definitions.count == 5)

    let first = try #require(definitions.first)
    #expect(first.hijriYear == 1447)
    #expect(first.hijriMonth == 1)
    #expect(first.length == 30)

    let second = definitions[1]
    #expect(second.hijriMonth == 2)
    #expect(second.length == 29)
}

private func loadFixture(named name: String, ext: String) throws -> Data {
    let bundle = Bundle.module
    guard let url = bundle.url(forResource: name, withExtension: ext) else {
        throw NSError(domain: "Fixture", code: 1)
    }
    return try Data(contentsOf: url)
}
