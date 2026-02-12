import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                ReminderListView()
            }
            .tabItem {
                Label("Reminders", systemImage: "list.bullet")
            }

            NavigationStack {
                HijriCalendarView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .onAppear {
            appState.startCalendarRefreshIfNeeded()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
