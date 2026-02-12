import SwiftUI
import HijriCalendarCore

struct ReminderDetailView: View {
    @Binding var reminder: HijriReminder
    @State private var isEditing = false

    var body: some View {
        Form {
            Section("Hijri Date") {
                Text(HijriDateDisplay.formatted(reminder.hijriDate))
                Text(recurrenceLabel)
                    .foregroundStyle(.secondary)
            }

            Section("Time") {
                Text(timeLabel)
            }

            Section("Duration") {
                Text("\(reminder.durationDays) day(s)")
            }

            if let notes = reminder.notesText, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            if !photoAttachments.isEmpty {
                Section("Photos") {
                    NavigationLink {
                        PhotoGalleryView(reminder: $reminder)
                    } label: {
                        HStack {
                            Text("View Photos")
                            Spacer()
                            Text("\(photoAttachments.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !otherAttachments.isEmpty {
                Section("Attachments") {
                    ForEach(otherAttachments) { attachment in
                        HStack(spacing: 12) {
                            Image(systemName: attachmentIconName(attachment))
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachmentLabel(attachment))
                                Text(attachment.type.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(reminder.title)
        .toolbar {
            Button("Edit") {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            ReminderEditorView(reminder: reminder) { updated in
                reminder = updated
            }
        }
    }

    private var photoAttachments: [Attachment] {
        reminder.attachments.filter { $0.type == .photo }
    }

    private var otherAttachments: [Attachment] {
        reminder.attachments.filter { $0.type != .photo }
    }

    private var recurrenceLabel: String {
        switch reminder.recurrence {
        case .annual:
            return "Annual"
        case .oneTime:
            if let year = reminder.hijriDate.year {
                return "One-time (\(year))"
            }
            return "One-time"
        }
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let calendar = Calendar.current
        let now = Date()
        let date = calendar.date(bySettingHour: reminder.time.hour, minute: reminder.time.minute, second: 0, of: now) ?? now
        return formatter.string(from: date)
    }

    private func attachmentLabel(_ attachment: Attachment) -> String {
        if let displayName = attachment.displayName, !displayName.isEmpty {
            return displayName
        }
        if let path = attachment.path {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        if let url = attachment.url {
            return url
        }
        return "Attachment"
    }

    private func attachmentIconName(_ attachment: Attachment) -> String {
        switch attachment.type {
        case .photo:
            return "photo"
        case .file:
            return "doc"
        case .link:
            return "link"
        }
    }
}

#Preview {
    NavigationStack {
        ReminderDetailView(
            reminder: .constant(
                HijriReminder(
                    title: "Zakat Due",
                    hijriDate: HijriDate(month: 9, day: 1),
                    recurrence: .annual,
                    time: ReminderTime(hour: 0, minute: 0),
                    durationDays: 1,
                    notesText: "Calculate and pay zakat.",
                    attachments: []
                )
            )
        )
    }
}
