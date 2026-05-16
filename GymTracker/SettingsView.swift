import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("appColorScheme") private var colorScheme = "system"
    @AppStorage("gym_unit") private var unit = "kg"
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExercise]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                List {
                    Section {
                        Picker("", selection: $colorScheme) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.cardBackground)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                    } header: {
                        sectionHeader("Appearance")
                    }

                    Section {
                        Picker("", selection: $unit) {
                            Text("Kilograms (kg)").tag("kg")
                            Text("Pounds (lb)").tag("lb")
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.cardBackground)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                    } header: {
                        sectionHeader("Weight Unit")
                    }
                    Section {
                        if customExercises.isEmpty {
                            Text("No custom exercises yet")
                                .foregroundStyle(Color.textMuted)
                                .listRowBackground(Color.cardBackground)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(customExercises) { exercise in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(exercise.category)
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .listRowBackground(Color.cardBackground)
                                .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: deleteCustomExercise)
                        }
                    } header: {
                        sectionHeader("Custom Exercises")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func deleteCustomExercise(at indexSet: IndexSet) {
        for i in indexSet {
            ExerciseData.remove(id: customExercises[i].id)
            modelContext.delete(customExercises[i])
        }
        try? modelContext.save()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
