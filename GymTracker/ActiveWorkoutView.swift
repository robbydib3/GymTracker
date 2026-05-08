import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var state: ActiveWorkoutState
    let onFinish: () -> Void
    let onDiscard: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExercise]
    @AppStorage("gym_unit") private var unit = "kg"

    @State private var showDiscardAlert = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                progressBar
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(state.exercises.indices, id: \.self) { i in
                            ExerciseCard(
                                exercise:      $state.exercises[i],
                                unit:          unit,
                                onCompleteSet: { j in state.completeSet(exIndex: i, setIndex: j) },
                                onAddSet:      {    state.addSet(exIndex: i) },
                                onDeleteSet:   { j in state.deleteSet(exIndex: i, setIndex: j) }
                            )
                        }

                        ghostButton("+ Add Exercise") { state.showExercisePicker = true }

                        Button("Discard Workout") { showDiscardAlert = true }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cardBackground)
                            .foregroundStyle(Color.destructiveRed)
                            .fontWeight(.semibold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.destructiveRed.opacity(0.4), lineWidth: 1))
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }

            // Toast
            if state.showToast {
                VStack {
                    Spacer()
                    Text("✓ Rest done — start your next set!")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.completedGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                        .padding(.bottom, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        // Rest timer overlay
        .overlay {
            if let totalSec = state.restTimerSeconds, let endDate = state.timerEndDate {
                RestTimerView(
                    totalSeconds: totalSec,
                    endDate:      endDate,
                    isMinimized:  $state.isTimerMinimized,
                    onDone:       { state.dismissTimer() }
                )
                .transition(.opacity)
            }
        }
        // Exercise picker sheet
        .sheet(isPresented: $state.showExercisePicker) {
            ExercisePickerView(
                customExercises: customExercises.map(\.asExerciseInfo),
                exclude:         state.exercises.map(\.exerciseId),
                onSelect: { info in
                    state.addExercise(info)
                },
                onAddCustom: { name, category in
                    let ex = CustomExercise(name: name, category: category)
                    modelContext.insert(ex)
                    ExerciseData.register(ex.asExerciseInfo)
                    state.addExercise(ex.asExerciseInfo)
                }
            )
        }
        .alert("Discard Workout?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { onDiscard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All progress for this session will be lost.")
        }
        .onAppear  { UIApplication.shared.isIdleTimerDisabled = true  }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.template.name)
                    .fontWeight(.heavy)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text("\(Fmt.duration(state.elapsedSeconds)) · \(state.doneSets)/\(state.totalSets) sets")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Discard") { showDiscardAlert = true }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.inputBackground)
                    .foregroundStyle(Color.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Finish") { finishWorkout() }
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.completedGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .overlay(alignment: .bottom) {
            Divider().background(Color.cardBorder)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.inputBackground.frame(height: 4)
                Color.gymOrange
                    .frame(width: geo.size.width * state.progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: state.progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Helpers

    private func ghostButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.inputBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
        }
    }

    private func finishWorkout() {
        // Sync notes from workout back to template for next time
        for ex in state.exercises {
            if let templateEx = state.template.exercises.first(where: { $0.exerciseId == ex.exerciseId }) {
                templateEx.notes = ex.notes
            }
        }
        let log = state.buildLog()
        modelContext.insert(log)
        try? modelContext.save()
        state.stop()
        onFinish()
    }
}

// MARK: - Exercise Card

private struct ExerciseCard: View {
    @Binding var exercise: ActiveExercise
    let unit: String
    let onCompleteSet: (Int) -> Void
    let onAddSet: () -> Void
    let onDeleteSet: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exerciseName)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(ExerciseData.info(for: exercise.exerciseId)?.category ?? "") · Rest \(exercise.restSeconds)s")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                if exercise.allDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.completedGreen)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(exercise.allDone ? Color.completedBg : Color.cardBackground)

            Divider().background(Color.cardBorder)

            // Set column headers
            HStack(spacing: 6) {
                Text("SET").frame(width: 28)
                Text("PREV").frame(maxWidth: .infinity)
                Text(unit.uppercased()).frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Spacer().frame(width: 24)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.textMuted)
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Set rows
            VStack(spacing: 6) {
                ForEach(exercise.sets.indices, id: \.self) { j in
                    SetRow(
                        set:       $exercise.sets[j],
                        setNumber: j + 1,
                        canDelete: exercise.sets.count > 1,
                        onComplete: { onCompleteSet(j) },
                        onDelete:   { onDeleteSet(j) }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            // Add set
            Button(action: onAddSet) {
                Text("+ Add Set")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.rowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.inputBorder, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // Notes
            notesField
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .cardStyle(highlighted: exercise.allDone)
    }

    private var notesField: some View {
        ZStack(alignment: .topLeading) {
            if exercise.notes.isEmpty {
                Text("Notes — machine settings, cues…")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 9)
            }
            TextEditor(text: $exercise.notes)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 80)
        }
        .background(Color.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cardBorder, lineWidth: 1))
    }
}

// MARK: - Set Row

private struct SetRow: View {
    @Binding var set: ActiveSet
    let setNumber: Int
    let canDelete: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Completion circle
            Button(action: { if !set.isDone { onComplete() } }) {
                ZStack {
                    Circle()
                        .strokeBorder(set.isDone ? Color.completedGreen : Color.inputBorder, lineWidth: 2)
                        .background(Circle().fill(set.isDone ? Color.completedGreen : Color.clear))
                    if set.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(setNumber)")
                            .font(.caption.bold())
                            .foregroundStyle(Color.gymOrange)
                    }
                }
            }
            .frame(width: 28, height: 28)
            .disabled(set.isDone)

            // Previous weight placeholder
            Text("—")
                .frame(maxWidth: .infinity)
                .font(.caption)
                .foregroundStyle(Color.textMuted)

            // Weight
            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(set.isDone ? Color.completedInput : Color.inputBackground)
                .foregroundStyle(set.isDone ? Color.completedGreen : Color.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.inputBorder, lineWidth: 1))
                .disabled(set.isDone)

            // Reps
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(set.isDone ? Color.completedInput : Color.inputBackground)
                .foregroundStyle(set.isDone ? Color.completedGreen : Color.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.inputBorder, lineWidth: 1))
                .disabled(set.isDone)

            // Delete
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.destructiveRed)
            }
            .frame(width: 24)
            .opacity(canDelete ? 1 : 0.25)
            .disabled(!canDelete)
        }
    }
}
