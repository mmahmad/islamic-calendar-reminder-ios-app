import Foundation

public enum CalendarProviderError: Error {
    case invalidResponse
    case invalidData
    case parsingFailed
}

extension CalendarProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response."
        case .invalidData:
            return "Received invalid calendar data."
        case .parsingFailed:
            return "Could not parse calendar data."
        }
    }
}

public protocol CalendarProvider {
    var source: CalendarSource { get }
    func fetchMonthDefinitions() async throws -> [HijriMonthDefinition]
}
