import Foundation
import HijriCalendarCore

@MainActor
final class AppState: ObservableObject {
    @Published var reminders: [HijriReminder] = SampleData.reminders
    @Published var manualMoonsightingEnabled: Bool {
        didSet {
            guard oldValue != manualMoonsightingEnabled else { return }
            UserDefaults.standard.set(manualMoonsightingEnabled, forKey: Self.manualMoonsightingKey)
            updateRefreshLoop()
            Task {
                await refreshCalendarData(force: true)
            }
        }
    }
    @Published var lastRefresh: Date?
    @Published var calculatedDefinitions: [HijriMonthDefinition] = []
    @Published var calendarDefinitions: [HijriMonthDefinition] = []
    @Published var manualOverrides: [ManualMoonsightingOverride] = [] {
        didSet {
            ManualMoonsightingStore.save(manualOverrides)
        }
    }
    @Published var calendarError: String?
    @Published var calendarUpdateMessage: String?
    @Published var isRefreshingCalendar = false

    private let calculatedProvider = CalculatedCalendarProvider()
    private var refreshLoopTask: Task<Void, Never>?
    private static let manualMoonsightingKey = "manualMoonsightingEnabled"

    init() {
        self.manualMoonsightingEnabled = UserDefaults.standard.bool(forKey: Self.manualMoonsightingKey)
        self.manualOverrides = ManualMoonsightingStore.load()
    }

    var calendarEngine: CalendarEngine? {
        guard !calendarDefinitions.isEmpty else { return nil }
        return CalendarEngine(definitions: calendarDefinitions, calendar: Calendar.current)
    }

    func refreshCalendarData(force: Bool = false) async {
        let now = Date()
        if !force, let lastRefresh, now.timeIntervalSince(lastRefresh) < 3600 {
            return
        }

        isRefreshingCalendar = true
        calendarError = nil
        defer { isRefreshingCalendar = false }

        do {
            let calculated = try await calculatedProvider.fetchMonthDefinitions()
            calculatedDefinitions = calculated
            let previous = calendarDefinitions
            let merged = manualMoonsightingEnabled ? applyManualOverrides(to: calculated) : calculated

            calendarDefinitions = merged.sorted { $0.gregorianStartDate < $1.gregorianStartDate }
            lastRefresh = now

            let updatedMonths = detectUpdatedMonths(old: previous, new: calendarDefinitions)
            calendarUpdateMessage = updatedMonths.isEmpty ? nil : updatedMonthsMessage(for: updatedMonths)
        } catch {
            if let providerError = error as? CalendarProviderError,
               let description = providerError.errorDescription {
                calendarError = "Unable to load the calculated calendar. \(description)"
            } else {
                calendarError = "Unable to load the calculated calendar. \(error.localizedDescription)"
            }
        }
    }

    func startCalendarRefreshIfNeeded() {
        updateRefreshLoop()
    }

