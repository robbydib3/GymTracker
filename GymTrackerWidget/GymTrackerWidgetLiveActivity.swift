import ActivityKit
import WidgetKit
import SwiftUI

private let gymOrange = Color(red: 0.976, green: 0.451, blue: 0.086)

// MARK: - Live Activity widget

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLockScreenView(
                endDate:      context.state.endDate,
                totalSeconds: context.state.totalSeconds,
                exerciseName: context.attributes.exerciseName
            )
            .activityBackgroundTint(Color(red: 0.10, green: 0.10, blue: 0.10))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(gymOrange)
                            .font(.system(size: 14, weight: .bold))
                        Text(context.attributes.exerciseName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(gymOrange)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("GymTracker · Rest")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("Rest Timer")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(gymOrange)
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(gymOrange)
                    .font(.system(size: 12, weight: .bold))
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(gymOrange)
                    .frame(minWidth: 36)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(gymOrange)
                    .font(.system(size: 12))
            }
            .keylineTint(gymOrange)
        }
    }
}

// MARK: - Lock Screen view

private struct RestTimerLockScreenView: View {
    let endDate: Date
    let totalSeconds: Int
    let exerciseName: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(gymOrange)
                    Text("GymTracker")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(exerciseName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Rest Timer")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(gymOrange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(endDate, style: .timer)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var progressFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        return remaining / Double(totalSeconds)
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: RestTimerAttributes(exerciseName: "Bench Press")) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerAttributes.ContentState(endDate: Date().addingTimeInterval(75), totalSeconds: 90)
}
