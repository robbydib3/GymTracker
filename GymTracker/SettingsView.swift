import SwiftUI

struct SettingsView: View {
    @AppStorage("appColorScheme") private var colorScheme = "system"
    @AppStorage("gym_unit") private var unit = "kg"

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
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
