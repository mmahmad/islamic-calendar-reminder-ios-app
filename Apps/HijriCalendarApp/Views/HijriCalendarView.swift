import SwiftUI
import HijriCalendarCore

struct HijriCalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedIndex = 0
    @State private var selectedMonthKey: HijriMonthKey?
    @State private var hasInitializedSelection = false
    @State private var pendingReminder: HijriReminder?

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
        .sheet(item: $pendingReminder) { reminder in
            ReminderEditorView(reminder: reminder) { newReminder in
                appState.reminders.append(newReminder)
            }
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
                            calendarDayCell(cell, in: definition)
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

    private func calendarDayCell(_ cell: HijriCalendarCell, in definition: HijriMonthDefinition) -> some View {
        let gregorianDay = calendar.component(.day, from: cell.gregorianDate)
        return VStack(spacing: 4) {
            Text("\(cell.hijriDay)")
                .font(.headline)
                .foregroundStyle(cell.isToday ? Color.accentColor : Color.primary)
            Text("\(gregorianDay)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(6)
        .background(cell.isToday ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            presentReminder(for: cell, month: definition.hijriMonth)
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

    private func presentReminder(for cell: HijriCalendarCell, month: Int) {
        let reminder = HijriReminder(
            title: "",
            hijriDate: HijriDate(month: month, day: cell.hijriDay),
            recurrence: .annual,
            time: ReminderTime(hour: 0, minute: 0),
            durationDays: 1
        )
        pendingReminder = reminder
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
