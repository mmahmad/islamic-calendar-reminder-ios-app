import Foundation
import HijriCalendarCore

protocol ReminderStoring {
    func load() -> [HijriReminder]
    func save(_ reminders: [HijriReminder])
}

struct JSONReminderStore: ReminderStoring {
    private let fileManager: FileManager
    private let filename: String

    init(fileManager: FileManager = .default, filename: String = "Reminders.json") {
        self.fileManager = fileManager
        self.filename = filename
    }

    func load() -> [HijriReminder] {
        let url = fileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([HijriReminder].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ reminders: [HijriReminder]) {
        let url = fileURL()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(reminders)
            try data.write(to: url, options: [.atomic])
        } catch {
            return
        }
    }

    private func fileURL() -> URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(filename)
    }
}
