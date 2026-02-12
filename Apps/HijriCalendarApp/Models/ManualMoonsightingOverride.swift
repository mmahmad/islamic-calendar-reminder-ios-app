import Foundation

struct ManualMoonsightingOverride: Identifiable, Codable, Hashable {
    let id: UUID
    let hijriYear: Int
    let hijriMonth: Int
    let gregorianStartDate: Date
    let createdAt: Date

    init(
        id: UUID = UUID(),
        hijriYear: Int,
        hijriMonth: Int,
        gregorianStartDate: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hijriYear = hijriYear
        self.hijriMonth = hijriMonth
        self.gregorianStartDate = gregorianStartDate
        self.createdAt = createdAt
    }
}

enum ManualMoonsightingStore {
    private static let filename = "ManualMoonsightingOverrides.json"

    static func load() -> [ManualMoonsightingOverride] {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ManualMoonsightingOverride].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ overrides: [ManualMoonsightingOverride]) {
        let url = fileURL()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(overrides)
            try data.write(to: url, options: [.atomic])
        } catch {
            return
        }
    }

    private static func fileURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(filename)
    }
}
