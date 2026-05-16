import Foundation

struct ExerciseInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    var isCustom: Bool = false
}

// MARK: - Built-in exercise list

let builtInExercises: [ExerciseInfo] = [
    // Chest
    ExerciseInfo(id: "bench_press",      name: "Bench Press",           category: "Chest"),
    ExerciseInfo(id: "incline_bench",    name: "Incline Bench Press",   category: "Chest"),
    ExerciseInfo(id: "decline_bench",    name: "Decline Bench Press",   category: "Chest"),
    ExerciseInfo(id: "chest_fly",        name: "Chest Fly",             category: "Chest"),
    ExerciseInfo(id: "cable_fly",        name: "Cable Fly",             category: "Chest"),
    ExerciseInfo(id: "dips",             name: "Dips",                  category: "Chest"),
    // Back
    ExerciseInfo(id: "deadlift",         name: "Deadlift",              category: "Back"),
    ExerciseInfo(id: "bent_over_row",    name: "Bent Over Row",         category: "Back"),
    ExerciseInfo(id: "lat_pulldown",     name: "Lat Pulldown",          category: "Back"),
    ExerciseInfo(id: "pull_up",          name: "Pull-up",               category: "Back"),
    ExerciseInfo(id: "cable_row",        name: "Cable Row",             category: "Back"),
    ExerciseInfo(id: "tbar_row",         name: "T-Bar Row",             category: "Back"),
    ExerciseInfo(id: "single_arm_row",   name: "Single Arm Row",        category: "Back"),
    ExerciseInfo(id: "face_pull",        name: "Face Pull",             category: "Back"),
    // Legs
    ExerciseInfo(id: "squat",            name: "Squat",                 category: "Legs"),
    ExerciseInfo(id: "leg_press",        name: "Leg Press",             category: "Legs"),
    ExerciseInfo(id: "rdl",              name: "Romanian Deadlift",     category: "Legs"),
    ExerciseInfo(id: "leg_extension",    name: "Leg Extension",         category: "Legs"),
    ExerciseInfo(id: "leg_curl",         name: "Leg Curl",              category: "Legs"),
    ExerciseInfo(id: "calf_raise",       name: "Calf Raise",            category: "Legs"),
    ExerciseInfo(id: "hack_squat",       name: "Hack Squat",            category: "Legs"),
    ExerciseInfo(id: "bulgarian_split",  name: "Bulgarian Split Squat", category: "Legs"),
    ExerciseInfo(id: "hip_thrust",       name: "Hip Thrust",            category: "Legs"),
    // Shoulders
    ExerciseInfo(id: "ohp",             name: "Overhead Press",        category: "Shoulders"),
    ExerciseInfo(id: "lateral_raise",   name: "Lateral Raise",         category: "Shoulders"),
    ExerciseInfo(id: "front_raise",     name: "Front Raise",           category: "Shoulders"),
    ExerciseInfo(id: "rear_delt_fly",   name: "Rear Delt Fly",         category: "Shoulders"),
    ExerciseInfo(id: "arnold_press",    name: "Arnold Press",          category: "Shoulders"),
    // Biceps
    ExerciseInfo(id: "barbell_curl",    name: "Barbell Curl",          category: "Biceps"),
    ExerciseInfo(id: "dumbbell_curl",   name: "Dumbbell Curl",         category: "Biceps"),
    ExerciseInfo(id: "hammer_curl",     name: "Hammer Curl",           category: "Biceps"),
    ExerciseInfo(id: "preacher_curl",   name: "Preacher Curl",         category: "Biceps"),
    ExerciseInfo(id: "cable_curl",      name: "Cable Curl",            category: "Biceps"),
    // Triceps
    ExerciseInfo(id: "tricep_pushdown", name: "Tricep Pushdown",       category: "Triceps"),
    ExerciseInfo(id: "skull_crusher",   name: "Skull Crusher",         category: "Triceps"),
    ExerciseInfo(id: "close_grip_bench",name: "Close Grip Bench",      category: "Triceps"),
    ExerciseInfo(id: "overhead_ext",    name: "Overhead Extension",    category: "Triceps"),
    // Core
    ExerciseInfo(id: "cable_crunch",    name: "Cable Crunch",          category: "Core"),
    ExerciseInfo(id: "ab_wheel",        name: "Ab Wheel Rollout",      category: "Core"),
    ExerciseInfo(id: "weighted_crunch", name: "Weighted Crunch",       category: "Core"),
]

let exerciseCategories: [String] = {
    var seen = Set<String>()
    return builtInExercises.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
}()

// MARK: - Lookup helpers

enum ExerciseData {
    private static var map: [String: ExerciseInfo] = {
        Dictionary(uniqueKeysWithValues: builtInExercises.map { ($0.id, $0) })
    }()

    static func info(for id: String) -> ExerciseInfo? { map[id] }

    static func name(for id: String) -> String { map[id]?.name ?? id }

    static func register(_ exercise: ExerciseInfo) {
        map[exercise.id] = exercise
    }

    static func remove(id: String) {
        map.removeValue(forKey: id)
    }
}
