import SwiftUI
import SwiftData
import Charts

// MARK: - Root

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeWorkout: ActiveWorkoutState? = nil
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let workout = activeWorkout {
                ActiveWorkoutView(
                    state:     workout,
                    onFinish:  { finishWorkout(workout) },
                    onDiscard: { workout.stop(); activeWorkout = nil }
                )
                .transition(.opacity)
            } else {
                TabView(selection: $selectedTab) {
                    HomeView(onStart: startWorkout)
                        .tabItem { Label("Home",      systemImage: "house.fill") }
                        .tag(0)

                    TemplatesView(onStart: startWorkout)
                        .tabItem { Label("Templates", systemImage: "list.clipboard.fill") }
                        .tag(1)

                    HistoryView()
                        .tabItem { Label("History",   systemImage: "calendar") }
                        .tag(2)

                    ProgressChartView()
                        .tabItem { Label("Progress",  systemImage: "chart.xyaxis.line") }
                        .tag(3)

                    SettingsView()
                        .tabItem { Label("Settings",  systemImage: "gearshape") }
                        .tag(4)
                }
                .tint(.gymOrange)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeWorkout == nil)
    }

    private func startWorkout(_ template: WorkoutTemplate) {
        activeWorkout = ActiveWorkoutState(template: template)
    }

    private func finishWorkout(_ workout: ActiveWorkoutState) {
        // Sync exercise notes back to the template for next session
        for ex in workout.exercises {
            workout.template.exercises
                .first { $0.exerciseId == ex.exerciseId }
                .map   { $0.notes = ex.notes }
        }
        let log = workout.buildLog()
        modelContext.insert(log)
        try? modelContext.save()
        workout.stop()
        activeWorkout = nil
        selectedTab   = 2   // jump to History
    }
}

// MARK: - Home

