// Claude Code edit test
// Hello I'm Claude
import ActivityKit
import Foundation
import Observation
import SwiftData
import UserNotifications

// MARK: - Value types (in-memory only, never persisted)

struct ActiveSet: Identifiable {
    var id    = UUID()
    var weight: Double
    var reps:   Int
    var isDone  = false
}

struct ActiveExercise: Identifiable {
    var id           = UUID()
    var exerciseId:    String
    var exerciseName:  String
    var restSeconds:   Int
    var notes:         String
    var sets:         [ActiveSet]

    var allDone: Bool { sets.allSatisfy(\.isDone) }
}

// MARK: - Observable state

@Observable
final class ActiveWorkoutState {

    // Workout data
    var exercises: [ActiveExercise]
    let template:   WorkoutTemplate

    // UI state
    var elapsedSeconds    = 0
    var restTimerSeconds: Int?   // non-nil while rest timer is showing
    var timerEndDate:     Date?  // absolute end time; source of truth for background-safe countdown
    var isTimerMinimized  = false
    var showToast         = false
    private var _currentActivity: AnyObject?  // type-erased Activity<RestTimerAttributes>
    var showExercisePicker = false

    let startedAt = Date()
    private var elapsedTimer: Timer?

    // MARK: Init

    init(template: WorkoutTemplate) {
        self.template  = template
        self.exercises = template.sortedExercises.map { te in
            ActiveExercise(
                exerciseId:   te.exerciseId,
                exerciseName: ExerciseData.name(for: te.exerciseId),
                restSeconds:  te.restSeconds,
                notes:        te.notes,
                sets:         te.sortedSets.map { ts in
                    ActiveSet(weight: ts.targetWeight, reps: ts.targetReps)
                }
            )
        }
        startElapsedTimer()
    }

    // MARK: - Computed

    var doneSets:  Int    { exercises.flatMap(\.sets).filter(\.isDone).count }
    var totalSets: Int    { exercises.flatMap(\.sets).count }
    var progress:  Double { totalSets > 0 ? Double(doneSets) / Double(totalSets) : 0 }

    // MARK: - Set actions

    func completeSet(exIndex: Int, setIndex: Int) {
        exercises[exIndex].sets[setIndex].isDone = true
        AudioManager.shared.setDone()
        let rest          = exercises[exIndex].restSeconds
        restTimerSeconds  = rest
        let end           = Date().addingTimeInterval(Double(rest))
        timerEndDate      = end
        isTimerMinimized  = false
        scheduleTimerNotification(at: end)
        if #available(iOS 16.2, *) {
            startLiveActivity(exerciseName: exercises[exIndex].exerciseName, endDate: end, totalSeconds: rest)
        }
    }

    func updateWeight(exIndex: Int, setIndex: Int, to value: Double) {
        exercises[exIndex].sets[setIndex].weight = value
    }

    func updateReps(exIndex: Int, setIndex: Int, to value: Int) {
        exercises[exIndex].sets[setIndex].reps = value
    }

    func addSet(exIndex: Int) {
        let last = exercises[exIndex].sets.last
        exercises[exIndex].sets.append(
            ActiveSet(weight: last?.weight ?? 0, reps: last?.reps ?? 10)
        )
    }

    func deleteSet(exIndex: Int, setIndex: Int) {
        guard exercises[exIndex].sets.count > 1 else { return }
        exercises[exIndex].sets.remove(at: setIndex)
    }

    func updateNotes(exIndex: Int, to value: String) {
        exercises[exIndex].notes = value
    }

    func addExercise(_ info: ExerciseInfo) {
        exercises.append(ActiveExercise(
            exerciseId:   info.id,
            exerciseName: info.name,
            restSeconds:  90,
            notes:        "",
            sets:         [ActiveSet(weight: 0, reps: 10)]
        ))
    }

    func dismissTimer() {
        cancelTimerNotification()
        if #available(iOS 16.2, *) { endLiveActivity() }
        restTimerSeconds = nil
        timerEndDate     = nil
        isTimerMinimized = false
        showToast        = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Build log for persistence
    //
    // Creates the SwiftData object graph. Caller must insert the returned
    // WorkoutLog into a ModelContext; SwiftData cascades to children.

    func buildLog() -> WorkoutLog {
        let log = WorkoutLog(
            templateId:      template.id,
            templateName:    template.name,
            startedAt:       startedAt,
            completedAt:     Date(),
            durationSeconds: elapsedSeconds
        )

        for (i, ex) in exercises.enumerated() {
            let completedSets = ex.sets.filter(\.isDone)
            guard !completedSets.isEmpty else { continue }

            let logEx = LogExercise(
                exerciseId:   ex.exerciseId,
                exerciseName: ex.exerciseName,
                notes:        ex.notes,
                sortIndex:    i
            )
            log.exercises.append(logEx)

            for (j, s) in completedSets.enumerated() {
                logEx.sets.append(LogSet(weight: s.weight, reps: s.reps, sortIndex: j))
            }
        }

        return log
    }

    // MARK: - Notifications

    private func scheduleTimerNotification(at endDate: Date) {
        let content       = UNMutableNotificationContent()
        content.title     = "Rest Complete"
        content.body      = "Time to start your next set!"
        content.sound     = .default
        let delay         = max(1, endDate.timeIntervalSinceNow)
        let trigger       = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request       = UNNotificationRequest(identifier: "rest-timer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
    }

    // MARK: - Live Activity (iOS 16.2+)

    func adjustTimerEndDate(_ newEndDate: Date) {
        timerEndDate = newEndDate
        if #available(iOS 16.2, *) {
            updateLiveActivity(endDate: newEndDate, totalSeconds: restTimerSeconds ?? 60)
        }
    }

    @available(iOS 16.2, *)
    private func startLiveActivity(exerciseName: String, endDate: Date, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let old = _currentActivity as? Activity<RestTimerAttributes> {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
        let attrs   = RestTimerAttributes(exerciseName: exerciseName)
        let state   = RestTimerAttributes.ContentState(endDate: endDate, totalSeconds: totalSeconds)
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(10))
        do {
            _currentActivity = try Activity<RestTimerAttributes>.request(
                attributes: attrs, content: content, pushType: nil
            )
        } catch { }
    }

    @available(iOS 16.2, *)
    private func updateLiveActivity(endDate: Date, totalSeconds: Int) {
        guard let activity = _currentActivity as? Activity<RestTimerAttributes> else { return }
        let state   = RestTimerAttributes.ContentState(endDate: endDate, totalSeconds: totalSeconds)
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(10))
        Task { await activity.update(content) }
    }

    @available(iOS 16.2, *)
    private func endLiveActivity() {
        guard let activity = _currentActivity as? Activity<RestTimerAttributes> else { return }
        _currentActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - Cleanup

    func stop() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        if #available(iOS 16.2, *) { endLiveActivity() }
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }
}
