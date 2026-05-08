import SwiftUI
import SwiftData
import UserNotifications

@main
struct GymTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
        }
        .modelContainer(for: [
            WorkoutTemplate.self,
            WorkoutLog.self,
            CustomExercise.self,
        ])
    }
}