struct HomeView: View {
    let onStart: (WorkoutTemplate) -> Void

    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutLog.startedAt) private var logs: [WorkoutLog]
    @AppStorage("gym_unit") private var unit = "kg"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        quickStart
                        recentWorkouts
                    }
                    .padding()
                }
            }
            .navigationTitle("GymTracker")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Quick start

    @ViewBuilder
    private var quickStart: some View {
        if templates.isEmpty {
            VStack(spacing: 8) {
                Text("📋").font(.system(size: 44))
                Text("No templates yet")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textSecondary)
                Text("Go to Templates to create your first workout")
                    .font(.caption)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Quick Start")
                ForEach(templates.prefix(4)) { template in
                    Button { onStart(template) } label: {
                        HStack {
                            Text(template.name)
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(template.exercises.count) exercises")
                                .font(.caption)
                                .opacity(0.85)
                            Image(systemName: "play.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.gymOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: Recent workouts

    @ViewBuilder
    private var recentWorkouts: some View {
        let recent = logs.suffix(3).reversed() as [WorkoutLog]
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Recent Workouts")
                ForEach(recent) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.templateName).fontWeight(.bold)
                                Text("\(Fmt.date(log.startedAt)) · \(Fmt.workoutDuration(log.durationSeconds))")
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Text("\(String(format: "%.0f", log.totalVolume)) \(unit)")
                                .fontWeight(.bold)
                                .foregroundStyle(Color.gymOrange)
                                .font(.subheadline)
                        }
                        Text(log.sortedExercises.map(\.exerciseName).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(1)
                    }
                    .padding(12)
                    .cardStyle()
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLog.startedAt, order: .reverse) private var logs: [WorkoutLog]
    @AppStorage("gym_unit") private var unit = "kg"

    @State private var expandedId: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if logs.isEmpty {
                    VStack(spacing: 8) {
                        Text("📅").font(.system(size: 44))
                        Text("No workouts logged yet")
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textSecondary)
                        Text("Start a workout from a template to see history")
                            .font(.caption).foregroundStyle(Color.textMuted)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(logs) { log in
                            logRow(log)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete { indexSet in
                            for i in indexSet { modelContext.delete(logs[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func logRow(_ log: WorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedId = expandedId == log.id ? nil : log.id
                }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(log.templateName)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textPrimary)
                        Text("\(Fmt.date(log.startedAt)) · \(Fmt.workoutDuration(log.durationSeconds))")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(String(format: "%.0f", log.totalVolume)) \(unit)")
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gymOrange)
                            .font(.subheadline)
                        Image(systemName: expandedId == log.id ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .padding(12)
            }

            // Expanded detail
            if expandedId == log.id {
                Divider().background(Color.cardBorder).padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(log.sortedExercises) { ex in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ex.exerciseName)
                                .fontWeight(.semibold)
                                .font(.subheadline)
                                .foregroundStyle(Color.textPrimary)
                            ForEach(ex.sortedSets.indices, id: \.self) { j in
                                let s = ex.sortedSets[j]
                                HStack(spacing: 6) {
                                    Text("S\(j + 1)")
                                        .foregroundStyle(Color.gymOrange)
                                        .font(.caption.bold())
                                        .frame(width: 22, alignment: .leading)
                                    Text("\(String(format: "%.4g", s.weight)) \(unit) × \(s.reps) reps")
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)
                                    Spacer()
                                    Text("= \(String(format: "%.0f", s.weight * Double(s.reps))) \(unit)")
                                        .font(.caption)
                                        .foregroundStyle(Color.textMuted)
                                }
                            }
                            if !ex.notes.isEmpty {
                                Text("📝 \(ex.notes)")
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                    .italic()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.rowBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
    }
}

// MARK: - Progress

struct ProgressChartView: View {
    @Query(sort: \WorkoutLog.startedAt) private var logs: [WorkoutLog]
    @Query private var customExercises: [CustomExercise]
    @AppStorage("gym_unit") private var unit = "kg"

    @State private var selectedExerciseId: String? = nil
    @State private var metric: ProgressMetric = .maxWeight

    enum ProgressMetric: String, CaseIterable {
        case maxWeight = "Max Weight"
        case volume    = "Volume"
        case maxReps   = "Max Reps"
    }

    private var exercisesWithData: [ExerciseInfo] {
        let seen = Set(logs.flatMap { $0.exercises.map(\.exerciseId) })
        return (builtInExercises + customExercises.map(\.asExerciseInfo)).filter { seen.contains($0.id) }
    }

    private struct ChartPoint: Identifiable {
        var id   = UUID()
        let date:      Date
        let value:     Double
    }

    private var chartPoints: [ChartPoint] {
        guard let id = selectedExerciseId else { return [] }
        return logs.compactMap { log -> ChartPoint? in
            guard let ex = log.exercises.first(where: { $0.exerciseId == id }),
                  !ex.sets.isEmpty else { return nil }
            let value: Double
            switch metric {
            case .maxWeight: value = ex.sets.map(\.weight).max() ?? 0
            case .volume:    value = ex.sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
            case .maxReps:   value = Double(ex.sets.map(\.reps).max() ?? 0)
            }
            return ChartPoint(date: log.startedAt, value: value)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if exercisesWithData.isEmpty {
                            VStack(spacing: 8) {
                                Text("📈").font(.system(size: 44))
                                Text("No data yet")
                                    .fontWeight(.bold).foregroundStyle(Color.textSecondary)
                                Text("Complete some workouts to see your progress")
                                    .font(.caption).foregroundStyle(Color.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 60)
                        } else {
                            exerciseSelector
                            if selectedExerciseId != nil {
                                metricPicker
                                chartCard
                                statsRow
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var exerciseSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(exercisesWithData) { ex in
                        CategoryChip(
                            label: ex.name,
                            isSelected: selectedExerciseId == ex.id
                        ) {
                            selectedExerciseId = ex.id
                        }
                    }
                }
            }
        }
    }

    private var metricPicker: some View {
        HStack(spacing: 6) {
            ForEach(ProgressMetric.allCases, id: \.self) { m in
                Button { metric = m } label: {
                    Text(m.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(metric == m ? Color.gymOrange : Color.inputBackground)
                        .foregroundStyle(metric == m ? .white : Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var chartCard: some View {
        VStack {
            if chartPoints.count >= 2 {
                Chart(chartPoints) { point in
                    LineMark(
                        x: .value("Date",  point.date),
                        y: .value(metric.rawValue, point.value)
                    )
                    .foregroundStyle(Color.gymOrange)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date",  point.date),
                        y: .value(metric.rawValue, point.value)
                    )
                    .foregroundStyle(Color.gymOrange)
                    .symbolSize(40)

                    AreaMark(
                        x: .value("Date",  point.date),
                        y: .value(metric.rawValue, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.gymOrange.opacity(0.25), Color.gymOrange.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.textSecondary)
                        AxisGridLine().foregroundStyle(Color.cardBorder)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisValueLabel().foregroundStyle(Color.textSecondary)
                        AxisGridLine().foregroundStyle(Color.cardBorder)
                    }
                }
                .frame(height: 200)
            } else {
                Text("Need at least 2 sessions to show chart")
                    .font(.caption)
                    .foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding(14)
        .cardStyle()
    }

    @ViewBuilder
    private var statsRow: some View {
        if !chartPoints.isEmpty {
            let vals   = chartPoints.map(\.value)
            let allEx  = chartPoints
            HStack(spacing: 10) {
                statCard("Best Weight", value: "\(String(format: "%.4g", allEx.map(\.value).max() ?? 0)) \(unit)",
                         show: metric == .maxWeight)
                statCard("Best Volume", value: "\(String(format: "%.0f", allEx.map(\.value).max() ?? 0)) \(unit)",
                         show: metric == .volume)
                statCard("Best Reps",   value: "\(Int(vals.max() ?? 0))",
                         show: metric == .maxReps)
            }
            // Always show all three for the selected exercise across all metrics
            .hidden()

            // Real stats row — always show all three best values
            let allPoints: [ProgressMetric: Double] = {
                guard let id = selectedExerciseId else { return [:] }
                var result: [ProgressMetric: Double] = [:]
                ProgressMetric.allCases.forEach { m in
                    result[m] = logs.compactMap { log -> Double? in
                        guard let ex = log.exercises.first(where: { $0.exerciseId == id }),
                              !ex.sets.isEmpty else { return nil }
                        switch m {
                        case .maxWeight: return ex.sets.map(\.weight).max()
                        case .volume:    return ex.sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
                        case .maxReps:   return Double(ex.sets.map(\.reps).max() ?? 0)
                        }
                    }.max()
                }
                return result
            }()

            HStack(spacing: 10) {
                statCard("Best Weight",
                         value: "\(String(format: "%.4g", allPoints[.maxWeight] ?? 0)) \(unit)")
                statCard("Best Volume",
                         value: "\(String(format: "%.0f", allPoints[.volume] ?? 0)) \(unit)")
                statCard("Best Reps",
                         value: "\(Int(allPoints[.maxReps] ?? 0))")
            }
        }
    }

    private func statCard(_ label: String, value: String, show: Bool = true) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.gymOrange)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.4)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .cardStyle()
    }
}
