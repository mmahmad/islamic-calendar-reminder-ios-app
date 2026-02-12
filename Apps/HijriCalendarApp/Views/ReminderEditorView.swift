import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import HijriCalendarCore

struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var hijriMonth: Int
    @State private var hijriDay: Int
    @State private var recurrence: HijriRecurrence
    @State private var hijriYearText: String
    @State private var time: Date
    @State private var durationDays: Int
    @State private var notesText: String
    @State private var attachments: [Attachment]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingFileImporter = false
    @State private var isShowingLinkEditor = false

    private let existingID: UUID?
    private let onSave: (HijriReminder) -> Void

    init(reminder: HijriReminder? = nil, onSave: @escaping (HijriReminder) -> Void) {
        self.existingID = reminder?.id
        self.onSave = onSave

        let calendar = Calendar.current
        let now = Date()
        let defaultTime = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now) ?? now
        let reminderTime = reminder.map { reminder in
            calendar.date(bySettingHour: reminder.time.hour, minute: reminder.time.minute, second: 0, of: now) ?? defaultTime
        } ?? defaultTime

        _title = State(initialValue: reminder?.title ?? "")
        _hijriMonth = State(initialValue: reminder?.hijriDate.month ?? 1)
        _hijriDay = State(initialValue: reminder?.hijriDate.day ?? 1)
        _recurrence = State(initialValue: reminder?.recurrence ?? .annual)
        _hijriYearText = State(initialValue: reminder?.hijriDate.year.map(String.init) ?? "")
        _time = State(initialValue: reminderTime)
        _durationDays = State(initialValue: reminder?.durationDays ?? 1)
        _notesText = State(initialValue: reminder?.notesText ?? "")
        _attachments = State(initialValue: reminder?.attachments ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Reminder title", text: $title)
                }

                Section("Hijri Date") {
                    Picker("Month", selection: $hijriMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(HijriDateDisplay.monthName(for: month)).tag(month)
                        }
                    }

                    Picker("Day", selection: $hijriDay) {
                        ForEach(1...29, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                        Text("30th (if applicable)").tag(30)
                    }

                    Text("The 30th is only used if the month is 30 days.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker("Recurrence", selection: $recurrence) {
                        Text("Annual").tag(HijriRecurrence.annual)
                        Text("One-time").tag(HijriRecurrence.oneTime)
                    }
                    .pickerStyle(.segmented)

                    if recurrence == .oneTime {
                        TextField("Hijri year", text: $hijriYearText)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Time") {
                    DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section("Duration") {
                    Stepper(value: $durationDays, in: 1...30) {
                        Text("\(durationDays) day(s)")
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notesText)
                        .frame(minHeight: 120)
                }

                Section("Attachments") {
                    if attachments.isEmpty {
                        Text("No attachments")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { attachment in
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
                            .swipeActions {
                                Button(role: .destructive) {
                                    removeAttachment(attachment)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 20, matching: .images) {
                        Label("Add Photo", systemImage: "photo")
                    }

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label("Add File", systemImage: "paperclip")
                    }

                    Button {
                        isShowingLinkEditor = true
                    } label: {
                        Label("Add Link", systemImage: "link")
                    }
                }
            }
            .navigationTitle(existingID == nil ? "New Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReminder()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .sheet(isPresented: $isShowingLinkEditor) {
            LinkAttachmentEditorView { attachment in
                attachments.append(attachment)
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case let .success(urls) = result {
                for url in urls {
                    if let attachment = AttachmentStorage.importFile(from: url) {
                        attachments.append(attachment)
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItems) { items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let attachment = AttachmentStorage.savePhotoData(data) {
                        await MainActor.run {
                            attachments.append(attachment)
                        }
                    }
                }
                await MainActor.run {
                    selectedPhotoItems = []
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if recurrence == .oneTime {
            return Int(hijriYearText) == nil
        }
        return false
    }

    private func saveReminder() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let reminderTime = ReminderTime(hour: components.hour ?? 0, minute: components.minute ?? 0)

        let yearValue: Int? = recurrence == .oneTime ? Int(hijriYearText) : nil
        let hijriDate = HijriDate(year: yearValue, month: hijriMonth, day: hijriDay)

        let reminder = HijriReminder(
            id: existingID ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            hijriDate: hijriDate,
            recurrence: recurrence,
            time: reminderTime,
            durationDays: durationDays,
            notesText: notesText.isEmpty ? nil : notesText,
            attachments: attachments
        )

        onSave(reminder)
        dismiss()
    }

    private func removeAttachment(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
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
    ReminderEditorView { _ in }
}
