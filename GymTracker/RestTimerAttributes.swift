import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date       // drives Text(endDate, style: .timer) auto-countdown
        var totalSeconds: Int   // original duration; used for progress arc denominator
    }

    var exerciseName: String
}
