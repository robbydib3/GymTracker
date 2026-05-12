import SwiftUI

struct RestTimerView: View {
    let totalSeconds: Int
    let endDate: Date
    @Binding var isMinimized: Bool
    let onDone: () -> Void
    let onAdjust: (Date) -> Void

    // Local adjusted end date so +/-15s buttons work without touching state
    @State private var adjustedEndDate: Date
    @State private var remaining: Int
    @State private var doneFired = false

    init(totalSeconds: Int, endDate: Date, isMinimized: Binding<Bool>,
         onDone: @escaping () -> Void, onAdjust: @escaping (Date) -> Void) {
        self.totalSeconds      = totalSeconds
        self.endDate           = endDate
        self._isMinimized      = isMinimized
        self.onDone            = onDone
        self.onAdjust          = onAdjust
        self._adjustedEndDate  = State(initialValue: endDate)
        self._remaining        = State(initialValue: max(0, Int(endDate.timeIntervalSinceNow)))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isMinimized {
                pillOverlay
            } else {
                dimmedPanel
            }
        }
        .task {
            while !doneFired, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                tick()
            }
        }
        // Immediately correct remaining time when app returns to foreground
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            remaining = max(0, Int(adjustedEndDate.timeIntervalSinceNow))
            if remaining == 0, !doneFired {
                doneFired = true
                AudioManager.shared.timerDone()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDone() }
            }
        }
    }

    // MARK: - Pill (minimized)

    private var pillOverlay: some View {
        VStack {
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.3)) { isMinimized = false }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text(Fmt.duration(remaining))
                        .fontWeight(.heavy)
                        .monospacedDigit()
                    Text("tap to expand")
                        .font(.caption2)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gymOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.gymOrange.opacity(0.45), radius: 10, y: 4)
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Full panel (expanded)

    private var dimmedPanel: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3)) { isMinimized = true }
                }

            panel
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var panel: some View {
        VStack(spacing: 16) {

            // Header
            HStack {
                Text("Rest Timer")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.3)) { isMinimized = true }
                } label: {
                    Text("Minimize")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.inputBackground)
                        .foregroundStyle(Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Ring
            ZStack {
                Circle()
                    .stroke(Color.inputBackground, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                Text(Fmt.duration(remaining))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(width: 128, height: 128)

            // Adjust buttons
            HStack(spacing: 12) {
                adjustButton(label: "-15s") {
                    adjustedEndDate = adjustedEndDate.addingTimeInterval(-15)
                    onAdjust(adjustedEndDate)
                }
                adjustButton(label: "+15s") {
                    adjustedEndDate = adjustedEndDate.addingTimeInterval(15)
                    onAdjust(adjustedEndDate)
                }
            }

            // Skip
            Button(action: onDone) {
                Text("Skip Rest")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gymOrange)
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func adjustButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.inputBackground)
                .foregroundStyle(Color.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remaining) / Double(totalSeconds)
    }

    private var ringColor: Color {
        progress > 0.5 ? .gymOrange : .yellow
    }

    private func tick() {
        guard !doneFired else { return }
        remaining = max(0, Int(adjustedEndDate.timeIntervalSinceNow))
        if remaining == 0 {
            doneFired = true
            AudioManager.shared.timerDone()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDone() }
        }
    }
}
