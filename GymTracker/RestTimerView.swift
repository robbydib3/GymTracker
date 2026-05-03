import SwiftUI

struct RestTimerView: View {
    let totalSeconds: Int
    @Binding var isMinimized: Bool
    let onDone: () -> Void

    @State private var remaining: Int
    @State private var doneFired = false


    init(totalSeconds: Int, isMinimized: Binding<Bool>, onDone: @escaping () -> Void) {
        self.totalSeconds  = totalSeconds
        self._isMinimized  = isMinimized
        self.onDone        = onDone
        self._remaining    = State(initialValue: totalSeconds)
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
                adjustButton(label: "-15s") { remaining = max(0, remaining - 15) }
                adjustButton(label: "+15s") { remaining += 15 }
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
        guard !doneFired, remaining > 0 else { return }
        remaining -= 1
        if remaining == 0 {
            doneFired = true
            AudioManager.shared.timerDone()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDone() }
        }
    }
}
