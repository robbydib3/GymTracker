import SwiftUI
import SwiftData
import UserNotifications

@main
struct GymTrackerApp: App {
    @AppStorage("appColorScheme") private var colorScheme = "system"

    private var preferredScheme: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredScheme)
                .onAppear {
                    UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
        }
        .modelContainer(for: [
            WorkoutTemplate.self,
            WorkoutLog.self,
            CustomExercise.self,
            UserProfile.self,
        ])
    }
}