    private func updateRefreshLoop() {
        refreshLoopTask?.cancel()
        refreshLoopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshCalendarData()
                try? await Task.sleep(nanoseconds: 3600 * 1_000_000_000)
            }
        }
    }

    func addManualOverride(year: Int, month: Int, gregorianStartDate: Date) {
        let entry = ManualMoonsightingOverride(
            hijriYear: year,
            hijriMonth: month,
            gregorianStartDate: gregorianStartDate
        )
        manualOverrides.append(entry)
        if !manualMoonsightingEnabled {
            manualMoonsightingEnabled = true
        } else {
            Task {
                await refreshCalendarData(force: true)
            }
        }
    }

    func deleteManualOverride(id: UUID) {
        manualOverrides.removeAll { $0.id == id }
        Task {
            await refreshCalendarData(force: true)
        }
    }

    func isManualOverrideActive(_ override: ManualMoonsightingOverride) -> Bool {
        activeManualOverrides()[HijriMonthKey(year: override.hijriYear, month: override.hijriMonth)]?.id == override.id
    }

    func activeManualOverride(forYear year: Int, month: Int) -> ManualMoonsightingOverride? {
        activeManualOverrides()[HijriMonthKey(year: year, month: month)]
    }

    func isManualOverrideInferringPreviousMonth(_ override: ManualMoonsightingOverride) -> Bool {
        guard isManualOverrideActive(override) else { return false }
        guard let previousKey = HijriMonthKey(year: override.hijriYear, month: override.hijriMonth).previousMonth() else {
            return false
        }
        if activeManualOverride(forYear: previousKey.year, month: previousKey.month) != nil {
            return false
        }
        guard let previousDefinition = calendarDefinitions.first(where: {
            $0.hijriYear == previousKey.year && $0.hijriMonth == previousKey.month
        }) else {
            return false
        }
        return previousDefinition.source == .manual
    }

    private func applyManualOverrides(to calculated: [HijriMonthDefinition]) -> [HijriMonthDefinition] {
        let calculatedMap = Dictionary(uniqueKeysWithValues: calculated.map { (HijriMonthKey($0), $0) })
        let overrides = activeManualOverrides()

        var merged: [HijriMonthKey: HijriMonthDefinition] = [:]
        for definition in calculated {
            let key = HijriMonthKey(definition)
            if let override = overrides[key] {
                merged[key] = HijriMonthDefinition(
                    hijriYear: override.hijriYear,
                    hijriMonth: override.hijriMonth,
                    gregorianStartDate: override.gregorianStartDate,
                    length: definition.length,
                    source: .manual
                )
            } else {
                merged[key] = definition
            }
        }

        let keys = merged.keys.sorted { lhs, rhs in
            if lhs.year == rhs.year { return lhs.month < rhs.month }
            return lhs.year < rhs.year
        }

        var updated: [HijriMonthKey: HijriMonthDefinition] = merged
        for key in keys {
            guard let current = merged[key] else { continue }
            let nextKey = key.nextMonth()
            let fallbackLength = calculatedMap[key]?.length ?? current.length
            var resolvedLength = fallbackLength
            var resolvedSource = current.source
            if let next = nextKey.flatMap({ merged[$0] }) {
                let diff = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: current.gregorianStartDate),
                    to: Calendar.current.startOfDay(for: next.gregorianStartDate)
                ).day ?? 0

                if (29...30).contains(diff) {
                    resolvedLength = diff
                    if resolvedSource != .manual && next.source == .manual {
                        resolvedSource = .manual
                    }
                }
            }

            updated[key] = HijriMonthDefinition(
                hijriYear: current.hijriYear,
                hijriMonth: current.hijriMonth,
                gregorianStartDate: current.gregorianStartDate,
                length: resolvedLength,
                source: resolvedSource
            )
        }

        return updated.values.sorted { $0.gregorianStartDate < $1.gregorianStartDate }
    }

    private func activeManualOverrides() -> [HijriMonthKey: ManualMoonsightingOverride] {
        let grouped = Dictionary(grouping: manualOverrides) { HijriMonthKey(year: $0.hijriYear, month: $0.hijriMonth) }
        return grouped.compactMapValues { overrides in
            overrides.sorted { $0.createdAt > $1.createdAt }.first
        }
    }

    private func detectUpdatedMonths(
        old: [HijriMonthDefinition],
        new: [HijriMonthDefinition]
    ) -> [HijriMonthDefinition] {
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { (HijriMonthKey($0), $0) })
        return new.filter { definition in
            guard let previous = oldMap[HijriMonthKey(definition)] else { return true }
            return previous.gregorianStartDate != definition.gregorianStartDate
                || previous.length != definition.length
                || previous.source != definition.source
        }
    }

    private func updatedMonthsMessage(for months: [HijriMonthDefinition]) -> String {
        let labels = months.map { "\(HijriDateDisplay.monthName(for: $0.hijriMonth)) \($0.hijriYear)" }
        if labels.count == 1, let first = labels.first {
            return "Calendar updated for \(first)."
        }
        return "Calendar updated for \(labels.joined(separator: ", "))."
    }
}

private struct HijriMonthKey: Hashable {
    let year: Int
    let month: Int

    init(_ definition: HijriMonthDefinition) {
        self.year = definition.hijriYear
        self.month = definition.hijriMonth
    }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    func nextMonth() -> HijriMonthKey? {
        if month < 12 {
            return HijriMonthKey(year: year, month: month + 1)
        }
        return HijriMonthKey(year: year + 1, month: 1)
    }

    func previousMonth() -> HijriMonthKey? {
        if month > 1 {
            return HijriMonthKey(year: year, month: month - 1)
        }
        return HijriMonthKey(year: year - 1, month: 12)
    }
}
