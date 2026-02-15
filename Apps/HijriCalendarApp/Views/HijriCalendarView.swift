import SwiftUI
import HijriCalendarCore

struct HijriCalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedIndex = 0
    @State private var selectedMonthKey: HijriMonthKey?
    @State private var hasInitializedSelection = false
    @State private var selectedDay: CalendarDaySelection?

    private let calendar = Calendar.current

    var body: some View {
        Group {
            if appState.isRefreshingCalendar && appState.calendarDefinitions.isEmpty {
                ProgressView("Loading calendar…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = appState.calendarError, appState.calendarDefinitions.isEmpty {
                calendarErrorView(message: error)
            } else if let definition = selectedDefinition {
                calendarContent(for: definition)
            } else {
                calendarEmptyView
            }
        }
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Today") {
                    jumpToToday()
                }
                .disabled(todayMonthIndex == nil || todayMonthIndex == selectedIndex)
            }
            if appState.authorityEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.isRefreshingCalendar {
                        ProgressView()
                    } else {
                        Button("Sync") {
                            Task {
                                await appState.refreshCalendarData(force: true)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            if appState.calendarDefinitions.isEmpty {
                await appState.refreshCalendarData(force: true)
            }
        }
        .onAppear {
            syncSelectionIfNeeded()
        }
        .onChange(of: appState.calendarDefinitions) { _ in
            syncSelectionIfNeeded()
        }
        .sheet(item: $selectedDay) { day in
            DayRemindersSheet(selection: day)
                .environmentObject(appState)
        }
    }

    private var calendarEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Calendar data is unavailable.")
                .font(.headline)
            Button("Try Again") {
                Task {
                    await appState.refreshCalendarData(force: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func calendarErrorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await appState.refreshCalendarData(force: true)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func calendarContent(for definition: HijriMonthDefinition) -> some View {
        let cells = monthCells(for: definition)
        let reminderDays = reminderDays(in: definition)
        return ScrollView {
            VStack(spacing: 16) {
                calendarHeader(for: definition)

                Text(attributionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let todayLabel = todayHijriLabel {
                    Text(todayLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                weekdayHeader

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(cells.indices, id: \.self) { index in
                        if let cell = cells[index] {
                            let day = calendar.startOfDay(for: cell.gregorianDate)
                            calendarDayCell(cell, in: definition, hasReminder: reminderDays.contains(day))
                        } else {
                            Color.clear
                                .frame(height: 52)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            await appState.refreshCalendarData(force: true)
        }
    }

    private func calendarHeader(for definition: HijriMonthDefinition) -> some View {
        HStack(alignment: .center) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(selectedIndex == 0)

            Spacer()

            VStack(spacing: 4) {
                Text("\(HijriDateDisplay.monthName(for: definition.hijriMonth)) \(definition.hijriYear)")
                    .font(.headline)
                Text(gregorianRangeLabel(for: definition))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(sourceLabel(for: definition))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedIndex >= sortedDefinitions.count - 1)
        }
        .padding(.top, 12)
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbols
        return HStack(spacing: 8) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarDayCell(
        _ cell: HijriCalendarCell,
        in definition: HijriMonthDefinition,
        hasReminder: Bool
    ) -> some View {
        let gregorianDay = calendar.component(.day, from: cell.gregorianDate)
        return VStack(spacing: 4) {
            Text("\(cell.hijriDay)")
                .font(.headline)
                .foregroundStyle(cell.isToday ? Color.accentColor : Color.primary)
            Text("\(gregorianDay)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Circle()
                .fill(hasReminder ? Color.red : Color.clear)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(6)
        .background(cell.isToday ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            presentDayDetails(for: cell, in: definition)
        }
    }

    private var sortedDefinitions: [HijriMonthDefinition] {
        appState.calendarDefinitions.sorted { lhs, rhs in
            if lhs.hijriYear == rhs.hijriYear {
                if lhs.hijriMonth == rhs.hijriMonth {
                    return lhs.gregorianStartDate < rhs.gregorianStartDate
                }
                return lhs.hijriMonth < rhs.hijriMonth
            }
            return lhs.hijriYear < rhs.hijriYear
        }
    }

    private var selectedDefinition: HijriMonthDefinition? {
        guard sortedDefinitions.indices.contains(selectedIndex) else { return nil }
        return sortedDefinitions[selectedIndex]
    }

    private var todayMonthIndex: Int? {
        let today = calendar.startOfDay(for: Date())
        return sortedDefinitions.firstIndex { definition in
            let start = calendar.startOfDay(for: definition.gregorianStartDate)
            guard let end = definition.gregorianEndDate(calendar: calendar) else { return false }
            return today >= start && today <= end
        }
    }

    private var todayHijriLabel: String? {
        guard let engine = appState.calendarEngine,
              let hijriDate = engine.hijriDate(for: Date()) else {
            return nil
        }
        return "Today: \(HijriDateDisplay.formatted(hijriDate))"
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekdayIndex = max(calendar.firstWeekday - 1, 0)
        let prefix = symbols[firstWeekdayIndex...]
        let suffix = symbols[..<firstWeekdayIndex]
        return Array(prefix + suffix)
    }

    private func monthCells(for definition: HijriMonthDefinition) -> [HijriCalendarCell?] {
        let start = calendar.startOfDay(for: definition.gregorianStartDate)
        let weekday = calendar.component(.weekday, from: start)
        let offset = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [HijriCalendarCell?] = Array(repeating: nil, count: offset)
        for day in 1...definition.length {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { continue }
            let isToday = calendar.isDateInToday(date)
            cells.append(HijriCalendarCell(hijriDay: day, gregorianDate: date, isToday: isToday))
        }
        return cells
    }

    private func reminderDays(in definition: HijriMonthDefinition) -> Set<Date> {
        guard let engine = appState.calendarEngine else { return [] }

        let monthStart = calendar.startOfDay(for: definition.gregorianStartDate)
        guard let monthEndExclusive = calendar.date(byAdding: .day, value: definition.length, to: monthStart) else {
            return []
        }

        let maxDuration = max(appState.reminders.map(\.durationDays).max() ?? 1, 1)
        let lookbackDays = maxDuration - 1
        let queryStart = calendar.date(byAdding: .day, value: -lookbackDays, to: monthStart) ?? monthStart
        let queryInterval = DateInterval(start: queryStart, end: monthEndExclusive)

        var days = Set<Date>()
        for reminder in appState.reminders {
            let occurrences = engine.occurrenceDates(for: reminder, within: queryInterval)
            for occurrence in occurrences {
                let day = calendar.startOfDay(for: occurrence)
                if day >= monthStart && day < monthEndExclusive {
                    days.insert(day)
                }
            }
        }
        return days
    }

    private func gregorianRangeLabel(for definition: HijriMonthDefinition) -> String {
        let start = definition.gregorianStartDate
        let end = definition.gregorianEndDate(calendar: calendar) ?? start

        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.dateFormat = "MMM"

        let startMonthLabel = monthFormatter.string(from: start)
        let endMonthLabel = monthFormatter.string(from: end)

        if startYear == endYear && startMonth == endMonth {
            return "\(startMonthLabel) \(startYear)"
        }
        if startYear == endYear {
            return "\(startMonthLabel)–\(endMonthLabel) \(startYear)"
        }
        return "\(startMonthLabel) \(startYear) – \(endMonthLabel) \(endYear)"
    }

    private func sourceLabel(for definition: HijriMonthDefinition) -> String {
        switch definition.source {
        case .moonsighting:
            return "Moonsighting"
        case .manual:
            return "Manual (user)"
        case .authority:
            return "Authority (\(appState.authorityDisplayName))"
        case .calculated:
            if appState.manualMoonsightingEnabled {
                return "Calculated (manual pending)"
            }
            if appState.authorityEnabled {
                return "Calculated (authority pending)"
            }
            return "Calculated"
        }
    }

    private var attributionText: String {
        if appState.authorityEnabled && appState.manualMoonsightingEnabled {
            return "Calculated dates: Fiqh Council (fiqhcouncil.org/calendar). Authority: \(appState.authorityDisplayName). Manual overrides enabled."
        }
        if appState.authorityEnabled {
            return "Calculated dates: Fiqh Council (fiqhcouncil.org/calendar). Authority: \(appState.authorityDisplayName)."
        }
        if appState.manualMoonsightingEnabled {
            return "Calculated dates: Fiqh Council (fiqhcouncil.org/calendar). Manual moonsighting updates are user-provided."
        }
        return "Calculated dates: Fiqh Council (fiqhcouncil.org/calendar)."
    }

    private func moveMonth(by offset: Int) {
        let newIndex = selectedIndex + offset
        applySelection(index: newIndex)
    }

    private func syncSelectionIfNeeded() {
        guard !sortedDefinitions.isEmpty else { return }
        if let key = selectedMonthKey,
           let index = sortedDefinitions.firstIndex(where: { $0.hijriYear == key.year && $0.hijriMonth == key.month }) {
            selectedIndex = index
            hasInitializedSelection = true
            return
        }

        if let current = appState.calendarEngine?.monthDefinition(containing: Date()),
           let index = sortedDefinitions.firstIndex(where: { $0.hijriYear == current.hijriYear && $0.hijriMonth == current.hijriMonth }) {
            applySelection(index: index)
        } else {
            applySelection(index: max(sortedDefinitions.count - 1, 0))
        }
        hasInitializedSelection = true
    }

    private func applySelection(index: Int) {
        guard sortedDefinitions.indices.contains(index) else { return }
        selectedIndex = index
        let definition = sortedDefinitions[index]
        selectedMonthKey = HijriMonthKey(year: definition.hijriYear, month: definition.hijriMonth)
    }

    private func jumpToToday() {
        guard let index = todayMonthIndex else { return }
        applySelection(index: index)
    }

    private func presentDayDetails(for cell: HijriCalendarCell, in definition: HijriMonthDefinition) {
        selectedDay = CalendarDaySelection(
            gregorianDate: calendar.startOfDay(for: cell.gregorianDate),
            hijriYear: definition.hijriYear,
            hijriMonth: definition.hijriMonth,
            hijriDay: cell.hijriDay
        )
    }
}

private struct CalendarDaySelection: Identifiable {
    let id = UUID()
    let gregorianDate: Date
    let hijriYear: Int
    let hijriMonth: Int
    let hijriDay: Int
}

private struct DayRemindersSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var pendingReminder: HijriReminder?

    let selection: CalendarDaySelection

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gregorianDateLabel)
                            .font(.headline)
                        Text(hijriDateLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reminders") {
                    if matchingReminderIDs.isEmpty {
                        Text("No reminders for this date.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matchingReminderIDs, id: \.self) { reminderID in
                            if let reminder = reminder(with: reminderID),
                               let reminderBinding = reminderBinding(for: reminderID) {
                                NavigationLink {
                                    ReminderDetailView(reminder: reminderBinding)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reminder.title)
                                            .font(.body)
                                        Text(timeAndRecurrenceLabel(for: reminder))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Day")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentAddReminder()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Reminder")
                }
            }
        }
        .sheet(item: $pendingReminder) { reminder in
            ReminderEditorView(reminder: reminder) { newReminder in
                appState.reminders.append(newReminder)
            }
        }
    }

    private var matchingReminderIDs: [UUID] {
        appState.reminders
            .filter(occursOnSelectedDay)
            .sorted { lhs, rhs in
                if lhs.time.hour == rhs.time.hour {
                    return lhs.time.minute < rhs.time.minute
                }
                return lhs.time.hour < rhs.time.hour
            }
            .map(\.id)
    }

    private var gregorianDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: selection.gregorianDate)
    }

    private var hijriDateLabel: String {
        "\(selection.hijriDay) \(HijriDateDisplay.monthName(for: selection.hijriMonth)) \(selection.hijriYear)"
    }

    private func occursOnSelectedDay(_ reminder: HijriReminder) -> Bool {
        guard let engine = appState.calendarEngine else { return false }
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: selection.gregorianDate) else {
            return false
        }
        let interval = DateInterval(start: selection.gregorianDate, end: dayEnd)
        return !engine.occurrenceDates(for: reminder, within: interval).isEmpty
    }

    private func reminder(with id: UUID) -> HijriReminder? {
        appState.reminders.first(where: { $0.id == id })
    }

    private func reminderBinding(for id: UUID) -> Binding<HijriReminder>? {
        guard let index = appState.reminders.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $appState.reminders[index]
    }

    private func timeAndRecurrenceLabel(for reminder: HijriReminder) -> String {
        let now = Date()
        let date = calendar.date(
            bySettingHour: reminder.time.hour,
            minute: reminder.time.minute,
            second: 0,
            of: now
        ) ?? now

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let recurrenceLabel = reminder.recurrence == .annual ? "Annual" : "One-time"
        return "\(formatter.string(from: date)) • \(recurrenceLabel)"
    }

    private func presentAddReminder() {
        pendingReminder = HijriReminder(
            title: "",
            hijriDate: HijriDate(month: selection.hijriMonth, day: selection.hijriDay),
            recurrence: .annual,
            time: ReminderTime(hour: 0, minute: 0),
            durationDays: 1
        )
    }
}

private struct HijriCalendarCell {
    let hijriDay: Int
    let gregorianDate: Date
    let isToday: Bool
}

private struct HijriMonthKey: Hashable {
    let year: Int
    let month: Int
}

#Preview {
    NavigationStack {
        HijriCalendarView()
            .environmentObject(AppState())
    }
}
