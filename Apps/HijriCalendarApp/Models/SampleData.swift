import Foundation
import HijriCalendarCore

enum SampleData {
    static let reminders: [HijriReminder] = [
        HijriReminder(
            title: "Zakat Due",
            hijriDate: HijriDate(month: 9, day: 1),
            recurrence: .annual,
            time: ReminderTime(hour: 0, minute: 0),
            durationDays: 1,
            notesText: "Calculate and pay zakat.",
            attachments: []
        ),
        HijriReminder(
            title: "Arafah Fasting",
            hijriDate: HijriDate(month: 12, day: 9),
            recurrence: .annual,
            time: ReminderTime(hour: 6, minute: 0),
            durationDays: 1,
            notesText: "Fast and make dua.",
            attachments: []
        ),
    ]
}
