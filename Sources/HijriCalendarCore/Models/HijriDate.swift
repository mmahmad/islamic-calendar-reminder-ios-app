import Foundation

public struct HijriDate: Hashable, Codable {
    public let year: Int?
    public let month: Int
    public let day: Int

    public init(year: Int? = nil, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}
