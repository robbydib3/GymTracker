import Foundation
import SwiftData

// MARK: - Template models

@Model
final class WorkoutTemplate {
    var id: String
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []

    init(id: String = UUID().uuidString, name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    var sortedExercises: [TemplateExercise] {
        exercises.sorted { $0.sortIndex < $1.sortIndex }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var exerciseNames: String {
        sortedExercises
            .compactMap { ExerciseData.name(for: $0.exerciseId) }
            .joined(separator: " · ")
    }
}

@Model
final class TemplateExercise {
    var exerciseId: String
    var restSeconds: Int
    var notes: String
    var sortIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \TemplateSet.exercise)
    var sets: [TemplateSet] = []

    var template: WorkoutTemplate?

    init(exerciseId: String, restSeconds: Int = 90, notes: String = "", sortIndex: Int = 0) {
        self.exerciseId = exerciseId
        self.restSeconds = restSeconds
        self.notes = notes
        self.sortIndex = sortIndex
    }

    var sortedSets: [TemplateSet] {
        sets.sorted { $0.sortIndex < $1.sortIndex }
    }
}

@Model
final class TemplateSet {
    var targetWeight: Double
    var targetReps: Int
    var sortIndex: Int

    var exercise: TemplateExercise?

    init(targetWeight: Double = 0, targetReps: Int = 10, sortIndex: Int = 0) {
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.sortIndex = sortIndex
    }
}

// MARK: - Log models

@Model
final class WorkoutLog {
    var id: String
    var templateId: String
    var templateName: String
    var startedAt: Date
    var completedAt: Date
    var durationSeconds: Int

    @Relationship(deleteRule: .cascade, inverse: \LogExercise.log)
    var exercises: [LogExercise] = []

    init(
        id: String = UUID().uuidString,
        templateId: String,
        templateName: String,
        startedAt: Date,
        completedAt: Date,
        durationSeconds: Int
    ) {
        self.id = id
        self.templateId = templateId
        self.templateName = templateName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
    }

    var sortedExercises: [LogExercise] {
        exercises.sorted { $0.sortIndex < $1.sortIndex }
    }

    var totalVolume: Double {
        exercises.reduce(0) { total, ex in
            total + ex.sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
        }
    }
}

@Model
final class LogExercise {
    var exerciseId: String
    var exerciseName: String
    var notes: String
    var sortIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \LogSet.exercise)
    var sets: [LogSet] = []

    var log: WorkoutLog?

    init(exerciseId: String, exerciseName: String, notes: String = "", sortIndex: Int = 0) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.notes = notes
        self.sortIndex = sortIndex
    }

    var sortedSets: [LogSet] {
        sets.sorted { $0.sortIndex < $1.sortIndex }
    }
}

@Model
final class LogSet {
    var weight: Double
    var reps: Int
    var sortIndex: Int

    var exercise: LogExercise?

    init(weight: Double, reps: Int, sortIndex: Int = 0) {
        self.weight = weight
        self.reps = reps
        self.sortIndex = sortIndex
    }
}

// MARK: - Custom exercise

@Model
final class CustomExercise {
    var id: String
    var name: String
    var category: String

    init(id: String = UUID().uuidString, name: String, category: String) {
        self.id = id
        self.name = name
        self.category = category
    }

    var asExerciseInfo: ExerciseInfo {
        ExerciseInfo(id: id, name: name, category: category, isCustom: true)
    }
}
