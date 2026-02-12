import SwiftUI
import HijriCalendarCore

struct ReminderListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isPresentingAdd = false
    @State private var editingReminder: HijriReminder?

    var body: some View {
        List {
            ForEach($appState.reminders) { $reminder in
                NavigationLink {
                    ReminderDetailView(reminder: $reminder)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title)
                            .font(.headline)
                        Text(HijriDateDisplay.formatted(reminder.hijriDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        editingReminder = reminder
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            deleteReminder(id: reminder.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .toolbar {
            Button {
                isPresentingAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $isPresentingAdd) {
            ReminderEditorView { newReminder in
                appState.reminders.append(newReminder)
            }
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderEditorView(reminder: reminder) { updated in
                updateReminder(updated)
            }
        }
    }

    private func deleteReminder(id: UUID) {
        appState.reminders.removeAll { $0.id == id }
    }

    private func updateReminder(_ updated: HijriReminder) {
        if let index = appState.reminders.firstIndex(where: { $0.id == updated.id }) {
            appState.reminders[index] = updated
        } else {
            appState.reminders.append(updated)
        }
    }
}

#Preview {
    NavigationStack {
        ReminderListView()
            .environmentObject(AppState())
    }
}
