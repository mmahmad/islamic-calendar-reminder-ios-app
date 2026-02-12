import Foundation
import Testing
@testable import HijriCalendarCore

@Test func chcProviderSelectsCalendarPdfLink() throws {
    let html = """
    <html>
      <body>
        <a href="/uploads/images/CHC%20Calendar%20Shaban%201447.pdf">Calendar</a>
        <a href="/uploads/images/Other.pdf">Other</a>
      </body>
    </html>
    """
    let provider = CHCCalendarProvider()
    let url = provider.extractLatestPDFURL(from: Data(html.utf8), baseURL: URL(string: "https://hilalcommittee.org/")!)

    #expect(url?.absoluteString == "https://hilalcommittee.org/uploads/images/CHC%20Calendar%20Shaban%201447.pdf")
}
