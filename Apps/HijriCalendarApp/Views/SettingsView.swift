import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Calendar") {
                Toggle("Use manual moonsighting updates", isOn: $appState.manualMoonsightingEnabled)
                NavigationLink("Moonsighting adjustments") {
                    MoonsightingAdjustmentsView()
                }
                HStack {
                    Text("Last refresh")
                    Spacer()
                    Text(lastRefreshText)
                        .foregroundStyle(.secondary)
                }
                if appState.isRefreshingCalendar {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Refreshing...")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Refresh now") {
                    Task {
                        await appState.refreshCalendarData(force: true)
                    }
                }
                .disabled(appState.isRefreshingCalendar)

                if let message = appState.calendarUpdateMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let error = appState.calendarError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Authority") {
                Toggle("Follow authority updates (CHC)", isOn: $appState.authorityEnabled)
                TextField("Authority feed URL", text: $appState.authorityFeedURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Manual overrides always take precedence over authority updates.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let authority = appState.authorityInfo {
                    Text("Authority: \(authority.name)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let error = appState.authorityError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Backup") {
                Button("Export backup") {
                }
                Button("Restore backup") {
                }
            }
        }
        .navigationTitle("Settings")
    }

    private var lastRefreshText: String {
        guard let date = appState.lastRefresh else {
            return "Never"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
