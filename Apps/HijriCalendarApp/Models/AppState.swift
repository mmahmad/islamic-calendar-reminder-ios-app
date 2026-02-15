import Foundation
import HijriCalendarCore

@MainActor
final class AppState: ObservableObject {
    @Published var reminders: [HijriReminder] = [] {
        didSet {
            reminderStore.save(reminders)
        }
    }
    @Published var authorityEnabled: Bool {
        didSet {
            guard oldValue != authorityEnabled else { return }
            UserDefaults.standard.set(authorityEnabled, forKey: Self.authorityEnabledKey)
            Task {
                if authorityEnabled {
                    await refreshAuthorityDirectory(force: true)
                }
                await refreshCalendarData(force: true)
            }
        }
    }
    @Published var authorityBaseURLString: String {
        didSet {
            guard oldValue != authorityBaseURLString else { return }
            UserDefaults.standard.set(authorityBaseURLString, forKey: Self.authorityBaseURLKey)
            Task {
                await refreshAuthorityDirectory(force: true)
                await refreshCalendarData(force: true)
            }
        }
    }
    @Published var selectedAuthoritySlug: String {
        didSet {
            guard oldValue != selectedAuthoritySlug else { return }
            UserDefaults.standard.set(selectedAuthoritySlug, forKey: Self.selectedAuthoritySlugKey)
            Task {
                await refreshCalendarData(force: true)
            }
        }
    }
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
    @Published var authorityInfo: AuthorityCalendarProvider.AuthorityInfo?
    @Published var availableAuthorities: [AuthorityDirectoryEntry] = []
    @Published var authorityError: String?
    @Published var calendarError: String?
    @Published var calendarUpdateMessage: String?
    @Published var calendarUpdatedMonths: [String] = []
    @Published var isRefreshingCalendar = false
    @Published var isRefreshingAuthorities = false

    private let reminderStore: any ReminderStoring
    private let calculatedProvider = CalculatedCalendarProvider()
    private var refreshLoopTask: Task<Void, Never>?
    private var authorityDirectoryLastRefresh: Date?
    private static let authorityEnabledKey = "authorityEnabled"
    private static let authorityBaseURLKey = "authorityBaseURL"
    private static let selectedAuthoritySlugKey = "selectedAuthoritySlug"
    private static let legacyAuthorityFeedURLKey = "authorityFeedURL"
    private static let manualMoonsightingKey = "manualMoonsightingEnabled"
    private static let defaultAuthorityBaseURL = ""
    private static let defaultSelectedAuthoritySlug = ""

    init(reminderStore: any ReminderStoring = JSONReminderStore()) {
        self.reminderStore = reminderStore
        self.reminders = reminderStore.load()
        self.authorityEnabled = UserDefaults.standard.bool(forKey: Self.authorityEnabledKey)
        let storedBaseURL = UserDefaults.standard.string(forKey: Self.authorityBaseURLKey) ?? Self.defaultAuthorityBaseURL
        let storedSlug = UserDefaults.standard.string(forKey: Self.selectedAuthoritySlugKey) ?? Self.defaultSelectedAuthoritySlug
        let migrated = Self.migratedAuthorityConfig(baseURL: storedBaseURL, slug: storedSlug)
        self.authorityBaseURLString = migrated.baseURL
        self.selectedAuthoritySlug = migrated.slug
        self.manualMoonsightingEnabled = UserDefaults.standard.bool(forKey: Self.manualMoonsightingKey)
        self.manualOverrides = ManualMoonsightingStore.load()
    }

    var calendarEngine: CalendarEngine? {
        guard !calendarDefinitions.isEmpty else { return nil }
        return CalendarEngine(definitions: calendarDefinitions, calendar: Calendar.current)
    }

