import SwiftUI
import SwiftData

// MARK: - Local editor state (never persisted directly)

struct EditableSet: Identifiable {
    var id           = UUID()
    var targetWeight = 0.0
    var targetReps   = 10
}

struct EditableExercise: Identifiable {
    var id          = UUID()
    var exerciseId:  String
    var restSeconds  = 90
    var notes        = ""
    var sets:       [EditableSet]
}

// MARK: - Templates List

struct TemplatesView: View {
    let onStart: (WorkoutTemplate) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query private var customExercises: [CustomExercise]
    @AppStorage("gym_unit") private var unit = "kg"

    @State private var editorTemplate: WorkoutTemplate? = nil  // nil = create new
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if templates.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(templates) { template in
                                TemplateCard(
                                    template: template,
                                    unit:     unit,
                                    onStart:  { onStart(template) },
                                    onEdit:   { editorTemplate = template; showEditor = true },
                                    onDelete: { delete(template) }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTemplate = nil
                        showEditor     = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .tint(.gymOrange)
                }
            }
            .sheet(isPresented: $showEditor) {
                TemplateEditorView(
                    template:        editorTemplate,
                    customExercises: customExercises.map(\.asExerciseInfo),
                    unit:            unit,
                    onAddCustom:     addCustomExercise
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📋").font(.system(size: 48))
            Text("No templates yet")
                .fontWeight(.bold)
                .foregroundStyle(Color.textSecondary)
            Button("Create First Template") {
                editorTemplate = nil
                showEditor     = true
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.gymOrange)
            .foregroundStyle(.white)
            .fontWeight(.bold)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func delete(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
    }

    @discardableResult
    private func addCustomExercise(name: String, category: String) -> ExerciseInfo {
        let ex = CustomExercise(name: name, category: category)
        modelContext.insert(ex)
        ExerciseData.register(ex.asExerciseInfo)
        try? modelContext.save()
        return ex.asExerciseInfo
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: WorkoutTemplate
    let unit:     String
    let onStart:  () -> Void
    let onEdit:   () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(template.exercises.count) exercises · \(template.totalSetCount) sets")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button("Edit", action: onEdit)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.inputBackground)
                        .foregroundStyle(Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button { showDeleteAlert = true } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .padding(7)
                            .background(Color.inputBackground)
                            .foregroundStyle(Color.destructiveRed)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if !template.exerciseNames.isEmpty {
                Text(template.exerciseNames)
                    .font(.caption)
                    .foregroundStyle(Color.textMuted)
                    .lineLimit(2)
            }

            Button(action: onStart) {
                Label("Start Workout", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gymOrange)
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .cardStyle()
        .alert("Delete \"\(template.name)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Template Editor

struct TemplateEditorView: View {
    let template:        WorkoutTemplate?
    let customExercises: [ExerciseInfo]
    let unit:            String
    let onAddCustom:     (String, String) -> ExerciseInfo

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var name:      String
    @State private var exercises: [EditableExercise]
    @State private var showPicker = false

    init(
        template: WorkoutTemplate?,
        customExercises: [ExerciseInfo],
        unit: String,
        onAddCustom: @escaping (String, String) -> ExerciseInfo
    ) {
        self.template        = template
        self.customExercises = customExercises
        self.unit            = unit
        self.onAddCustom     = onAddCustom
        _name      = State(initialValue: template?.name ?? "")
        _exercises = State(initialValue: template?.sortedExercises.map { te in
            EditableExercise(
                exerciseId:  te.exerciseId,
                restSeconds: te.restSeconds,
                notes:       te.notes,
                sets:        te.sortedSets.map { ts in
                    EditableSet(targetWeight: ts.targetWeight, targetReps: ts.targetReps)
                }
            )
        } ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        GymTextField(label: "Template Name", placeholder: "e.g. Push Day A", text: $name)

                        ForEach($exercises) { $ex in
                            EditableExerciseCard(exercise: $ex, unit: unit, onRemove: {
                                exercises.removeAll { $0.id == ex.id }
                            })
                        }

                        Button { showPicker = true } label: {
                            Label("Add Exercise", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cardBackground)
                                .foregroundStyle(Color.textSecondary)
                                .fontWeight(.semibold)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.inputBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
                                )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(template == nil ? "Create" : "Save") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gymOrange)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView(
                    customExercises: customExercises,
                    exclude:         exercises.map(\.exerciseId),
                    onSelect: { info in
                        exercises.append(EditableExercise(
                            exerciseId: info.id,
                            sets:       [EditableSet()]
                        ))
                    },
                    onAddCustom: { name, cat in
                        let info = onAddCustom(name, cat)
                        exercises.append(EditableExercise(exerciseId: info.id, sets: [EditableSet()]))
                    }
                )
            }
        }
    }

    // Saves to SwiftData — delete + recreate exercises for simplicity
    private func save() {
        let t: WorkoutTemplate
        if let existing = template {
            t = existing
            t.name = name.trimmingCharacters(in: .whitespaces)
            for ex in t.exercises { modelContext.delete(ex) }
            t.exercises = []
        } else {
            t = WorkoutTemplate(name: name.trimmingCharacters(in: .whitespaces))
            modelContext.insert(t)
        }

        for (i, editEx) in exercises.enumerated() {
            let te = TemplateExercise(
                exerciseId:  editEx.exerciseId,
                restSeconds: editEx.restSeconds,
                notes:       editEx.notes,
                sortIndex:   i
            )
            modelContext.insert(te)
            t.exercises.append(te)

            for (j, editSet) in editEx.sets.enumerated() {
                let ts = TemplateSet(
                    targetWeight: editSet.targetWeight,
                    targetReps:   editSet.targetReps,
                    sortIndex:    j
                )
                modelContext.insert(ts)
                te.sets.append(ts)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Editable Exercise Card (inside template editor)

private struct EditableExerciseCard: View {
    @Binding var exercise: EditableExercise
    let unit:     String
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ExerciseData.name(for: exercise.exerciseId))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                    Text(ExerciseData.info(for: exercise.exerciseId)?.category ?? "")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.destructiveRed)
                        .font(.title3)
                }
            }

            // Rest seconds
            HStack {
                Text("Rest (sec)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                TextField("90", value: $exercise.restSeconds, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.inputBorder, lineWidth: 1))
                    .foregroundStyle(Color.textPrimary)
            }

            // Set column headers
            HStack(spacing: 6) {
                Text("#").frame(width: 24)
                Text("TARGET \(unit.uppercased())").frame(maxWidth: .infinity)
                Text("TARGET REPS").frame(maxWidth: .infinity)
                Spacer().frame(width: 24)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.textMuted)

            // Sets
            ForEach($exercise.sets) { $set in
                HStack(spacing: 6) {
                    let idx = exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                    Text("\(idx + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.gymOrange)
                        .frame(width: 24)

                    TextField("0", value: $set.targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.inputBackground)
                        .foregroundStyle(Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.inputBorder, lineWidth: 1))

                    TextField("10", value: $set.targetReps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.inputBackground)
                        .foregroundStyle(Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.inputBorder, lineWidth: 1))

                    Button {
                        exercise.sets.removeAll { $0.id == set.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.destructiveRed)
                    }
                    .frame(width: 24)
                    .opacity(exercise.sets.count > 1 ? 1 : 0.25)
                    .disabled(exercise.sets.count <= 1)
                }
            }

            // Add set
            Button {
                let last = exercise.sets.last
                exercise.sets.append(EditableSet(
                    targetWeight: last?.targetWeight ?? 0,
                    targetReps:   last?.targetReps ?? 10
                ))
            } label: {
                Text("+ Add Set")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.rowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.inputBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            }

            // Notes
            GymTextField(label: "Notes", placeholder: "Machine settings, cues, reminders…", text: $exercise.notes)
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Exercise Picker (shared with ActiveWorkoutView)

struct ExercisePickerView: View {
    let customExercises: [ExerciseInfo]
    let exclude:         [String]
    let onSelect:        (ExerciseInfo) -> Void
    let onAddCustom:     (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var search   = ""
    @State private var category = "All"
    @State private var creating = false
    @State private var newName  = ""
    @State private var newCat   = exerciseCategories.first ?? "Chest"

    private var allExercises: [ExerciseInfo] {
        (builtInExercises + customExercises)
            .filter { !exclude.contains($0.id) }
    }

    private var allCategories: [String] {
        var seen  = Set<String>()
        var cats  = ["All"]
        (builtInExercises + customExercises).forEach {
            if seen.insert($0.category).inserted { cats.append($0.category) }
        }
        return cats
    }

    private var filtered: [ExerciseInfo] {
        allExercises.filter {
            (category == "All" || $0.category == category) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if creating {
                    createForm
                } else {
                    pickerList
                }
            }
            .navigationTitle(creating ? "New Exercise" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(creating ? "Back" : "Cancel") {
                        if creating { creating = false } else { dismiss() }
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                if creating {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { confirmCreate() }
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gymOrange)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var pickerList: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textMuted)
                TextField("Search exercises…", text: $search)
                    .foregroundStyle(Color.textPrimary)
                    .tint(.gymOrange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(allCategories, id: \.self) { cat in
                        CategoryChip(label: cat, isSelected: category == cat) {
                            category = cat
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 6)

            // Results
            List {
                ForEach(filtered) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textPrimary)
                                HStack(spacing: 4) {
                                    Text(exercise.category)
                                    if exercise.isCustom { Text("· Custom") }
                                }
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.gymOrange)
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                }

                Button {
                    newName  = search
                    creating = true
                } label: {
                    Label(
                        filtered.isEmpty && !search.isEmpty ? "Create \"\(search)\"" : "Create custom exercise",
                        systemImage: "plus.circle"
                    )
                    .foregroundStyle(Color.gymOrange)
                    .fontWeight(.semibold)
                }
                .listRowBackground(Color.cardBackground)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var createForm: some View {
        VStack(spacing: 16) {
            GymTextField(label: "Exercise Name", placeholder: "e.g. Zercher Squat", text: $newName)

            VStack(alignment: .leading, spacing: 4) {
                Text("Category")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Picker("Category", selection: $newCat) {
                    ForEach(exerciseCategories + ["Other"], id: \.self) { Text($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }

            Spacer()
        }
        .padding()
    }

    private func confirmCreate() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        onAddCustom(name, newCat)
        dismiss()
    }
}
