import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Avatar circle (reusable in toolbar + account sheet)

struct AvatarCircleView: View {
    let imageData: Data?
    let name: String

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined()
    }

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if !initials.isEmpty {
                ZStack {
                    Color.gymOrange
                    Text(initials.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(Color.textMuted)
            }
        }
        .clipShape(Circle())
    }
}

// MARK: - Camera picker (UIImagePickerController wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Account screen

struct AccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutLog.startedAt) private var logs: [WorkoutLog]
    @AppStorage("gym_unit") private var unit = "kg"

    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showSourcePicker = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false

    private var profile: UserProfile? { profiles.first }

    // MARK: Lifecycle

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        photoSection
                        nameSection
                        statsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gymOrange)
                }
            }
            .confirmationDialog("Choose Photo", isPresented: $showSourcePicker) {
                Button("Camera") { showCamera = true }
                Button("Photo Library") { showPhotoLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showPhotoLibrary, selection: $photoItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(selectedImage: $pickedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        pickedImage = img
                    }
                }
            }
            .onAppear { name = profile?.name ?? "" }
        }
    }

    // MARK: Photo section

    private var photoSection: some View {
        VStack(spacing: 10) {
            Button { showSourcePicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    currentAvatarView
                        .frame(width: 90, height: 90)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.gymOrange)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text("Change Photo")
                .font(.caption)
                .foregroundStyle(Color.gymOrange)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var currentAvatarView: some View {
        if let img = pickedImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
        } else {
            AvatarCircleView(imageData: profile?.profileImageData, name: name)
                .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
        }
    }

    // MARK: Name section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField("Your name", text: $name)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.inputBorder, lineWidth: 1))
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: Stats section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Stats")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(spacing: 0) {
                statRow(icon: "figure.strengthtraining.traditional",
                        label: "Workouts",
                        value: "\(logs.count)")
                Divider().padding(.leading, 44)

                statRow(icon: "scalemass.fill",
                        label: "Total Weight",
                        value: formattedTotalVolume)
                Divider().padding(.leading, 44)

                statRow(icon: "trophy.fill",
                        label: "PRs Set",
                        value: "\(prCount)")
                Divider().padding(.leading, 44)

                statRow(icon: "timer",
                        label: "Avg Duration",
                        value: avgDuration)
                Divider().padding(.leading, 44)

                statRow(icon: "flame.fill",
                        label: "Current Streak",
                        value: streakText)
                Divider().padding(.leading, 44)

                statRow(icon: "calendar",
                        label: "Member Since",
                        value: memberSince)
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder, lineWidth: 1))
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.gymOrange)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.textSecondary)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: Computed stats

    private var formattedTotalVolume: String {
        let total = logs.reduce(0.0) { $0 + $1.totalVolume }
        if total >= 1_000 {
            return String(format: "%.1fk %@", total / 1_000, unit)
        }
        return String(format: "%.0f %@", total, unit)
    }

    private var prCount: Int {
        var count = 0
        var runningMax: [String: Double] = [:]
        for log in logs {
            for ex in log.exercises {
                if let best = ex.sets.map(\.weight).max(),
                   best > (runningMax[ex.exerciseId] ?? 0) {
                    count += 1
                    runningMax[ex.exerciseId] = best
                }
            }
        }
        return count
    }

    private var avgDuration: String {
        guard !logs.isEmpty else { return "—" }
        let avg = logs.reduce(0) { $0 + $1.durationSeconds } / logs.count
        return Fmt.workoutDuration(avg)
    }

    private var streakText: String {
        let cal = Calendar.current
        let workoutDays = Set(logs.map { cal.startOfDay(for: $0.startedAt) })
        var day = cal.startOfDay(for: Date())
        if !workoutDays.contains(day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var streak = 0
        while workoutDays.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        if streak == 0 { return "—" }
        return streak == 1 ? "1 day" : "\(streak) days"
    }

    private var memberSince: String {
        let date = profile?.memberSince ?? Date()
        return date.formatted(.dateTime.month(.wide).year())
    }

    // MARK: Save

    private func saveProfile() {
        let p: UserProfile
        if let existing = profile {
            p = existing
        } else {
            let earliest = logs.min(by: { $0.startedAt < $1.startedAt })?.startedAt ?? Date()
            p = UserProfile(name: name, memberSince: earliest)
            modelContext.insert(p)
        }
        p.name = name
        if let img = pickedImage,
           let data = img.jpegData(compressionQuality: 0.7) {
            p.profileImageData = data
        }
        try? modelContext.save()
    }
}