    var authorityBaseURL: URL? {
        let trimmed = authorityBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var authorityFeedURL: URL? {
        guard let baseURL = authorityBaseURL else { return nil }
        let slug = selectedAuthoritySlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else { return nil }
        return baseURL
            .appendingPathComponent("authority")
            .appendingPathComponent(slug)
    }

    var authorityDisplayName: String {
        if let name = authorityInfo?.name {
            return name
        }
        if let match = availableAuthorities.first(where: { $0.slug == selectedAuthoritySlug }) {
            return match.name
        }
        if selectedAuthoritySlug.isEmpty {
            return "Selected authority"
        }
        return selectedAuthoritySlug
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }

    func refreshCalendarData(force: Bool = false) async {
        let now = Date()
        if !force, let lastRefresh, now.timeIntervalSince(lastRefresh) < 3600 {
            return
        }

        isRefreshingCalendar = true
        calendarError = nil
        authorityError = nil
        authorityInfo = nil
        defer { isRefreshingCalendar = false }

        do {
            let calculated = try await calculatedProvider.fetchMonthDefinitions()
            calculatedDefinitions = calculated
            let previous = calendarDefinitions
            var merged = calculated

            if authorityEnabled {
                await refreshAuthorityDirectory(force: force)
                if let feedURL = authorityFeedURL {
                    do {
                        let provider = AuthorityCalendarProvider(feedURL: feedURL)
                        let (info, overrides) = try await provider.fetchAuthorityOverrides()
                        authorityInfo = info
                        merged = applyOverrides(
                            to: merged,
                            overrides: overrides.map { MonthStartOverride(year: $0.hijriYear, month: $0.hijriMonth, date: $0.gregorianStartDate) },
                            overrideSource: .authority
                        )
                    } catch {
                        if isCancellation(error) {
                            return
                        }
                        authorityError = "Authority feed is unavailable right now."
                    }
                } else if authorityBaseURL == nil {
                    authorityError = "Authority API base URL is missing."
                } else {
                    authorityError = "Select an authority to follow."
                }
            }

            if manualMoonsightingEnabled {
                merged = applyOverrides(
                    to: merged,
                    overrides: activeManualOverrides()
                        .values
                        .map { MonthStartOverride(year: $0.hijriYear, month: $0.hijriMonth, date: $0.gregorianStartDate) },
                    overrideSource: .manual
                )
            }

            calendarDefinitions = merged.sorted { $0.gregorianStartDate < $1.gregorianStartDate }
            lastRefresh = now

            let updatedMonths = detectUpdatedMonths(old: previous, new: calendarDefinitions)
            if updatedMonths.isEmpty {
                calendarUpdateMessage = nil
                calendarUpdatedMonths = []
            } else {
                let notice = updatedMonthsNotice(for: updatedMonths)
                calendarUpdateMessage = notice.summary
                calendarUpdatedMonths = notice.months
            }
        } catch {
            if isCancellation(error) {
                return
            }
            if let providerError = error as? CalendarProviderError,
               let description = providerError.errorDescription {
                calendarError = "Unable to load the calculated calendar. \(description)"
            } else {
                calendarError = "Unable to load the calculated calendar. \(error.localizedDescription)"
            }
        }
    }

    func refreshAuthorityDirectory(force: Bool = false) async {
        let now = Date()
        if !force,
           let authorityDirectoryLastRefresh,
           now.timeIntervalSince(authorityDirectoryLastRefresh) < 3600 {
            return
        }

        guard let baseURL = authorityBaseURL else {
            availableAuthorities = []
            authorityDirectoryLastRefresh = nil
            return
        }

        isRefreshingAuthorities = true
        defer { isRefreshingAuthorities = false }

        do {
            let listURL = baseURL.appendingPathComponent("authorities")
            let (data, response) = try await URLSession.shared.data(from: listURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw CalendarProviderError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(AuthorityDirectoryResponse.self, from: data)
            let authorities = decoded.authorities
                .filter { $0.isActive ?? true }
                .sorted { lhs, rhs in lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }

            availableAuthorities = authorities
            authorityDirectoryLastRefresh = now

            if selectedAuthoritySlug.isEmpty, let firstSlug = authorities.first?.slug {
                selectedAuthoritySlug = firstSlug
            }
        } catch {
            if isCancellation(error) {
                return
            }
            availableAuthorities = []
            authorityDirectoryLastRefresh = nil
            if authorityEnabled {
                authorityError = "Authority directory is unavailable right now."
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

    private func applyOverrides(
        to base: [HijriMonthDefinition],
        overrides: [MonthStartOverride],
        overrideSource: CalendarSource
    ) -> [HijriMonthDefinition] {
        let baseMap = Dictionary(uniqueKeysWithValues: base.map { (HijriMonthKey($0), $0) })
        let overrideMap = Dictionary(uniqueKeysWithValues: overrides.map { (HijriMonthKey(year: $0.year, month: $0.month), $0) })

        var merged: [HijriMonthKey: HijriMonthDefinition] = [:]
        for definition in base {
            let key = HijriMonthKey(definition)
            if let override = overrideMap[key] {
                merged[key] = HijriMonthDefinition(
                    hijriYear: override.year,
                    hijriMonth: override.month,
                    gregorianStartDate: override.date,
                    length: definition.length,
                    source: overrideSource
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
            let fallbackLength = baseMap[key]?.length ?? current.length
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
                    let nextKey = HijriMonthKey(year: next.hijriYear, month: next.hijriMonth)
                    if resolvedSource != .manual, overrideMap[nextKey] != nil {
                        resolvedSource = overrideSource
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

    private func updatedMonthsNotice(for months: [HijriMonthDefinition]) -> (summary: String, months: [String]) {
        let labels = months.map { "\(HijriDateDisplay.monthName(for: $0.hijriMonth)) \($0.hijriYear)" }
        if labels.count == 1, let first = labels.first {
            return ("Calendar updated for \(first).", labels)
        }
        if labels.count <= 3 {
            return ("Calendar updated for \(labels.joined(separator: ", ")).", labels)
        }
        return ("Calendar updated for \(labels.count) months.", labels)
    }

    private static func migratedAuthorityConfig(baseURL: String, slug: String) -> (baseURL: String, slug: String) {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBaseURL.isEmpty && !trimmedSlug.isEmpty {
            return (trimmedBaseURL, trimmedSlug)
        }

        guard
            let legacyFeedURL = UserDefaults.standard.string(forKey: legacyAuthorityFeedURLKey),
            let legacyURL = URL(string: legacyFeedURL)
        else {
            return (trimmedBaseURL, trimmedSlug)
        }

        let pathParts = legacyURL.pathComponents
        guard
            let authorityIndex = pathParts.firstIndex(of: "authority"),
            pathParts.count > authorityIndex + 1
        else {
            return (trimmedBaseURL, trimmedSlug)
        }

        let migratedSlug = String(pathParts[authorityIndex + 1])
        var components = URLComponents()
        components.scheme = legacyURL.scheme
        components.host = legacyURL.host
        components.port = legacyURL.port
        let migratedBaseURL = components.string ?? ""

        let resolvedBaseURL = trimmedBaseURL.isEmpty ? migratedBaseURL : trimmedBaseURL
        let resolvedSlug = trimmedSlug.isEmpty ? migratedSlug : trimmedSlug
        return (resolvedBaseURL, resolvedSlug)
    }
}

private struct AuthorityDirectoryResponse: Decodable {
    let authorities: [AuthorityDirectoryEntry]
}

struct AuthorityDirectoryEntry: Decodable, Hashable, Identifiable {
    let slug: String
    let name: String
    let regionCode: String
    let methodology: String
    let isActive: Bool?

    var id: String { slug }
}

private struct MonthStartOverride {
    let year: Int
    let month: Int
    let date: Date
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
