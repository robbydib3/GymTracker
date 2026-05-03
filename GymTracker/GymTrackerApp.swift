import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            WorkoutTemplate.self,
            WorkoutLog.self,
            CustomExercise.self,
        ])
    }
}
