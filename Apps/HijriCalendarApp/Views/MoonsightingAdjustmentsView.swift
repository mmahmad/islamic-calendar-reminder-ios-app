import SwiftUI
import HijriCalendarCore

struct MoonsightingAdjustmentsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hijriYear: Int = 0
    @State private var hijriMonth: Int = 1
    @State private var gregorianStartDate: Date = Date()
    @State private var showConfirmation = false
    @State private var pendingOverride: PendingOverride?
    @State private var hasInitialized = false

    var body: some View {
        Form {
            Section("Add override") {
                if availableYears.isEmpty {
                    Text("Calendar data is unavailable. Refresh in Settings first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Hijri year", selection: $hijriYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    Picker("Hijri month", selection: $hijriMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(HijriDateDisplay.monthName(for: month)).tag(month)
                        }
                    }
                    DatePicker("Gregorian start date", selection: $gregorianStartDate, displayedComponents: .date)

                    if let calculated = calculatedStartDate {
                        Text("Calculated start: \(dateFormatter.string(from: calculated))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let diff = dateDifferenceDays {
                        let label = diff == 0 ? "Same as calculated date" : "\(diff) day(s) from calculated date"
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(abs(diff) > 1 ? .red : .secondary)
                    }

                    Button("Save override") {
                        attemptSave()
                    }
                    .disabled(calculatedStartDate == nil)

                    if !appState.manualMoonsightingEnabled {
                        Text("Saving an override will enable manual moonsighting updates.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("History") {
                if historyOverrides.isEmpty {
                    Text("No overrides yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(historyOverrides) { entry in
                        historyRow(for: entry)
                            .swipeActions {
                                Button(role: .destructive) {
                                    appState.deleteManualOverride(id: entry.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Moonsighting")
        .onAppear {
            initializeSelectionIfNeeded()
        }
        .onChange(of: appState.calculatedDefinitions) { _ in
            initializeSelectionIfNeeded()
        }
        .onChange(of: hijriYear) { _ in
            syncDefaultDate()
        }
        .onChange(of: hijriMonth) { _ in
            syncDefaultDate()
        }
        .alert("Confirm override", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingOverride = nil
            }
            Button("Save anyway") {
                if let pendingOverride {
                    saveOverride(pendingOverride)
                }
            }
        } message: {
            if let pendingOverride {
                Text("This date is \(pendingOverride.diff) day(s) from the calculated calendar. Do you want to save it anyway?")
            } else {
                Text("This date differs from the calculated calendar. Do you want to save it anyway?")
            }
        }
    }

    private var availableYears: [Int] {
        let years = Set(appState.calculatedDefinitions.map(\.hijriYear))
        if !years.isEmpty {
            return years.sorted()
        }
        if let current = appState.calendarEngine?.hijriDate(for: Date())?.year {
            return [current]
        }
        return []
    }

    private var calculatedStartDate: Date? {
        appState.calculatedDefinitions.first { definition in
            definition.hijriYear == hijriYear && definition.hijriMonth == hijriMonth
        }?.gregorianStartDate
    }

    private var dateDifferenceDays: Int? {
        guard let calculated = calculatedStartDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calculated)
        let target = calendar.startOfDay(for: gregorianStartDate)
        return calendar.dateComponents([.day], from: start, to: target).day
    }

    private var historyOverrides: [ManualMoonsightingOverride] {
        appState.manualOverrides.sorted { $0.createdAt > $1.createdAt }
    }

    private func historyRow(for entry: ManualMoonsightingOverride) -> some View {
        let isActive = appState.isManualOverrideActive(entry)
        let infersPreviousMonth = appState.isManualOverrideInferringPreviousMonth(entry)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(HijriDateDisplay.monthName(for: entry.hijriMonth)) \(entry.hijriYear)")
                    .font(.headline)
                Text("Starts \(dateFormatter.string(from: entry.gregorianStartDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Added \(dateFormatter.string(from: entry.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(isActive ? "Active" : "History")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())

                if infersPreviousMonth {
                    Text("Prev month inferred")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func attemptSave() {
        guard let diff = dateDifferenceDays else { return }
        let pending = PendingOverride(
            year: hijriYear,
            month: hijriMonth,
            date: gregorianStartDate,
            diff: diff
        )
        if abs(diff) > 1 {
            pendingOverride = pending
            showConfirmation = true
        } else {
            saveOverride(pending)
        }
    }

    private func saveOverride(_ pending: PendingOverride) {
        appState.addManualOverride(
            year: pending.year,
            month: pending.month,
            gregorianStartDate: pending.date
        )
        pendingOverride = nil
    }

    private func initializeSelectionIfNeeded() {
        guard !hasInitialized else { return }
        guard !availableYears.isEmpty else { return }
        if let current = appState.calendarEngine?.monthDefinition(containing: Date()) {
            hijriYear = current.hijriYear
            hijriMonth = current.hijriMonth
        } else if let year = availableYears.first {
            hijriYear = year
            hijriMonth = 1
        }
        syncDefaultDate()
        hasInitialized = true
    }

    private func syncDefaultDate() {
        if let calculatedStartDate {
            gregorianStartDate = calculatedStartDate
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

private struct PendingOverride {
    let year: Int
    let month: Int
    let date: Date
    let diff: Int
}

#Preview {
    NavigationStack {
        MoonsightingAdjustmentsView()
            .environmentObject(AppState())
    }
}
