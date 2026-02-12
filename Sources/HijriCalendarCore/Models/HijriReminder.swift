import Foundation

public enum HijriRecurrence: String, Codable {
    case annual
    case oneTime
}

public struct ReminderTime: Hashable, Codable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}

public struct HijriReminder: Identifiable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var hijriDate: HijriDate
    public var recurrence: HijriRecurrence
    public var time: ReminderTime
    public var durationDays: Int
    public var notesText: String?
    public var attachments: [Attachment]

    public init(
        id: UUID = UUID(),
        title: String,
        hijriDate: HijriDate,
        recurrence: HijriRecurrence,
        time: ReminderTime,
        durationDays: Int = 1,
        notesText: String? = nil,
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.title = title
        self.hijriDate = hijriDate
        self.recurrence = recurrence
        self.time = time
        self.durationDays = max(durationDays, 1)
        self.notesText = notesText
        self.attachments = attachments
    }
}
