import SwiftUI
import HijriCalendarCore

@main
struct HijriCalendarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
